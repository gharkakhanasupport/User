-- ============================================================
-- GKK SMS Bridge — Supabase Database Setup
-- Run this in: Supabase Dashboard > SQL Editor
-- ============================================================

-- 1. Create sms_queue table
CREATE TABLE IF NOT EXISTS public.sms_queue (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  phone TEXT NOT NULL,
  otp TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'verified')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Enable Realtime on sms_queue (so Bridge Phone gets instant alerts)
ALTER PUBLICATION supabase_realtime ADD TABLE sms_queue;

-- 3. RLS Policies for sms_queue
ALTER TABLE sms_queue ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to insert OTP requests
CREATE POLICY "Users can insert OTP requests" 
  ON sms_queue FOR INSERT 
  TO authenticated 
  WITH CHECK (true);

-- Allow authenticated users to read OTPs (for verification)
CREATE POLICY "Users can read OTPs" 
  ON sms_queue FOR SELECT 
  TO authenticated 
  USING (true);

-- Allow authenticated users to update OTP status
CREATE POLICY "Users can update OTP status" 
  ON sms_queue FOR UPDATE 
  TO authenticated 
  USING (true);

-- Allow anon to read and update (for the Gateway app)
CREATE POLICY "Anon can read sms_queue" 
  ON sms_queue FOR SELECT 
  TO anon 
  USING (true);

CREATE POLICY "Anon can update sms_queue" 
  ON sms_queue FOR UPDATE 
  TO anon 
  USING (true);

-- 4. Add phone_verified column to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN DEFAULT false;

-- 5. Auto-cleanup: delete OTPs older than 30 minutes (run periodically via cron or pg_cron)
-- You can set this up in Supabase Dashboard > Database > Extensions > pg_cron
-- Example cron job:
-- SELECT cron.schedule('cleanup-old-otps', '*/30 * * * *', $$DELETE FROM sms_queue WHERE created_at < now() - interval '30 minutes'$$);

-- ============================================================
-- Done! Your database is ready for the SMS Bridge system.
-- ============================================================
