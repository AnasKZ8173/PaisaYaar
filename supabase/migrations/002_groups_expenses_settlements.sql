-- ============================================================================
-- Splitly (PocketYaar) — Groups, Roles, Expenses, Settlements & Activity
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tables
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (char_length(trim(name)) >= 2),
  description TEXT NOT NULL DEFAULT '',
  icon_key TEXT NOT NULL DEFAULT 'users',
  image_url TEXT,
  category TEXT NOT NULL DEFAULT 'General',
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  currency TEXT NOT NULL DEFAULT 'PKR',
  is_archived BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.group_settings (
  group_id UUID PRIMARY KEY REFERENCES public.groups(id) ON DELETE CASCADE,
  require_expense_approval BOOLEAN NOT NULL DEFAULT false,
  auto_confirm_settlements BOOLEAN NOT NULL DEFAULT false,
  who_can_add_expense TEXT NOT NULL DEFAULT 'all' CHECK (who_can_add_expense IN ('owner', 'admins', 'all')),
  who_can_approve_expense TEXT NOT NULL DEFAULT 'admins' CHECK (who_can_approve_expense IN ('owner', 'admins')),
  who_can_invite TEXT NOT NULL DEFAULT 'admins' CHECK (who_can_invite IN ('owner', 'admins', 'all')),
  who_can_remove_member TEXT NOT NULL DEFAULT 'admins' CHECK (who_can_remove_member IN ('owner', 'admins')),
  who_can_edit_group TEXT NOT NULL DEFAULT 'admins' CHECK (who_can_edit_group IN ('owner', 'admins')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'sub_admin', 'member')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'removed', 'left')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (group_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.group_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  invitee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_group_invites_pending_unique
  ON public.group_invites (group_id, invitee_id)
  WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS public.group_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  title TEXT NOT NULL CHECK (char_length(trim(title)) >= 1),
  description TEXT NOT NULL DEFAULT '',
  total_amount_minor BIGINT NOT NULL CHECK (total_amount_minor > 0),
  currency TEXT NOT NULL DEFAULT 'PKR',
  category TEXT NOT NULL DEFAULT 'Other',
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  split_method TEXT NOT NULL DEFAULT 'equal' CHECK (split_method IN ('equal', 'exact', 'percentage', 'shares')),
  payment_method TEXT NOT NULL DEFAULT 'cash',
  receipt_url TEXT,
  approval_status TEXT NOT NULL DEFAULT 'approved' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_group_expenses_group_date
  ON public.group_expenses (group_id, expense_date DESC)
  WHERE is_deleted = false;

CREATE TABLE IF NOT EXISTS public.expense_payers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id UUID NOT NULL REFERENCES public.group_expenses(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  paid_amount_minor BIGINT NOT NULL CHECK (paid_amount_minor > 0),
  deducted_personal_account_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (expense_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.expense_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id UUID NOT NULL REFERENCES public.group_expenses(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  share_amount_minor BIGINT NOT NULL CHECK (share_amount_minor >= 0),
  share_value NUMERIC,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (expense_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.expense_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id UUID NOT NULL REFERENCES public.group_expenses(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  decision TEXT NOT NULL CHECK (decision IN ('approved', 'rejected')),
  note TEXT NOT NULL DEFAULT '',
  acted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.group_settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
  currency TEXT NOT NULL DEFAULT 'PKR',
  payment_method TEXT NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash', 'bank', 'easypaisa', 'jazzcash', 'other')),
  settlement_date DATE NOT NULL DEFAULT CURRENT_DATE,
  reference TEXT NOT NULL DEFAULT '',
  proof_url TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'rejected', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (sender_id <> receiver_id)
);

CREATE INDEX IF NOT EXISTS idx_group_settlements_group_status
  ON public.group_settlements (group_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.settlement_confirmations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  settlement_id UUID NOT NULL REFERENCES public.group_settlements(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  decision TEXT NOT NULL CHECK (decision IN ('confirmed', 'rejected')),
  note TEXT NOT NULL DEFAULT '',
  acted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.group_activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  action_type TEXT NOT NULL,
  entity_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_group_activity_group_created
  ON public.group_activity (group_id, created_at DESC);

-- Triggers
DROP TRIGGER IF EXISTS trg_groups_updated_at ON public.groups;
CREATE TRIGGER trg_groups_updated_at BEFORE UPDATE ON public.groups FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_group_settings_updated_at ON public.group_settings;
CREATE TRIGGER trg_group_settings_updated_at BEFORE UPDATE ON public.group_settings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_group_members_updated_at ON public.group_members;
CREATE TRIGGER trg_group_members_updated_at BEFORE UPDATE ON public.group_members FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_group_invites_updated_at ON public.group_invites;
CREATE TRIGGER trg_group_invites_updated_at BEFORE UPDATE ON public.group_invites FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_group_expenses_updated_at ON public.group_expenses;
CREATE TRIGGER trg_group_expenses_updated_at BEFORE UPDATE ON public.group_expenses FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_group_settlements_updated_at ON public.group_settlements;
CREATE TRIGGER trg_group_settlements_updated_at BEFORE UPDATE ON public.group_settlements FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 2. Security Definer Permission Helpers (Prevents RLS Recursion)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_active_group_member(gid UUID, uid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = gid AND user_id = uid AND status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.get_group_role(gid UUID, uid UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM public.group_members
  WHERE group_id = gid AND user_id = uid AND status = 'active'
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.has_group_permission(gid UUID, uid UUID, perm TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  u_role TEXT;
  setting_val TEXT;
BEGIN
  u_role := public.get_group_role(gid, uid);
  IF u_role IS NULL THEN
    RETURN false;
  END IF;
  IF u_role = 'owner' THEN
    RETURN true;
  END IF;

  SELECT CASE perm
    WHEN 'add_expense' THEN who_can_add_expense
    WHEN 'approve_expense' THEN who_can_approve_expense
    WHEN 'invite' THEN who_can_invite
    WHEN 'remove_member' THEN who_can_remove_member
    WHEN 'edit_group' THEN who_can_edit_group
    ELSE 'owner'
  END INTO setting_val
  FROM public.group_settings
  WHERE group_id = gid;

  IF setting_val = 'all' THEN
    RETURN true;
  ELSIF setting_val = 'admins' AND u_role IN ('owner', 'sub_admin') THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. Grants & Row Level Security (RLS)
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON public.groups TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.group_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.group_members TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.group_invites TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.group_expenses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.expense_payers TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.expense_participants TO authenticated;
GRANT SELECT, INSERT ON public.expense_approvals TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.group_settlements TO authenticated;
GRANT SELECT, INSERT ON public.settlement_confirmations TO authenticated;
GRANT SELECT ON public.group_activity TO authenticated;

ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_payers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settlement_confirmations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_activity ENABLE ROW LEVEL SECURITY;

-- groups
DROP POLICY IF EXISTS "groups_select_member_or_invitee" ON public.groups;
CREATE POLICY "groups_select_member_or_invitee" ON public.groups FOR SELECT
  USING (
    public.is_active_group_member(id, auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.group_invites gi
      WHERE gi.group_id = id AND gi.invitee_id = auth.uid() AND gi.status = 'pending'
    )
  );

DROP POLICY IF EXISTS "groups_update_permitted" ON public.groups;
CREATE POLICY "groups_update_permitted" ON public.groups FOR UPDATE
  USING (public.has_group_permission(id, auth.uid(), 'edit_group'));

DROP POLICY IF EXISTS "groups_delete_owner" ON public.groups;
CREATE POLICY "groups_delete_owner" ON public.groups FOR DELETE
  USING (owner_id = auth.uid());

-- group_settings
DROP POLICY IF EXISTS "group_settings_select_member" ON public.group_settings;
CREATE POLICY "group_settings_select_member" ON public.group_settings FOR SELECT
  USING (public.is_active_group_member(group_id, auth.uid()));

DROP POLICY IF EXISTS "group_settings_update_owner" ON public.group_settings;
CREATE POLICY "group_settings_update_owner" ON public.group_settings FOR UPDATE
  USING (public.get_group_role(group_id, auth.uid()) = 'owner');

-- group_members
DROP POLICY IF EXISTS "group_members_select_member" ON public.group_members;
CREATE POLICY "group_members_select_member" ON public.group_members FOR SELECT
  USING (public.is_active_group_member(group_id, auth.uid()));

DROP POLICY IF EXISTS "group_members_update_admin_or_self_leave" ON public.group_members;
CREATE POLICY "group_members_update_admin_or_self_leave" ON public.group_members FOR UPDATE
  USING (
    public.get_group_role(group_id, auth.uid()) = 'owner'
    OR (public.has_group_permission(group_id, auth.uid(), 'remove_member') AND role = 'member')
    OR (user_id = auth.uid() AND role <> 'owner')
  );

-- group_invites
DROP POLICY IF EXISTS "group_invites_select" ON public.group_invites;
CREATE POLICY "group_invites_select" ON public.group_invites FOR SELECT
  USING (
    invitee_id = auth.uid()
    OR public.is_active_group_member(group_id, auth.uid())
  );

DROP POLICY IF EXISTS "group_invites_insert" ON public.group_invites;
CREATE POLICY "group_invites_insert" ON public.group_invites FOR INSERT
  WITH CHECK (
    inviter_id = auth.uid()
    AND public.has_group_permission(group_id, auth.uid(), 'invite')
  );

DROP POLICY IF EXISTS "group_invites_update" ON public.group_invites;
CREATE POLICY "group_invites_update" ON public.group_invites FOR UPDATE
  USING (invitee_id = auth.uid() OR inviter_id = auth.uid() OR public.get_group_role(group_id, auth.uid()) = 'owner');

-- group_expenses & children
DROP POLICY IF EXISTS "group_expenses_select" ON public.group_expenses;
CREATE POLICY "group_expenses_select" ON public.group_expenses FOR SELECT
  USING (public.is_active_group_member(group_id, auth.uid()) AND is_deleted = false);

DROP POLICY IF EXISTS "expense_payers_select" ON public.expense_payers;
CREATE POLICY "expense_payers_select" ON public.expense_payers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.group_expenses ge
      WHERE ge.id = expense_id AND public.is_active_group_member(ge.group_id, auth.uid())
    )
  );

DROP POLICY IF EXISTS "expense_participants_select" ON public.expense_participants;
CREATE POLICY "expense_participants_select" ON public.expense_participants FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.group_expenses ge
      WHERE ge.id = expense_id AND public.is_active_group_member(ge.group_id, auth.uid())
    )
  );

DROP POLICY IF EXISTS "expense_approvals_select" ON public.expense_approvals;
CREATE POLICY "expense_approvals_select" ON public.expense_approvals FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.group_expenses ge
      WHERE ge.id = expense_id AND public.is_active_group_member(ge.group_id, auth.uid())
    )
  );

-- group_settlements
DROP POLICY IF EXISTS "group_settlements_select" ON public.group_settlements;
CREATE POLICY "group_settlements_select" ON public.group_settlements FOR SELECT
  USING (public.is_active_group_member(group_id, auth.uid()));

DROP POLICY IF EXISTS "settlement_confirmations_select" ON public.settlement_confirmations;
CREATE POLICY "settlement_confirmations_select" ON public.settlement_confirmations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.group_settlements gs
      WHERE gs.id = settlement_id AND public.is_active_group_member(gs.group_id, auth.uid())
    )
  );

-- group_activity (immutable append-only)
DROP POLICY IF EXISTS "group_activity_select" ON public.group_activity;
CREATE POLICY "group_activity_select" ON public.group_activity FOR SELECT
  USING (public.is_active_group_member(group_id, auth.uid()));

-- ----------------------------------------------------------------------------
-- 4. Atomic Transactional RPCs
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_group_with_owner(
  p_name TEXT,
  p_description TEXT DEFAULT '',
  p_category TEXT DEFAULT 'General',
  p_currency TEXT DEFAULT 'PKR',
  p_icon_key TEXT DEFAULT 'users'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  new_gid UUID;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  INSERT INTO public.groups (name, description, category, currency, icon_key, owner_id)
  VALUES (trim(p_name), COALESCE(trim(p_description), ''), COALESCE(p_category, 'General'), COALESCE(p_currency, 'PKR'), COALESCE(p_icon_key, 'users'), uid)
  RETURNING id INTO new_gid;

  INSERT INTO public.group_settings (group_id) VALUES (new_gid);

  INSERT INTO public.group_members (group_id, user_id, role, status)
  VALUES (new_gid, uid, 'owner', 'active');

  INSERT INTO public.group_activity (group_id, actor_id, action_type, entity_id, metadata)
  VALUES (new_gid, uid, 'group_created', new_gid, jsonb_build_object('name', trim(p_name)));

  RETURN new_gid;
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_to_group_invite(
  p_invite_id UUID,
  p_accept BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  inv RECORD;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO inv FROM public.group_invites
  WHERE id = p_invite_id AND invitee_id = uid AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending invite not found';
  END IF;

  IF p_accept THEN
    UPDATE public.group_invites SET status = 'accepted' WHERE id = p_invite_id;

    INSERT INTO public.group_members (group_id, user_id, role, status)
    VALUES (inv.group_id, uid, 'member', 'active')
    ON CONFLICT (group_id, user_id)
    DO UPDATE SET status = 'active', role = 'member', joined_at = now();

    INSERT INTO public.group_activity (group_id, actor_id, action_type, entity_id, metadata)
    VALUES (inv.group_id, uid, 'member_joined', uid, '{}'::jsonb);
  ELSE
    UPDATE public.group_invites SET status = 'rejected' WHERE id = p_invite_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_group_expense(
  p_group_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_total_amount_minor BIGINT,
  p_category TEXT,
  p_expense_date DATE,
  p_split_method TEXT,
  p_payment_method TEXT,
  p_payers JSONB,
  p_participants JSONB,
  p_receipt_url TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  req_approval BOOLEAN;
  init_status TEXT;
  payers_sum BIGINT := 0;
  shares_sum BIGINT := 0;
  new_eid UUID;
  item JSONB;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT public.has_group_permission(p_group_id, uid, 'add_expense') THEN
    RAISE EXCEPTION 'Permission denied to add expenses in this group';
  END IF;

  IF p_total_amount_minor <= 0 THEN
    RAISE EXCEPTION 'Expense total must be positive';
  END IF;

  SELECT COALESCE(SUM((elem->>'paid_amount_minor')::BIGINT), 0)
  INTO payers_sum
  FROM jsonb_array_elements(p_payers) elem;

  IF payers_sum <> p_total_amount_minor THEN
    RAISE EXCEPTION 'Sum of payer contributions (%) must equal total (%)', payers_sum, p_total_amount_minor;
  END IF;

  SELECT COALESCE(SUM((elem->>'share_amount_minor')::BIGINT), 0)
  INTO shares_sum
  FROM jsonb_array_elements(p_participants) elem;

  IF shares_sum <> p_total_amount_minor THEN
    RAISE EXCEPTION 'Sum of participant shares (%) must equal total (%)', shares_sum, p_total_amount_minor;
  END IF;

  SELECT require_expense_approval INTO req_approval
  FROM public.group_settings WHERE group_id = p_group_id;

  IF COALESCE(req_approval, false) AND NOT public.has_group_permission(p_group_id, uid, 'approve_expense') THEN
    init_status := 'pending';
  ELSE
    init_status := 'approved';
  END IF;

  INSERT INTO public.group_expenses (
    group_id, created_by, title, description, total_amount_minor,
    currency, category, expense_date, split_method, payment_method,
    receipt_url, approval_status
  )
  SELECT
    p_group_id, uid, trim(p_title), COALESCE(trim(p_description), ''),
    p_total_amount_minor, g.currency, COALESCE(p_category, 'Other'),
    COALESCE(p_expense_date, CURRENT_DATE), COALESCE(p_split_method, 'equal'),
    COALESCE(p_payment_method, 'cash'), p_receipt_url, init_status
  FROM public.groups g WHERE g.id = p_group_id
  RETURNING id INTO new_eid;

  FOR item IN SELECT * FROM jsonb_array_elements(p_payers) LOOP
    INSERT INTO public.expense_payers (expense_id, user_id, paid_amount_minor)
    VALUES (new_eid, (item->>'user_id')::UUID, (item->>'paid_amount_minor')::BIGINT);
  END LOOP;

  FOR item IN SELECT * FROM jsonb_array_elements(p_participants) LOOP
    INSERT INTO public.expense_participants (expense_id, user_id, share_amount_minor)
    VALUES (new_eid, (item->>'user_id')::UUID, (item->>'share_amount_minor')::BIGINT);
  END LOOP;

  INSERT INTO public.group_activity (group_id, actor_id, action_type, entity_id, metadata)
  VALUES (
    p_group_id, uid, 'expense_created', new_eid,
    jsonb_build_object('title', trim(p_title), 'total_amount_minor', p_total_amount_minor, 'status', init_status)
  );

  RETURN new_eid;
END;
$$;

CREATE OR REPLACE FUNCTION public.decide_group_expense(
  p_expense_id UUID,
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
  exp RECORD;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_decision NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid decision';
  END IF;

  SELECT * INTO exp FROM public.group_expenses WHERE id = p_expense_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Expense not found';
  END IF;

  IF NOT public.has_group_permission(exp.group_id, uid, 'approve_expense') THEN
    RAISE EXCEPTION 'Permission denied to approve/reject expenses';
  END IF;

  UPDATE public.group_expenses SET approval_status = p_decision WHERE id = p_expense_id;

  INSERT INTO public.expense_approvals (expense_id, actor_id, decision, note)
  VALUES (p_expense_id, uid, p_decision, COALESCE(p_note, ''));

  INSERT INTO public.group_activity (group_id, actor_id, action_type, entity_id, metadata)
  VALUES (
    exp.group_id, uid,
    CASE WHEN p_decision = 'approved' THEN 'expense_approved' ELSE 'expense_rejected' END,
    p_expense_id, jsonb_build_object('title', exp.title)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_group_settlement(
  p_group_id UUID,
  p_receiver_id UUID,
  p_amount_minor BIGINT,
  p_payment_method TEXT DEFAULT 'cash',
  p_reference TEXT DEFAULT '',
  p_proof_url TEXT DEFAULT NULL
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
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT public.is_active_group_member(p_group_id, uid) OR NOT public.is_active_group_member(p_group_id, p_receiver_id) THEN
    RAISE EXCEPTION 'Both sender and receiver must be active group members';
  END IF;

  IF p_amount_minor <= 0 THEN
    RAISE EXCEPTION 'Settlement amount must be positive';
  END IF;

  SELECT auto_confirm_settlements INTO auto_confirm FROM public.group_settings WHERE group_id = p_group_id;
  init_status := CASE WHEN COALESCE(auto_confirm, false) THEN 'confirmed' ELSE 'pending' END;

  INSERT INTO public.group_settlements (
    group_id, sender_id, receiver_id, amount_minor, currency,
    payment_method, reference, proof_url, status
  )
  SELECT
    p_group_id, uid, p_receiver_id, p_amount_minor, g.currency,
    COALESCE(p_payment_method, 'cash'), COALESCE(p_reference, ''), p_proof_url, init_status
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
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO st FROM public.group_settlements WHERE id = p_settlement_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Settlement not found';
  END IF;

  IF st.status <> 'pending' THEN
    RAISE EXCEPTION 'Settlement is no longer pending';
  END IF;

  IF p_decision = 'cancelled' THEN
    IF st.sender_id <> uid THEN
      RAISE EXCEPTION 'Only sender can cancel a pending settlement';
    END IF;
    UPDATE public.group_settlements SET status = 'cancelled' WHERE id = p_settlement_id;
    RETURN;
  END IF;

  IF p_decision NOT IN ('confirmed', 'rejected') THEN
    RAISE EXCEPTION 'Invalid decision';
  END IF;

  IF st.receiver_id <> uid THEN
    RAISE EXCEPTION 'Only receiver can confirm or reject a settlement';
  END IF;

  UPDATE public.group_settlements SET status = p_decision WHERE id = p_settlement_id;

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

-- Helper view/RPC to fetch member profiles safely for a group
CREATE OR REPLACE FUNCTION public.get_group_members_with_profiles(p_group_id UUID)
RETURNS TABLE (
  member_id UUID,
  user_id UUID,
  public_id TEXT,
  full_name TEXT,
  avatar_url TEXT,
  role TEXT,
  status TEXT,
  joined_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_active_group_member(p_group_id, auth.uid()) THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;

  RETURN QUERY
  SELECT
    gm.id AS member_id,
    gm.user_id,
    p.public_id,
    p.full_name,
    p.avatar_url,
    gm.role,
    gm.status,
    gm.joined_at
  FROM public.group_members gm
  JOIN public.profiles p ON p.id = gm.user_id
  WHERE gm.group_id = p_group_id AND gm.status = 'active'
  ORDER BY
    CASE gm.role WHEN 'owner' THEN 0 WHEN 'sub_admin' THEN 1 ELSE 2 END,
    p.full_name ASC;
END;
$$;
