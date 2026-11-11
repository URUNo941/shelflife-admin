const { test } = require("node:test");
const assert = require("node:assert/strict");
const { validate } = require("../controllers/inventoryController");
test("reject ownership transfer, unsafe quantities and impossible dates", () => {
  for (const value of [
    { user_id: 2 },
    { product_id: 1 },
    { quantity: -1 },
    { quantity: 1.5 },
    { quantity: 2147483648 },
    { expiration_date: "2025-02-29" },
    { status: "expired" },
    { product_name: "x".repeat(101) },
    [],
  ])
    assert.ok(validate(value, true));
  assert.equal(
    validate({
      product_name: "Milk",
      expiration_date: "2024-02-29",
      quantity: 1,
    }),
    null,
  );
});
test("promise query helper unwraps mysql2 results without a callback", async () => {
  const pool = require("../db_config");
  const execute = pool.execute;
  try {
    pool.execute = async (...args) => {
      assert.deepEqual(args, ["SELECT ?", [7]]);
      return [[{ value: 7 }], []];
    };
    assert.deepEqual(await require("../utils/db").query("SELECT ?", [7]), [
      { value: 7 },
    ]);
  } finally {
    pool.execute = execute;
    await pool.end();
  }
});
