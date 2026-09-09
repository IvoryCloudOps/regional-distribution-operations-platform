-- Regional Distribution Operations Platform - Application Schema
-- Target: Amazon RDS MySQL (distributiondb)
-- Safe to re-run: uses IF NOT EXISTS / drops only application tables in dependency order.

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS warehouses;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE warehouses (
  warehouse_id INT AUTO_INCREMENT PRIMARY KEY,
  name         VARCHAR(100) NOT NULL,
  location     VARCHAR(150) NOT NULL,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE products (
  product_id  INT AUTO_INCREMENT PRIMARY KEY,
  sku         VARCHAR(20) NOT NULL UNIQUE,
  name        VARCHAR(150) NOT NULL,
  category    VARCHAR(50) NOT NULL,
  unit_price  DECIMAL(10,2) NOT NULL,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_products_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE inventory (
  inventory_id        INT AUTO_INCREMENT PRIMARY KEY,
  product_id          INT NOT NULL,
  warehouse_id        INT NOT NULL,
  quantity_available  INT NOT NULL DEFAULT 0,
  quantity_reserved   INT NOT NULL DEFAULT 0,
  reorder_level       INT NOT NULL DEFAULT 0,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_product_warehouse (product_id, warehouse_id),
  CONSTRAINT fk_inventory_product   FOREIGN KEY (product_id) REFERENCES products(product_id),
  CONSTRAINT fk_inventory_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
  INDEX idx_inventory_warehouse (warehouse_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE customers (
  customer_id  INT AUTO_INCREMENT PRIMARY KEY,
  name         VARCHAR(150) NOT NULL,
  email        VARCHAR(150),
  phone        VARCHAR(30),
  city         VARCHAR(100),
  state        VARCHAR(2),
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE orders (
  order_id      INT AUTO_INCREMENT PRIMARY KEY,
  order_number  VARCHAR(20) NOT NULL UNIQUE,
  customer_id   INT NOT NULL,
  order_date    DATE NOT NULL,
  status        ENUM('Pending','Processing','Ready to Ship','Shipped','Completed','Cancelled') NOT NULL DEFAULT 'Pending',
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  INDEX idx_orders_status (status),
  INDEX idx_orders_date (order_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE order_items (
  order_item_id  INT AUTO_INCREMENT PRIMARY KEY,
  order_id       INT NOT NULL,
  product_id     INT NOT NULL,
  quantity       INT NOT NULL,
  unit_price     DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_items_order   FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
  CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(product_id),
  INDEX idx_items_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE shipments (
  shipment_id             INT AUTO_INCREMENT PRIMARY KEY,
  shipment_number         VARCHAR(20) NOT NULL UNIQUE,
  order_id                INT NOT NULL,
  warehouse_id            INT NOT NULL,
  carrier                 VARCHAR(50) NOT NULL,
  tracking_number         VARCHAR(50),
  status                  ENUM('Preparing','Shipped','In Transit','Delivered','Delayed') NOT NULL DEFAULT 'Preparing',
  expected_delivery_date  DATE,
  shipped_date            DATE,
  created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_shipments_order     FOREIGN KEY (order_id) REFERENCES orders(order_id),
  CONSTRAINT fk_shipments_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
  INDEX idx_shipments_status (status),
  INDEX idx_shipments_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
