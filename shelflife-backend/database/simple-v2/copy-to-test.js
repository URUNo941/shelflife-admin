// Database-only prototype. Never alters the source database or reads the app .env.
const mysql = require("mysql2/promise");
const fs = require("node:fs");
const path = require("node:path");

function planCopy(source) {
  const categories = [];
  const categoryIds = new Map();
  const products = [];
  const byBarcode = new Map();
  const withoutBarcode = new Map();
  const conflicts = [];
  const errors = [];
  const userIds = new Set(source.users.map((u) => u.user_id));
  let nextId = Math.max(0, ...source.products.map((p) => p.product_id)) + 1;
  const categoryId = (name) => {
    if (typeof name !== "string" || !name.trim() || name.length > 50) {
      errors.push("Invalid or empty category.");
      return null;
    }
    // Do not invent equivalence between categories with different spellings.
    if (!categoryIds.has(name)) {
      categoryIds.set(name, categories.length + 1);
      categories.push({
        category_id: categories.length + 1,
        category_name: name,
      });
    }
    return categoryIds.get(name);
  };
  function addProduct(p, id) {
    const barcode = p.barcode === "" || p.barcode == null ? null : p.barcode;
    const row = {
      product_id: id,
      barcode,
      product_name: p.product_name,
      category_id: categoryId(p.category),
      created_by: p.created_by ?? null,
      created_at: p.created_at,
    };
    if (
      typeof row.product_name !== "string" ||
      !row.product_name.trim() ||
      row.product_name.length > 100
    )
      errors.push(`Invalid product name at product ${id}.`);
    if (
      barcode !== null &&
      (typeof barcode !== "string" || barcode.length > 50 || !barcode.trim())
    )
      errors.push(`Invalid barcode at product ${id}.`);
    if (row.created_by !== null && !userIds.has(row.created_by))
      errors.push(`Unknown creator at product ${id}.`);
    products.push(row);
    if (barcode !== null) {
      if (byBarcode.has(barcode))
        errors.push(`Duplicate catalog barcode: ${barcode}`);
      byBarcode.set(barcode, { row, category: p.category, catalog: true });
    }
    return row;
  }
  // V1 global catalog IDs remain stable.
  for (const p of source.products) addProduct(p, p.product_id);
  const items = source.items.map((item) => {
    if (!userIds.has(item.user_id))
      errors.push(`Unknown owner at item ${item.item_id}.`);
    if (!Number.isInteger(item.quantity) || item.quantity < 1)
      errors.push(`Invalid quantity at item ${item.item_id}.`);
    if (!["active", "consumed", "discarded"].includes(item.status))
      errors.push(`Invalid status at item ${item.item_id}.`);
    else if (item.status !== "active" && item.status_updated_at == null)
      errors.push(`Missing status change time at item ${item.item_id}.`);
    const date = item.expiration_date;
    if (
      typeof date !== "string" ||
      !/^\d{4}-\d{2}-\d{2}$/.test(date) ||
      date < "1000-01-01" ||
      Number.isNaN(Date.parse(date)) ||
      new Date(date).toISOString().slice(0, 10) !== date
    )
      errors.push(`Invalid expiration date at item ${item.item_id}.`);
    const barcode =
      item.barcode === "" || item.barcode == null ? null : item.barcode;
    let product;
    if (barcode !== null && byBarcode.has(barcode)) {
      const match = byBarcode.get(barcode);
      product = match.row;
      if (
        item.product_name !== product.product_name ||
        item.category !== match.category
      ) {
        conflicts.push({
          item_id: item.item_id,
          barcode,
          inventory: { name: item.product_name, category: item.category },
          catalog: { name: product.product_name, category: match.category },
          can_accept_catalog: match.catalog,
        });
      }
    } else if (barcode === null) {
      // Identical unbarcoded definitions can share a product; batches never merge.
      const key = JSON.stringify([item.product_name, item.category]);
      product = withoutBarcode.get(key);
      if (!product) {
        product = addProduct(
          { ...item, created_by: item.user_id, barcode: null },
          nextId++,
        );
        withoutBarcode.set(key, product);
      }
    } else {
      product = addProduct({ ...item, created_by: item.user_id }, nextId++);
      byBarcode.get(barcode).catalog = false;
    }
    return {
      item_id: item.item_id,
      user_id: item.user_id,
      product_id: product.product_id,
      quantity: item.quantity,
      expiration_date: item.expiration_date,
      status: item.status,
      status_updated_at: item.status_updated_at,
      created_at: item.created_at,
      updated_at: item.updated_at,
    };
  });
  // Catch common case/space collisions before creating any target. SQL also
  // enforces its own collation; a less common collision rolls back target rows.
  const names = new Set();
  for (const c of categories) {
    const key = c.category_name.trim().toLowerCase();
    if (names.has(key))
      errors.push(`Review differently spelled category: ${c.category_name}`);
    names.add(key);
  }
  // Unbarcoded products must be unique by name within a category in V2.
  const unbarcoded = new Set();
  for (const p of products) {
    if (p.barcode !== null || typeof p.product_name !== "string") continue;
    const key = JSON.stringify([
      p.product_name.trim().toLowerCase(),
      p.category_id,
    ]);
    if (unbarcoded.has(key))
      errors.push(
        `Review differently spelled unbarcoded product at product ${p.product_id}.`,
      );
    unbarcoded.add(key);
  }
  return {
    users: source.users.map((u) => ({ ...u, email: u.email ?? null })),
    categories,
    products,
    items,
    report: {
      counts: {
        users: source.users.length,
        categories: categories.length,
        products: products.length,
        inventory_items: items.length,
      },
      catalog_label_conflicts: conflicts,
      errors,
      note: "No source rows are changed. Catalog label acceptance affects only the new test database. Batches and quantities are never merged.",
    },
  };
}

