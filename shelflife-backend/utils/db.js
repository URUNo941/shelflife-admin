const con = require('../db_config');

// db_config exports a mysql2/promise pool: query() returns [rows, fields]
// and ignores callbacks, so await it instead of passing one.
async function query(sql, values = []) {
  const [result] = await con.query(sql, values);
  return result;
}

function handleDatabaseError(res, error) {
  console.error(error.message);
  if (error.code === 'ER_DUP_ENTRY') {
    return res.status(409).json({ message: 'A record with that value already exists.' });
  }
  return res.status(500).json({ message: 'Database server error.' });
}

function isPositiveId(value) {
  return /^\d+$/.test(String(value)) && Number(value) > 0;
}

module.exports = { query, handleDatabaseError, isPositiveId };
