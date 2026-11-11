const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const mysql = require("mysql2/promise");

test(
  "V1 → V2 preservation and authenticated API integration",
  { skip: !process.env.TEST_DB_HOST },
  async (t) => {
    // Never use the application DB. Create a unique, disposable database.
    const database = "shelflife_test_" + crypto.randomBytes(8).toString("hex");
    const config = {
      host: process.env.TEST_DB_HOST,
      port: Number(process.env.TEST_DB_PORT || 3306),
      user: process.env.TEST_DB_USER || "root",
      password: process.env.TEST_DB_PASSWORD || "",
      multipleStatements: true,
    };
    const root = await mysql.createConnection(config);
    let c, pool, server;
    try {
      await root.query(
        `CREATE DATABASE ${database} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
      );
      c = await mysql.createConnection({
        ...config,
        database,
        dateStrings: true,
      });
      await c.query(
        fs.readFileSync(
          path.join(__dirname, "../database/shelflife_db.sql"),
          "utf8",
        ),
      );
      const before = (
        await c.query("SELECT * FROM inventory_items ORDER BY item_id")
      )[0];
      Object.assign(process.env, {
        DB_HOST: config.host,
        DB_PORT: String(config.port),
        DB_USER: config.user,
        DB_PASSWORD: config.password,
        DB_NAME: database,
        JWT_SECRET: crypto.randomBytes(32).toString("hex"),
      });
      pool = require("../db_config");
      const { migrate } = require("../database/migrate");
      await migrate(c);
      await migrate(c);
      const after = (
        await c.query("SELECT * FROM inventory_items ORDER BY item_id")
      )[0];
      for (let i = 0; i < before.length; i++)
        for (const key of Object.keys(before[i]))
          assert.equal(after[i][key], before[i][key], key);
      assert.equal(after[0].product_name_snapshot, "Fresh Milk");
      assert.equal(after[2].product_id, null);
      assert.equal(
        (await c.query("SELECT COUNT(*) n FROM inventory_events"))[0][0].n,
        0,
      );
      const app = require("../app");
      server = await new Promise((resolve) => {
        const s = app.listen(0, "127.0.0.1", () => resolve(s));
      });
      const base = `http://127.0.0.1:${server.address().port}/api`;
      async function call(method, url, body, token) {
        const r = await fetch(base + url, {
          method,
          headers: {
            "Content-Type": "application/json",
            ...(token ? { Authorization: "Bearer " + token } : {}),
          },
          ...(body ? { body: JSON.stringify(body) } : {}),
        });
        return {
          status: r.status,
          body: r.status === 204 ? null : await r.json(),
        };
      }
      let alice, bob, admin, item, product;
      await t.test(
        "registration hashes passwords and ignores requested admin role",
        async () => {
          const r = await call("POST", "/auth/register", {
            username: "alice",
            email: "alice@example.test",
            password: "correct horse battery",
            role: "admin",
          });
          assert.equal(r.status, 201);
          assert.equal(r.body.role, "user");
          assert.equal(r.body.password_hash, undefined);
          const hash = (
            await c.query(
              "SELECT password_hash FROM users WHERE username='alice'",
            )
          )[0][0].password_hash;
          assert.match(hash, /^\$argon2/);
          assert.equal(
            (
              await call("POST", "/auth/register", {
                username: "alice",
                email: "alice@example.test",
                password: "correct horse battery",
              })
            ).status,
            409,
          );
          await call("POST", "/auth/register", {
            username: "bob",
            email: "bob@example.test",
            password: "correct horse battery",
          });
          alice = (
            await call("POST", "/auth/login", {
              username: "alice",
              password: "correct horse battery",
            })
          ).body;
          bob = (
            await call("POST", "/auth/login", {
              username: "bob",
              password: "correct horse battery",
            })
          ).body;
          assert.ok(alice.token);
          assert.ok(bob.token);
          assert.equal(
            (
              await call("POST", "/auth/login", {
                username: "alice",
                password: "wrong",
              })
            ).status,
            401,
          );
          assert.equal(
            (
              await call("POST", "/auth/login", {
                username: "tom123",
                password: "hashed_pass_here",
              })
            ).status,
            401,
          );
        },
      );
      await t.test(
        "all inventory routes require authentication and enforce ownership",
        async () => {
          for (const [method, url, body] of [
            ["GET", "/items/1"],
            ["POST", "/items", {}],
            ["PUT", "/items/1", { status: "consumed" }],
            ["DELETE", "/items/1"],
            ["GET", "/me/inventory"],
          ])
            assert.equal((await call(method, url, body)).status, 401);
          const body = {
            product_name: "Milk",
            barcode: "8850123456789",
            quantity: 2,
            expiration_date: "2026-12-01",
          };
          assert.equal(
            (
              await call(
                "POST",
                "/me/inventory",
                { ...body, user_id: bob.user.user_id },
                alice.token,
              )
            ).status,
            400,
          );
          const created = await call(
            "POST",
            "/me/inventory",
            body,
            alice.token,
          );
          assert.equal(created.status, 201);
          item = created.body;
          assert.equal(item.user_id, alice.user.user_id);
          assert.equal(item.product_id, 1);
          assert.equal(
            (await call("GET", `/items/${alice.user.user_id}`, null, bob.token))
              .status,
            403,
          );
          assert.equal(
            (
              await call(
                "GET",
                `/me/inventory/item/${item.item_id}`,
                null,
                bob.token,
              )
            ).status,
            404,
          );
          for (const method of ["PUT", "PATCH", "DELETE"])
            assert.equal(
              (
                await call(
                  method,
                  `/items/${item.item_id}`,
                  method === "DELETE" ? null : { quantity: 9 },
                  bob.token,
                )
              ).status,
              404,
            );
          assert.equal(
            (
              await call(
                "PATCH",
                `/me/inventory/${item.item_id}`,
                { quantity: 0 },
                alice.token,
              )
            ).status,
            400,
          );
          assert.equal(
            (
              await call(
                "PATCH",
                `/me/inventory/${item.item_id}`,
                { expiration_date: "2026-02-30" },
                alice.token,
              )
            ).status,
            400,
          );
          assert.equal(
            (
              await call(
                "PATCH",
                `/me/inventory/${item.item_id}`,
                { status: "consumed" },
                alice.token,
              )
            ).status,
            200,
          );
          const events = (
            await c.query(
              "SELECT * FROM inventory_events WHERE item_id=? ORDER BY event_id",
              [item.item_id],
            )
          )[0];
          assert.deepEqual(
            events.map((e) => [e.event_type, e.quantity_change]),
            [
              ["added", 2],
              ["consumed", -2],
            ],
          );
          assert.equal(
            (
              await call(
                "DELETE",
                `/me/inventory/${item.item_id}`,
                null,
                alice.token,
              )
            ).status,
            204,
          );
          assert.equal(
            (
              await call(
                "GET",
                `/me/inventory/item/${item.item_id}`,
                null,
                alice.token,
              )
            ).status,
            404,
          );
          assert.equal(
            (
              await c.query(
                "SELECT COUNT(*) n FROM inventory_items WHERE item_id=?",
                [item.item_id],
              )
            )[0][0].n,
            1,
          );
        },
      );
      await t.test(
        "an event failure rolls back the corresponding inventory write",
        async () => {
          const before = (
            await c.query("SELECT COUNT(*) n FROM inventory_items")
          )[0][0].n;
          await c.query(
            "CREATE TRIGGER reject_event BEFORE INSERT ON inventory_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='test failure'",
          );
          try {
            const r = await call(
              "POST",
              "/me/inventory",
              { product_name: "Must roll back", expiration_date: "2026-12-31" },
              alice.token,
            );
            assert.equal(r.status, 500);
            assert.equal(r.body.message, "Database server error.");
            assert.equal(
              (await c.query("SELECT COUNT(*) n FROM inventory_items"))[0][0].n,
              before,
            );
          } finally {
            await c.query("DROP TRIGGER reject_event");
          }
        },
      );
      await t.test(
        "admin checks current role; catalog writes synchronize V2 and preserve aliases",
        async () => {
          assert.equal(
            (await call("GET", "/admin/users", null, alice.token)).status,
            403,
          );
          await c.query("UPDATE users SET role='admin' WHERE user_id=?", [
            alice.user.user_id,
          ]);
          admin = alice.token;
          assert.equal(
            (await call("GET", "/admin/users", null, admin)).status,
            200,
          );
          const r = await call(
            "POST",
            "/admin/products",
            {
              barcode: "TEST001",
              product_name: "Test product",
              category: "Test category",
            },
            admin,
          );
          assert.equal(r.status, 201);
          product = r.body;
          assert.ok(product.category_id);
          assert.equal(
            (
              await call(
                "PATCH",
                `/admin/products/${product.product_id}`,
                { barcode: "TEST002" },
                admin,
              )
            ).status,
            200,
          );
          for (const barcode of ["TEST001", "TEST002"])
            assert.equal(
              (
                await call(
                  "GET",
                  `/products/barcodes/${barcode}`,
                  null,
                  bob.token,
                )
              ).body.product_id,
              product.product_id,
            );
          const collision = await call(
            "PATCH",
            `/admin/products/${product.product_id}`,
            { barcode: "8850123456789" },
            admin,
          );
          assert.equal(collision.status, 409);
          assert.equal(
            (await call("GET", `/products/${product.product_id}`, null, admin))
              .body.barcode,
            "TEST002",
          );
          assert.equal(
            (
              await call(
                "GET",
                "/admin/analytics/summary?from=bad",
                null,
                admin,
              )
            ).status,
            400,
          );
          assert.equal(
            (await call("GET", "/admin/analytics/summary", null, admin)).status,
            200,
          );
          assert.equal(
            (
              await call(
                "DELETE",
                `/admin/products/${product.product_id}`,
                null,
                admin,
              )
            ).status,
            204,
          );
          assert.equal(
            (await call("GET", "/products/barcodes/TEST001", null, bob.token))
              .status,
            404,
          );
          assert.equal(
            (
              await c.query(
                "SELECT COUNT(*) n FROM audit_logs WHERE entity_type=?",
                ["product"],
              )
            )[0][0].n,
            3,
          );
          assert.equal(
            (
              await call(
                "DELETE",
                `/admin/users/${alice.user.user_id}`,
                null,
                admin,
              )
            ).status,
            400,
          );
          assert.equal(
            (
              await call(
                "PATCH",
                `/admin/users/${bob.user.user_id}`,
                { username: "bob-edited" },
                admin,
              )
            ).status,
            200,
          );
          assert.equal(
            (
              await c.query(
                "SELECT COUNT(*) n FROM audit_logs WHERE entity_type='user'",
              )
            )[0][0].n,
            1,
          );
          await c.query("UPDATE users SET role='user' WHERE user_id=?", [
            alice.user.user_id,
          ]);
          assert.equal(
            (await call("GET", "/admin/users", null, admin)).status,
            403,
          );
        },
      );
      await t.test(
        "deactivation invalidates existing token and preserves inventory",
        async () => {
          await c.query("UPDATE users SET is_active=0 WHERE user_id=?", [
            bob.user.user_id,
          ]);
          assert.equal(
            (await call("GET", "/me/inventory", null, bob.token)).status,
            401,
          );
          assert.equal(
            (await call("GET", "/me", null, alice.token)).body.password_hash,
            undefined,
          );
        },
      );
    } finally {
      if (server) await new Promise((resolve) => server.close(resolve));
      if (pool) await pool.end();
      if (c) await c.end();
      // database is generated above and is never read from app configuration.
      await root.query(`DROP DATABASE ${database}`);
      await root.end();
    }
  },
);
