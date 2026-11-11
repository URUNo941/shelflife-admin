const pool = require('../db_config');

// db_config exports a mysql2 *promise* pool, so await it directly.
// (Passing a callback to a promise pool is ignored and the request hangs.)
async function query(sql, values = []) {
  const [rows] = await pool.query(sql, values);
  return rows;
}

// Run several queries on one connection inside a transaction.
async function withTransaction(work) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const q = async (sql, values = []) => (await conn.query(sql, values))[0];
    const result = await work(q);
    await conn.commit();
    return result;
  } catch (error) {
    await conn.rollback();
    throw error;
  } finally {
    conn.release();
  }
}

function handleDatabaseError(res, error) {
  console.error(error.message);
  if (error.code === 'ER_DUP_ENTRY') {
    return res.status(409).json({ message: 'A record with that value already exists.' });
  }
  if (error.code === 'ER_ROW_IS_REFERENCED_2' || error.code === 'ER_ROW_IS_REFERENCED') {
    return res.status(409).json({ message: 'This record is still used by inventory items.' });
  }
  if (error.code === 'ER_NO_REFERENCED_ROW_2' || error.code === 'ER_NO_REFERENCED_ROW') {
    return res.status(400).json({ message: 'A referenced record does not exist.' });
  }
  return res.status(500).json({ message: 'Database server error.' });
}

function isPositiveId(value) {
  return /^\d+$/.test(String(value)) && Number(value) > 0;
}

module.exports = { query, withTransaction, handleDatabaseError, isPositiveId };
