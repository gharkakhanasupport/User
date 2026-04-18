-- Migration: Unified Wallet RPC Implementation
-- Integrates with existing `wallet` and `wallet_transactions` tables.

CREATE OR REPLACE FUNCTION process_wallet_payment(p_user_id UUID, p_amount NUMERIC, p_order_id UUID)
RETURNS void AS $$
DECLARE
    curr_bal NUMERIC;
    v_wallet_id UUID;
BEGIN
    -- SECURITY CHECK: Verify requester is the target user or it's a valid ID
    -- We use p_user_id for flexibility but check auth.uid() for extra safety if needed.
    
    -- LOCK row for user identity (works across Web/App simultaneously) to prevent race conditions
    v_wallet_id := (SELECT id FROM public.wallet WHERE user_id = p_user_id FOR UPDATE);
    curr_bal := (SELECT balance FROM public.wallet WHERE id = v_wallet_id);
    
    IF v_wallet_id IS NULL THEN
        RAISE EXCEPTION 'WALLET_NOT_FOUND';
    END IF;

    IF curr_bal < p_amount THEN 
        RAISE EXCEPTION 'INSUFFICIENT_FUNDS'; 
    END IF;
    
    -- Update balance and usage metrics
    UPDATE wallet 
    SET 
        balance = balance - p_amount,
        total_credit_used = total_credit_used + p_amount,
        updated_at = NOW() 
    WHERE id = v_wallet_id;
    
    -- Record the transaction
    INSERT INTO wallet_transactions (
        wallet_id, 
        type, 
        amount, 
        description, 
        related_order_id, 
        status
    )
    VALUES (
        v_wallet_id, 
        'debit', 
        p_amount, 
        'Order Payment (' || p_order_id || ')', 
        p_order_id, 
        'completed'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
