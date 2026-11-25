-- ============================================================================
-- PocketYaar — Group Chat, Admin Tagging, Settlement Account Link & Fast Dashboard
-- ============================================================================

-- 1. Chat permission in group_settings
ALTER TABLE public.group_settings
  ADD COLUMN IF NOT EXISTS allow_all_members_chat BOOLEAN NOT NULL DEFAULT true;

-- 2. Group Messages Table
CREATE TABLE IF NOT EXISTS public.group_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  body TEXT NOT NULL CHECK (char_length(trim(body)) >= 1),
  is_announcement BOOLEAN NOT NULL DEFAULT false,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_group_messages_group_created
  ON public.group_messages (group_id, created_at DESC)
  WHERE is_deleted = false;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.group_messages;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

GRANT SELECT, INSERT, UPDATE ON public.group_messages TO authenticated;
ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "group_messages_select_member" ON public.group_messages;
CREATE POLICY "group_messages_select_member" ON public.group_messages FOR SELECT
  USING (public.is_active_group_member(group_id, auth.uid()) AND is_deleted = false);

DROP POLICY IF EXISTS "group_messages_insert_permitted" ON public.group_messages;
CREATE POLICY "group_messages_insert_permitted" ON public.group_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND public.is_active_group_member(group_id, auth.uid())
    AND (
      public.get_group_role(group_id, auth.uid()) IN ('owner', 'sub_admin')
      OR EXISTS (
        SELECT 1 FROM public.group_settings gs
        WHERE gs.group_id = group_messages.group_id AND gs.allow_all_members_chat = true
      )
    )
  );

DROP POLICY IF EXISTS "group_messages_soft_delete_own" ON public.group_messages;
CREATE POLICY "group_messages_soft_delete_own" ON public.group_messages FOR UPDATE
  USING (sender_id = auth.uid());

-- 3. Trigger: Notify tagged users (@public_id) or @all when an admin posts
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

  -- If admin uses @all, notify all active members except sender
  IF sender_role IN ('owner', 'sub_admin') AND NEW.body ~* '@all\y' THEN
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

  -- Notify specifically tagged @public_id members
  FOR tagged IN
    SELECT DISTINCT gm.user_id
    FROM public.group_members gm
    JOIN public.profiles p ON p.id = gm.user_id
    WHERE gm.group_id = NEW.group_id
      AND gm.status = 'active'
      AND gm.user_id <> NEW.sender_id
      AND NEW.body ~* ('@' || p.public_id || '\y')
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

DROP TRIGGER IF EXISTS trg_notify_group_message_tags ON public.group_messages;
CREATE TRIGGER trg_notify_group_message_tags
  AFTER INSERT ON public.group_messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_group_message_tags();

-- 4. Fast Single-Query Dashboard Summary for Group Balances & Recent Group Expenses
CREATE OR REPLACE FUNCTION public.get_my_group_dashboard_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  total_owed BIGINT := 0;
  total_receivable BIGINT := 0;
  recent_items JSONB := '[]'::jsonb;
BEGIN
  IF uid IS NULL THEN
    RETURN jsonb_build_object(
      'total_owed_minor', 0,
      'total_receivable_minor', 0,
      'recent_expenses', '[]'::jsonb
    );
  END IF;

  -- Per-group net balance for current user
  WITH my_groups AS (
    SELECT group_id FROM public.group_members WHERE user_id = uid AND status = 'active'
  ),
  group_paid AS (
    SELECT ge.group_id, COALESCE(SUM(ep.paid_amount_minor), 0) AS paid
    FROM public.group_expenses ge
    JOIN public.expense_payers ep ON ep.expense_id = ge.id
    WHERE ge.group_id IN (SELECT group_id FROM my_groups)
      AND ge.approval_status = 'approved'
      AND ge.is_deleted = false
      AND ep.user_id = uid
    GROUP BY ge.group_id
  ),
  group_share AS (
    SELECT ge.group_id, COALESCE(SUM(ep.share_amount_minor), 0) AS share
    FROM public.group_expenses ge
    JOIN public.expense_participants ep ON ep.expense_id = ge.id
    WHERE ge.group_id IN (SELECT group_id FROM my_groups)
      AND ge.approval_status = 'approved'
      AND ge.is_deleted = false
      AND ep.user_id = uid
    GROUP BY ge.group_id
  ),
  group_sent AS (
    SELECT group_id, COALESCE(SUM(amount_minor), 0) AS sent
    FROM public.group_settlements
    WHERE group_id IN (SELECT group_id FROM my_groups)
      AND status = 'confirmed' AND sender_id = uid
    GROUP BY group_id
  ),
  group_recv AS (
    SELECT group_id, COALESCE(SUM(amount_minor), 0) AS recv
    FROM public.group_settlements
    WHERE group_id IN (SELECT group_id FROM my_groups)
      AND status = 'confirmed' AND receiver_id = uid
    GROUP BY group_id
  ),
  group_nets AS (
    SELECT
      mg.group_id,
      COALESCE(gp.paid, 0) - COALESCE(gs.share, 0) + COALESCE(gsent.sent, 0) - COALESCE(grecv.recv, 0) AS net
    FROM my_groups mg
    LEFT JOIN group_paid gp ON gp.group_id = mg.group_id
    LEFT JOIN group_share gs ON gs.group_id = mg.group_id
    LEFT JOIN group_sent gsent ON gsent.group_id = mg.group_id
    LEFT JOIN group_recv grecv ON grecv.group_id = mg.group_id
  )
  SELECT
    COALESCE(SUM(CASE WHEN net < 0 THEN -net ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN net > 0 THEN net ELSE 0 END), 0)
  INTO total_owed, total_receivable
  FROM group_nets;

  -- Recent 8 group expenses involving the user (or in user's groups)
  SELECT COALESCE(jsonb_agg(item), '[]'::jsonb)
  INTO recent_items
  FROM (
    SELECT jsonb_build_object(
      'expense_id', ge.id,
      'group_id', ge.group_id,
      'group_name', g.name,
      'title', ge.title,
      'total_amount_minor', ge.total_amount_minor,
      'currency', ge.currency,
      'expense_date', ge.expense_date,
      'approval_status', ge.approval_status,
      'my_paid_minor', COALESCE((SELECT SUM(paid_amount_minor) FROM public.expense_payers WHERE expense_id = ge.id AND user_id = uid), 0),
      'my_share_minor', COALESCE((SELECT SUM(share_amount_minor) FROM public.expense_participants WHERE expense_id = ge.id AND user_id = uid), 0)
    ) AS item
    FROM public.group_expenses ge
    JOIN public.groups g ON g.id = ge.group_id
    JOIN public.group_members gm ON gm.group_id = ge.group_id AND gm.user_id = uid AND gm.status = 'active'
    WHERE ge.is_deleted = false
    ORDER BY ge.expense_date DESC, ge.created_at DESC
    LIMIT 8
  ) sub;

  RETURN jsonb_build_object(
    'total_owed_minor', total_owed,
    'total_receivable_minor', total_receivable,
    'recent_expenses', recent_items
  );
END;
$$;
