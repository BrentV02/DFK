-- ══════════════════════════════════════════════════════
--  DFK Database Schema
--  Plak dit in Supabase → SQL Editor → Run
-- ══════════════════════════════════════════════════════


-- ── 1. Profiles (rijder-info, gekoppeld aan auth.users) ──

CREATE TABLE IF NOT EXISTS profiles (
  id                    UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  rol                   TEXT NOT NULL DEFAULT 'rijder' CHECK (rol IN ('rijder', 'admin')),

  -- Persoonlijke gegevens
  voornaam              TEXT,
  naam                  TEXT,
  geboortedatum         DATE,
  telefoon              TEXT,

  -- Kart type
  kart_type             TEXT CHECK (kart_type IN ('eigen', 'huur')),

  -- Eigen kart
  klasse                TEXT,
  startnummer           INT,
  kampioenschappen      TEXT[]   DEFAULT '{}',
  kart_in_werkplaats    BOOLEAN  DEFAULT false,
  banden_in_werkplaats  BOOLEAN  DEFAULT false,
  bak_in_werkplaats     BOOLEAN  DEFAULT false,
  benzine               TEXT,

  -- Huur kart
  lengte                INT,
  gewicht               INT,
  huurkart_type         TEXT,
  uitrusting            TEXT[]   DEFAULT '{}',

  aangemaakt_op         TIMESTAMPTZ DEFAULT NOW()
);


-- ── 2. Evenementen ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS evenementen (
  id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  naam        TEXT        NOT NULL,
  datum       DATE        NOT NULL,
  circuit     TEXT        NOT NULL,
  type        TEXT,
  klassen     TEXT[]      DEFAULT '{}',
  deadline    TIMESTAMPTZ,
  aangemaakt_op TIMESTAMPTZ DEFAULT NOW()
);


-- ── 3. Inschrijvingen ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS inschrijvingen (
  id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  rijder_id     UUID        REFERENCES profiles(id)     ON DELETE CASCADE,
  event_id      UUID        REFERENCES evenementen(id)  ON DELETE CASCADE,
  bevestigd_op  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (rijder_id, event_id)
);


-- ══════════════════════════════════════════════════════
--  Row Level Security
-- ══════════════════════════════════════════════════════

ALTER TABLE profiles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE evenementen   ENABLE ROW LEVEL SECURITY;
ALTER TABLE inschrijvingen ENABLE ROW LEVEL SECURITY;

-- Hulpfunctie: is de huidige gebruiker admin?
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND rol = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;


-- ── Profiles policies ─────────────────────────────────────

-- Eigen profiel lezen
CREATE POLICY "Eigen profiel lezen"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

-- Eigen profiel aanmaken (bij registratie)
CREATE POLICY "Eigen profiel aanmaken"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Eigen profiel aanpassen
CREATE POLICY "Eigen profiel aanpassen"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Admin: alle profielen lezen
CREATE POLICY "Admin leest alle profielen"
  ON profiles FOR SELECT
  USING (is_admin());

-- Admin: alle profielen aanpassen
CREATE POLICY "Admin past alle profielen aan"
  ON profiles FOR UPDATE
  USING (is_admin());

-- Admin: profiel verwijderen
CREATE POLICY "Admin verwijdert profielen"
  ON profiles FOR DELETE
  USING (is_admin());


-- ── Evenementen policies ──────────────────────────────────

-- Iedereen mag evenementen zien (ook niet-ingelogd)
CREATE POLICY "Iedereen ziet evenementen"
  ON evenementen FOR SELECT
  USING (true);

-- Alleen admin mag evenementen beheren
CREATE POLICY "Admin beheert evenementen"
  ON evenementen FOR ALL
  USING (is_admin());


-- ── Inschrijvingen policies ───────────────────────────────

-- Eigen inschrijvingen zien
CREATE POLICY "Eigen inschrijvingen zien"
  ON inschrijvingen FOR SELECT
  USING (rijder_id = auth.uid());

-- Zichzelf inschrijven
CREATE POLICY "Zichzelf inschrijven"
  ON inschrijvingen FOR INSERT
  WITH CHECK (rijder_id = auth.uid());

-- Eigen inschrijving verwijderen (uitschrijven)
CREATE POLICY "Eigen inschrijving verwijderen"
  ON inschrijvingen FOR DELETE
  USING (rijder_id = auth.uid());

-- Admin ziet alle inschrijvingen
CREATE POLICY "Admin ziet alle inschrijvingen"
  ON inschrijvingen FOR SELECT
  USING (is_admin());


-- ══════════════════════════════════════════════════════
--  Trigger: maak automatisch een leeg profiel aan
--  zodra een gebruiker zich registreert
-- ══════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id)
  VALUES (NEW.id)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
