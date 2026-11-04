process.env.JWT_SECRET ??= 'test-only-secret-for-local-crud-tests';

const assert = require('node:assert/strict');
const argon2 = require('argon2');
const db = require('../db_config');
const app = require('../server');
const { test } = require('node:test');

test('authenticated CRUD works for every database entity', async () => {
  const suffix = Date.now().toString();
  const adminName = `crud_admin_${suffix}`;
  const memberName = `crud_member_${suffix}`;
  const productBarcode = `test${suffix}`.slice(0, 50);
  const connection = db.promise();
  let adminId;
  let memberId;
  let createdUserId;
  let productId;
  let itemId;
  let otherItemId;
  let server;

  try {
    const passwordHash = await argon2.hash('Test-password-42');
    const [admin] = await connection.query(
      'INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)',
      [adminName, passwordHash, 'admin'],
    );
    adminId = admin.insertId;
    const [member] = await connection.query(
      'INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)',
      [memberName, passwordHash, 'user'],
    );
    memberId = member.insertId;

    server = await new Promise((resolve) => {
      const listener = app.listen(0, '127.0.0.1', () => resolve(listener));
    });
    const base = `http://127.0.0.1:${server.address().port}/api`;
    async function request(path, { method = 'GET', token, body } = {}) {
      const response = await fetch(`${base}${path}`, {
        method,
        headers: {
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...(body ? { 'Content-Type': 'application/json' } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      const text = await response.text();
      return { status: response.status, data: text ? JSON.parse(text) : null };
    }

    assert.equal((await request('/products')).status, 401);
    const adminLogin = await request('/auth/login', {
      method: 'POST',
      body: { username: adminName, password: 'Test-password-42' },
    });
    assert.equal(adminLogin.status, 200);
    const adminToken = adminLogin.data.token;
    const memberLogin = await request('/auth/login', {
      method: 'POST',
      body: { username: memberName, password: 'Test-password-42' },
    });
    assert.equal(memberLogin.status, 200);
    const memberToken = memberLogin.data.token;

    const users = await request('/users', { token: adminToken });
    assert.equal(users.status, 200);
    assert.ok(users.data.every((user) => !('password_hash' in user)));
    assert.equal((await request('/users', { token: memberToken })).status, 403);

    let response = await request('/products', {
      method: 'POST',
      token: adminToken,
      body: {
        barcode: productBarcode,
        product_name: 'CRUD test product',
        created_by: adminId,
      },
    });
    assert.equal(response.status, 201);
    productId = response.data.product_id;
    assert.equal((await request(`/products/${productId}`, { token: adminToken })).status, 200);
    assert.equal(
      (await request(`/products/master/${productBarcode}`, { token: adminToken })).status,
      200,
    );
    assert.equal(
      (
        await request(`/products/${productId}`, {
          method: 'PATCH',
          token: adminToken,
          body: { category: 'Test' },
        })
      ).status,
      200,
    );
    assert.equal(
      (await request(`/products/${productId}`, { method: 'DELETE', token: adminToken })).status,
      204,
    );
    productId = null;

    response = await request('/users', {
      method: 'POST',
      token: adminToken,
      body: { username: `crud_created_${suffix}`, password: 'Another-test-42' },
    });
    assert.equal(response.status, 201);
    createdUserId = response.data.user_id;
    assert.equal(
      (
        await request(`/users/${createdUserId}`, {
          method: 'PATCH',
          token: adminToken,
          body: { role: 'admin' },
        })
      ).status,
      200,
    );
    assert.equal(
      (await request(`/users/${createdUserId}`, { method: 'DELETE', token: adminToken })).status,
      204,
    );
    createdUserId = null;

    response = await request('/items', {
      method: 'POST',
      token: adminToken,
      body: {
        user_id: memberId,
        barcode: productBarcode,
        product_name: 'CRUD test item',
        quantity: 2,
        expiration_date: '2027-01-15',
      },
    });
    assert.equal(response.status, 201);
    itemId = response.data.item_id;
    assert.equal((await request(`/items/${memberId}`, { token: memberToken })).status, 200);
    assert.equal((await request(`/items/${memberId}/${itemId}`, { token: memberToken })).status, 200);
    assert.equal(
      (
        await request(`/items/${itemId}`, {
          method: 'PATCH',
          token: memberToken,
          body: { quantity: 3 },
        })
      ).status,
      200,
    );
    assert.equal(
      (
        await request(`/items/${itemId}`, {
          method: 'PATCH',
          token: memberToken,
          body: { user_id: adminId },
        })
      ).status,
      403,
    );
    assert.equal(
      (await request(`/items/${itemId}`, { method: 'DELETE', token: memberToken })).status,
      204,
    );
    itemId = null;
    response = await request('/items', {
      method: 'POST',
      token: adminToken,
      body: {
        user_id: adminId,
        product_name: 'Ownership test item',
        quantity: 1,
        expiration_date: '2027-01-15',
      },
    });
    assert.equal(response.status, 201);
    otherItemId = response.data.item_id;
    assert.equal(
      (
        await request(`/items/${otherItemId}`, {
          method: 'PATCH',
          token: memberToken,
          body: { user_id: memberId },
        })
      ).status,
      403,
    );
    assert.equal(
      (await request(`/items/${otherItemId}`, { method: 'DELETE', token: adminToken })).status,
      204,
    );
    otherItemId = null;
  } finally {
    if (server) {
      await new Promise((resolve) => {
        server.close(resolve);
        server.closeAllConnections();
      });
    }
    if (itemId) await connection.query('DELETE FROM inventory_items WHERE item_id = ?', [itemId]);
    if (otherItemId) {
      await connection.query('DELETE FROM inventory_items WHERE item_id = ?', [otherItemId]);
    }
    if (productId) {
      await connection.query('DELETE FROM global_products WHERE product_id = ?', [productId]);
    }
    if (createdUserId) {
      await connection.query('DELETE FROM users WHERE user_id = ?', [createdUserId]);
    }
    if (memberId) {
      await connection.query('DELETE FROM inventory_items WHERE user_id = ?', [memberId]);
      await connection.query('DELETE FROM users WHERE user_id = ?', [memberId]);
    }
    if (adminId) await connection.query('DELETE FROM users WHERE user_id = ?', [adminId]);
    await db.end();
  }
});
