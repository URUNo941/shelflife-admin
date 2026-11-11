// End-to-end API test against a throwaway copy of the V2 database.
// Runs only when TEST_DB_HOST is set. Creates a randomly named database from
// database/shelflife_v2_db.sql, starts server.js on a free port, and drops
// only that database afterwards. Never touches shelflife_db or shelflife_v2_db.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const mysql = require('mysql2/promise');
const jwt = require('jsonwebtoken');

const backend = path.join(__dirname, '..');

test('API works on the V2 database with the same JSON shape', { skip: !process.env.TEST_DB_HOST }, async (t) => {
  const dbName = `shelflife_v2_apitest_${crypto.randomBytes(6).toString('hex')}`;
  const secret = crypto.randomBytes(24).toString('hex');
  const port = String(39000 + Math.floor(Math.random() * 1000));
  const config = {
    host: process.env.TEST_DB_HOST,
    port: Number(process.env.TEST_DB_PORT || 3306),
    user: process.env.TEST_DB_USER || 'root',
    password: process.env.TEST_DB_PASSWORD || '',
  };
  const root = await mysql.createConnection({ ...config, multipleStatements: true });
  const install = fs
    .readFileSync(path.join(backend, 'database/shelflife_v2_db.sql'), 'utf8')
    .replaceAll('shelflife_v2_db', dbName);
  let server;
  try {
    await root.query(install);
    server = spawn(process.execPath, ['server.js'], {
      cwd: backend,
      env: {
        ...process.env,
        PORT: port,
        DB_HOST: config.host,
        DB_PORT: String(config.port),
        DB_USER: config.user,
        DB_PASSWORD: config.password,
        DB_NAME: dbName,
        JWT_SECRET: secret,
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('server did not start')), 10000);
      server.stdout.on('data', (d) => {
        if (String(d).includes('Server is running')) {
          clearTimeout(timer);
          resolve();
        }
      });
      server.on('exit', (code) => reject(new Error(`server exited ${code}`)));
    });

    const base = `http://127.0.0.1:${port}/api`;
    const admin = jwt.sign({ userId: 1, role: 'admin' }, secret);
    const call = async (method, url, body, token) => {
      const res = await fetch(base + url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: body === undefined ? undefined : JSON.stringify(body),
      });
      const text = await res.text();
      return { status: res.status, body: text ? JSON.parse(text) : null };
    };
    const sql = async (q, v = []) => (await root.query(q.replaceAll('DB', `\`${dbName}\``), v))[0];

    await t.test('GET /items/:userId returns the fields Flutter reads', async () => {
      const { status, body } = await call('GET', '/items/1');
      assert.equal(status, 200);
      assert.equal(body.length, 4);
      for (const field of ['item_id', 'user_id', 'barcode', 'product_name', 'category', 'quantity', 'expiration_date', 'status'])
        assert.ok(field in body[0], `missing ${field}`);
      const milk = body.find((i) => i.item_id === 1);
      assert.equal(milk.product_name, 'Fresh Milk 1L');
      assert.equal(milk.category, 'Food');
      assert.equal(milk.barcode, '8850123456789');
      // Plain date, not a UTC timestamp that shifts the day in Thailand.
      assert.equal(milk.expiration_date, '2026-11-05');
    });

    await t.test('POST /items with a known barcode reuses the product', async () => {
      const { status, body } = await call('POST', '/items', {
        user_id: 2, barcode: '8850123456789', product_name: 'Milk', category: 'Food', quantity: 3, expiration_date: '2026-12-01',
      });
      assert.equal(status, 201);
      assert.equal(body.message, 'Item added successfully');
      const [row] = await sql('SELECT product_id FROM DB.inventory_items WHERE item_id = ?', [body.item_id]);
      assert.equal(row.product_id, 1);
      assert.equal((await sql('SELECT COUNT(*) n FROM DB.products'))[0].n, 4);
    });

    await t.test('POST /items without barcode shares one product and creates the category once', async () => {
      const item = { user_id: 2, product_name: 'Bananas', category: 'Fruit', expiration_date: '2026-11-20' };
      assert.equal((await call('POST', '/items', item)).status, 201);
      assert.equal((await call('POST', '/items', { ...item, quantity: 2 })).status, 201);
      assert.equal((await sql("SELECT COUNT(*) n FROM DB.products WHERE product_name = 'Bananas'"))[0].n, 1);
      assert.equal((await sql("SELECT COUNT(*) n FROM DB.categories WHERE category_name = 'Fruit'"))[0].n, 1);
      const list = (await call('GET', '/items/2')).body;
      assert.equal(list.filter((i) => i.product_name === 'Bananas' && i.category === 'Fruit').length, 2);
    });

    await t.test('POST /items without product_name is rejected', async () => {
      assert.equal((await call('POST', '/items', { user_id: 2, expiration_date: '2026-11-20' })).status, 400);
    });

    await t.test('PUT /items/:id records when the status changed', async () => {
      assert.equal((await call('PUT', '/items/2', { status: 'consumed' })).status, 200);
      const [row] = await sql('SELECT status, status_updated_at FROM DB.inventory_items WHERE item_id = 2');
      assert.equal(row.status, 'consumed');
      assert.notEqual(row.status_updated_at, null);
      assert.equal((await call('PUT', '/items/2', { status: 'eaten' })).status, 400);
    });

    await t.test('DELETE /items/:id removes the batch but keeps the product', async () => {
      assert.equal((await call('DELETE', '/items/3')).status, 200);
      assert.equal((await sql('SELECT COUNT(*) n FROM DB.inventory_items WHERE item_id = 3'))[0].n, 0);
      assert.equal((await sql('SELECT COUNT(*) n FROM DB.products WHERE product_id = 3'))[0].n, 1);
    });

    await t.test('product endpoints return category by name', async () => {
      const list = await call('GET', '/products');
      assert.equal(list.status, 200);
      assert.ok(list.body.every((p) => typeof p.category === 'string'));
      const byCode = await call('GET', '/products/master/8850111222333');
      assert.equal(byCode.status, 200);
      assert.equal(byCode.body.category, 'Medicine');
      assert.equal((await call('GET', '/products/master/0000')).status, 404);
    });

    await t.test('admin can create, update and delete products; in-use products are protected', async () => {
      const created = await call('POST', '/products', { barcode: 'TEST-1', product_name: 'Test soap', category: 'Household' }, admin);
      assert.equal(created.status, 201);
      assert.equal(created.body.category, 'Household');
      const updated = await call('PUT', `/products/${created.body.product_id}`, { category: 'Food' }, admin);
      assert.equal(updated.status, 200);
      assert.equal(updated.body.category, 'Food');
      assert.equal((await call('DELETE', '/products/1', undefined, admin)).status, 409);
      assert.equal((await call('DELETE', `/products/${created.body.product_id}`, undefined, admin)).status, 204);
      assert.equal((await call('POST', '/products', { barcode: 'X', product_name: 'Y' })).status, 401);
    });

    await t.test('admin user endpoints respond (no hanging queries)', async () => {
      const users = await call('GET', '/users', undefined, admin);
      assert.equal(users.status, 200);
      assert.equal(users.body.length, 2);
      assert.equal('password_hash' in users.body[0], false);
    });
  } finally {
    if (server) server.kill();
    await root.query(`DROP DATABASE IF EXISTS \`${dbName}\``);
    await root.end();
  }
});
