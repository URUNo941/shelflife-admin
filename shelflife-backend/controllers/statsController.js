const { query, handleDatabaseError } = require('../utils/db');

// สถิติ Consumed vs Discarded (ระบบสถิติลดขยะอาหาร)
// - active: ของที่ยังอยู่ในตู้ตอนนี้ (ไม่ขึ้นกับช่วงเวลา)
// - consumed / discarded: นับตามเวลาที่เปลี่ยนสถานะ (status_updated_at) ในช่วงที่เลือก
// - expired: ของที่ยัง active แต่เลยวันหมดอายุแล้ว (คำนวณสด ไม่ได้เก็บในตาราง)

// ช่วงเวลาที่รองรับ -> จุดเริ่มต้นใน SQL (whitelist เท่านั้น ไม่เอาข้อความจากผู้ใช้ไปต่อ SQL)
const PERIOD_START = {
  today: 'CURDATE()',
  week: 'CURDATE() - INTERVAL 6 DAY',
  month: "DATE_FORMAT(CURDATE(), '%Y-%m-01')",
  year: 'MAKEDATE(YEAR(CURDATE()), 1)',
  all: null,
};

function periodOf(req) {
  const period = req.query.period || 'all';
  return Object.prototype.hasOwnProperty.call(PERIOD_START, period) ? period : null;
}

async function summarize({ userId = null, period }) {
  const start = PERIOD_START[period];
  const ownerSql = userId === null ? '' : ' AND i.user_id = ?';
  const ownerValues = userId === null ? [] : [userId];
  const periodSql = start ? ` AND (i.status = 'active' OR i.status_updated_at >= ${start})` : '';

  const rows = await query(
    `SELECT i.status, COUNT(*) AS batches, COALESCE(SUM(i.quantity), 0) AS quantity
     FROM inventory_items AS i WHERE 1 = 1${ownerSql}${periodSql}
     GROUP BY i.status`,
    ownerValues,
  );
  const [expired] = await query(
    `SELECT COUNT(*) AS batches, COALESCE(SUM(i.quantity), 0) AS quantity
     FROM inventory_items AS i
     WHERE i.status = 'active' AND i.expiration_date < CURDATE()${ownerSql}`,
    ownerValues,
  );
  const topWasted = await query(
    `SELECT c.category_name AS category, COUNT(*) AS batches
     FROM inventory_items AS i
     JOIN products AS p ON p.product_id = i.product_id
     JOIN categories AS c ON c.category_id = p.category_id
     WHERE i.status = 'discarded'${ownerSql}${start ? ` AND i.status_updated_at >= ${start}` : ''}
     GROUP BY c.category_id, c.category_name
     ORDER BY batches DESC, c.category_name ASC
     LIMIT 5`,
    ownerValues,
  );

  const pick = (status) => {
    const row = rows.find((r) => r.status === status);
    return { batches: Number(row?.batches ?? 0), quantity: Number(row?.quantity ?? 0) };
  };
  const consumed = pick('consumed');
  const discarded = pick('discarded');
  const finished = consumed.batches + discarded.batches;
  return {
    period,
    active: pick('active'),
    consumed,
    discarded,
    expired: { batches: Number(expired.batches), quantity: Number(expired.quantity) },
    // % ของที่ทิ้ง จากของที่ใช้จบแล้วทั้งหมด (ยิ่งต่ำยิ่งดี)
    waste_rate: finished ? Math.round((discarded.batches * 1000) / finished) / 10 : 0,
    top_discarded_categories: topWasted.map((r) => ({ category: r.category, batches: Number(r.batches) })),
  };
}

// GET /api/stats/me?period=today|week|month|year|all
async function myStats(req, res) {
  const period = periodOf(req);
  if (!period) return res.status(400).json({ message: 'period must be today, week, month, year or all.' });
  try {
    return res.json(await summarize({ userId: req.auth.userId, period }));
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

// GET /api/stats/system?period=...  (admin)
async function systemStats(req, res) {
  const period = periodOf(req);
  if (!period) return res.status(400).json({ message: 'period must be today, week, month, year or all.' });
  try {
    const summary = await summarize({ period });
    const [[users], [products]] = await Promise.all([
      query('SELECT COUNT(*) AS n FROM users'),
      query('SELECT COUNT(*) AS n FROM products'),
    ]);
    return res.json({ ...summary, total_users: Number(users.n), total_products: Number(products.n) });
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

module.exports = { myStats, systemStats, PERIOD_START };
