-- Add trial_used_at column to track one-time free trial usage.
-- NULL = trial never used; non-NULL = timestamp when trial was activated.
ALTER TABLE subscriptions
  ADD COLUMN IF NOT EXISTS trial_used_at TIMESTAMPTZ NULL;
