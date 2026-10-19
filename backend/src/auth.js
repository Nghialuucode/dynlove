const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { pool } = require('./db');

const SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES = process.env.JWT_EXPIRES || '15m';
const REFRESH_DAYS = parseInt(process.env.REFRESH_EXPIRES_DAYS || '30', 10);

function signAccess(userId) {
  return jwt.sign({ sub: userId }, SECRET, { expiresIn: JWT_EXPIRES });
}

function hashToken(t) {
  return crypto.createHash('sha256').update(t).digest('hex');
}

async function issueRefresh(userId) {
  const token = crypto.randomBytes(48).toString('hex');
  const hash = hashToken(token);
  const expires = new Date(Date.now() + REFRESH_DAYS * 86400_000);
  await pool.query(
    'INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1,$2,$3)',
    [userId, hash, expires]
  );
  return token;
}

async function rotateRefresh(oldToken) {
  const hash = hashToken(oldToken);
  const { rows } = await pool.query(
    'SELECT * FROM refresh_tokens WHERE token_hash=$1 AND expires_at > NOW()',
    [hash]
  );
  if (!rows.length) throw new Error('invalid_refresh');
  await pool.query('DELETE FROM refresh_tokens WHERE id=$1', [rows[0].id]);
  return issueRefresh(rows[0].user_id);
}

function authMiddleware(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'no_token' });
  try {
    const payload = jwt.verify(token, SECRET);
    req.userId = payload.sub;
    next();
  } catch {
    res.status(401).json({ error: 'bad_token' });
  }
}

module.exports = { signAccess, issueRefresh, rotateRefresh, authMiddleware };
