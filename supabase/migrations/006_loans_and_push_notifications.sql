-- ============================================================================
-- PocketYaar — Loan Management, Repayments, Due Reminders & Push Tokens
-- ============================================================================

-- 1. Seed "Loan Given" category under Expenses
INSERT INTO public.expense_categories (user_id, name, icon_key, color_hex, is_default)
SELECT NULL, 'Loan Given', 'hand_coins', '#0284C7', true
WHERE NOT EXISTS (
  SELECT 1 FROM public.expense_categories ec WHERE ec.user_id IS NULL AND ec.name = 'Loan Given'
);

-- 2. Add idempotency_key to notifications (for due-date reminders)
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_idempotency
  ON public.notifications (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- 3. Loans Table
CREATE TABLE IF NOT EXISTS public.loans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  borrower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
  remaining_minor BIGINT NOT NULL CHECK (remaining_minor >= 0),
  currency TEXT NOT NULL DEFAULT 'PKR',
  title TEXT NOT NULL DEFAULT 'Loan',
  note TEXT NOT NULL DEFAULT '',
  due_date DATE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'paid', 'rejected', 'cancelled')),
  linked_lender_tx_id UUID REFERENCES public.personal_transactions(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (lender_id <> borrower_id)
);

CREATE INDEX IF NOT EXISTS idx_loans_lender ON public.loans (lender_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_loans_borrower ON public.loans (borrower_id, status, created_at DESC);

DROP TRIGGER IF EXISTS trg_loans_updated_at ON public.loans;
CREATE TRIGGER trg_loans_updated_at BEFORE UPDATE ON public.loans FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 4. Loan Repayments Table
CREATE TABLE IF NOT EXISTS public.loan_repayments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_id UUID NOT NULL REFERENCES public.loans(id) ON DELETE CASCADE,
  payer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
  payment_method TEXT NOT NULL DEFAULT 'account',
  linked_tx_id UUID REFERENCES public.personal_transactions(id) ON DELETE SET NULL,
  note TEXT NOT NULL DEFAULT '',
  paid_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Link personal_transactions -> loans
ALTER TABLE public.personal_transactions
  ADD COLUMN IF NOT EXISTS linked_loan_id UUID REFERENCES public.loans(id) ON DELETE SET NULL;

-- 6. Device Tokens for Mobile Push Infrastructure
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  token TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);

-- Enable Realtime on loans
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.loans;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 7. Grants & RLS
GRANT SELECT, INSERT, UPDATE ON public.loans TO authenticated;
GRANT SELECT, INSERT ON public.loan_repayments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.device_tokens TO authenticated;

ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_repayments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "loans_select_parties" ON public.loans;
CREATE POLICY "loans_select_parties" ON public.loans FOR SELECT
  USING (auth.uid() = lender_id OR auth.uid() = borrower_id);

