-- ============================================================================
-- PocketYaar — Personal Finance V2:
-- 1. Income (Fixed / Extra) kept separate from Accounts
-- 2. Transfer To (with recipient_name, deducts from selected account)
-- 3. Cash Expense (does NOT deduct from accounts' available balance)
-- 4. Cash Withdrawal (deducts from selected account's available balance)
-- ============================================================================

ALTER TABLE public.personal_transactions
  ALTER COLUMN account_id DROP NOT NULL;

ALTER TABLE public.personal_transactions
  ADD COLUMN IF NOT EXISTS recipient_name TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS income_kind TEXT NOT NULL DEFAULT 'extra'
    CHECK (income_kind IN ('fixed', 'extra'));

CREATE OR REPLACE FUNCTION public.record_personal_transaction(
  p_account_id UUID DEFAULT NULL,
  p_tx_type TEXT DEFAULT 'expense',
  p_amount_minor BIGINT DEFAULT 0,
  p_title TEXT DEFAULT '',
  p_category_id UUID DEFAULT NULL,
  p_transfer_account_id UUID DEFAULT NULL,
  p_source TEXT DEFAULT '',
  p_payment_method TEXT DEFAULT 'cash',
  p_note TEXT DEFAULT '',
  p_tx_date DATE DEFAULT CURRENT_DATE,
  p_linked_group_expense_id UUID DEFAULT NULL,
  p_recipient_name TEXT DEFAULT '',
  p_income_kind TEXT DEFAULT 'extra'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  new_id UUID;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_amount_minor <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  IF p_tx_type = 'income' THEN
    -- Income is tracked separately from account balances.
    NULL;

  ELSIF p_tx_type = 'expense' THEN
    -- Cash expenses do NOT deduct from accounts' available balance.
    -- Non-cash / account expenses deduct from the selected account.
    IF COALESCE(p_payment_method, 'cash') <> 'cash' THEN
      IF p_account_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.personal_accounts WHERE id = p_account_id AND user_id = uid
      ) THEN
        RAISE EXCEPTION 'Select an account for non-cash expense';
      END IF;
      UPDATE public.personal_accounts
      SET balance_minor = balance_minor - p_amount_minor
      WHERE id = p_account_id;
    END IF;

  ELSIF p_tx_type = 'cash_withdrawal' THEN
    IF p_account_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.personal_accounts WHERE id = p_account_id AND user_id = uid
    ) THEN
      RAISE EXCEPTION 'Select an account to withdraw cash from';
    END IF;
    UPDATE public.personal_accounts
    SET balance_minor = balance_minor - p_amount_minor
    WHERE id = p_account_id;

  ELSIF p_tx_type = 'transfer' THEN
    IF p_account_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.personal_accounts WHERE id = p_account_id AND user_id = uid
    ) THEN
      RAISE EXCEPTION 'Select a source account for transfer';
    END IF;
    IF p_transfer_account_id IS NOT NULL AND p_transfer_account_id <> p_account_id THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.personal_accounts WHERE id = p_transfer_account_id AND user_id = uid
      ) THEN
        RAISE EXCEPTION 'Destination account not found';
      END IF;
      UPDATE public.personal_accounts
      SET balance_minor = balance_minor + p_amount_minor
      WHERE id = p_transfer_account_id;
    END IF;
    UPDATE public.personal_accounts
    SET balance_minor = balance_minor - p_amount_minor
    WHERE id = p_account_id;

  ELSIF p_tx_type = 'group_payment' THEN
    IF p_account_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.personal_accounts WHERE id = p_account_id AND user_id = uid
    ) THEN
      RAISE EXCEPTION 'Account not found';
    END IF;
    UPDATE public.personal_accounts
    SET balance_minor = balance_minor - p_amount_minor
    WHERE id = p_account_id;

  ELSIF p_tx_type = 'reimbursement' THEN
    IF p_account_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.personal_accounts WHERE id = p_account_id AND user_id = uid
    ) THEN
      RAISE EXCEPTION 'Account not found';
    END IF;
    UPDATE public.personal_accounts
    SET balance_minor = balance_minor + p_amount_minor
    WHERE id = p_account_id;

  ELSE
    RAISE EXCEPTION 'Unsupported transaction type: %', p_tx_type;
  END IF;

  INSERT INTO public.personal_transactions (
    user_id, account_id, transfer_account_id, category_id, tx_type,
    amount_minor, title, source, payment_method, note, tx_date,
    linked_group_expense_id, recipient_name, income_kind
  )
  VALUES (
    uid,
    CASE WHEN p_tx_type = 'income' OR (p_tx_type = 'expense' AND COALESCE(p_payment_method, 'cash') = 'cash')
         THEN NULL ELSE p_account_id END,
    p_transfer_account_id,
    p_category_id,
    p_tx_type,
    p_amount_minor,
    trim(p_title),
    COALESCE(trim(p_source), ''),
    COALESCE(p_payment_method, 'cash'),
    COALESCE(trim(p_note), ''),
    COALESCE(p_tx_date, CURRENT_DATE),
    p_linked_group_expense_id,
    COALESCE(trim(p_recipient_name), ''),
    COALESCE(p_income_kind, 'extra')
  )
  RETURNING id INTO new_id;

  RETURN new_id;
END;
$$;
