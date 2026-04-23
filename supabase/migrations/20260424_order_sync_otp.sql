-- Ensure orders table has delivery_otp for sync between Kitchen and User DB
ALTER TABLE IF EXISTS public.orders 
ADD COLUMN IF NOT EXISTS delivery_otp TEXT;

-- Ensure primary_address and default_address_id exist in users table
ALTER TABLE IF EXISTS public.users
ADD COLUMN IF NOT EXISTS primary_address TEXT,
ADD COLUMN IF NOT EXISTS default_address_id UUID REFERENCES public.saved_addresses(id) ON DELETE SET NULL;

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_orders_delivery_otp ON public.orders(delivery_otp);
CREATE INDEX IF NOT EXISTS idx_users_default_address_id ON public.users(default_address_id);
