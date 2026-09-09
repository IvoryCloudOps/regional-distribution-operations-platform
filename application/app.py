"""
Regional Distribution Operations Platform - internal operations application.

Small Flask app serving inventory lookup, order processing, shipment tracking,
warehouse operations, and basic reporting for ~200-300 internal employees.
Runs on the existing private EC2/ASG tier behind the internal ALB and reads/
writes to the existing RDS MySQL database. See application/README.md.
"""

import csv
import io
import logging
import os
import sys
from datetime import datetime

import boto3
from flask import Flask, jsonify, redirect, render_template, request, url_for

import db

logging.basicConfig(
    stream=sys.stdout,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
logger = logging.getLogger("distribution_app")

AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
S3_BUCKET = os.environ.get("S3_BUCKET", "")

app = Flask(__name__)
logger.info("Distribution Operations application starting up")

_s3_client = boto3.client("s3", region_name=AWS_REGION)

ORDER_STATUSES = ["Pending", "Processing", "Ready to Ship", "Shipped", "Completed", "Cancelled"]
SHIPMENT_STATUSES = ["Preparing", "Shipped", "In Transit", "Delivered", "Delayed"]

STOCK_STATUS_CASE = """
    CASE
        WHEN i.quantity_available <= 0 THEN 'Out of Stock'
        WHEN i.quantity_available <= i.reorder_level THEN 'Low Stock'
        ELSE 'In Stock'
    END
"""


# ---------------------------------------------------------------------------
# Health endpoints
# ---------------------------------------------------------------------------

@app.route("/health")
def health():
    """ALB target group health check: process is alive. Does not touch RDS."""
    return jsonify(status="ok"), 200


@app.route("/health/db")
def health_db():
    """Optional deeper check; deliberately separate from ALB health above."""
    ok, message = db.check_health()
    return jsonify(status="ok" if ok else "error", detail=message), (200 if ok else 503)


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

@app.route("/")
def index():
    return redirect(url_for("dashboard"))


@app.route("/dashboard")
def dashboard():
    metrics = get_dashboard_metrics()
    inventory_by_warehouse = db.query(
        """
        SELECT w.name AS warehouse, COALESCE(SUM(i.quantity_available), 0) AS units
        FROM warehouses w
        LEFT JOIN inventory i ON i.warehouse_id = w.warehouse_id
        GROUP BY w.warehouse_id, w.name
        ORDER BY w.name
        """
    )
    return render_template("dashboard.html", metrics=metrics, inventory_by_warehouse=inventory_by_warehouse)


def get_dashboard_metrics():
    orders_today = db.query_one(
        "SELECT COUNT(*) AS n FROM orders WHERE order_date = CURDATE()"
    )["n"]
    orders_this_month = db.query_one(
        "SELECT COUNT(*) AS n FROM orders WHERE YEAR(order_date) = YEAR(CURDATE()) AND MONTH(order_date) = MONTH(CURDATE())"
    )["n"]
    open_orders = db.query_one(
        "SELECT COUNT(*) AS n FROM orders WHERE status NOT IN ('Completed', 'Cancelled')"
    )["n"]
    completed_orders = db.query_one(
        "SELECT COUNT(*) AS n FROM orders WHERE status = 'Completed'"
    )["n"]
    active_shipments = db.query_one(
        "SELECT COUNT(*) AS n FROM shipments WHERE status IN ('Preparing', 'Shipped', 'In Transit')"
    )["n"]
    delayed_shipments = db.query_one(
        "SELECT COUNT(*) AS n FROM shipments WHERE status = 'Delayed'"
    )["n"]
    low_stock_skus = db.query_one(
        "SELECT COUNT(*) AS n FROM inventory WHERE quantity_available <= reorder_level"
    )["n"]
    return {
        "orders_today": orders_today,
        "orders_this_month": orders_this_month,
        "open_orders": open_orders,
        "completed_orders": completed_orders,
        "active_shipments": active_shipments,
        "delayed_shipments": delayed_shipments,
        "low_stock_skus": low_stock_skus,
    }


# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------

@app.route("/inventory")
def inventory():
    search = request.args.get("q", "").strip()
    warehouse_id = request.args.get("warehouse_id", "")
    warehouses = db.query("SELECT warehouse_id, name FROM warehouses ORDER BY name")

    sql = f"""
        SELECT p.sku, p.name AS product_name, w.warehouse_id, w.name AS warehouse,
               i.quantity_available, i.quantity_reserved, i.reorder_level,
               {STOCK_STATUS_CASE} AS stock_status
        FROM inventory i
        JOIN products p ON p.product_id = i.product_id
        JOIN warehouses w ON w.warehouse_id = i.warehouse_id
        WHERE 1 = 1
    """
    params = []
    if search:
        sql += " AND (p.sku LIKE %s OR p.name LIKE %s)"
        like = f"%{search}%"
        params.extend([like, like])
    if warehouse_id:
        sql += " AND w.warehouse_id = %s"
        params.append(warehouse_id)
    sql += " ORDER BY p.name, w.name"

    records = db.query(sql, params)
    return render_template(
        "inventory.html", records=records, warehouses=warehouses, search=search, warehouse_id=warehouse_id
    )


# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------

@app.route("/orders")
def orders():
    status_filter = request.args.get("status", "")
    sql = """
        SELECT o.order_id, o.order_number, c.name AS customer_name, o.order_date, o.status,
               (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.order_id) AS item_count,
               (SELECT COALESCE(SUM(oi.quantity * oi.unit_price), 0)
                  FROM order_items oi WHERE oi.order_id = o.order_id) AS total_amount
        FROM orders o
        JOIN customers c ON c.customer_id = o.customer_id
        WHERE 1 = 1
    """
    params = []
    if status_filter:
        sql += " AND o.status = %s"
        params.append(status_filter)
    sql += " ORDER BY o.order_date DESC, o.order_id DESC"
    order_rows = db.query(sql, params)
    return render_template("orders.html", orders=order_rows, statuses=ORDER_STATUSES, status_filter=status_filter)


@app.route("/orders/new", methods=["GET", "POST"])
def new_order():
    if request.method == "GET":
        customers = db.query("SELECT customer_id, name FROM customers ORDER BY name")
        products = db.query("SELECT product_id, sku, name, unit_price FROM products ORDER BY name")
        return render_template("order_new.html", customers=customers, products=products)

    customer_id = request.form.get("customer_id")
    product_ids = request.form.getlist("product_id")
    quantities = request.form.getlist("quantity")

    items = []
    for product_id, quantity in zip(product_ids, quantities):
        if product_id and quantity and int(quantity) > 0:
            items.append((int(product_id), int(quantity)))

    if not customer_id or not items:
        logger.warning("Rejected new order submission: missing customer or line items")
        return render_template(
            "order_new.html",
            customers=db.query("SELECT customer_id, name FROM customers ORDER BY name"),
            products=db.query("SELECT product_id, sku, name, unit_price FROM products ORDER BY name"),
            error="Select a customer and at least one product/quantity.",
        )

    try:
        with db.transaction() as conn:
            with conn.cursor() as cursor:
                next_id = db.query_one("SELECT COALESCE(MAX(order_id), 0) + 1 AS next_id FROM orders")["next_id"]
                order_number = f"ORD-{100000 + next_id}"
                cursor.execute(
                    "INSERT INTO orders (order_number, customer_id, order_date, status) VALUES (%s, %s, CURDATE(), 'Pending')",
                    (order_number, customer_id),
                )
                order_id = cursor.lastrowid
                for product_id, quantity in items:
                    price_row = db.query_one("SELECT unit_price FROM products WHERE product_id = %s", (product_id,))
                    cursor.execute(
                        "INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (%s, %s, %s, %s)",
                        (order_id, product_id, quantity, price_row["unit_price"]),
                    )
        logger.info("Created order %s with %d line item(s)", order_number, len(items))
    except Exception:
        logger.exception("Failed to create new order")
        raise

    return redirect(url_for("order_detail", order_id=order_id))


@app.route("/orders/<int:order_id>")
def order_detail(order_id):
    order = db.query_one(
        """
        SELECT o.order_id, o.order_number, o.order_date, o.status,
               c.name AS customer_name, c.email, c.city, c.state
        FROM orders o
        JOIN customers c ON c.customer_id = o.customer_id
        WHERE o.order_id = %s
        """,
        (order_id,),
    )
    if not order:
        return render_template("order_detail.html", order=None), 404

    items = db.query(
        """
        SELECT p.sku, p.name AS product_name, oi.quantity, oi.unit_price,
               (oi.quantity * oi.unit_price) AS line_total
        FROM order_items oi
        JOIN products p ON p.product_id = oi.product_id
        WHERE oi.order_id = %s
        """,
        (order_id,),
    )
    shipments_for_order = db.query(
        """
        SELECT shipment_id, shipment_number, carrier, tracking_number, status, expected_delivery_date, shipped_date
        FROM shipments WHERE order_id = %s
        """,
        (order_id,),
    )
    total = sum(item["line_total"] for item in items)
    return render_template(
        "order_detail.html", order=order, items=items, total=total,
        shipments=shipments_for_order, statuses=ORDER_STATUSES,
    )


@app.route("/orders/<int:order_id>/status", methods=["POST"])
def update_order_status(order_id):
    new_status = request.form.get("status")
    if new_status in ORDER_STATUSES:
        db.execute("UPDATE orders SET status = %s WHERE order_id = %s", (new_status, order_id))
        logger.info("Order %s status updated to %s", order_id, new_status)
    return redirect(url_for("order_detail", order_id=order_id))


# ---------------------------------------------------------------------------
# Shipments
# ---------------------------------------------------------------------------

@app.route("/shipments")
def shipments():
    search = request.args.get("q", "").strip()
    status_filter = request.args.get("status", "")

    sql = """
        SELECT s.shipment_id, s.shipment_number, s.order_id, o.order_number, w.name AS warehouse,
               s.carrier, s.tracking_number, s.status, s.expected_delivery_date, s.shipped_date
        FROM shipments s
        JOIN orders o ON o.order_id = s.order_id
        JOIN warehouses w ON w.warehouse_id = s.warehouse_id
        WHERE 1 = 1
    """
    params = []
    if search:
        sql += " AND (s.shipment_number LIKE %s OR o.order_number LIKE %s OR CAST(s.order_id AS CHAR) = %s)"
        like = f"%{search}%"
        params.extend([like, like, search])
    if status_filter:
        sql += " AND s.status = %s"
        params.append(status_filter)
    sql += " ORDER BY s.expected_delivery_date"

    records = db.query(sql, params)
    return render_template(
        "shipments.html", shipments=records, statuses=SHIPMENT_STATUSES, search=search, status_filter=status_filter
    )


@app.route("/shipments/<int:shipment_id>/status", methods=["POST"])
def update_shipment_status(shipment_id):
    new_status = request.form.get("status")
    if new_status in SHIPMENT_STATUSES:
        db.execute("UPDATE shipments SET status = %s WHERE shipment_id = %s", (new_status, shipment_id))
        logger.info("Shipment %s status updated to %s", shipment_id, new_status)
    return redirect(url_for("shipments"))


# ---------------------------------------------------------------------------
# Warehouses
# ---------------------------------------------------------------------------

@app.route("/warehouses")
def warehouses():
    records = db.query(
        f"""
        SELECT w.warehouse_id, w.name, w.location,
               COUNT(DISTINCT i.product_id) AS total_products,
               COALESCE(SUM(i.quantity_available), 0) AS total_units,
               SUM(CASE WHEN i.quantity_available <= i.reorder_level THEN 1 ELSE 0 END) AS low_stock_items,
               (SELECT COUNT(DISTINCT s.order_id) FROM shipments s
                  WHERE s.warehouse_id = w.warehouse_id AND s.status != 'Delivered') AS active_orders,
               (SELECT COUNT(*) FROM shipments s
                  WHERE s.warehouse_id = w.warehouse_id AND s.status IN ('Preparing', 'Shipped', 'In Transit', 'Delayed')) AS outbound_shipments
        FROM warehouses w
        LEFT JOIN inventory i ON i.warehouse_id = w.warehouse_id
        GROUP BY w.warehouse_id, w.name, w.location
        ORDER BY w.name
        """
    )
    return render_template("warehouses.html", warehouses=records)


@app.route("/warehouses/<int:warehouse_id>")
def warehouse_detail(warehouse_id):
    warehouse = db.query_one("SELECT warehouse_id, name, location FROM warehouses WHERE warehouse_id = %s", (warehouse_id,))
    if not warehouse:
        return render_template("warehouse_detail.html", warehouse=None), 404
    records = db.query(
        f"""
        SELECT p.sku, p.name AS product_name, i.quantity_available, i.quantity_reserved, i.reorder_level,
               {STOCK_STATUS_CASE} AS stock_status
        FROM inventory i
        JOIN products p ON p.product_id = i.product_id
        WHERE i.warehouse_id = %s
        ORDER BY p.name
        """,
        (warehouse_id,),
    )
    return render_template("warehouse_detail.html", warehouse=warehouse, records=records)


# ---------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------

@app.route("/reports")
def reports():
    metrics = get_dashboard_metrics()
    inventory_by_warehouse = db.query(
        """
        SELECT w.name AS warehouse, COALESCE(SUM(i.quantity_available), 0) AS units
        FROM warehouses w
        LEFT JOIN inventory i ON i.warehouse_id = w.warehouse_id
        GROUP BY w.warehouse_id, w.name
        ORDER BY w.name
        """
    )
    return render_template(
        "reports.html", metrics=metrics, inventory_by_warehouse=inventory_by_warehouse,
        s3_enabled=bool(S3_BUCKET),
    )


@app.route("/reports/export/<report_type>", methods=["POST"])
def export_report(report_type):
    if report_type == "inventory":
        rows = db.query(
            f"""
            SELECT p.sku, p.name AS product_name, w.name AS warehouse,
                   i.quantity_available, i.quantity_reserved, i.reorder_level,
                   {STOCK_STATUS_CASE} AS stock_status
            FROM inventory i
            JOIN products p ON p.product_id = i.product_id
            JOIN warehouses w ON w.warehouse_id = i.warehouse_id
            ORDER BY p.name, w.name
            """
        )
        header = ["sku", "product_name", "warehouse", "quantity_available", "quantity_reserved", "reorder_level", "stock_status"]
    elif report_type == "orders":
        rows = db.query(
            """
            SELECT o.order_number, c.name AS customer_name, o.order_date, o.status,
                   (SELECT COALESCE(SUM(oi.quantity * oi.unit_price), 0)
                      FROM order_items oi WHERE oi.order_id = o.order_id) AS total_amount
            FROM orders o
            JOIN customers c ON c.customer_id = o.customer_id
            ORDER BY o.order_date DESC
            """
        )
        header = ["order_number", "customer_name", "order_date", "status", "total_amount"]
    else:
        return jsonify(error="Unknown report type"), 400

    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=header)
    writer.writeheader()
    for row in rows:
        writer.writerow({key: row[key] for key in header})

    if not S3_BUCKET:
        logger.warning("S3_BUCKET not configured; report generated but not uploaded")
        return jsonify(error="S3 bucket not configured on this instance"), 503

    timestamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    key = f"reports/{report_type}-{timestamp}.csv"
    try:
        _s3_client.put_object(Bucket=S3_BUCKET, Key=key, Body=buffer.getvalue().encode("utf-8"), ContentType="text/csv")
        download_url = _s3_client.generate_presigned_url(
            "get_object", Params={"Bucket": S3_BUCKET, "Key": key}, ExpiresIn=3600
        )
        logger.info("Uploaded %s report to s3://%s/%s", report_type, S3_BUCKET, key)
    except Exception:
        logger.exception("Failed to upload report to S3")
        return jsonify(error="Failed to upload report to S3"), 502

    return jsonify(status="ok", s3_key=key, download_url=download_url)


@app.errorhandler(500)
def handle_internal_error(exc):
    logger.exception("Unhandled application error: %s", exc)
    return render_template("error.html", message="An unexpected error occurred."), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 80)))
