// ─────────────────────────────────────────────
//  DFK – Supabase configuratie
//  Vul hieronder jouw Project URL en Anon Key in
//  (te vinden in Supabase → Project Settings → API)
// ─────────────────────────────────────────────

const SUPABASE_URL  = 'https://peycptkmzttxsqalwbtg.supabase.co';
const SUPABASE_KEY  = 'sb_publishable_wyecy0yXOa9kd3YG-VHPpw_xKxxPEFW';

const _supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

// ── Auth helpers ──────────────────────────────

async function getSession() {
  const { data } = await _supabase.auth.getSession();
  return data.session;
}

async function getUser() {
  const { data } = await _supabase.auth.getUser();
  return data.user;
}

async function getProfile(userId) {
  const { data } = await _supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();
  return data;
}

// Redirect naar login als niet ingelogd
async function requireAuth() {
  const session = await getSession();
  if (!session) { window.location.href = 'index.html'; return null; }
  return session;
}

// Redirect naar login als geen admin-rol
async function requireAdmin() {
  const session = await requireAuth();
  if (!session) return null;
  const profile = await getProfile(session.user.id);
  if (!profile || profile.rol !== 'admin') {
    window.location.href = 'evenementen.html';
    return null;
  }
  return { session, profile };
}
