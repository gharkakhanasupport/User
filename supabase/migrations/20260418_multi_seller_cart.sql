-- Migration: Multi-Seller Cart — Split Orders Schema + Atomic RPC
-- Creates separate tables to avoid touching existing 'orders' table.

-- ═══════════════════════════════════════════════════════════════
-- 1. TABLES
-- ═══════════════════════════════════════════════════════════════

-- split_orders: one row per kitchen per checkout session
CREATE TABLE IF NOT EXISTS public.split_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  cook_id TEXT NOT NULL,
  kitchen_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','confirmed','preparing','out_for_delivery','delivered','cancelled')),
  subtotal NUMERIC(10,2) NOT NULL,
  delivery_fee NUMERIC(10,2) NOT NULL DEFAULT 0,
  total NUMERIC(10,2) NOT NULL,
  delivery_address JSONB NOT NULL DEFAULT '{}'::jsonb,
  note TEXT,
  payment_method TEXT DEFAULT 'wallet',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- split_order_items: one row per dish per order
CREATE TABLE IF NOT EXISTS public.split_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.split_orders(id) ON DELETE CASCADE,
  menu_item_id TEXT NOT NULL,
  dish_name TEXT NOT NULL,
  price_at_order NUMERIC(10,2) NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  image_url TEXT
);

-- ═══════════════════════════════════════════════════════════════
-- 2. ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.split_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_order_items ENABLE ROW LEVEL SECURITY;

-- Clean up existing policies if they exist (allows re-running script)
DROP POLICY IF EXISTS "Users read own split_orders" ON public.split_orders;
DROP POLICY IF EXISTS "Users insert own split_orders" ON public.split_orders;
DROP POLICY IF EXISTS "Users read own split_order_items" ON public.split_order_items;
DROP POLICY IF EXISTS "Users insert own split_order_items" ON public.split_order_items;

CREATE POLICY "Users read own split_orders"
  ON public.split_orders FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users insert own split_orders"
  ON public.split_orders FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users read own split_order_items"
  ON public.split_order_items FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.split_orders WHERE id = order_id AND user_id = auth.uid()));

CREATE POLICY "Users insert own split_order_items"
  ON public.split_order_items FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.split_orders WHERE id = order_id AND user_id = auth.uid()));

-- ═══════════════════════════════════════════════════════════════
-- 3. ATOMIC place_split_order RPC
-- ═══════════════════════════════════════════════════════════════
-- Input: user id, delivery address, payment method, array of kitchen order groups
-- Returns: array of created order summaries

CREATE OR REPLACE FUNCTION public.place_split_order(
  p_user_id UUID,
  p_delivery_address JSONB,
  p_payment_method TEXT,
  p_orders JSONB
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_group JSONB;
  v_item JSONB;
  v_order_id UUID;
  v_subtotal NUMERIC;
  v_group_total NUMERIC;
  v_grand_total NUMERIC := 0;
  v_wallet_id UUID;
  v_wallet_balance NUMERIC;
  v_result JSONB := '[]'::jsonb;
BEGIN
  -- 1. Calculate Grand Total across all split orders
  FOR v_group IN SELECT * FROM jsonb_array_elements(p_orders)
  LOOP
    v_subtotal := (
      SELECT COALESCE(SUM((item->>'price_at_order')::NUMERIC * (item->>'quantity')::INTEGER), 0)
      FROM jsonb_array_elements(v_group->'items') AS item
    );
    v_grand_total := v_grand_total + v_subtotal + COALESCE((v_group->>'delivery_fee')::NUMERIC, 0);
  END LOOP;

  -- 2. Handle Wallet Payment
  IF p_payment_method = 'wallet' THEN
    -- Lock wallet row to prevent race conditions
    SELECT id, balance INTO v_wallet_id, v_wallet_balance 
    FROM public.wallet 
    WHERE user_id = p_user_id 
    FOR UPDATE;

    IF v_wallet_id IS NULL THEN
      RAISE EXCEPTION 'WALLET_NOT_FOUND';
    END IF;

    IF v_wallet_balance < v_grand_total THEN
      RAISE EXCEPTION 'INSUFFICIENT_FUNDS';
    END IF;

    -- Debit grand total
    UPDATE public.wallet 
    SET balance = balance - v_grand_total,
        total_credit_used = COALESCE(total_credit_used, 0) + v_grand_total,
        updated_at = NOW() 
    WHERE id = v_wallet_id;

    -- Record a single transaction for the multi-order checkout
    INSERT INTO public.wallet_transactions (
      wallet_id, type, amount, description, status
    ) VALUES (
      v_wallet_id, 'debit', v_grand_total, 'Order Payment (Split Orders)', 'completed'
    );
  END IF;

  -- 3. Create each split order
  FOR v_group IN SELECT * FROM jsonb_array_elements(p_orders)
  LOOP
    -- Calculate group total
    v_subtotal := (
      SELECT COALESCE(SUM((item->>'price_at_order')::NUMERIC * (item->>'quantity')::INTEGER), 0)
      FROM jsonb_array_elements(v_group->'items') AS item
    );
    v_group_total := v_subtotal + COALESCE((v_group->>'delivery_fee')::NUMERIC, 0);

    -- Insert order row
    INSERT INTO public.split_orders (
      user_id, cook_id, kitchen_name, status, subtotal,
      delivery_fee, total, delivery_address, note, payment_method
    ) VALUES (
      p_user_id,
      v_group->>'cook_id',
      v_group->>'kitchen_name',
      'pending',
      v_subtotal,
      COALESCE((v_group->>'delivery_fee')::NUMERIC, 0),
      v_group_total,
      p_delivery_address,
      v_group->>'note',
      p_payment_method
    ) RETURNING id INTO v_order_id;

    -- 4. Increment kitchen order count
    UPDATE public.kitchens 
    SET total_orders = COALESCE(total_orders, 0) + 1 
    WHERE id::text = v_group->>'cook_id' 
       OR cook_id = v_group->>'cook_id';

    -- 5. Insert order items
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_group->'items')
    LOOP
      INSERT INTO public.split_order_items (
        order_id, menu_item_id, dish_name, price_at_order, quantity, image_url
      ) VALUES (
        v_order_id,
        v_item->>'menu_item_id',
        v_item->>'dish_name',
        (v_item->>'price_at_order')::NUMERIC,
        (v_item->>'quantity')::INTEGER,
        v_item->>'image_url'
      );
    END LOOP;

    -- Accumulate result
    v_result := v_result || jsonb_build_array(jsonb_build_object(
      'order_id', v_order_id,
      'cook_id', v_group->>'cook_id',
      'kitchen_name', v_group->>'kitchen_name',
      'total', v_group_total
    ));
  END LOOP;

  RETURN v_result;
END;
$$;
