CREATE TABLE IF NOT EXISTS public.official_brand (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_name VARCHAR(255) NOT NULL,
    official_domain VARCHAR(255) UNIQUE NOT NULL CHECK (official_domain = lower(official_domain)),
    category VARCHAR(255) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_in TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
  );

  GRANT SELECT ON public.official_brand TO authenticated, anon;

  ALTER TABLE public.official_brand ENABLE ROW LEVEL SECURITY;

  CREATE POLICY "Users can view active official brands"
  ON public.official_brand FOR SELECT
  TO authenticated, anon
  USING (active = TRUE);

  INSERT INTO public.official_brand (entity_name, official_domain, category, active)
  VALUES
    ('Bancolombia', 'bancolombia.com', 'Banca', TRUE),
    ('Banco de Bogota', 'bancodebogota.com', 'Banca', TRUE),
    ('Davivienda', 'davivienda.com', 'Banca', TRUE),
    ('BBVA Colombia', 'bbva.com.co', 'Banca', TRUE),
    ('Nequi', 'nequi.com.co', 'Billetera Digital', TRUE),
    ('DaviPlata', 'daviplata.com', 'Billetera Digital', TRUE),
    ('DIAN', 'dian.gov.co', 'Gobierno', TRUE),
    ('Servientrega', 'servientrega.com', 'Logistica', TRUE),
    ('Inter Rapidisimo', 'interrapidisimo.com', 'Logistica', TRUE),
    ('Mercado Libre Colombia', 'mercadolibre.com.co', 'Comercio Electronico', TRUE),
    ('Google', 'google.com', 'Tecnologia', TRUE),
    ('Microsoft', 'microsoft.com', 'Tecnologia', TRUE)
  ON CONFLICT (official_domain) DO NOTHING;
