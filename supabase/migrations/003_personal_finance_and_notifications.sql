-- ============================================================================
-- PocketYaar — Personal Finance, Budgets & Real-Time Notifications
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Personal Accounts
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.personal_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (char_length(trim(name)) >= 1),
  account_type TEXT NOT NULL CHECK (account_type IN ('bank', 'cash', 'easypaisa', 'jazzcash', 'custom')),
  currency TEXT NOT NULL DEFAULT 'PKR',
  balance_minor BIGINT NOT NULL DEFAULT 0,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_personal_accounts_user ON public.personal_accounts (user_id) WHERE is_archived = false;

DROP TRIGGER IF EXISTS trg_personal_accounts_updated_at ON public.personal_accounts;
CREATE TRIGGER trg_personal_accounts_updated_at BEFORE UPDATE ON public.personal_accounts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 2. Expense Categories (System defaults have user_id IS NULL)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.expense_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (char_length(trim(name)) >= 1),
  icon_key TEXT NOT NULL DEFAULT 'tag',
  color_hex TEXT NOT NULL DEFAULT '#558B2F',
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed system default categories once
INSERT INTO public.expense_categories (user_id, name, icon_key, color_hex, is_default)
SELECT NULL, v.name, v.icon_key, v.color_hex, true
FROM (VALUES
  ('Food', 'utensils', '#558B2F'),
  ('Transport', 'car', '#0284C7'),
  ('Shopping', 'shopping_bag', '#9333EA'),
  ('Bills', 'receipt', '#D97706'),
  ('Home', 'home', '#0D9488'),
  ('Health', 'heart', '#DC2626'),
  ('Entertainment', 'film', '#EC4899'),
  ('Education', 'book', '#4F46E5'),
  ('Other', 'tag', '#6B7280')
) AS v(name, icon_key, color_hex)
WHERE NOT EXISTS (
  SELECT 1 FROM public.expense_categories ec WHERE ec.user_id IS NULL AND ec.name = v.name
);

-- ----------------------------------------------------------------------------
-- 3. Personal Transactions
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.personal_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES public.personal_accounts(id) ON DELETE RESTRICT,
  transfer_account_id UUID REFERENCES public.personal_accounts(id) ON DELETE RESTRICT,
  category_id UUID REFERENCES public.expense_categories(id) ON DELETE SET NULL,
  tx_type TEXT NOT NULL CHECK (tx_type IN ('income', 'expense', 'transfer', 'cash_withdrawal', 'group_payment', 'reimbursement')),
  amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
  title TEXT NOT NULL CHECK (char_length(trim(title)) >= 1),
  source TEXT NOT NULL DEFAULT '',
  payment_method TEXT NOT NULL DEFAULT 'cash',
  note TEXT NOT NULL DEFAULT '',
  tx_date DATE NOT NULL DEFAULT CURRENT_DATE,
  linked_group_expense_id UUID REFERENCES public.group_expenses(id) ON DELETE SET NULL,
  linked_settlement_id UUID REFERENCES public.group_settlements(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_personal_tx_user_date ON public.personal_transactions (user_id, tx_date DESC, created_at DESC);

DROP TRIGGER IF EXISTS trg_personal_tx_updated_at ON public.personal_transactions;
CREATE TRIGGER trg_personal_tx_updated_at BEFORE UPDATE ON public.personal_transactions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 4. Monthly Budgets
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES public.expense_categories(id) ON DELETE CASCADE,
  month_date DATE NOT NULL,
  limit_minor BIGINT NOT NULL CHECK (limit_minor > 0),
  currency TEXT NOT NULL DEFAULT 'PKR',
  notify_threshold_pct INT NOT NULL DEFAULT 80,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, category_id, month_date)
);

DROP TRIGGER IF EXISTS trg_budgets_updated_at ON public.budgets;
CREATE TRIGGER trg_budgets_updated_at BEFORE UPDATE ON public.budgets FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 5. Notifications
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id, is_read, created_at DESC);

-- Enable Realtime on notifications
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- ----------------------------------------------------------------------------
-- 6. Grants & RLS
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON public.personal_accounts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.expense_categories TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.personal_transactions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.budgets TO authenticated;
GRANT SELECT, UPDATE, DELETE ON public.notifications TO authenticated;

