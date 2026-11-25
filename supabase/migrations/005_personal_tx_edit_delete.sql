-- ============================================================================
-- PocketYaar — Balance-Safe Edit & Delete for Personal Transactions
-- ============================================================================

CREATE OR REPLACE FUNCTION public.delete_personal_transaction(p_tx_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  tx RECORD;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO tx FROM public.personal_transactions
  WHERE id = p_tx_id AND user_id = uid
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction not found';
  END IF;

  -- Reverse previous account balance impact
  IF tx.account_id IS NOT NULL THEN
    IF tx.tx_type IN ('expense', 'transfer', 'cash_withdrawal', 'group_payment') THEN
      UPDATE public.personal_accounts
      SET balance_minor = balance_minor + tx.amount_minor
      WHERE id = tx.account_id AND user_id = uid;
    ELSIF tx.tx_type IN ('income', 'reimbursement') THEN
      UPDATE public.personal_accounts
      SET balance_minor = balance_minor - tx.amount_minor
      WHERE id = tx.account_id AND user_id = uid;
    END IF;
  END IF;

  IF tx.transfer_account_id IS NOT NULL AND tx.tx_type = 'transfer' THEN
    UPDATE public.personal_accounts
    SET balance_minor = balance_minor - tx.amount_minor
    WHERE id = tx.transfer_account_id AND user_id = uid;
  END IF;

  DELETE FROM public.personal_transactions WHERE id = p_tx_id AND user_id = uid;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_personal_transaction(
  p_tx_id UUID,
  p_account_id UUID DEFAULT NULL,
  p_tx_type TEXT DEFAULT 'expense',
  p_amount_minor BIGINT DEFAULT 0,
  p_title TEXT DEFAULT '',
  p_category_id UUID DEFAULT NULL,
  p_source TEXT DEFAULT '',
  p_payment_method TEXT DEFAULT 'cash',
  p_note TEXT DEFAULT '',
  p_recipient_name TEXT DEFAULT '',
  p_income_kind TEXT DEFAULT 'extra'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  old_tx RECORD;
  effective_account_id UUID;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_amount_minor <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  SELECT * INTO old_tx FROM public.personal_transactions
  WHERE id = p_tx_id AND user_id = uid
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction not found';
  END IF;

  -- 1. Reverse old account impact
  IF old_tx.account_id IS NOT NULL THEN
    IF old_tx.tx_type IN ('expense', 'transfer', 'cash_withdrawal', 'group_payment') THEN
      UPDATE public.personal_accounts
      SET balance_minor = balance_minor + old_tx.amount_minor
      WHERE id = old_tx.account_id AND user_id = uid;
    ELSIF old_tx.tx_type IN ('income', 'reimbursement') THEN
      UPDATE public.personal_accounts
      SET balance_minor = balance_minor - old_tx.amount_minor
      WHERE id = old_tx.account_id AND user_id = uid;
    END IF;
  END IF;

  -- 2. Apply new account impact
  effective_account_id := CASE
    WHEN p_tx_type = 'income' OR (p_tx_type = 'expense' AND COALESCE(p_payment_method, 'cash') = 'cash')
    THEN NULL
    ELSE p_account_id
  END;

  IF effective_account_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.personal_accounts WHERE id = effective_account_id AND user_id = uid
    ) THEN
      RAISE EXCEPTION 'Account not found';
    END IF;

    IF p_tx_type IN ('expense', 'transfer', 'cash_withdrawal', 'group_payment') THEN
      UPDATE public.personal_accounts
      SET balance_minor = balance_minor - p_amount_minor
      WHERE id = effective_account_id AND user_id = uid;
    ELSIF p_tx_type = 'reimbursement' THEN
      UPDATE public.personal_accounts
      SET balance_minor = balance_minor + p_amount_minor
      WHERE id = effective_account_id AND user_id = uid;
    END IF;
  END IF;

  -- 3. Update transaction record
  UPDATE public.personal_transactions
  SET
    account_id = effective_account_id,
    category_id = p_category_id,
    tx_type = p_tx_type,
    amount_minor = p_amount_minor,
    title = trim(p_title),
    source = COALESCE(trim(p_source), ''),
    payment_method = COALESCE(p_payment_method, 'cash'),
    note = COALESCE(trim(p_note), ''),
    recipient_name = COALESCE(trim(p_recipient_name), ''),
    income_kind = COALESCE(p_income_kind, 'extra')
  WHERE id = p_tx_id AND user_id = uid;
END;
$$;
