# Application — Regional Distribution Operations Platform

Lightweight internal operations app proving out the AWS infrastructure. Serves
inventory lookup, order processing, shipment tracking, warehouse operations,
and basic reporting for the ~200-300 internal employees described in the
project [README](../README.md). All data is synthetic.

## Architecture

```
Browser (via Client VPN)
   ↓
Internal ALB  (health check: GET /health)
   ↓
Flask app on EC2 (Auto Scaling Group, gunicorn on :80)
   ↓
Amazon RDS MySQL (distributiondb)
```

Single Flask process serves both the server-rendered UI (Jinja2 templates)
and the small JSON endpoints used by the report-export button. No separate
frontend/backend deployment, no containers, no new AWS services.

## Files

```
application/
  app.py                    Flask routes/views
  db.py                     Secrets Manager + MySQL connection helpers
  requirements.txt
  schema.sql                Table definitions (idempotent, safe to re-run)
  seed.sql                  Synthetic demo data (idempotent, safe to re-run)
  distribution-app.service  systemd unit installed by EC2 bootstrap
  templates/                Jinja2 templates (dashboard, inventory, orders, ...)
  static/                   style.css, app.js
```

## Database schema

`warehouses`, `products`, `inventory` (per product/warehouse), `customers`,
`orders`, `order_items`, `shipments`. See [schema.sql](schema.sql) for full
column/relationship definitions.

To initialize or reset the database (run from an EC2 instance or anywhere
with network access to RDS, e.g. via SSM):

```bash
mysql -h <rds-endpoint> -u <user> -p distributiondb < schema.sql
mysql -h <rds-endpoint> -u <user> -p distributiondb < seed.sql
```

`seed.sql` was generated deterministically by
[scripts/generate_seed_data.py](../scripts/generate_seed_data.py) (requires
Python 3; re-run it to regenerate with different fake data).

## Credentials

The app never stores or hardcodes database credentials. On startup, and
whenever a connection fails, [db.py](db.py) calls
`secretsmanager:GetSecretValue` (via the EC2 instance's IAM role — see
`distribution_app_access` policy in `terraform/iam.tf`) using the secret ARN
passed in via the `DB_SECRET_ARN` environment variable. That ARN is the
RDS-managed master secret created by `manage_master_user_password = true` in
`terraform/database.tf`; only the ARN (not a credential) is written into
`/etc/distribution-app.env` by the EC2 user-data script.

## Environment variables

Set in `/etc/distribution-app.env` by `terraform/scripts/app_user_data.sh`
(templated with Terraform values, not secrets):

| Variable         | Source                                              |
|------------------|------------------------------------------------------|
| `DB_SECRET_ARN`  | `aws_db_instance.distribution_mysql.master_user_secret[0].secret_arn` |
| `DB_NAME`        | `aws_db_instance.distribution_mysql.db_name` (`distributiondb`) |
| `S3_BUCKET`      | `aws_s3_bucket.distribution_bucket.id`              |
| `AWS_REGION`     | `us-east-1`                                         |

## How the application starts

1. Terraform's `aws_launch_template.distribution_app` renders
   `terraform/scripts/app_user_data.sh` with the variables above.
2. On boot, the instance downloads the app bundle from
   `s3://<bucket>/app-releases/distribution-app.zip` (built with
   `scripts/package_app.sh`), creates a virtualenv, installs
   `requirements.txt`, and installs `distribution-app.service` under systemd.
3. `systemctl enable --now distribution-app` starts gunicorn bound to
   `0.0.0.0:80`, matching the existing ALB target group and security group
   rule (ALB → app tier, port 80).
4. Any instance the Auto Scaling Group launches repeats the same steps, so
   no instance is uniquely responsible for application state — all business
   data lives in RDS.

## Pages / features

- `/dashboard` — orders today/this month, open/completed orders, active &
  delayed shipments, low-stock SKU count, inventory units by warehouse.
- `/inventory` — search by SKU or product name, filter by warehouse.
- `/orders`, `/orders/new`, `/orders/<id>` — list, create, view, and update
  status of orders (statuses: Pending, Processing, Ready to Ship, Shipped,
  Completed, Cancelled).
- `/shipments` — search by shipment/order number, filter and update status
  (Preparing, Shipped, In Transit, Delivered, Delayed).
- `/warehouses`, `/warehouses/<id>` — per-warehouse operational overview and
  scoped inventory.
- `/reports` — the same metrics as the dashboard, plus buttons to export an
  inventory or orders CSV to the existing S3 bucket (`reports/` prefix) with
  a temporary presigned download link.

## Health endpoints

- `GET /health` — always returns `200` if the Flask process is alive. Used
  by the ALB target group health check. Does not touch RDS.
- `GET /health/db` — optional, separate deeper check that queries RDS;
  intentionally not wired to the ALB so a transient database issue does not
  trigger unnecessary instance replacement.

## Logging

Standard library `logging` configured to stdout (`journalctl -u
distribution-app` / CloudWatch agent on the instance). Logs application
startup, Secrets Manager retrieval, DB connection failures/retries, order
and shipment status changes, and unhandled exceptions.
