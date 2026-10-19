const express = require('express');
const crypto = require('crypto');
const { pool } = require('./db');
const { signAccess, issueRefresh, rotateRefresh, authMiddleware } = require('./auth');
const { emitToCouple } = require('./socket');

const router = express.Router();

// ─── HELPERS ────────────────────────────────────────────────────────────────

function todayStr() {
  return new Date().toISOString().slice(0, 10); // 'YYYY-MM-DD'
}

function weekKey() {
  const now = new Date();
  const start = new Date(now.getFullYear(), 0, 1);
  const week = Math.ceil(((now - start) / 86400000 + start.getDay() + 1) / 7);
  return `${now.getFullYear()}-W${String(week).padStart(2, '0')}`;
}

function monthKey() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

async function getCoupleIdForUser(userId) {
  const { rows } = await pool.query('SELECT couple_id FROM users WHERE id=$1', [userId]);
  return rows[0]?.couple_id || null;
}

// ─── AUTH ────────────────────────────────────────────────────────────────────

router.post('/auth/request-otp', (req, res) => {
  const { phone } = req.body;
  if (!phone) return res.status(400).json({ error: 'phone_required' });
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

// ─── COUPLES ─────────────────────────────────────────────────────────────────

// Tạo mã mời
router.post('/couples/invite', authMiddleware, async (req, res) => {
  try {
    const { rows: u } = await pool.query('SELECT couple_id FROM users WHERE id=$1', [req.userId]);
    if (u[0]?.couple_id) return res.status(400).json({ error: 'already_paired' });

    // Xóa couple mồ côi cũ nếu có (user1_id = user2_id)
    await pool.query(
      `DELETE FROM couples WHERE user1_id=$1 AND user2_id=$1`,
      [req.userId]
    );

    const code = crypto.randomBytes(3).toString('hex').toUpperCase();
    await pool.query(
      `INSERT INTO couples (user1_id, user2_id, start_love_date, invite_code)
       VALUES ($1, $1, CURRENT_DATE, $2)`,
      [req.userId, code]
    );
    res.json({ invite_code: code });
  } catch (err) {
    console.error('[invite]', err);
    res.status(500).json({ error: 'server_error', detail: err.message });
  }
});

// Nhập mã ghép đôi
router.post('/couples/join', authMiddleware, async (req, res) => {
  try {
    const { code, startLoveDate } = req.body;
    if (!code) return res.status(400).json({ error: 'code_required' });

    const { rows: c } = await pool.query(
      'SELECT * FROM couples WHERE invite_code=$1',
      [code.toUpperCase().trim()]
    );
    if (!c.length) return res.status(404).json({ error: 'code_not_found' });
    const couple = c[0];

    // Chỉ join được nếu phòng chưa có người thứ 2 (user1_id = user2_id)
    if (couple.user1_id !== couple.user2_id) {
      return res.status(400).json({ error: 'room_full' });
    }
    if (couple.user1_id === req.userId) {
      return res.status(400).json({ error: 'cannot_join_own_room' });
    }

    const loveDate = startLoveDate || todayStr();

    // Cập nhật couple: điền user2, ngày yêu, xóa invite_code
    await pool.query(
      'UPDATE couples SET user2_id=$1, start_love_date=$2, invite_code=NULL WHERE id=$3',
      [req.userId, loveDate, couple.id]
    );

    // Gán couple_id cho cả 2 users
    await pool.query(
      'UPDATE users SET couple_id=$1 WHERE id=$2 OR id=$3',
      [couple.id, couple.user1_id, req.userId]
    );

    // Tạo pet nếu chưa có
    await pool.query(
      'INSERT INTO pets (couple_id) VALUES ($1) ON CONFLICT (couple_id) DO NOTHING',
      [couple.id]
    );

    const { rows: full } = await pool.query('SELECT * FROM couples WHERE id=$1', [couple.id]);

    // Thông báo real-time cho user1
    emitToCouple(couple.id, 'couple:joined', { couple: full[0] });

    res.json({ couple: full[0] });
  } catch (err) {
    console.error('[join]', err);
    res.status(500).json({ error: 'server_error', detail: err.message });
  }
});

router.get('/couples/me', authMiddleware, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT c.*,
        (SELECT json_agg(u) FROM (
          SELECT id, full_name, phone FROM users WHERE id = c.user1_id OR id = c.user2_id
        ) u) AS members
       FROM couples c
       JOIN users me ON me.couple_id = c.id
       WHERE me.id = $1`,
      [req.userId]
    );
    if (!rows.length) return res.status(404).json({ error: 'no_couple' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'server_error', detail: err.message });
  }
});

// ─── CHECK-IN ────────────────────────────────────────────────────────────────

router.post('/checkin', authMiddleware, async (req, res) => {
  try {
    const coupleId = await getCoupleIdForUser(req.userId);
    if (!coupleId) return res.status(404).json({ error: 'no_couple' });

    const today = todayStr();

    // Kiểm tra xem hôm nay đã điểm danh chưa
    const { rows: existing } = await pool.query(
      'SELECT id FROM daily_checkins WHERE couple_id=$1 AND user_id=$2 AND checkin_date=$3',
      [coupleId, req.userId, today]
    );
    if (existing.length) {
      return res.status(400).json({ error: 'already_checkin_today' });
    }

    await pool.query(
      'INSERT INTO daily_checkins (couple_id, user_id, checkin_date) VALUES ($1,$2,$3)',
      [coupleId, req.userId, today]
    );

    // Kiểm tra cả 2 đã điểm danh chưa
    const { rows: bothCheckins } = await pool.query(
      `SELECT user_id FROM daily_checkins 
       WHERE couple_id=$1 AND checkin_date=$2`,
      [coupleId, today]
    );

    const bothCheckedIn = bothCheckins.length >= 2;

    // Nếu cả 2 điểm danh → tặng thêm EXP
    let bonusExp = 0;
    if (bothCheckedIn) {
      bonusExp = 20;
      await pool.query(
        `UPDATE pets SET exp = exp + $1, level = 1 + (exp + $1) / 100, updated_at = NOW()
         WHERE couple_id = $2`,
        [bonusExp, coupleId]
      );

      // Ghi nhận mission điểm danh ngày
      await pool.query(
        `INSERT INTO missions (couple_id, mission_type, period_key, reward_exp)
         VALUES ($1, 'daily_checkin', $2, $3)
         ON CONFLICT (couple_id, mission_type, period_key) DO NOTHING`,
        [coupleId, today, bonusExp]
      );

      // Kiểm tra weekly mission (7 ngày điểm danh trong tuần)
      const wk = weekKey();
      const { rows: weekDays } = await pool.query(
        `SELECT COUNT(DISTINCT checkin_date) as cnt FROM daily_checkins
         WHERE couple_id=$1 AND checkin_date >= date_trunc('week', CURRENT_DATE)
         AND checkin_date < date_trunc('week', CURRENT_DATE) + INTERVAL '7 days'`,
        [coupleId]
      );
      if (parseInt(weekDays[0]?.cnt || 0) >= 7) {
        const inserted = await pool.query(
          `INSERT INTO missions (couple_id, mission_type, period_key, reward_exp)
           VALUES ($1, 'weekly_checkin', $2, 100)
           ON CONFLICT (couple_id, mission_type, period_key) DO NOTHING
           RETURNING id`,
          [coupleId, wk]
        );
        if (inserted.rows.length) {
          await pool.query(`UPDATE pets SET exp = exp + 100, updated_at = NOW() WHERE couple_id=$1`, [coupleId]);
        }
      }

      // Kiểm tra monthly mission
      const mk = monthKey();
      const { rows: monthDays } = await pool.query(
        `SELECT COUNT(DISTINCT checkin_date) as cnt FROM daily_checkins
         WHERE couple_id=$1 AND date_trunc('month', checkin_date) = date_trunc('month', CURRENT_DATE)`,
        [coupleId]
      );
      const daysInMonth = new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0).getDate();
      if (parseInt(monthDays[0]?.cnt || 0) >= daysInMonth) {
        const inserted = await pool.query(
          `INSERT INTO missions (couple_id, mission_type, period_key, reward_exp)
           VALUES ($1, 'monthly_checkin', $2, 500)
           ON CONFLICT (couple_id, mission_type, period_key) DO NOTHING
           RETURNING id`,
          [coupleId, mk]
        );
        if (inserted.rows.length) {
          await pool.query(`UPDATE pets SET exp = exp + 500, updated_at = NOW() WHERE couple_id=$1`, [coupleId]);
        }
      }

      emitToCouple(coupleId, 'checkin:both', { date: today, bonusExp });
    }

    const { rows: petRows } = await pool.query('SELECT * FROM pets WHERE couple_id=$1', [coupleId]);

    res.json({
      ok: true,
      both_checked_in: bothCheckedIn,
      bonus_exp: bonusExp,
      checkin_count_today: bothCheckins.length,
      pet: petRows[0] || null,
    });
  } catch (err) {
    console.error('[checkin]', err);
    res.status(500).json({ error: 'server_error', detail: err.message });
  }
});

// ─── PET ─────────────────────────────────────────────────────────────────────

router.get('/pets/me', authMiddleware, async (req, res) => {
  try {
    const coupleId = await getCoupleIdForUser(req.userId);
    if (!coupleId) return res.status(404).json({ error: 'no_couple' });

    const { rows } = await pool.query('SELECT * FROM pets WHERE couple_id=$1', [coupleId]);
    if (!rows.length) return res.status(404).json({ error: 'no_pet' });

    const today = todayStr();

    // Đếm số lần cho ăn và tắm của mỗi người hôm nay
    const { rows: myActions } = await pool.query(
      `SELECT action, COUNT(*) as cnt FROM pet_interactions
       WHERE couple_id=$1 AND user_id=$2 AND interaction_date=$3
       GROUP BY action`,
      [coupleId, req.userId, today]
    );
    const myFeed = parseInt(myActions.find(a => a.action === 'feed')?.cnt || 0);
    const myBathe = parseInt(myActions.find(a => a.action === 'bathe')?.cnt || 0);

    // Kiểm tra partner đã cho ăn/tắm chưa
    const { rows: partnerPending } = await pool.query(
      `SELECT action FROM pet_pending_actions
       WHERE couple_id=$1 AND user_id!=$2 AND action_date=$3`,
      [coupleId, req.userId, today]
    );
    const partnerFedToday = partnerPending.some(p => p.action === 'feed');
    const partnerBathedToday = partnerPending.some(p => p.action === 'bathe');

    // Kiểm tra mình đã điểm danh chưa
    const { rows: myCheckin } = await pool.query(
      'SELECT id FROM daily_checkins WHERE couple_id=$1 AND user_id=$2 AND checkin_date=$3',
      [coupleId, req.userId, today]
    );

    // Đếm điểm danh của cả 2 hôm nay
    const { rows: todayCheckins } = await pool.query(
      'SELECT COUNT(*) as cnt FROM daily_checkins WHERE couple_id=$1 AND checkin_date=$2',
      [coupleId, today]
    );

    res.json({
      ...rows[0],
      my_feed_today: myFeed,
      my_bathe_today: myBathe,
      partner_fed_today: partnerFedToday,
      partner_bathed_today: partnerBathedToday,
      my_checkin_today: myCheckin.length > 0,
      both_checkin_today: parseInt(todayCheckins[0]?.cnt || 0) >= 2,
    });
  } catch (err) {
    console.error('[pets/me]', err);
    res.status(500).json({ error: 'server_error', detail: err.message });
  }
});

// Tương tác với pet
router.post('/pets/interact', authMiddleware, async (req, res) => {
  try {
    const { action } = req.body; // feed | pet | bathe
    const coupleId = await getCoupleIdForUser(req.userId);
    if (!coupleId) return res.status(404).json({ error: 'no_couple' });

    const today = todayStr();

    // Kiểm tra cả 2 đã điểm danh chưa (bắt buộc để được cho ăn)
    const { rows: checkinRows } = await pool.query(
      'SELECT COUNT(*) as cnt FROM daily_checkins WHERE couple_id=$1 AND checkin_date=$2',
      [coupleId, today]
    );
    const bothCheckedIn = parseInt(checkinRows[0]?.cnt || 0) >= 2;

    if ((action === 'feed' || action === 'bathe') && !bothCheckedIn) {
      return res.status(400).json({
        error: 'checkin_required',
        message: 'Cả 2 cần điểm danh hằng ngày trước khi tương tác với thú cưng!'
      });
    }

    // Giới hạn 2 lần/ngày cho feed và bathe
    if (action === 'feed' || action === 'bathe') {
      const { rows: countRows } = await pool.query(
        `SELECT COUNT(*) as cnt FROM pet_interactions
         WHERE couple_id=$1 AND user_id=$2 AND action=$3 AND interaction_date=$4`,
        [coupleId, req.userId, action, today]
      );
      const count = parseInt(countRows[0]?.cnt || 0);
      if (count >= 2) {
        return res.status(400).json({
          error: 'daily_limit_reached',
          message: action === 'feed'
            ? 'Bạn đã cho ăn 2 lần hôm nay rồi! Đợi đến ngày mai nhé 🐾'
            : 'Bạn đã tắm cho pet 2 lần hôm nay rồi! Đợi đến ngày mai nhé 🛁'
        });
      }
    }

    // Ghi lại interaction
    await pool.query(
      'INSERT INTO pet_interactions (couple_id, user_id, action, interaction_date) VALUES ($1,$2,$3,$4)',
      [coupleId, req.userId, action, today]
    );

    // Xử lý cooperative mechanic cho feed và bathe
    let expGained = 0;
    let cooperativeBonus = false;
    let waitingForPartner = false;

    if (action === 'feed' || action === 'bathe') {
      // Kiểm tra partner đã thực hiện hành động này chưa
      const { rows: partnerPending } = await pool.query(
        `SELECT id FROM pet_pending_actions
         WHERE couple_id=$1 AND user_id!=$2 AND action=$3 AND action_date=$4`,
        [coupleId, req.userId, action, today]
      );

      if (partnerPending.length > 0) {
        // Partner đã làm trước → CỔ ĐỘNG ĐIỂM! Xóa pending và tính EXP
        await pool.query(
          `DELETE FROM pet_pending_actions
           WHERE couple_id=$1 AND action=$2 AND action_date=$3`,
          [coupleId, action, today]
        );
        expGained = action === 'feed' ? 30 : 25;
        cooperativeBonus = true;

        // Ghi mission nếu cả 2 cho ăn
        if (action === 'feed') {
          await pool.query(
            `INSERT INTO missions (couple_id, mission_type, period_key, reward_exp)
             VALUES ($1, 'daily_feed_both', $2, $3)
             ON CONFLICT (couple_id, mission_type, period_key) DO NOTHING`,
            [coupleId, today, expGained]
          );
        }
        if (action === 'bathe') {
          await pool.query(
            `INSERT INTO missions (couple_id, mission_type, period_key, reward_exp)
             VALUES ($1, 'daily_bathe_both', $2, $3)
             ON CONFLICT (couple_id, mission_type, period_key) DO NOTHING`,
            [coupleId, today, expGained]
          );
        }
      } else {
        // Mình làm trước, chờ partner
        await pool.query(
          `INSERT INTO pet_pending_actions (couple_id, user_id, action, action_date)
           VALUES ($1,$2,$3,$4)
           ON CONFLICT (couple_id, user_id, action, action_date) DO NOTHING`,
          [coupleId, req.userId, action, today]
        );
        expGained = 0;
        waitingForPartner = true;
      }
    } else {
      // action = 'pet' → không cần cooperative, cộng điểm ngay
      expGained = 5;
    }

    // Cập nhật stats pet
    const hungerGain = action === 'feed' ? 20 : 0;
    const waterGain = action === 'bathe' ? 15 : 0;
    const happinessGain = action === 'pet' ? 10 : (cooperativeBonus ? 5 : 0);

    const { rows: petRows } = await pool.query(
      `UPDATE pets SET
         exp = exp + $1,
         level = 1 + (exp + $1) / 100,
         hunger = LEAST(100, hunger + $2),
         happiness = LEAST(100, happiness + $3),
         updated_at = NOW()
       WHERE couple_id = $4
       RETURNING *`,
      [expGained, hungerGain, happinessGain, coupleId]
    );

    const pet = petRows[0];
    emitToCouple(coupleId, 'pet:update', { pet, action, cooperativeBonus, waitingForPartner });

    res.json({
      pet,
      gained_exp: expGained,
      cooperative_bonus: cooperativeBonus,
      waiting_for_partner: waitingForPartner,
      message: waitingForPartner
        ? (action === 'feed'
          ? 'Đã cho ăn! Đang chờ người ấy cùng cho ăn để tính điểm 🐾💕'
          : 'Đã tắm! Đang chờ người ấy cùng tắm để tính điểm 🛁💕')
        : (cooperativeBonus
          ? (action === 'feed'
            ? 'Cả hai cùng cho ăn! Thú cưng vui lắm! +30 EXP 🎉'
            : 'Cả hai cùng tắm! Thú cưng sạch sẽ! +25 EXP 🎉')
          : 'Đã xoa đầu! Thú cưng thích lắm! +5 EXP 🥰')
    });
  } catch (err) {
    console.error('[pets/interact]', err);
    res.status(500).json({ error: 'server_error', detail: err.message });
  }
});

// ─── MISSIONS ─────────────────────────────────────────────────────────────────

router.get('/missions', authMiddleware, async (req, res) => {
  try {
    const coupleId = await getCoupleIdForUser(req.userId);
    if (!coupleId) return res.status(404).json({ error: 'no_couple' });

    const today = todayStr();
    const wk = weekKey();
    const mk = monthKey();

    // Kiểm tra điểm danh hôm nay
    const { rows: checkins } = await pool.query(
      'SELECT COUNT(*) as cnt FROM daily_checkins WHERE couple_id=$1 AND checkin_date=$2',
      [coupleId, today]
    );
    const checkinCount = parseInt(checkins[0]?.cnt || 0);

    // Kiểm tra cho ăn hôm nay
    const { rows: feedMission } = await pool.query(
      `SELECT id FROM missions WHERE couple_id=$1 AND mission_type='daily_feed_both' AND period_key=$2`,
      [coupleId, today]
    );

    // Kiểm tra tắm hôm nay
    const { rows: batheMission } = await pool.query(
      `SELECT id FROM missions WHERE couple_id=$1 AND mission_type='daily_bathe_both' AND period_key=$2`,
      [coupleId, today]
    );

    // Điểm danh tuần (cả 2 cùng điểm trong 7 ngày)
    const { rows: weekDays } = await pool.query(
      `SELECT COUNT(DISTINCT checkin_date) as cnt FROM daily_checkins
       WHERE couple_id=$1 AND checkin_date >= date_trunc('week', CURRENT_DATE)`,
      [coupleId]
    );
    const weekCheckinCount = parseInt(weekDays[0]?.cnt || 0);
    const { rows: weekMission } = await pool.query(
      `SELECT id FROM missions WHERE couple_id=$1 AND mission_type='weekly_checkin' AND period_key=$2`,
      [coupleId, wk]
    );

    // Điểm danh tháng
    const { rows: monthDays } = await pool.query(
      `SELECT COUNT(DISTINCT checkin_date) as cnt FROM daily_checkins
       WHERE couple_id=$1 AND date_trunc('month', checkin_date) = date_trunc('month', CURRENT_DATE)`,
      [coupleId]
    );
    const monthCheckinCount = parseInt(monthDays[0]?.cnt || 0);
    const daysInMonth = new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0).getDate();
    const { rows: monthMission } = await pool.query(
      `SELECT id FROM missions WHERE couple_id=$1 AND mission_type='monthly_checkin' AND period_key=$2`,
      [coupleId, mk]
    );

    res.json({
      daily: [
        {
          id: 'daily_checkin',
          title: 'Cùng điểm danh hôm nay',
          description: 'Cả 2 cùng điểm danh mỗi ngày để nhận +20 EXP',
          progress: checkinCount,
          target: 2,
          done: checkinCount >= 2,
          reward: '+20 EXP',
          period: today,
        },
        {
          id: 'daily_feed_both',
          title: 'Cùng nhau cho thú cưng ăn',
          description: 'Cả 2 cùng cho ăn trong ngày để nhận +30 EXP',
          progress: feedMission.length > 0 ? 2 : (checkinCount > 0 ? 1 : 0),
          target: 2,
          done: feedMission.length > 0,
          reward: '+30 EXP',
          period: today,
        },
        {
          id: 'daily_bathe_both',
          title: 'Cùng nhau tắm thú cưng',
          description: 'Cả 2 cùng tắm cho pet trong ngày để nhận +25 EXP',
          progress: batheMission.length > 0 ? 2 : (checkinCount > 0 ? 1 : 0),
          target: 2,
          done: batheMission.length > 0,
          reward: '+25 EXP',
          period: today,
        },
      ],
      weekly: [
        {
          id: 'weekly_checkin',
          title: 'Điểm danh 7 ngày liên tiếp',
          description: 'Cả 2 cùng điểm danh đủ 7 ngày trong tuần để nhận +100 EXP',
          progress: weekCheckinCount,
          target: 7,
          done: weekMission.length > 0,
          reward: '+100 EXP',
          period: wk,
        },
      ],
      monthly: [
        {
          id: 'monthly_checkin',
          title: `Điểm danh đủ tháng (${daysInMonth} ngày)`,
          description: `Cả 2 cùng điểm danh đủ ${daysInMonth} ngày trong tháng để nhận +500 EXP`,
          progress: monthCheckinCount,
          target: daysInMonth,
          done: monthMission.length > 0,
          reward: '+500 EXP',
          period: mk,
        },
      ],
    });
  } catch (err) {
    console.error('[missions]', err);
    res.status(500).json({ error: 'server_error', detail: err.message });
  }
});

// ─── MESSAGES ─────────────────────────────────────────────────────────────────

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
