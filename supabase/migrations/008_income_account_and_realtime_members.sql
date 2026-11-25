-- ============================================================================
-- PocketYaar — Income -> Account Balance, Rock-Solid @Tagging & Realtime Members
-- ============================================================================

-- 1. Enable Realtime on group_members and group_settings
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.group_members;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.group_settings;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 2. Update record_personal_transaction so Income requires & credits an account
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
    IF p_account_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.personal_accounts WHERE id = p_account_id AND user_id = uid
    ) THEN
      RAISE EXCEPTION 'Select an account to receive income';
    END IF;
    UPDATE public.personal_accounts
    SET balance_minor = balance_minor + p_amount_minor
    WHERE id = p_account_id;

  ELSIF p_tx_type = 'expense' THEN
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
    CASE WHEN p_tx_type = 'expense' AND COALESCE(p_payment_method, 'cash') = 'cash'
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

-- 3. Update update_personal_transaction so Income also requires & credits an account
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

  effective_account_id := CASE
    WHEN p_tx_type = 'expense' AND COALESCE(p_payment_method, 'cash') = 'cash'
    THEN NULL
    ELSE p_account_id
  END;

  IF p_tx_type = 'income' AND effective_account_id IS NULL THEN
    RAISE EXCEPTION 'Select an account to receive income';
  END IF;

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
    ELSIF p_tx_type IN ('income', 'reimbursement') THEN
      UPDATE public.personal_accounts
      SET balance_minor = balance_minor + p_amount_minor
      WHERE id = effective_account_id AND user_id = uid;
    END IF;
  END IF;

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

-- 4. Rock-solid @tag notification trigger (handles @public_id and @all cleanly)
CREATE OR REPLACE FUNCTION public.notify_on_group_message_tags()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sender_role TEXT;
  sender_name TEXT;
  grp_name TEXT;
  tagged RECORD;
BEGIN
  sender_role := public.get_group_role(NEW.group_id, NEW.sender_id);
  SELECT full_name INTO sender_name FROM public.profiles WHERE id = NEW.sender_id;
  SELECT name INTO grp_name FROM public.groups WHERE id = NEW.group_id;

  IF sender_role IN ('owner', 'sub_admin') AND NEW.body ~* '(^|[^a-z0-9_])@all($|[^a-z0-9_])' THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    SELECT
      gm.user_id,
      'group_announcement',
      COALESCE(grp_name, 'Group') || ' • ' || COALESCE(sender_name, 'Admin'),
      NEW.body,
      jsonb_build_object('group_id', NEW.group_id, 'message_id', NEW.id)
    FROM public.group_members gm
    WHERE gm.group_id = NEW.group_id
      AND gm.status = 'active'
      AND gm.user_id <> NEW.sender_id;
    RETURN NEW;
  END IF;

  FOR tagged IN
    SELECT DISTINCT gm.user_id
    FROM public.group_members gm
    JOIN public.profiles p ON p.id = gm.user_id
    WHERE gm.group_id = NEW.group_id
      AND gm.status = 'active'
      AND gm.user_id <> NEW.sender_id
      AND NEW.body ~* ('(^|[^a-z0-9_])@' || p.public_id || '($|[^a-z0-9_])')
  LOOP
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      tagged.user_id,
      'group_tag',
      COALESCE(grp_name, 'Group') || ': ' || COALESCE(sender_name, 'Member') || ' tagged you',
      NEW.body,
      jsonb_build_object('group_id', NEW.group_id, 'message_id', NEW.id)
    );
  END LOOP;

  RETURN NEW;
END;
$$;