ALTER TABLE public.personal_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "personal_accounts_own" ON public.personal_accounts;
CREATE POLICY "personal_accounts_own" ON public.personal_accounts FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "expense_categories_select" ON public.expense_categories;
CREATE POLICY "expense_categories_select" ON public.expense_categories FOR SELECT
  USING (user_id IS NULL OR auth.uid() = user_id);

DROP POLICY IF EXISTS "expense_categories_modify_own" ON public.expense_categories;
CREATE POLICY "expense_categories_modify_own" ON public.expense_categories FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "personal_tx_own" ON public.personal_transactions;
CREATE POLICY "personal_tx_own" ON public.personal_transactions FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "budgets_own" ON public.budgets;
CREATE POLICY "budgets_own" ON public.budgets FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "notifications_own" ON public.notifications;
CREATE POLICY "notifications_own" ON public.notifications FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 7. Atomic Personal Transaction RPCs (Maintains Account Balances Safely)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_personal_transaction(
  p_account_id UUID,
  p_tx_type TEXT,
  p_amount_minor BIGINT,
  p_title TEXT,
  p_category_id UUID DEFAULT NULL,
  p_transfer_account_id UUID DEFAULT NULL,
  p_source TEXT DEFAULT '',
  p_payment_method TEXT DEFAULT 'cash',
  p_note TEXT DEFAULT '',
  p_tx_date DATE DEFAULT CURRENT_DATE,
  p_linked_group_expense_id UUID DEFAULT NULL
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

  IF NOT EXISTS (SELECT 1 FROM public.personal_accounts WHERE id = p_account_id AND user_id = uid) THEN
    RAISE EXCEPTION 'Account not found';
  END IF;

  IF p_tx_type IN ('transfer', 'cash_withdrawal') THEN
    IF p_transfer_account_id IS NULL OR p_transfer_account_id = p_account_id THEN
      RAISE EXCEPTION 'Select a valid destination account';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.personal_accounts WHERE id = p_transfer_account_id AND user_id = uid) THEN
      RAISE EXCEPTION 'Destination account not found';
    END IF;

    UPDATE public.personal_accounts SET balance_minor = balance_minor - p_amount_minor WHERE id = p_account_id;
    UPDATE public.personal_accounts SET balance_minor = balance_minor + p_amount_minor WHERE id = p_transfer_account_id;
  ELSIF p_tx_type IN ('income', 'reimbursement') THEN
    UPDATE public.personal_accounts SET balance_minor = balance_minor + p_amount_minor WHERE id = p_account_id;
  ELSIF p_tx_type IN ('expense', 'group_payment') THEN
    UPDATE public.personal_accounts SET balance_minor = balance_minor - p_amount_minor WHERE id = p_account_id;
  ELSE
    RAISE EXCEPTION 'Unsupported transaction type: %', p_tx_type;
  END IF;

  INSERT INTO public.personal_transactions (
    user_id, account_id, transfer_account_id, category_id, tx_type,
    amount_minor, title, source, payment_method, note, tx_date, linked_group_expense_id
  )
  VALUES (
    uid, p_account_id, p_transfer_account_id, p_category_id, p_tx_type,
    p_amount_minor, trim(p_title), COALESCE(trim(p_source), ''),
    COALESCE(p_payment_method, 'cash'), COALESCE(trim(p_note), ''),
    COALESCE(p_tx_date, CURRENT_DATE), p_linked_group_expense_id
  )
  RETURNING id INTO new_id;

  RETURN new_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. Automatic Notification Triggers (Only notify users involved!)
-- ----------------------------------------------------------------------------

-- Notify participant when added to a group expense (if not the creator)
CREATE OR REPLACE FUNCTION public.notify_on_expense_participant()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  exp RECORD;
  creator_name TEXT;
  grp_name TEXT;
