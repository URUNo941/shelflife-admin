const pool = require("../db_config");
async function query(sql, values = []) {
  const [rows] = await pool.execute(sql, values);
  return rows;
}
async function transaction(fn) {
  const c = await pool.getConnection();
  try {
    await c.beginTransaction();
    const result = await fn(
      async (sql, values = []) => (await c.execute(sql, values))[0],
    );
    await c.commit();
    return result;
  } catch (e) {
    await c.rollback();
    throw e;
  } finally {
    c.release();
  }
}
function handleDatabaseError(res, error) {
  if (error.code === "ER_DUP_ENTRY")
    return res.status(409).json({ message: "That value already exists." });
  if (error.code === "ER_NO_REFERENCED_ROW_2")
    return res
      .status(400)
      .json({ message: "Referenced record does not exist." });
  return res.status(500).json({ message: "Database server error." });
}
function isPositiveId(v) {
  return (
    /^\d+$/.test(String(v)) && Number.isSafeInteger(Number(v)) && Number(v) > 0
  );
}
module.exports = { query, transaction, handleDatabaseError, isPositiveId };
