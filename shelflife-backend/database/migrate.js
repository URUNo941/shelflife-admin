// Additive, resumable migration. MySQL DDL auto-commits; do not promise rollback.
require("dotenv").config();
const pool = require("../db_config");
async function migrate(connection) {
  const q = async (sql, args = []) => (await connection.query(sql, args))[0];
  const [lock] = await q(
    "SELECT GET_LOCK(CONCAT(DATABASE(), ':shelflife-v2'), 10) acquired",
  );
  if (!lock.acquired) throw new Error("Another migration is running.");
  try {
    await q(
      `CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(50) PRIMARY KEY, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`,
    );
    if (
      (await q("SELECT version FROM schema_migrations WHERE version='002_v2'"))
        .length
    )
      return;
    const column = async (table, name, type) => {
      if (
        !(
          await q(
            "SELECT 1 FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name=? AND column_name=?",
            [table, name],
          )
        ).length
      )
        await q(`ALTER TABLE ${table} ADD COLUMN ${name} ${type}`);
    };
    const constraint = async (table, name, definition) => {
      if (
        !(
          await q(
            "SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema=DATABASE() AND table_name=? AND constraint_name=?",
            [table, name],
          )
        ).length
      )
        await q(`ALTER TABLE ${table} ADD CONSTRAINT ${name} ${definition}`);
    };
    await column("users", "email", "VARCHAR(254) NULL");
    await column("users", "is_active", "BOOLEAN NOT NULL DEFAULT 1");
    await constraint("users", "uq_users_email_v2", "UNIQUE (email)");
    await q(`CREATE TABLE IF NOT EXISTS categories (
      category_id INT PRIMARY KEY AUTO_INCREMENT, category_name VARCHAR(50) NOT NULL UNIQUE,
      is_active BOOLEAN NOT NULL DEFAULT 1
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
    await column("global_products", "category_id", "INT NULL");
    await column("global_products", "is_active", "BOOLEAN NOT NULL DEFAULT 1");
    await column(
      "global_products",
      "updated_at",
      "TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
    );
    await constraint(
      "global_products",
      "fk_products_category_v2",
      "FOREIGN KEY (category_id) REFERENCES categories(category_id)",
    );
    await column("inventory_items", "product_id", "INT NULL");
    await column(
      "inventory_items",
      "product_name_snapshot",
      "VARCHAR(100) NULL",
    );
    await column("inventory_items", "deleted_at", "TIMESTAMP NULL");
    await constraint(
      "inventory_items",
      "fk_inventory_product_v2",
      "FOREIGN KEY (product_id) REFERENCES global_products(product_id) ON DELETE SET NULL",
    );
    await q(`CREATE TABLE IF NOT EXISTS product_barcodes (
      barcode_id INT PRIMARY KEY AUTO_INCREMENT, product_id INT NOT NULL,
      barcode VARCHAR(50) NOT NULL UNIQUE, is_primary BOOLEAN NOT NULL DEFAULT 0,
      CONSTRAINT fk_barcode_product_v2 FOREIGN KEY (product_id) REFERENCES global_products(product_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
    await q(`CREATE TABLE IF NOT EXISTS inventory_events (
      event_id BIGINT PRIMARY KEY AUTO_INCREMENT, item_id INT NOT NULL, user_id INT NOT NULL,
      event_type VARCHAR(20) NOT NULL, quantity_change INT NOT NULL,
      occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_events_time (occurred_at, event_type),
      FOREIGN KEY (item_id) REFERENCES inventory_items(item_id),
      FOREIGN KEY (user_id) REFERENCES users(user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
    await q(`CREATE TABLE IF NOT EXISTS audit_logs (
      log_id BIGINT PRIMARY KEY AUTO_INCREMENT, actor_user_id INT NULL,
      action VARCHAR(50) NOT NULL, entity_type VARCHAR(50) NOT NULL, entity_id INT NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (actor_user_id) REFERENCES users(user_id) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
    if (
      !(
        await q(
          "SELECT 1 FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='inventory_items' AND index_name='idx_owner_expiry_v2'",
        )
      ).length
    )
      await q(
        "CREATE INDEX idx_owner_expiry_v2 ON inventory_items(user_id,status,deleted_at,expiration_date)",
      );
    await connection.beginTransaction();
    try {
      await q(
        `INSERT INTO categories(category_name) SELECT category FROM (SELECT category FROM global_products UNION SELECT category FROM inventory_items) legacy_categories WHERE 1=1 ON DUPLICATE KEY UPDATE category_name=VALUES(category_name)`,
      );
      await q(
        "UPDATE global_products p JOIN categories c ON c.category_name=p.category SET p.category_id=c.category_id WHERE p.category_id IS NULL",
      );
      await q(
        "INSERT INTO product_barcodes(product_id,barcode,is_primary) SELECT product_id,barcode,1 FROM global_products ON DUPLICATE KEY UPDATE barcode=VALUES(barcode)",
      );
      await q(
        "UPDATE inventory_items i JOIN global_products p ON p.barcode=i.barcode SET i.product_id=p.product_id, i.updated_at=i.updated_at WHERE i.product_id IS NULL",
      );
      await q(
        "UPDATE inventory_items SET product_name_snapshot=product_name, updated_at=updated_at WHERE product_name_snapshot IS NULL",
      );
      await q("INSERT INTO schema_migrations(version) VALUES ('002_v2')");
      await connection.commit();
    } catch (e) {
      await connection.rollback();
      throw e;
    }
  } finally {
    await q("SELECT RELEASE_LOCK(CONCAT(DATABASE(), ':shelflife-v2'))");
  }
}
if (require.main === module)
  (async () => {
    const connection = await pool.getConnection();
    try {
      await migrate(connection);
      console.log("V2 migration complete.");
    } finally {
      connection.release();
      await pool.end();
    }
  })().catch(() => {
    console.error(
      "Migration failed. Inspect schema and configuration before resuming.",
    );
    process.exitCode = 1;
  });
module.exports = { migrate };