BEGIN
  SELECT * INTO exp FROM public.group_expenses WHERE id = NEW.expense_id;
  IF NOT FOUND OR NEW.user_id = exp.created_by THEN
    RETURN NEW;
  END IF;

  SELECT full_name INTO creator_name FROM public.profiles WHERE id = exp.created_by;
  SELECT name INTO grp_name FROM public.groups WHERE id = exp.group_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.user_id,
    'expense_added',
    COALESCE(grp_name, 'Group') || ': ' || exp.title,
    COALESCE(creator_name, 'Someone') || ' added an expense where your share is ' || exp.currency || ' ' || round(NEW.share_amount_minor / 100.0, 2),
    jsonb_build_object('group_id', exp.group_id, 'expense_id', exp.id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_expense_participant ON public.expense_participants;
CREATE TRIGGER trg_notify_expense_participant
  AFTER INSERT ON public.expense_participants
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_expense_participant();

-- Notify payer when added as a payer by someone else
CREATE OR REPLACE FUNCTION public.notify_on_expense_payer()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  exp RECORD;
  creator_name TEXT;
  grp_name TEXT;
BEGIN
  SELECT * INTO exp FROM public.group_expenses WHERE id = NEW.expense_id;
  IF NOT FOUND OR NEW.user_id = exp.created_by THEN
    RETURN NEW;
  END IF;
  -- Avoid duplicate if already notified as participant
  IF EXISTS (SELECT 1 FROM public.expense_participants WHERE expense_id = NEW.expense_id AND user_id = NEW.user_id) THEN
    RETURN NEW;
  END IF;

  SELECT full_name INTO creator_name FROM public.profiles WHERE id = exp.created_by;
  SELECT name INTO grp_name FROM public.groups WHERE id = exp.group_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.user_id,
    'expense_added',
    COALESCE(grp_name, 'Group') || ': ' || exp.title,
    COALESCE(creator_name, 'Someone') || ' recorded ' || exp.currency || ' ' || round(NEW.paid_amount_minor / 100.0, 2) || ' paid by you.',
    jsonb_build_object('group_id', exp.group_id, 'expense_id', exp.id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_expense_payer ON public.expense_payers;
CREATE TRIGGER trg_notify_expense_payer
  AFTER INSERT ON public.expense_payers
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_expense_payer();

-- Notify receiver when a settlement is submitted, and sender when confirmed/rejected
CREATE OR REPLACE FUNCTION public.notify_on_settlement_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sender_name TEXT;
  receiver_name TEXT;
  grp_name TEXT;
BEGIN
  SELECT full_name INTO sender_name FROM public.profiles WHERE id = NEW.sender_id;
  SELECT full_name INTO receiver_name FROM public.profiles WHERE id = NEW.receiver_id;
  SELECT name INTO grp_name FROM public.groups WHERE id = NEW.group_id;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.receiver_id,
      'settlement_request',
      'Payment from ' || COALESCE(sender_name, 'Member'),
      COALESCE(sender_name, 'Member') || ' submitted ' || NEW.currency || ' ' || round(NEW.amount_minor / 100.0, 2) || ' in ' || COALESCE(grp_name, 'Group'),
      jsonb_build_object('group_id', NEW.group_id, 'settlement_id', NEW.id)
    );
  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status IN ('confirmed', 'rejected') THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.sender_id,
      'settlement_' || NEW.status,
      'Settlement ' || NEW.status,
      COALESCE(receiver_name, 'Receiver') || ' ' || NEW.status || ' your payment of ' || NEW.currency || ' ' || round(NEW.amount_minor / 100.0, 2),
      jsonb_build_object('group_id', NEW.group_id, 'settlement_id', NEW.id)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_settlement ON public.group_settlements;
CREATE TRIGGER trg_notify_settlement
  AFTER INSERT OR UPDATE ON public.group_settlements
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_settlement_change();

-- Notify user when invited to a group
CREATE OR REPLACE FUNCTION public.notify_on_group_invite()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  inviter_name TEXT;
  grp_name TEXT;
BEGIN
  SELECT full_name INTO inviter_name FROM public.profiles WHERE id = NEW.inviter_id;
  SELECT name INTO grp_name FROM public.groups WHERE id = NEW.group_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.invitee_id,
    'group_invite',
    'Group Invitation: ' || COALESCE(grp_name, 'Group'),
    COALESCE(inviter_name, 'Someone') || ' invited you to join ' || COALESCE(grp_name, 'a group'),
    jsonb_build_object('group_id', NEW.group_id, 'invite_id', NEW.id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_group_invite ON public.group_invites;
CREATE TRIGGER trg_notify_group_invite
  AFTER INSERT ON public.group_invites
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_group_invite();
