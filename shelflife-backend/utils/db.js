const con = require('../db_config');

function query(sql, values = []) {
  return new Promise((resolve, reject) => {
    con.query(sql, values, (error, result) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(result);
    });
  });
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
