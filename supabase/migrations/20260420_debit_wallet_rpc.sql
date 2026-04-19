-- Migration: Add missing debit_wallet RPC
-- Allows order_service to debit the wallet securely before placing an order.

CREATE OR REPLACE FUNCTION public.debit_wallet(
    p_user_id UUID,
    p_amount NUMERIC,
    p_description TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    curr_bal NUMERIC;
    v_wallet_id UUID;
BEGIN
    -- LOCK row for user identity to prevent race conditions
    SELECT id INTO v_wallet_id FROM public.wallet WHERE user_id = p_user_id FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RAISE EXCEPTION 'WALLET_NOT_FOUND';
    END IF;

    SELECT balance INTO curr_bal FROM public.wallet WHERE id = v_wallet_id;

    IF curr_bal < p_amount THEN 
        RAISE EXCEPTION 'INSUFFICIENT_FUNDS'; 
    END IF;
    
    -- Update balance and usage metrics
    UPDATE public.wallet 
    SET 
        balance = balance - p_amount,
        total_credit_used = COALESCE(total_credit_used, 0) + p_amount,
        updated_at = NOW() 
    WHERE id = v_wallet_id;
    
    -- Record the transaction
    INSERT INTO public.wallet_transactions (
        wallet_id, 
        type, 
        amount, 
        description, 
        status
    )
    VALUES (
        v_wallet_id, 
        'debit', 
        p_amount, 
        p_description, 
        'completed'
    );
END;
$$;
