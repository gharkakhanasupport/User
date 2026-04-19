-- ═══════════════════════════════════════════════════════════════
-- Migration: app_config (realtime settings toggle) + orders table
-- Date: 2026-04-20
-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- 1. APP_CONFIG TABLE — single-row settings with realtime
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.app_config (
  id TEXT PRIMARY KEY DEFAULT 'global',
  split_kitchen_enabled BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed the single global row (default: split kitchen ON)
INSERT INTO public.app_config (id, split_kitchen_enabled)
VALUES ('global', true)
ON CONFLICT (id) DO NOTHING;

-- Auto-touch updated_at on every UPDATE
CREATE OR REPLACE FUNCTION public.touch_app_config_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_config_updated_at ON public.app_config;
CREATE TRIGGER trg_app_config_updated_at
  BEFORE UPDATE ON public.app_config
  FOR EACH ROW EXECUTE FUNCTION public.touch_app_config_updated_at();

-- RLS: allow any authenticated user to SELECT (read the toggle)
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read app_config" ON public.app_config;
CREATE POLICY "Anyone can read app_config"
  ON public.app_config FOR SELECT
  USING (true);

-- NOTE: Only admin/service-role can UPDATE this row.
-- No INSERT/UPDATE policy for authenticated users (admin controls via dashboard).

-- ═══════════════════════════════════════════════════════════════
-- 2. ENABLE REALTIME on app_config
--    (so AppConfigService receives instant updates)
-- ═══════════════════════════════════════════════════════════════
-- Supabase Realtime requires the table to be added to the
-- supabase_realtime publication. Run this in the SQL Editor:
--
--   ALTER PUBLICATION supabase_realtime ADD TABLE public.app_config;
--
-- (Cannot be done inside a standard migration — must be executed
--  separately in the Supabase Dashboard SQL Editor.)


-- ═══════════════════════════════════════════════════════════════
-- 3. ORDERS TABLE — single-kitchen ordering
--    (only created if it doesn't already exist)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.orders (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  cook_id TEXT NOT NULL,
  customer_id TEXT NULL,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  delivery_address TEXT NULL,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  total_amount DOUBLE PRECISION NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'::text,
  created_at TIMESTAMPTZ NULL DEFAULT now(),
  accepted_at TIMESTAMPTZ NULL,
  completed_at TIMESTAMPTZ NULL,
  updated_at TIMESTAMPTZ NULL DEFAULT now(),
  delivery_partner_id UUID NULL,
  delivery_partner_name TEXT NULL,
  delivery_partner_phone TEXT NULL,
  pickup_lat DOUBLE PRECISION NULL,
  pickup_lng DOUBLE PRECISION NULL,
  delivery_lat DOUBLE PRECISION NULL,
  delivery_lng DOUBLE PRECISION NULL,
  current_location JSONB NULL,
  delivery_otp TEXT NULL,
  assigned_at TIMESTAMPTZ NULL,
  picked_up_at TIMESTAMPTZ NULL,
  out_for_delivery_at TIMESTAMPTZ NULL,
  delivered_at TIMESTAMPTZ NULL,
  CONSTRAINT orders_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_orders_delivery_partner
  ON public.orders USING btree (delivery_partner_id) TABLESPACE pg_default
  WHERE delivery_partner_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_orders_status_partner
  ON public.orders USING btree (status, delivery_partner_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_orders_cook_id
  ON public.orders USING btree (cook_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_orders_customer_id
  ON public.orders USING btree (customer_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_orders_status
  ON public.orders USING btree (status) TABLESPACE pg_default;

-- Trigger: auto-update updated_at
-- (reuses the generic touch_updated_at if it exists, otherwise create one)
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_touch_orders_updated_at ON public.orders;
CREATE TRIGGER trg_touch_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Trigger: generate delivery OTP on status change
CREATE OR REPLACE FUNCTION public.generate_delivery_otp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Generate a 4-digit OTP when order moves to 'out_for_delivery'
  IF NEW.status = 'out_for_delivery' AND (OLD.status IS DISTINCT FROM 'out_for_delivery') THEN
    NEW.delivery_otp := LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_generate_delivery_otp ON public.orders;
CREATE TRIGGER trg_generate_delivery_otp
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.generate_delivery_otp();

-- RLS for orders
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own orders" ON public.orders;
CREATE POLICY "Users read own orders"
  ON public.orders FOR SELECT
  USING (auth.uid()::text = customer_id);

DROP POLICY IF EXISTS "Users insert own orders" ON public.orders;
CREATE POLICY "Users insert own orders"
  ON public.orders FOR INSERT
  WITH CHECK (auth.uid()::text = customer_id);

-- Enable realtime on orders too (for order tracking)
-- Run separately in SQL Editor:
--   ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
