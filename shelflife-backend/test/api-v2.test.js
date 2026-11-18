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
const argon2 = require('argon2');

const backend = path.join(__dirname, '..');

test('ShelfLife API on the V2 database', { skip: !process.env.TEST_DB_HOST }, async (t) => {
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
    // Sample users: 1 = tom123 (admin, owns items 1-4), 2 = sarah (user, no items)
    const adminToken = jwt.sign({ userId: 1, role: 'admin' }, secret);
    const sarahToken = jwt.sign({ userId: 2, role: 'user' }, secret);
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

    let mintToken;
    await t.test('register creates a user (argon2id hash) and returns a token', async () => {
      const res = await call('POST', '/auth/register', { username: 'mint', email: 'Mint@Example.com', password: 'secret1' });
      assert.equal(res.status, 201);
      assert.ok(res.body.token);
      assert.equal(res.body.user.role, 'user');
      assert.equal(res.body.user.email, 'mint@example.com');
      assert.equal('password_hash' in res.body.user, false);
      const [row] = await sql("SELECT password_hash FROM DB.users WHERE username = 'mint'");
      assert.match(row.password_hash, /^\$argon2id\$/);
      mintToken = res.body.token;
    });

    await t.test('register validates input and rejects duplicates', async () => {
      assert.equal((await call('POST', '/auth/register', { username: 'ab', email: 'a@b.co', password: 'secret1' })).status, 400);
      assert.equal((await call('POST', '/auth/register', { username: 'abc', email: 'nope', password: 'secret1' })).status, 400);
      assert.equal((await call('POST', '/auth/register', { username: 'abc', email: 'a@b.co', password: '123' })).status, 400);
      assert.equal((await call('POST', '/auth/register', { username: 'mint', email: 'x@y.co', password: 'secret1' })).status, 409);
    });

    await t.test('login works with the right password only; role comes from the DB', async () => {
      const ok = await call('POST', '/auth/login', { username: 'mint', password: 'secret1' });
      assert.equal(ok.status, 200);
      assert.equal(jwt.verify(ok.body.token, secret).role, 'user');
      assert.equal((await call('POST', '/auth/login', { username: 'mint', password: 'wrong!!' })).status, 401);
      // sample accounts have placeholder hashes: login fails cleanly instead of crashing
      assert.equal((await call('POST', '/auth/login', { username: 'tom123', password: 'anything' })).status, 401);
      const me = await call('GET', '/auth/me', undefined, mintToken);
      assert.equal(me.body.username, 'mint');
    });

    await t.test('inventory requires a valid token', async () => {
      assert.equal((await call('GET', '/items')).status, 401);
      assert.equal((await call('GET', '/items', undefined, 'not-a-token')).status, 401);
      const forged = jwt.sign({ userId: 1, role: 'admin' }, 'some-other-secret');
      assert.equal((await call('GET', '/items', undefined, forged)).status, 401);
    });

    await t.test('GET /items returns only my active batches with the fields Flutter reads', async () => {
      const { status, body } = await call('GET', '/items', undefined, adminToken);
      assert.equal(status, 200);
      assert.equal(body.length, 6);
      for (const field of ['item_id', 'user_id', 'barcode', 'product_name', 'category', 'quantity', 'expiration_date', 'image_url', 'status', 'created_at'])
        assert.ok(field in body[0], `missing ${field}`);
      const milk = body.find((i) => i.item_id === 1);
      assert.equal(milk.product_name, 'Fresh Milk 1L');
      assert.equal(milk.category, 'Food');
      assert.equal(milk.expiration_date, '2026-11-05'); // plain date, no UTC shift
      assert.equal((await call('GET', '/items', undefined, sarahToken)).body.length, 0);
      assert.equal((await call('GET', '/items?status=bogus', undefined, sarahToken)).status, 400);
    });

    let uploadedImageUrl;
    await t.test('image upload requires authentication and serves uploaded images', async () => {
      const uploadUrl = `${base}/upload`;
      assert.equal((await fetch(uploadUrl, { method: 'POST' })).status, 401);

      const form = new FormData();
      form.append('image', new Blob(['test image bytes'], { type: 'image/png' }), 'sample.png');
      const response = await fetch(uploadUrl, {
        method: 'POST',
        headers: { Authorization: `Bearer ${sarahToken}` },
        body: form,
      });
      assert.equal(response.status, 200);
      uploadedImageUrl = (await response.json()).imageUrl;
      assert.match(uploadedImageUrl, /^http:\/\/127\.0\.0\.1:\d+\/uploads\/[a-f0-9]+\.png$/);

      const imageResponse = await fetch(uploadedImageUrl);
      assert.equal(imageResponse.status, 200);
      assert.equal(await imageResponse.text(), 'test image bytes');
      await fs.promises.unlink(
        path.join(backend, 'uploads', path.basename(new URL(uploadedImageUrl).pathname)),
      );
    });

    let sarahItem;
    await t.test('POST /items: known barcode reuses the product, owner comes from the token', async () => {
      const { status, body } = await call('POST', '/items', {
        user_id: 1, barcode: '8850123456789', product_name: 'Milk', category: 'Food', quantity: 3, expiration_date: '2026-12-01', image_url: uploadedImageUrl,
      }, sarahToken);
      assert.equal(status, 201);
      assert.equal(body.user_id, 2); // body.user_id is ignored
      assert.equal(body.product_id, 1);
      assert.equal(body.product_name, 'Fresh Milk 1L');
      assert.equal(body.image_url, uploadedImageUrl);
      assert.equal((await sql('SELECT COUNT(*) n FROM DB.products'))[0].n, 6);
      sarahItem = body.item_id;
    });

    await t.test('POST /items without barcode shares one product and creates the category once', async () => {
      const item = { product_name: 'Bananas', category: 'Fruit', expiration_date: '2026-11-20' };
      assert.equal((await call('POST', '/items', item, sarahToken)).status, 201);
      assert.equal((await call('POST', '/items', { ...item, quantity: 2 }, sarahToken)).status, 201);
      assert.equal((await sql("SELECT COUNT(*) n FROM DB.products WHERE product_name = 'Bananas'"))[0].n, 1);
      assert.equal((await sql("SELECT COUNT(*) n FROM DB.categories WHERE category_name = 'Fruit'"))[0].n, 1);
      assert.equal((await call('POST', '/items', { expiration_date: '2026-11-20' }, sarahToken)).status, 400);
      assert.equal((await call('POST', '/items', { product_name: 'X', expiration_date: '2026-02-30' }, sarahToken)).status, 400);
    });

    await t.test('users cannot read, change or delete another user\'s batch', async () => {
      assert.equal((await call('GET', '/items/1', undefined, sarahToken)).status, 404);
      assert.equal((await call('PUT', '/items/1', { quantity: 9 }, sarahToken)).status, 404);
      assert.equal((await call('DELETE', '/items/1', undefined, sarahToken)).status, 404);
      assert.equal((await sql('SELECT quantity FROM DB.inventory_items WHERE item_id = 1'))[0].quantity, 2);
    });

    await t.test('PUT /items/:id edits quantity, expiry and product; status records its time', async () => {
      const edited = await call('PUT', `/items/${sarahItem}`, {
        quantity: 2,
        expiration_date: '2026-12-05',
        image_url: `${uploadedImageUrl}?updated`,
      }, sarahToken);
      assert.equal(edited.status, 200);
      assert.equal(edited.body.quantity, 2);
      assert.equal(edited.body.expiration_date, '2026-12-05');
      assert.equal(edited.body.image_url, `${uploadedImageUrl}?updated`);
      const consumed = await call('PUT', `/items/${sarahItem}`, { status: 'consumed' }, sarahToken);
      assert.equal(consumed.body.status, 'consumed');
      assert.notEqual(consumed.body.status_updated_at, null);
      assert.equal((await call('PUT', `/items/${sarahItem}`, { status: 'eaten' }, sarahToken)).status, 400);
      assert.equal((await call('PUT', `/items/${sarahItem}`, { quantity: 0 }, sarahToken)).status, 400);
      const active = (await call('GET', '/items', undefined, sarahToken)).body;
      assert.equal(active.some((i) => i.item_id === sarahItem), false);
      const all = (await call('GET', '/items?status=all', undefined, sarahToken)).body;
      assert.equal(all.some((i) => i.item_id === sarahItem), true);
    });

    await t.test('stats count consumed vs discarded for me and for the whole system', async () => {
      const bananas = (await call('GET', '/items', undefined, sarahToken)).body.filter((i) => i.product_name === 'Bananas');
      await call('PUT', `/items/${bananas[0].item_id}`, { status: 'discarded' }, sarahToken);
      const mine = await call('GET', '/stats/me?period=today', undefined, sarahToken);
      assert.equal(mine.status, 200);
      assert.equal(mine.body.consumed.batches, 1);
      assert.equal(mine.body.discarded.batches, 1);
      assert.equal(mine.body.active.batches, 1);
      assert.equal(mine.body.waste_rate, 50);
      assert.deepEqual(mine.body.top_discarded_categories, [{ category: 'Fruit', batches: 1 }]);
      assert.equal((await call('GET', '/stats/me?period=decade', undefined, sarahToken)).status, 400);
      assert.equal((await call('GET', '/stats/system', undefined, sarahToken)).status, 403);
      const system = await call('GET', '/stats/system?period=all', undefined, adminToken);
      assert.equal(system.status, 200);
      assert.equal(system.body.total_users, 3);
      assert.equal(system.body.total_products, 7);
      assert.equal(system.body.active.batches, 7);
      // tom123's sample batches expire before today's date in this test run? count only checks the shape
      assert.equal(typeof system.body.expired.batches, 'number');
    });

    await t.test('DELETE /items/:id removes my batch but keeps the product', async () => {
      assert.equal((await call('DELETE', `/items/${sarahItem}`, undefined, sarahToken)).status, 204);
      assert.equal((await sql('SELECT COUNT(*) n FROM DB.inventory_items WHERE item_id = ?', [sarahItem]))[0].n, 0);
      assert.equal((await sql('SELECT COUNT(*) n FROM DB.products WHERE product_id = 1'))[0].n, 1);
    });

    await t.test('barcode auto-fill lookup returns name and category', async () => {
      const byCode = await call('GET', '/products/master/8850111222333');
      assert.equal(byCode.status, 200);
      assert.equal(byCode.body.product_name, 'Paracetamol 500mg (10s)');
      assert.equal(byCode.body.category, 'Medicine');
      assert.equal((await call('GET', '/products/master/0000')).status, 404);
    });

    await t.test('admin manages the catalog; users cannot; in-use products are protected', async () => {
      assert.equal((await call('POST', '/products', { barcode: '111', product_name: 'Y' }, sarahToken)).status, 403);
      const created = await call('POST', '/products', { barcode: '5550001', product_name: 'Test soap', category: 'Household' }, adminToken);
      assert.equal(created.status, 201);
      assert.equal(created.body.category, 'Household');
      const updated = await call('PUT', `/products/${created.body.product_id}`, { category: 'Other' }, adminToken);
      assert.equal(updated.body.category, 'Other');
      assert.equal((await call('POST', '/products', { barcode: '5550001', product_name: 'Dup' }, adminToken)).status, 409);
      assert.equal((await call('DELETE', '/products/1', undefined, adminToken)).status, 409);
      assert.equal((await call('DELETE', `/products/${created.body.product_id}`, undefined, adminToken)).status, 204);
    });

    await t.test('admin manages users; last admin and self are protected', async () => {
      assert.equal((await call('GET', '/users', undefined, sarahToken)).status, 403);
      const list = await call('GET', '/users', undefined, adminToken);
      assert.equal(list.status, 200);
      assert.equal('password_hash' in list.body[0], false);
      const created = await call('POST', '/users', { username: 'newbie', password: 'secret1', role: 'user' }, adminToken);
      assert.equal(created.status, 201);
      const promoted = await call('PUT', `/users/${created.body.user_id}`, { role: 'admin' }, adminToken);
      assert.equal(promoted.body.role, 'admin');
      assert.equal((await call('PUT', '/users/1', { role: 'user' }, adminToken)).status, 400); // self
      assert.equal((await call('DELETE', '/users/1', undefined, adminToken)).status, 400); // self
      assert.equal((await call('DELETE', `/users/${created.body.user_id}`, undefined, adminToken)).status, 204);
      // only one admin left (tom123): demoting it from another admin token is refused
      const hash = await argon2.hash('secret1', { type: argon2.argon2id });
      await sql("INSERT INTO DB.users (username, password_hash, role) VALUES ('helper', ?, 'user')", [hash]);
      const [helper] = await sql("SELECT user_id FROM DB.users WHERE username = 'helper'");
      const helperAdmin = jwt.sign({ userId: helper.user_id, role: 'admin' }, secret);
      assert.equal((await call('PUT', '/users/1', { role: 'user' }, helperAdmin)).status, 400);
      assert.equal((await call('DELETE', '/users/1', undefined, helperAdmin)).status, 400);
    });
  } finally {
    if (server) server.kill();
    await root.query(`DROP DATABASE IF EXISTS \`${dbName}\``);
    await root.end();
  }
});
