-- NEW, EMPTY TEST DATABASE ONLY. The existing application still uses V1.
-- Four business tables. No DROP, TRUNCATE, replacement data or default accounts.

CREATE TABLE users (
  user_id INT NOT NULL AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL,
  email VARCHAR(254) NULL,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('user', 'admin') NOT NULL DEFAULT 'user',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_users_username (username),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE categories (
  category_id INT NOT NULL AUTO_INCREMENT,
  category_name VARCHAR(50) NOT NULL,
  PRIMARY KEY (category_id),
  UNIQUE KEY uq_category_name (category_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE products (
  product_id INT NOT NULL AUTO_INCREMENT,
  barcode VARCHAR(50) NULL,
  product_name VARCHAR(100) NOT NULL,
  category_id INT NOT NULL,
  created_by INT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- Filled automatically: the name only when the product has no barcode, else NULL.
  -- Lets products with different barcodes share a name, but blocks duplicate
  -- unbarcoded products with the same name in the same category.
  unbarcoded_name VARCHAR(100) AS (IF(barcode IS NULL, product_name, NULL)) STORED,
  PRIMARY KEY (product_id),
  UNIQUE KEY uq_product_barcode (barcode),
  UNIQUE KEY uq_unbarcoded_name_category (unbarcoded_name, category_id),
  CONSTRAINT fk_product_category FOREIGN KEY (category_id)
    REFERENCES categories (category_id) ON DELETE RESTRICT,
  CONSTRAINT fk_product_creator FOREIGN KEY (created_by)
    REFERENCES users (user_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE inventory_items (
  item_id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  product_id INT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  expiration_date DATE NOT NULL,
  status ENUM('active', 'consumed', 'discarded') NOT NULL DEFAULT 'active',
  status_updated_at TIMESTAMP NULL DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (item_id),
  KEY idx_inventory_owner_status_expiry (user_id, status, expiration_date),
  CONSTRAINT chk_inventory_quantity CHECK (quantity > 0),
  -- A consumed/discarded batch must record when its status changed.
  CONSTRAINT chk_inventory_status_time CHECK (status = 'active' OR status_updated_at IS NOT NULL),
  -- Deleting an account also deletes that user's own batches (same as V1).
  CONSTRAINT fk_inventory_user FOREIGN KEY (user_id)
    REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_inventory_product FOREIGN KEY (product_id)
    REFERENCES products (product_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
