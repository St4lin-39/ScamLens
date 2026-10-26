CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP TABLE IF EXISTS public.device CASCADE;
DROP TABLE IF EXISTS public.user CASCADE;

CREATE TABLE public.user (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_in TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.device (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.user(id) ON DELETE SET NULL,
  uuid_device VARCHAR(255) UNIQUE NOT NULL,
  model_device VARCHAR(255) NOT NULL,
  operating_system VARCHAR(255) NOT NULL,
  version_os VARCHAR(255) NOT NULL,
  token_push TEXT,
  last_access TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

GRANT SELECT, INSERT, UPDATE ON public.user TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.device TO authenticated;

ALTER TABLE public.user ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
ON public.user FOR SELECT TO authenticated
USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
ON public.user FOR INSERT TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
ON public.user FOR UPDATE TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can manage their own devices"
ON public.device FOR ALL
USING (auth.uid() = user_id OR user_id IS NULL);
