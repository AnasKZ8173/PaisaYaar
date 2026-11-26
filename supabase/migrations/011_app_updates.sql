-- ============================================================================
-- PocketYaar — In-App APK Update Popup Configuration
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.app_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  latest_version_code INT NOT NULL,
  latest_version_name TEXT NOT NULL,
  download_url TEXT NOT NULL,
  release_notes TEXT NOT NULL DEFAULT '',
  is_force_update BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT ON public.app_updates TO anon, authenticated;
ALTER TABLE public.app_updates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_updates_public_read" ON public.app_updates;
CREATE POLICY "app_updates_public_read" ON public.app_updates FOR SELECT
  USING (is_active = true);

-- Seed initial current version (versionCode = 1, matches pubspec.yaml 1.0.0+1)
INSERT INTO public.app_updates (
  latest_version_code, latest_version_name, download_url, release_notes, is_force_update
)
SELECT 1, '1.0.0', 'https://github.com/AnasKZ8173/PaisaYaar/releases', 'Initial BETA release', false
WHERE NOT EXISTS (SELECT 1 FROM public.app_updates);
