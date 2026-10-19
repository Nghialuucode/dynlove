const express = require('express');
const crypto = require('crypto');
const { pool } = require('./db');
const { signAccess, issueRefresh, rotateRefresh, authMiddleware } = require('./auth');
const { emitToCouple } = require('./socket');

const router = express.Router();

// --- AUTH (mock OTP: bất kỳ phone nào cũng nhận OTP "123456") ---
router.post('/auth/request-otp', (req, res) => {
  const { phone } = req.body;
  if (!phone) return res.status(400).json({ error: 'phone_required' });
  // TODO production: gọi Firebase Auth
  console.log(`[OTP] Sending 123456 to ${phone}`);
  res.json({ ok: true, note: 'use 123456' });
});

router.post('/auth/verify-otp', async (req, res) => {
  const { phone, otp, fullName } = req.body;
  if (otp !== '123456') return res.status(400).json({ error: 'bad_otp' });
  let { rows } = await pool.query('SELECT * FROM users WHERE phone=$1', [phone]);
  let user = rows[0];
  if (!user) {
    ({ rows } = await pool.query(
      'INSERT INTO users (phone, full_name) VALUES ($1,$2) RETURNING *',
      [phone, fullName || 'User']
    ));
    user = rows[0];
  }
  const access = signAccess(user.id);
  const refresh = await issueRefresh(user.id);
  res.json({ user, access, refresh });
});

router.post('/auth/refresh', async (req, res) => {
  try {
    const refresh = await rotateRefresh(req.body.refresh);
    const { rows } = await pool.query(
      'SELECT user_id FROM refresh_tokens WHERE token_hash=$1',
      [crypto.createHash('sha256').update(refresh).digest('hex')]
    );
    res.json({ access: signAccess(rows[0].user_id), refresh });
  } catch {
    res.status(401).json({ error: 'invalid_refresh' });
  }
});

// --- COUPLES ---
router.post('/couples/invite', authMiddleware, async (req, res) => {
  const { rows: u } = await pool.query('SELECT couple_id FROM users WHERE id=$1', [req.userId]);
  if (u[0].couple_id) return res.status(400).json({ error: 'already_paired' });
  const code = crypto.randomBytes(3).toString('hex').toUpperCase();
  await pool.query(
    `INSERT INTO couples (user1_id, user2_id, start_love_date, invite_code)
     VALUES ($1, $1, CURRENT_DATE, $2)
     ON CONFLICT DO NOTHING`,
    [req.userId, code]
  ).catch(() => {});
  // Nếu đã có couple row mồ côi từ trước, update code
  await pool.query(
    `UPDATE couples SET invite_code=$1 WHERE user1_id=$2 AND user2_id=$2`,
    [code, req.userId]
  );
  res.json({ invite_code: code });
});

router.post('/couples/join', authMiddleware, async (req, res) => {
  const { code, startLoveDate } = req.body;
  const { rows: c } = await pool.query(
    'SELECT * FROM couples WHERE invite_code=$1',
    [code]
  );
  if (!c.length) return res.status(404).json({ error: 'code_not_found' });
  const couple = c[0];
  if (couple.user1_id === couple.user2_id) {
    await pool.query(
      'UPDATE couples SET user2_id=$1, start_love_date=$2, invite_code=NULL WHERE id=$3',
      [req.userId, startLoveDate || new Date().toISOString().slice(0,10), couple.id]
    );
  }
  await pool.query('UPDATE users SET couple_id=$1 WHERE id IN ($2,$3)',
    [couple.id, couple.user1_id, req.userId]);
  await pool.query(
    'INSERT INTO pets (couple_id) VALUES ($1) ON CONFLICT (couple_id) DO NOTHING',
    [couple.id]
  );
  const { rows: full } = await pool.query('SELECT * FROM couples WHERE id=$1', [couple.id]);
  res.json({ couple: full[0] });
});

router.get('/couples/me', authMiddleware, async (req, res) => {
  const { rows } = await pool.query(
    `SELECT c.*, 
      (SELECT json_agg(u) FROM (
        SELECT id, full_name, phone FROM users WHERE id IN (c.user1_id, c.user2_id)
      ) u) AS members
     FROM couples c
     JOIN users me ON me.couple_id = c.id
     WHERE me.id = $1`,
    [req.userId]
  );
  if (!rows.length) return res.status(404).json({ error: 'no_couple' });
  res.json(rows[0]);
});

// --- PET ---
router.get('/pets/me', authMiddleware, async (req, res) => {
  const { rows } = await pool.query(
    `SELECT p.* FROM pets p
     JOIN users u ON u.couple_id = p.couple_id
     WHERE u.id = $1`,
    [req.userId]
  );
  if (!rows.length) return res.status(404).json({ error: 'no_pet' });
  res.json(rows[0]);
});

router.post('/pets/interact', authMiddleware, async (req, res) => {
  const { action } = req.body; // feed | pet | bathe
  const gain = { feed: 10, pet: 5, bathe: 8 }[action] || 5;
  const { rows } = await pool.query(
    `UPDATE pets SET 
       exp = exp + $1,
       level = 1 + (exp + $1) / 100,
       hunger = LEAST(100, hunger + $2),
       happiness = LEAST(100, happiness + $3),
       updated_at = NOW()
     FROM users u
     WHERE u.id = $4 AND u.couple_id = pets.couple_id
     RETURNING pets.*`,
    [gain, action === 'feed' ? 20 : 0, gain, req.userId]
  );
  if (!rows.length) return res.status(404).json({ error: 'no_pet' });
  const pet = rows[0];
  emitToCouple(pet.couple_id, 'pet:update', { pet, action });
  res.json({ pet, gained: gain });
});

// --- MESSAGES ---
router.get('/messages', authMiddleware, async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit || '50'), 100);
  const { rows } = await pool.query(
    `SELECT m.*, u.full_name AS sender_name FROM messages m
     JOIN users u ON u.id = m.sender_id
     JOIN users me ON me.couple_id = m.couple_id
     WHERE me.id = $1
     ORDER BY m.created_at DESC LIMIT $2`,
    [req.userId, limit]
  );
  res.json(rows.reverse());
});

router.get('/health', (req, res) => res.json({ status: 'ok', ts: Date.now() }));

module.exports = router;