function safeName(name) {
  return (
    typeof name === "string" &&
    /^[a-zA-Z0-9_]+$/.test(name) &&
    name.length <= 64
  );
}

async function copyToTest({
  config,
  sourceName,
  targetName,
  copy = false,
  acceptCatalogLabels = false,
  reportPath,
}) {
  if (!safeName(sourceName))
    throw new Error("Specify a valid --source database name.");
  if (
    copy &&
    (!safeName(targetName) ||
      !targetName.startsWith("shelflife_v2_") ||
      targetName === sourceName)
  )
    throw new Error(
      "Target must be a new, different database named shelflife_v2_*.",
    );
  const source = await mysql.createConnection({
    ...config,
    database: sourceName,
    dateStrings: true,
    multipleStatements: false,
  });
  let target;
  try {
    await source.query("SET time_zone = '+00:00'");
    const [engines] = await source.query(
      "SELECT table_name,engine FROM information_schema.tables WHERE table_schema=? AND table_name IN ('users','global_products','inventory_items')",
      [sourceName],
    );
    if (engines.length !== 3 || engines.some((r) => r.engine !== "InnoDB"))
      throw new Error("Source must have the three V1 InnoDB tables.");
    const expectedColumns = {
      users: [
        "user_id",
        "username",
        "password_hash",
        "role",
        "created_at",
        "updated_at",
      ],
      global_products: [
        "product_id",
        "barcode",
        "product_name",
        "category",
        "created_by",
        "created_at",
      ],
      inventory_items: [
        "item_id",
        "user_id",
        "barcode",
        "product_name",
        "category",
        "quantity",
        "expiration_date",
        "status",
        "status_updated_at",
        "created_at",
        "updated_at",
      ],
    };
    for (const [table, expected] of Object.entries(expectedColumns)) {
      const [columns] = await source.query(
        "SELECT column_name FROM information_schema.columns WHERE table_schema=? AND table_name=?",
        [sourceName, table],
      );
      const actual = columns.map((c) => c.column_name).sort();
      if (JSON.stringify(actual) !== JSON.stringify([...expected].sort()))
        throw new Error(
          `Source ${table} is not the expected V1 schema. Review extra/missing columns before copying.`,
        );
    }
    await source.query("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ");
    await source.query("START TRANSACTION WITH CONSISTENT SNAPSHOT, READ ONLY");
    const users = (
      await source.query(
        "SELECT user_id,username,password_hash,role,created_at,updated_at FROM users ORDER BY user_id",
      )
    )[0];
    const products = (
      await source.query("SELECT * FROM global_products ORDER BY product_id")
    )[0];
    const items = (
      await source.query("SELECT * FROM inventory_items ORDER BY item_id")
    )[0];
    const plan = planCopy({ users, products, items });
    await source.rollback(); // End read-only snapshot; nothing has been written.
    if (reportPath)
      fs.writeFileSync(
        reportPath,
        JSON.stringify(plan.report, null, 2) + "\n",
        { flag: "wx" },
      );
    if (!copy) return plan.report;
    if (plan.report.errors.length)
      throw new Error(
        "Source validation failed. Review the report; source was not changed.",
      );
    const conflicts = plan.report.catalog_label_conflicts;
    if (conflicts.some((c) => !c.can_accept_catalog))
      throw new Error(
        "Conflicting inventory labels without an authoritative catalog entry. Resolve them on a source COPY first.",
      );
    if (conflicts.length && !acceptCatalogLabels)
      throw new Error(
        "Catalog and inventory labels differ. Review the report before opting in with --accept-catalog-labels.",
      );
    if (conflicts.length && !reportPath)
      throw new Error(
        "A new --report file is required when accepting label differences.",
      );
    target = await mysql.createConnection({
      ...config,
      multipleStatements: false,
      dateStrings: true,
    });
    // No IF NOT EXISTS: an existing target is an error, never an overwrite.
    await target.query(
      `CREATE DATABASE \`${targetName}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
    );
    await target.changeUser({ database: targetName });
    // changeUser resets session settings; set UTC after selecting the target.
    await target.query("SET time_zone = '+00:00'");
    const sql = fs
      .readFileSync(path.join(__dirname, "schema.sql"), "utf8")
      .replace(/^--.*$/gm, "");
    for (const statement of sql.split(";").filter((s) => s.trim()))
      await target.query(statement);
    await target.beginTransaction();
    try {
      async function insert(table, rows) {
        for (const row of rows) {
          const fields = Object.keys(row);
          await target.execute(
            `INSERT INTO ${table} (${fields.join(",")}) VALUES (${fields.map(() => "?").join(",")})`,
            Object.values(row),
          );
        }
      }
      await insert("users", plan.users);
      await insert("categories", plan.categories);
      await insert("products", plan.products);
      await insert("inventory_items", plan.items);
      for (const [table, expected] of Object.entries(plan.report.counts)) {
        const [[row]] = await target.query(
          `SELECT COUNT(*) count FROM ${table}`,
        );
        if (row.count !== expected)
          throw new Error(`Count mismatch in ${table}.`);
      }
      await target.commit();
    } catch (error) {
      await target.rollback();
      throw error;
    }
    return { ...plan.report, target: targetName, copied: true };
  } finally {
    if (target) await target.end();
    await source.end();
  }
}

if (require.main === module) {
  const args = process.argv.slice(2);
  const allowed = new Set([
    "--source",
    "--target",
    "--report",
    "--copy",
    "--accept-catalog-labels",
  ]);
  const value = (flag) => {
    const i = args.indexOf(flag);
    return i < 0 ? undefined : args[i + 1];
  };
  const invalid = args.some(
    (arg, i) => arg.startsWith("--") && !allowed.has(arg),
  );
  if (invalid || !process.env.MIGRATION_DB_USER) {
    console.error(
      "Set MIGRATION_DB_USER (and HOST/PORT/PASSWORD as needed). Use --source NAME [--report NEW_FILE] [--copy --target shelflife_v2_NAME] [--accept-catalog-labels].",
    );
    process.exitCode = 1;
  } else
    copyToTest({
      config: {
        host: process.env.MIGRATION_DB_HOST || "127.0.0.1",
        port: Number(process.env.MIGRATION_DB_PORT || 3306),
        user: process.env.MIGRATION_DB_USER,
        password: process.env.MIGRATION_DB_PASSWORD || "",
      },
      sourceName: value("--source"),
      targetName: value("--target"),
      reportPath: value("--report"),
      copy: args.includes("--copy"),
      acceptCatalogLabels: args.includes("--accept-catalog-labels"),
    })
      .then((report) => console.log(JSON.stringify(report, null, 2)))
      .catch((error) => {
        // Do not echo SQL error payloads: a duplicate row could contain private data.
        console.error(
          error.code
            ? `Database operation failed (${error.code}). Source is unchanged; an incomplete test target may remain. Use a new target name after inspection.`
            : error.message,
        );
        process.exitCode = 1;
      });
}
module.exports = { planCopy, copyToTest };
