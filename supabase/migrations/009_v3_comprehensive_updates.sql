-- ============================================================================
-- PocketYaar V3 — Group Expense Edit/Delete, Settlement Refunds,
-- Loan Repayment Approvals, Payment Proofs, & @ProfileName Tagging
-- ============================================================================

-- 1. Storage bucket for payment screenshots / proofs
INSERT INTO storage.buckets (id, name, public)
VALUES ('proofs', 'proofs', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "proofs_public_read" ON storage.objects;
CREATE POLICY "proofs_public_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'proofs');

DROP POLICY IF EXISTS "proofs_user_upload" ON storage.objects;
CREATE POLICY "proofs_user_upload" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'proofs'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- 2. Group Expenses: track who edited an expense (e.g. "Edited by Admin")
ALTER TABLE public.group_expenses
  ADD COLUMN IF NOT EXISTS edited_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS edited_by_name TEXT;

-- Admin-only delete (blocked if a confirmed settlement occurred on/after expense creation)
CREATE OR REPLACE FUNCTION public.delete_group_expense(p_expense_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  exp RECORD;
  u_role TEXT;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

  SELECT * INTO exp FROM public.group_expenses
  WHERE id = p_expense_id AND is_deleted = false
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Expense not found'; END IF;

  u_role := public.get_group_role(exp.group_id, uid);
  IF u_role NOT IN ('owner', 'sub_admin') THEN
    RAISE EXCEPTION 'Only group admins or sub-admins can delete expenses';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.group_settlements
    WHERE group_id = exp.group_id
      AND status = 'confirmed'
      AND created_at >= exp.created_at
  ) THEN
    RAISE EXCEPTION 'Cannot delete an expense after its settlement has been completed';
  END IF;

  UPDATE public.group_expenses SET is_deleted = true WHERE id = p_expense_id;

  -- Refund linked personal deduction if any
  UPDATE public.personal_accounts pa
  SET balance_minor = pa.balance_minor + pt.amount_minor
  FROM public.personal_transactions pt
  WHERE pt.linked_group_expense_id = p_expense_id
    AND pt.account_id = pa.id;

  DELETE FROM public.personal_transactions WHERE linked_group_expense_id = p_expense_id;

  INSERT INTO public.group_activity (group_id, actor_id, action_type, entity_id, metadata)
  VALUES (exp.group_id, uid, 'expense_deleted', p_expense_id, jsonb_build_object('title', exp.title));
END;
$$;

-- Edit group expense (creator OR admin/sub-admin)
CREATE OR REPLACE FUNCTION public.update_group_expense(
  p_expense_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_total_amount_minor BIGINT,
  p_category TEXT,
  p_split_method TEXT,
  p_payment_method TEXT,
  p_payers JSONB,
  p_participants JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  exp RECORD;
  u_role TEXT;
  editor_name TEXT;
  payers_sum BIGINT := 0;
  shares_sum BIGINT := 0;
  item JSONB;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

  SELECT * INTO exp FROM public.group_expenses
  WHERE id = p_expense_id AND is_deleted = false
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Expense not found'; END IF;

  u_role := public.get_group_role(exp.group_id, uid);
  IF exp.created_by <> uid AND u_role NOT IN ('owner', 'sub_admin') THEN
    RAISE EXCEPTION 'Only the creator or an admin can edit this expense';
  END IF;

  IF p_total_amount_minor <= 0 THEN RAISE EXCEPTION 'Total must be positive'; END IF;

  SELECT COALESCE(SUM((elem->>'paid_amount_minor')::BIGINT), 0)
  INTO payers_sum FROM jsonb_array_elements(p_payers) elem;
  IF payers_sum <> p_total_amount_minor THEN
    RAISE EXCEPTION 'Sum of payers must equal total';
  END IF;

  SELECT COALESCE(SUM((elem->>'share_amount_minor')::BIGINT), 0)
  INTO shares_sum FROM jsonb_array_elements(p_participants) elem;
  IF shares_sum <> p_total_amount_minor THEN
    RAISE EXCEPTION 'Sum of shares must equal total';
  END IF;

  IF u_role IN ('owner', 'sub_admin') THEN
    SELECT full_name INTO editor_name FROM public.profiles WHERE id = uid;
  END IF;

  UPDATE public.group_expenses
  SET
    title = trim(p_title),
    description = COALESCE(trim(p_description), ''),
    total_amount_minor = p_total_amount_minor,
    category = COALESCE(p_category, 'Other'),
    split_method = COALESCE(p_split_method, 'equal'),
    payment_method = COALESCE(p_payment_method, 'cash'),
    edited_by = CASE WHEN u_role IN ('owner', 'sub_admin') THEN uid ELSE edited_by END,
    edited_by_name = CASE WHEN u_role IN ('owner', 'sub_admin') THEN editor_name ELSE edited_by_name END
  WHERE id = p_expense_id;

  DELETE FROM public.expense_payers WHERE expense_id = p_expense_id;
  DELETE FROM public.expense_participants WHERE expense_id = p_expense_id;

  FOR item IN SELECT * FROM jsonb_array_elements(p_payers) LOOP
    INSERT INTO public.expense_payers (expense_id, user_id, paid_amount_minor)
    VALUES (p_expense_id, (item->>'user_id')::UUID, (item->>'paid_amount_minor')::BIGINT);
  END LOOP;

  FOR item IN SELECT * FROM jsonb_array_elements(p_participants) LOOP
    INSERT INTO public.expense_participants (expense_id, user_id, share_amount_minor)
    VALUES (p_expense_id, (item->>'user_id')::UUID, (item->>'share_amount_minor')::BIGINT);
  END LOOP;

  INSERT INTO public.group_activity (group_id, actor_id, action_type, entity_id, metadata)
  VALUES (exp.group_id, uid, 'expense_edited', p_expense_id, jsonb_build_object('title', trim(p_title)));
END;
$$;

-- 3. Settlements: link personal account deduction & refund on rejection
ALTER TABLE public.group_settlements
  ADD COLUMN IF NOT EXISTS deducted_account_id UUID REFERENCES public.personal_accounts(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS linked_personal_tx_id UUID REFERENCES public.personal_transactions(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.submit_group_settlement(
  p_group_id UUID,
  p_receiver_id UUID,
  p_amount_minor BIGINT,
  p_payment_method TEXT DEFAULT 'cash',
  p_reference TEXT DEFAULT '',
  p_proof_url TEXT DEFAULT NULL,
  p_account_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  auto_confirm BOOLEAN := false;
  init_status TEXT;
  new_sid UUID;
  tx_id UUID;
  recv_name TEXT;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

  IF NOT public.is_active_group_member(p_group_id, uid) OR NOT public.is_active_group_member(p_group_id, p_receiver_id) THEN
    RAISE EXCEPTION 'Both sender and receiver must be active group members';
  END IF;

  IF p_amount_minor <= 0 THEN RAISE EXCEPTION 'Settlement amount must be positive'; END IF;

  -- Cash settlements MUST always generate a pending request for receiver confirmation
  IF COALESCE(p_payment_method, 'cash') = 'cash' THEN
    init_status := 'pending';
  ELSE
    SELECT auto_confirm_settlements INTO auto_confirm FROM public.group_settings WHERE group_id = p_group_id;
    init_status := CASE WHEN COALESCE(auto_confirm, false) THEN 'confirmed' ELSE 'pending' END;
  END IF;

  -- Deduct from payer personal account if online/account selected
  IF p_account_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.personal_accounts WHERE id = p_account_id AND user_id = uid) THEN
      RAISE EXCEPTION 'Account not found';
    END IF;
    SELECT full_name INTO recv_name FROM public.profiles WHERE id = p_receiver_id;
    UPDATE public.personal_accounts SET balance_minor = balance_minor - p_amount_minor WHERE id = p_account_id;

    INSERT INTO public.personal_transactions (
      user_id, account_id, tx_type, amount_minor, title, payment_method
    )
    VALUES (
      uid, p_account_id, 'group_payment', p_amount_minor,
      'Group Settlement to ' || COALESCE(recv_name, 'Member'),
      COALESCE(p_payment_method, 'bank')
    )
    RETURNING id INTO tx_id;
  END IF;

  INSERT INTO public.group_settlements (
    group_id, sender_id, receiver_id, amount_minor, currency,
    payment_method, reference, proof_url, status, deducted_account_id, linked_personal_tx_id
  )
  SELECT
    p_group_id, uid, p_receiver_id, p_amount_minor, g.currency,
    COALESCE(p_payment_method, 'cash'), COALESCE(p_reference, ''), p_proof_url,
    init_status, p_account_id, tx_id
  FROM public.groups g WHERE g.id = p_group_id
  RETURNING id INTO new_sid;

  INSERT INTO public.group_activity (group_id, actor_id, action_type, entity_id, metadata)
  VALUES (
    p_group_id, uid, 'payment_submitted', new_sid,
    jsonb_build_object('receiver_id', p_receiver_id, 'amount_minor', p_amount_minor, 'status', init_status)
  );

  RETURN new_sid;
END;
$$;

CREATE OR REPLACE FUNCTION public.decide_group_settlement(
  p_settlement_id UUID,
  p_decision TEXT,
  p_note TEXT DEFAULT ''
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  st RECORD;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

  SELECT * INTO st FROM public.group_settlements WHERE id = p_settlement_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Settlement not found'; END IF;
  IF st.status <> 'pending' THEN RAISE EXCEPTION 'Settlement is no longer pending'; END IF;

  IF p_decision = 'cancelled' THEN
    IF st.sender_id <> uid THEN RAISE EXCEPTION 'Only sender can cancel a pending settlement'; END IF;
    UPDATE public.group_settlements SET status = 'cancelled' WHERE id = p_settlement_id;
    IF st.deducted_account_id IS NOT NULL THEN
      UPDATE public.personal_accounts SET balance_minor = balance_minor + st.amount_minor WHERE id = st.deducted_account_id;
    END IF;
    IF st.linked_personal_tx_id IS NOT NULL THEN
      DELETE FROM public.personal_transactions WHERE id = st.linked_personal_tx_id;
    END IF;
    RETURN;
  END IF;

  IF p_decision NOT IN ('confirmed', 'rejected') THEN RAISE EXCEPTION 'Invalid decision'; END IF;
  IF st.receiver_id <> uid THEN RAISE EXCEPTION 'Only receiver can confirm or reject a settlement'; END IF;

  UPDATE public.group_settlements SET status = p_decision WHERE id = p_settlement_id;

  -- Refund payer's personal account if online payment was rejected
  IF p_decision = 'rejected' THEN
    IF st.deducted_account_id IS NOT NULL THEN
      UPDATE public.personal_accounts SET balance_minor = balance_minor + st.amount_minor WHERE id = st.deducted_account_id;
    END IF;
    IF st.linked_personal_tx_id IS NOT NULL THEN
      DELETE FROM public.personal_transactions WHERE id = st.linked_personal_tx_id;
    END IF;
  END IF;

  INSERT INTO public.settlement_confirmations (settlement_id, actor_id, decision, note)
  VALUES (p_settlement_id, uid, p_decision, COALESCE(p_note, ''));

  INSERT INTO public.group_activity (group_id, actor_id, action_type, entity_id, metadata)
  VALUES (
    st.group_id, uid,
    CASE WHEN p_decision = 'confirmed' THEN 'payment_confirmed' ELSE 'payment_rejected' END,
    p_settlement_id, jsonb_build_object('amount_minor', st.amount_minor)
  );
END;
$$;

-- 4. Loan Repayments: Pending Lender Approval + Account Selection + Proof Screenshot
ALTER TABLE public.loan_repayments
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS proof_url TEXT,
  ADD COLUMN IF NOT EXISTS borrower_account_id UUID REFERENCES public.personal_accounts(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS lender_account_id UUID REFERENCES public.personal_accounts(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.record_loan_repayment(
  p_loan_id UUID,
  p_amount_minor BIGINT,
  p_account_id UUID DEFAULT NULL,
  p_payment_method TEXT DEFAULT 'account',
  p_note TEXT DEFAULT '',
  p_proof_url TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  ln RECORD;
  payer_name TEXT;
  tx_id UUID;
  repay_id UUID;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_amount_minor <= 0 THEN RAISE EXCEPTION 'Repayment amount must be positive'; END IF;

  SELECT * INTO ln FROM public.loans
  WHERE id = p_loan_id AND borrower_id = uid AND status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Active loan not found for repayment'; END IF;
  IF p_amount_minor > ln.remaining_minor THEN
    RAISE EXCEPTION 'Repayment amount exceeds remaining loan balance';
  END IF;

  IF p_account_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.personal_accounts WHERE id = p_account_id AND user_id = uid) THEN
      RAISE EXCEPTION 'Account not found';
    END IF;
    UPDATE public.personal_accounts SET balance_minor = balance_minor - p_amount_minor WHERE id = p_account_id;

    INSERT INTO public.personal_transactions (
      user_id, account_id, tx_type, amount_minor, title,
      payment_method, note, linked_loan_id
    )
    VALUES (
      uid, p_account_id, 'expense', p_amount_minor, 'Loan Repayment: ' || ln.title,
      COALESCE(p_payment_method, 'account'), COALESCE(trim(p_note), ''), p_loan_id
    )
    RETURNING id INTO tx_id;
  END IF;

  -- Insert as PENDING until lender approves
  INSERT INTO public.loan_repayments (
    loan_id, payer_id, amount_minor, payment_method, linked_tx_id,
    note, status, proof_url, borrower_account_id
  )
  VALUES (
    p_loan_id, uid, p_amount_minor, COALESCE(p_payment_method, 'account'),
    tx_id, COALESCE(trim(p_note), ''), 'pending', p_proof_url, p_account_id
  )
  RETURNING id INTO repay_id;

  SELECT full_name INTO payer_name FROM public.profiles WHERE id = uid;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    ln.lender_id,
    'loan_repayment_request',
    'Loan Repayment Request from ' || COALESCE(payer_name, 'Borrower'),
    COALESCE(payer_name, 'Borrower') || ' submitted a ' || COALESCE(p_payment_method, 'cash') || ' repayment of ' || ln.currency || ' ' || round(p_amount_minor / 100.0, 2) || ' for "' || ln.title || '"',
    jsonb_build_object('loan_id', p_loan_id, 'repayment_id', repay_id, 'payment_method', COALESCE(p_payment_method, 'account'))
  );

  RETURN repay_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decide_loan_repayment(
  p_repayment_id UUID,
  p_accept BOOLEAN,
  p_lender_account_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  rp RECORD;
  ln RECORD;
  lender_name TEXT;
  new_remaining BIGINT;
  new_status TEXT;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

  SELECT * INTO rp FROM public.loan_repayments WHERE id = p_repayment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Repayment not found'; END IF;
  IF rp.status <> 'pending' THEN RAISE EXCEPTION 'Repayment is no longer pending'; END IF;

  SELECT * INTO ln FROM public.loans WHERE id = rp.loan_id FOR UPDATE;
  IF NOT FOUND OR ln.lender_id <> uid THEN
    RAISE EXCEPTION 'Only the lender can approve or reject this repayment';
  END IF;

  SELECT full_name INTO lender_name FROM public.profiles WHERE id = uid;

  IF p_accept THEN
    new_remaining := GREATEST(0, ln.remaining_minor - rp.amount_minor);
    new_status := CASE WHEN new_remaining = 0 THEN 'paid' ELSE 'active' END;

    UPDATE public.loan_repayments
    SET status = 'approved', lender_account_id = p_lender_account_id
    WHERE id = p_repayment_id;

    UPDATE public.loans
    SET remaining_minor = new_remaining, status = new_status
    WHERE id = ln.id;

    -- Credit lender account if online payment and lender chose an account
    IF p_lender_account_id IS NOT NULL THEN
      IF NOT EXISTS (SELECT 1 FROM public.personal_accounts WHERE id = p_lender_account_id AND user_id = uid) THEN
        RAISE EXCEPTION 'Selected lender account not found';
      END IF;
      UPDATE public.personal_accounts
      SET balance_minor = balance_minor + rp.amount_minor
      WHERE id = p_lender_account_id;

      INSERT INTO public.personal_transactions (
        user_id, account_id, tx_type, amount_minor, title, payment_method, linked_loan_id
      )
      VALUES (
        uid, p_lender_account_id, 'reimbursement', rp.amount_minor,
        'Loan Repaid: ' || ln.title, rp.payment_method, ln.id
      );
    END IF;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      rp.payer_id,
      'loan_repayment_approved',
      'Repayment Approved',
      COALESCE(lender_name, 'Lender') || ' approved your repayment of ' || ln.currency || ' ' || round(rp.amount_minor / 100.0, 2),
      jsonb_build_object('loan_id', ln.id, 'repayment_id', rp.id)
    );
  ELSE
    UPDATE public.loan_repayments SET status = 'rejected' WHERE id = p_repayment_id;

    -- Refund borrower if online payment deducted from borrower's account
    IF rp.borrower_account_id IS NOT NULL THEN
      UPDATE public.personal_accounts
      SET balance_minor = balance_minor + rp.amount_minor
      WHERE id = rp.borrower_account_id;
    END IF;
    IF rp.linked_tx_id IS NOT NULL THEN
      DELETE FROM public.personal_transactions WHERE id = rp.linked_tx_id;
    END IF;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      rp.payer_id,
      'loan_repayment_rejected',
      'Repayment Rejected',
      COALESCE(lender_name, 'Lender') || ' rejected your repayment of ' || ln.currency || ' ' || round(rp.amount_minor / 100.0, 2),
      jsonb_build_object('loan_id', ln.id, 'repayment_id', rp.id)
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_pending_loan_repayments_for_lender()
RETURNS TABLE (
  repayment_id UUID,
  loan_id UUID,
  loan_title TEXT,
  payer_id UUID,
  payer_name TEXT,
  amount_minor BIGINT,
  currency TEXT,
  payment_method TEXT,
  proof_url TEXT,
  note TEXT,
  paid_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

  RETURN QUERY
  SELECT
    lr.id AS repayment_id,
    lr.loan_id,
    l.title AS loan_title,
    lr.payer_id,
    p.full_name AS payer_name,
    lr.amount_minor,
    l.currency,
    lr.payment_method,
    lr.proof_url,
    lr.note,
    lr.paid_at
  FROM public.loan_repayments lr
  JOIN public.loans l ON l.id = lr.loan_id
  JOIN public.profiles p ON p.id = lr.payer_id
  WHERE l.lender_id = uid AND lr.status = 'pending'
  ORDER BY lr.paid_at DESC;
END;
$$;

-- 5. Mention Trigger: support BOTH @public_id AND @full_name
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
      AND (
        NEW.body ~* ('(^|[^a-z0-9_])@' || p.public_id || '($|[^a-z0-9_])')
        OR position(lower('@' || p.full_name) in lower(NEW.body)) > 0
      )
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

-- 6. Fast RPC returning user's share of approved group expenses for Dashboard charts
CREATE OR REPLACE FUNCTION public.get_my_group_expense_shares()
RETURNS TABLE (
  expense_id UUID,
  group_id UUID,
  group_name TEXT,
  title TEXT,
  category TEXT,
  currency TEXT,
  expense_date DATE,
  my_share_minor BIGINT,
  my_paid_minor BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN RETURN; END IF;

  RETURN QUERY
  SELECT
    ge.id AS expense_id,
    ge.group_id,
    g.name AS group_name,
    ge.title,
    ge.category,
    ge.currency,
    ge.expense_date,
    COALESCE(ep.share_amount_minor, 0) AS my_share_minor,
    COALESCE((SELECT SUM(paid_amount_minor) FROM public.expense_payers p2 WHERE p2.expense_id = ge.id AND p2.user_id = uid), 0) AS my_paid_minor
  FROM public.group_expenses ge
  JOIN public.groups g ON g.id = ge.group_id
  JOIN public.expense_participants ep ON ep.expense_id = ge.id AND ep.user_id = uid
  WHERE ge.is_deleted = false
    AND ge.approval_status = 'approved'
  ORDER BY ge.expense_date DESC, ge.created_at DESC
  LIMIT 200;
END;
$$;
