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
  active BOOLEAN DEFAULT TRUE,
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
ON public.user FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
ON public.user FOR INSERT
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
ON public.user FOR UPDATE
USING (auth.uid() = id);

CREATE POLICY "Users can manage their own devices"
ON public.device FOR ALL
USING (auth.uid() = user_id OR user_id IS NULL);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user (id, name, last_name, email, active, created_in)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
    NEW.email,
    TRUE,
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
