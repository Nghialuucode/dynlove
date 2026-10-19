-- DynLove schema v2 migration (idempotent)
-- Run this after schema.sql to add new tables

-- Tracking per-user, per-day check-ins
CREATE TABLE IF NOT EXISTS daily_checkins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  checkin_date DATE NOT NULL DEFAULT CURRENT_DATE,
  checked_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(couple_id, user_id, checkin_date)
);

-- Tracking per-user, per-day pet interactions (feed/bathe limits)
CREATE TABLE IF NOT EXISTS pet_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action TEXT NOT NULL, -- 'feed' | 'bathe' | 'pet'
  interaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pet_int_lookup ON pet_interactions(couple_id, action, interaction_date);

-- Track pending cooperative actions (waiting for partner)
-- When user1 feeds, insert here; when user2 also feeds same day, apply EXP to both
CREATE TABLE IF NOT EXISTS pet_pending_actions (
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  action_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (couple_id, user_id, action, action_date)
);

-- Missions tracking
CREATE TABLE IF NOT EXISTS missions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  mission_type TEXT NOT NULL, -- 'daily_checkin' | 'weekly_checkin' | 'monthly_checkin' | 'daily_feed_both' | 'daily_bathe_both'
  period_key TEXT NOT NULL, -- e.g. '2026-10-19' for daily, '2026-W42' for weekly, '2026-10' for monthly
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  reward_exp INT DEFAULT 0,
  UNIQUE(couple_id, mission_type, period_key)
);

-- Add start_love_date default to CURRENT_DATE in couples if not exists
-- (already handled in schema.sql but making it safe)
ALTER TABLE couples ALTER COLUMN start_love_date SET DEFAULT CURRENT_DATE;
