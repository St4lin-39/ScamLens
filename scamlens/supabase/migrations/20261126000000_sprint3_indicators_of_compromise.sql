CREATE TABLE IF NOT EXISTS public.indicator_of_compromise (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(20) NOT NULL CHECK (type IN ('URL', 'DOMAIN', 'IP')),
    value TEXT NOT NULL CHECK (
      btrim(value) <> '' AND (type = 'URL' OR value = lower(value))
    ),
    attack_type VARCHAR(100) NOT NULL,
    detection_source VARCHAR(100) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_in TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT uq_ioc_type_value UNIQUE (type, value)
  );

  CREATE INDEX IF NOT EXISTS idx_ioc_active_value
    ON public.indicator_of_compromise (value)
    WHERE active = TRUE;

  GRANT SELECT ON public.indicator_of_compromise TO authenticated, anon;

  ALTER TABLE public.indicator_of_compromise ENABLE ROW LEVEL SECURITY;

  CREATE POLICY "Users can view active indicators of compromise"
  ON public.indicator_of_compromise FOR SELECT
  TO authenticated, anon
  USING (active = TRUE);

  INSERT INTO public.indicator_of_compromise (type, value, attack_type, detection_source, active)
  VALUES
    ('DOMAIN', 'secure-verify-account.xyz', 'PHISHING', 'OPENPHISH', TRUE),
    ('DOMAIN', 'pagos-impuestos-col.top', 'SMISHING', 'COMMUNITY_VERIFIED', TRUE),
    ('URL', 'https://promo-bono-regalo.online/reclamar', 'QRISHING', 'URLHAUS', TRUE),
    ('IP', '198.51.100.42', 'MALWARE', 'URLHAUS', TRUE)
  ON CONFLICT (type, value) DO NOTHING;