DROP POLICY IF EXISTS "loan_repayments_select_parties" ON public.loan_repayments;
CREATE POLICY "loan_repayments_select_parties" ON public.loan_repayments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.loans l
      WHERE l.id = loan_id AND (l.lender_id = auth.uid() OR l.borrower_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "device_tokens_own" ON public.device_tokens;
CREATE POLICY "device_tokens_own" ON public.device_tokens FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 8. Atomic RPCs for Loan Lifecycle
CREATE OR REPLACE FUNCTION public.create_loan_request(
  p_borrower_id UUID,
  p_amount_minor BIGINT,
  p_title TEXT DEFAULT 'Loan',
  p_due_date DATE DEFAULT NULL,
  p_note TEXT DEFAULT '',
  p_lender_tx_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  lender_name TEXT;
  new_id UUID;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_borrower_id = uid THEN RAISE EXCEPTION 'Cannot create a loan to yourself'; END IF;
  IF p_amount_minor <= 0 THEN RAISE EXCEPTION 'Loan amount must be positive'; END IF;

  INSERT INTO public.loans (
    lender_id, borrower_id, amount_minor, remaining_minor,
    title, note, due_date, status, linked_lender_tx_id
  )
  VALUES (
    uid, p_borrower_id, p_amount_minor, p_amount_minor,
    COALESCE(NULLIF(trim(p_title), ''), 'Loan'),
    COALESCE(trim(p_note), ''),
    p_due_date, 'pending', p_lender_tx_id
  )
  RETURNING id INTO new_id;

  SELECT full_name INTO lender_name FROM public.profiles WHERE id = uid;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    p_borrower_id,
    'loan_request',
    'New Loan Request from ' || COALESCE(lender_name, 'User'),
    COALESCE(lender_name, 'Someone') || ' sent you a loan request of PKR ' || round(p_amount_minor / 100.0, 2),
    jsonb_build_object('loan_id', new_id)
  );

  RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_to_loan_request(
  p_loan_id UUID,
  p_accept BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  ln RECORD;
  borrower_name TEXT;
  new_status TEXT;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

  SELECT * INTO ln FROM public.loans
  WHERE id = p_loan_id AND borrower_id = uid AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending loan request not found';
  END IF;

  new_status := CASE WHEN p_accept THEN 'active' ELSE 'rejected' END;
  UPDATE public.loans SET status = new_status WHERE id = p_loan_id;

  SELECT full_name INTO borrower_name FROM public.profiles WHERE id = uid;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    ln.lender_id,
    CASE WHEN p_accept THEN 'loan_accepted' ELSE 'loan_rejected' END,
    'Loan Request ' || CASE WHEN p_accept THEN 'Accepted' ELSE 'Rejected' END,
    COALESCE(borrower_name, 'Borrower') || ' ' || CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END || ' your loan of PKR ' || round(ln.amount_minor / 100.0, 2),
    jsonb_build_object('loan_id', p_loan_id)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_loan_request(p_loan_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  UPDATE public.loans
  SET status = 'cancelled'
  WHERE id = p_loan_id AND lender_id = uid AND status = 'pending';
END;
$$;

CREATE OR REPLACE FUNCTION public.record_loan_repayment(
  p_loan_id UUID,
  p_amount_minor BIGINT,
  p_account_id UUID DEFAULT NULL,
  p_payment_method TEXT DEFAULT 'account',
  p_note TEXT DEFAULT ''
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
  new_remaining BIGINT;
  new_status TEXT;
  tx_id UUID;
  repay_id UUID;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_amount_minor <= 0 THEN RAISE EXCEPTION 'Repayment amount must be positive'; END IF;

  SELECT * INTO ln FROM public.loans
  WHERE id = p_loan_id AND borrower_id = uid AND status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active loan not found for repayment';
  END IF;

  IF p_amount_minor > ln.remaining_minor THEN
    RAISE EXCEPTION 'Repayment amount exceeds remaining loan balance';
  END IF;

  -- Record personal transaction if paying from an online/personal account
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

  new_remaining := ln.remaining_minor - p_amount_minor;
  new_status := CASE WHEN new_remaining = 0 THEN 'paid' ELSE 'active' END;

  UPDATE public.loans
  SET remaining_minor = new_remaining, status = new_status
  WHERE id = p_loan_id;

  INSERT INTO public.loan_repayments (loan_id, payer_id, amount_minor, payment_method, linked_tx_id, note)
  VALUES (p_loan_id, uid, p_amount_minor, COALESCE(p_payment_method, 'account'), tx_id, COALESCE(trim(p_note), ''))
  RETURNING id INTO repay_id;

  SELECT full_name INTO payer_name FROM public.profiles WHERE id = uid;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    ln.lender_id,
    'loan_repayment',
    CASE WHEN new_status = 'paid' THEN 'Loan Fully Repaid' ELSE 'Loan Repayment Received' END,
    COALESCE(payer_name, 'Borrower') || ' repaid PKR ' || round(p_amount_minor / 100.0, 2) || ' for "' || ln.title || '"',
    jsonb_build_object('loan_id', p_loan_id, 'repayment_id', repay_id)
  );

  RETURN repay_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_and_create_loan_due_reminders()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  ln RECORD;
  today_str TEXT := to_char(CURRENT_DATE, 'YYYY-MM-DD');
BEGIN
  IF uid IS NULL THEN RETURN; END IF;

  FOR ln IN
    SELECT * FROM public.loans
    WHERE status = 'active'
      AND due_date IS NOT NULL
      AND due_date <= CURRENT_DATE
      AND (lender_id = uid OR borrower_id = uid)
  LOOP
    INSERT INTO public.notifications (user_id, type, title, body, data, idempotency_key)
    VALUES (
      ln.lender_id,
      'loan_due_reminder',
      'Loan Due Reminder: ' || ln.title,
      'Repayment of ' || ln.currency || ' ' || round(ln.remaining_minor / 100.0, 2) || ' is due today.',
      jsonb_build_object('loan_id', ln.id),
      'loan_due:' || ln.id || ':' || ln.lender_id || ':' || today_str
    )
    ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

    INSERT INTO public.notifications (user_id, type, title, body, data, idempotency_key)
    VALUES (
      ln.borrower_id,
      'loan_due_reminder',
      'Loan Due Reminder: ' || ln.title,
      'Your loan repayment of ' || ln.currency || ' ' || round(ln.remaining_minor / 100.0, 2) || ' is due.',
      jsonb_build_object('loan_id', ln.id),
      'loan_due:' || ln.id || ':' || ln.borrower_id || ':' || today_str
    )
    ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_loans_with_profiles()
RETURNS TABLE (
  id UUID,
  lender_id UUID,
  lender_name TEXT,
  lender_public_id TEXT,
  borrower_id UUID,
  borrower_name TEXT,
  borrower_public_id TEXT,
  amount_minor BIGINT,
  remaining_minor BIGINT,
  currency TEXT,
  title TEXT,
  note TEXT,
  due_date DATE,
  status TEXT,
  created_at TIMESTAMPTZ
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
    l.id,
    l.lender_id,
    pl.full_name AS lender_name,
    pl.public_id AS lender_public_id,
    l.borrower_id,
    pb.full_name AS borrower_name,
    pb.public_id AS borrower_public_id,
    l.amount_minor,
    l.remaining_minor,
    l.currency,
    l.title,
    l.note,
    l.due_date,
    l.status,
    l.created_at
  FROM public.loans l
  JOIN public.profiles pl ON pl.id = l.lender_id
  JOIN public.profiles pb ON pb.id = l.borrower_id
  WHERE l.lender_id = uid OR l.borrower_id = uid
  ORDER BY l.created_at DESC;
END;
$$;
