-- Migration: Atomic Wallet Top-Up RPC
-- Safely increments wallet balance and records transaction in one go.

CREATE OR REPLACE FUNCTION public.top_up_wallet(
    p_user_id UUID,
    p_amount NUMERIC,
    p_reference_id TEXT,
    p_description TEXT DEFAULT 'Wallet Top-up'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with service_role privileges to bypass RLS for balance updates
AS $$
DECLARE
    v_wallet_id UUID;
BEGIN
    -- 1. Check if this reference_id has already been processed (Idempotency)
    IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE reference_id = p_reference_id) THEN
        RETURN;
    END IF;

    -- 2. Get and lock the wallet row
    SELECT id INTO v_wallet_id 
    FROM public.wallet 
    WHERE user_id = p_user_id 
    FOR UPDATE;

    -- 3. Create wallet if it doesn't exist
    IF v_wallet_id IS NULL THEN
        INSERT INTO public.wallet (user_id, balance, total_credit_received)
        VALUES (p_user_id, p_amount, p_amount)
        RETURNING id INTO v_wallet_id;
    ELSE
        -- 4. Update existing wallet
        UPDATE public.wallet
        SET 
            balance = balance + p_amount,
            total_credit_received = COALESCE(total_credit_received, 0) + p_amount,
            updated_at = NOW()
        WHERE id = v_wallet_id;
    END IF;

    -- 5. Record the transaction
    INSERT INTO public.wallet_transactions (
        wallet_id,
        type,
        amount,
        description,
        status,
        reference_id
    ) VALUES (
        v_wallet_id,
        'credit',
        p_amount,
        p_description,
        'completed',
        p_reference_id
    );
END;
$$;
