const { test } = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const mysql = require("mysql2/promise");
const { planCopy, copyToTest } = require("./copy-to-test");

const timestamp = "2026-11-03 13:27:43";
function item(id, overrides = {}) {
  return {
    item_id: id,
    user_id: 1,
    barcode: "A1",
    product_name: "Milk",
    category: "Food",
    quantity: 2,
    expiration_date: "2026-12-01",
    status: "active",
    status_updated_at: null,
    created_at: timestamp,
    updated_at: timestamp,
    ...overrides,
  };
}
const user = {
  user_id: 1,
  username: "test-user",
  password_hash: "not-a-real-password-hash",
  role: "user",
  created_at: timestamp,
  updated_at: timestamp,
};

test("normalization shares product definitions but never merges batches", () => {
  const p = planCopy({
    users: [user],
    products: [],
    items: [item(1), item(2, { expiration_date: "2027-01-01" })],
  });
  assert.equal(p.products.length, 1);
  assert.equal(p.categories.length, 1);
  assert.equal(p.items.length, 2);
  assert.equal(p.items[0].product_id, p.items[1].product_id);
  for (const row of p.items)
    for (const removed of ["barcode", "product_name", "category"])
      assert.equal(removed in row, false);
  assert.deepEqual(
    p.items.map((i) => i.quantity),
    [2, 2],
  );
  assert.equal(p.report.errors.length, 0);
});
test("unbarcoded items share only exact name/category definitions", () => {
  const p = planCopy({
    users: [user],
    products: [],
    items: [
      item(1, { barcode: null }),
      item(2, { barcode: "" }),
      item(3, { barcode: null, product_name: "Other milk" }),
    ],
  });
  assert.equal(p.products.length, 2);
  assert.equal(p.items.length, 3);
  assert.equal(p.products[0].barcode, null);
  assert.equal(p.items[0].product_id, p.items[1].product_id);
});
test("ambiguous labels are reported without exposing account hashes", () => {
  const p = planCopy({
    users: [user],
    products: [],
    items: [item(1), item(2, { product_name: "Different item" })],
  });
  assert.equal(p.report.catalog_label_conflicts.length, 1);
  assert.equal(p.report.catalog_label_conflicts[0].can_accept_catalog, false);
  assert.equal(JSON.stringify(p.report).includes(user.password_hash), false);
});
test("invalid values and category case collisions require review", () => {
  const p = planCopy({
    users: [user],
    products: [],
    items: [
      item(1, { quantity: 0, expiration_date: "2026-02-30" }),
      item(2, { barcode: "A2", category: "food" }),
    ],
  });
  assert.equal(p.report.errors.length, 3);
});
test("install file shelflife_v2_db.sql contains schema.sql unchanged", () => {
  const schema = fs.readFileSync(path.join(__dirname, "schema.sql"), "utf8").trim();
  const install = fs.readFileSync(
    path.join(__dirname, "../shelflife_v2_db.sql"),
    "utf8",
  );
  assert.ok(
    install.includes(schema),
    "Regenerate shelflife_v2_db.sql after changing schema.sql",
  );
  assert.doesNotMatch(install, /\b(DROP|TRUNCATE)\s+(TABLE|DATABASE)\b/i);
});
test("consumed/discarded batches need a status change time", () => {
  const p = planCopy({
    users: [user],
    products: [],
    items: [
      item(1, { status: "consumed" }),
      item(2, { status: "discarded", status_updated_at: timestamp }),
      item(3, { status_updated_at: timestamp }),
    ],
  });
  assert.equal(p.report.errors.length, 1);
  assert.match(p.report.errors[0], /item 1\b/);
});
test("unbarcoded products differing only by case require review", () => {
  const p = planCopy({
    users: [user],
    products: [],
    items: [
      item(1, { barcode: null, product_name: "Milk" }),
      item(2, { barcode: null, product_name: "milk " }),
    ],
  });
  assert.equal(p.report.errors.length, 1);
  assert.match(p.report.errors[0], /unbarcoded/);
});

