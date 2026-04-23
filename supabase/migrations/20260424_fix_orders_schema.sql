-- Migration: Add missing columns to orders table
-- Description: Adds payment_method, delivery_address, customer_name, customer_phone, and user_email to support the application's order payload.

-- Add columns if they don't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='payment_method') THEN
        ALTER TABLE public.orders ADD COLUMN payment_method TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_address') THEN
        ALTER TABLE public.orders ADD COLUMN delivery_address TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='customer_name') THEN
        ALTER TABLE public.orders ADD COLUMN customer_name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='customer_phone') THEN
        ALTER TABLE public.orders ADD COLUMN customer_phone TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='kitchen_name') THEN
        ALTER TABLE public.orders ADD COLUMN kitchen_name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='user_email') THEN
        ALTER TABLE public.orders ADD COLUMN user_email TEXT;
    END IF;
END $$;

-- Update RLS policies to ensure users can still see their orders (already covered by user_id check, but good to keep in mind)
-- No changes needed to existing policies as they are based on user_id.