test(
  "V1 source stays intact; normalized test copy enforces relationships",
  { skip: !process.env.TEST_DB_HOST },
  async (t) => {
    const suffix = crypto.randomBytes(8).toString("hex");
    const sourceName = `shelflife_source_test_${suffix}`;
    const targetName = `shelflife_v2_test_${suffix}`;
    const config = {
      host: process.env.TEST_DB_HOST,
      port: Number(process.env.TEST_DB_PORT || 3306),
      user: process.env.TEST_DB_USER || "root",
      password: process.env.TEST_DB_PASSWORD || "",
    };
    const root = await mysql.createConnection({
      ...config,
      multipleStatements: true,
      dateStrings: true,
    });
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "shelflife-db-test-"));
    const extraTarget = `shelflife_v2_rollback_${suffix}`;
    let before;
    const snapshot = async () => {
      const result = {};
      for (const [table, key] of [
        ["users", "user_id"],
        ["global_products", "product_id"],
        ["inventory_items", "item_id"],
      ])
        result[table] = (
          await root.query(
            `SELECT * FROM \`${sourceName}\`.${table} ORDER BY ${key}`,
          )
        )[0];
      return result;
    };
    try {
      await root.query(
        `CREATE DATABASE \`${sourceName}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
      );
      await root.changeUser({ database: sourceName });
      await root.query(
        fs.readFileSync(path.join(__dirname, "../shelflife_db.sql"), "utf8"),
      );
      before = await snapshot();
      await t.test(
        "dry run identifies the two catalog-label conflicts",
        async () => {
          const report = await copyToTest({ config, sourceName });
          assert.equal(report.catalog_label_conflicts.length, 2);
          assert.deepEqual(report.counts, {
            users: 2,
            categories: 2,
            products: 4,
            inventory_items: 4,
          });
          assert.deepEqual(await snapshot(), before);
        },
      );
      await t.test(
        "source/target collision and unreviewed labels cannot create a target",
        async () => {
          await assert.rejects(
            copyToTest({
              config,
              sourceName,
              targetName: sourceName,
              copy: true,
            }),
            /Target must/,
          );
          await assert.rejects(
            copyToTest({ config, sourceName, targetName, copy: true }),
            /labels differ/,
          );
          assert.equal(
            (
              await root.query(
                "SELECT schema_name FROM information_schema.schemata WHERE schema_name=?",
                [targetName],
              )
            )[0].length,
            0,
          );
          assert.deepEqual(await snapshot(), before);
        },
      );
      await t.test(
        "copy requires explicit label acceptance and preserves all batches/account fields",
        async () => {
          const report = await copyToTest({
            config,
            sourceName,
            targetName,
            copy: true,
            acceptCatalogLabels: true,
            reportPath: path.join(dir, "accepted.json"),
          });
          assert.equal(report.copied, true);
          assert.deepEqual(await snapshot(), before);
          const rows = (
            await root.query(
              `SELECT * FROM \`${targetName}\`.inventory_items ORDER BY item_id`,
            )
          )[0];
          for (let i = 0; i < rows.length; i++)
            for (const field of [
              "item_id",
              "user_id",
              "quantity",
              "expiration_date",
              "status",
              "status_updated_at",
              "created_at",
              "updated_at",
            ])
              assert.equal(rows[i][field], before.inventory_items[i][field]);
          const users = (
            await root.query(
              `SELECT * FROM \`${targetName}\`.users ORDER BY user_id`,
            )
          )[0];
          for (let i = 0; i < users.length; i++) {
            for (const key of Object.keys(before.users[i]))
              assert.equal(users[i][key], before.users[i][key]);
            assert.equal(users[i].email, null);
          }
          const tables = (
            await root.query(
              "SELECT table_name FROM information_schema.tables WHERE table_schema=? ORDER BY table_name",
              [targetName],
            )
          )[0].map((r) => r.table_name);
          assert.deepEqual(tables, [
            "categories",
            "inventory_items",
            "products",
            "users",
          ]);
          const joined = (
            await root.query(
              `SELECT p.product_name,c.category_name FROM \`${targetName}\`.inventory_items i JOIN \`${targetName}\`.products p ON p.product_id=i.product_id JOIN \`${targetName}\`.categories c ON c.category_id=p.category_id WHERE i.item_id=1`,
            )
          )[0][0];
          assert.deepEqual(
            { ...joined },
            { product_name: "Fresh Milk 1L", category_name: "Food" },
          );
        },
      );
      await t.test(
        "repeating a copy never overwrites an existing target",
        async () => {
          await assert.rejects(
            copyToTest({
              config,
              sourceName,
              targetName,
              copy: true,
              acceptCatalogLabels: true,
              reportPath: path.join(dir, "repeat.json"),
            }),
            (e) => e.code === "ER_DB_CREATE_EXISTS",
          );
          assert.equal(
            (
              await root.query(
                `SELECT COUNT(*) n FROM \`${targetName}\`.inventory_items`,
              )
            )[0][0].n,
            4,
          );
          assert.deepEqual(await snapshot(), before);
        },
      );
      await t.test(
        "foreign keys and quantity constraint protect inventory",
        async () => {
          await assert.rejects(
            root.query(
              `DELETE FROM \`${targetName}\`.products WHERE product_id=1`,
            ),
          );
          await assert.rejects(
            root.query(
              `UPDATE \`${targetName}\`.inventory_items SET product_id=999999 WHERE item_id=1`,
            ),
          );
          await assert.rejects(
            root.query(
              `UPDATE \`${targetName}\`.inventory_items SET quantity=0 WHERE item_id=1`,
            ),
          );
          await assert.rejects(
            root.query(
              `INSERT INTO \`${targetName}\`.categories(category_name) VALUES ('Food')`,
            ),
          );
          // A finished batch must say when it finished.
          await assert.rejects(
            root.query(
              `UPDATE \`${targetName}\`.inventory_items SET status='consumed', status_updated_at=NULL WHERE item_id=1`,
            ),
          );
          await root.query(
            `UPDATE \`${targetName}\`.inventory_items SET status='consumed', status_updated_at=CURRENT_TIMESTAMP WHERE item_id=1`,
          );
        },
      );
      await t.test(
        "unbarcoded names are unique per category; barcoded names may repeat",
        async () => {
          const db = `\`${targetName}\``;
          await root.query(
            `INSERT INTO ${db}.products(barcode,product_name,category_id) VALUES ('B-1','Same name',1),('B-2','Same name',1)`,
          );
          await root.query(
            `INSERT INTO ${db}.products(barcode,product_name,category_id) VALUES (NULL,'Loose bananas',1)`,
          );
          await assert.rejects(
            root.query(
              `INSERT INTO ${db}.products(barcode,product_name,category_id) VALUES (NULL,'Loose bananas',1)`,
            ),
            (e) => e.code === "ER_DUP_ENTRY",
          );
          await root.query(
            `INSERT INTO ${db}.products(barcode,product_name,category_id) VALUES (NULL,'Loose bananas',2)`,
          );
        },
      );
      await t.test(
        "deleting a user removes only their batches and keeps products",
        async () => {
          const db = `\`${targetName}\``;
          const [[{ n: productsBefore }]] = await root.query(
            `SELECT COUNT(*) n FROM ${db}.products`,
          );
          await root.query(`DELETE FROM ${db}.users WHERE user_id=1`);
          const [[{ n: items }]] = await root.query(
            `SELECT COUNT(*) n FROM ${db}.inventory_items WHERE user_id=1`,
          );
          assert.equal(items, 0);
          const [[{ n: productsAfter }]] = await root.query(
            `SELECT COUNT(*) n FROM ${db}.products`,
          );
          assert.equal(productsAfter, productsBefore);
          const [[{ n: orphanCreators }]] = await root.query(
            `SELECT COUNT(*) n FROM ${db}.products WHERE created_by=1`,
          );
          assert.equal(orphanCreators, 0);
        },
      );
      await t.test(
        "a collation collision rolls back all target rows, never the source",
        async () => {
          // Different accent spelling collides under unicode_ci. Preserve and reject it.
          await root.query(
            `INSERT INTO \`${sourceName}\`.global_products(barcode,product_name,category,created_by) VALUES ('test-accent','Test item','Fóod',1)`,
          );
          const augmented = await snapshot();
          await assert.rejects(
            copyToTest({
              config,
              sourceName,
              targetName: extraTarget,
              copy: true,
              acceptCatalogLabels: true,
              reportPath: path.join(dir, "collision.json"),
            }),
            (e) => e.code === "ER_DUP_ENTRY",
          );
          for (const table of [
            "users",
            "categories",
            "products",
            "inventory_items",
          ])
            assert.equal(
              (
                await root.query(
                  `SELECT COUNT(*) n FROM \`${extraTarget}\`.${table}`,
                )
              )[0][0].n,
              0,
            );
          assert.deepEqual(await snapshot(), augmented);
        },
      );
    } finally {
      // Only these locally generated names may be removed, never a CLI/app DB name.
      for (const name of [sourceName, targetName, extraTarget])
        await root.query(`DROP DATABASE IF EXISTS \`${name}\``);
      await root.end();
      for (const name of fs.readdirSync(dir))
        fs.unlinkSync(path.join(dir, name));
      fs.rmdirSync(dir);
    }
  },
);
