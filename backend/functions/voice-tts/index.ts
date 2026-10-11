// Supabase Edge Function: voice-tts  (text-to-speech)
// Receives a SHORT piece of text and returns spoken audio, so the app does not depend on the
// device having an English/Hindi voice installed. Provider chosen by environment variables;
// the API key lives ONLY here.
//
// Secrets (Edge Functions -> Secrets):
//   TTS_PROVIDER   "openai" (default) or "google"
//   TTS_API_KEY    the provider's API key (required)
//   TTS_MODEL      optional. openai default: tts-1
//   TTS_VOICE_EN   optional voice name for English (openai default: nova)
//   TTS_VOICE_HI   optional voice name for Hindi   (openai default: nova)
//
// Deploy with "Verify JWT" ON. To add another provider, add one entry to PROVIDERS below.

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

const toB64 = (bytes: Uint8Array) => {
  let bin = ''; for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(bin);
};

type Provider = (key: string, text: string, lang: 'en' | 'hi') => Promise<{ audio: string; mimeType: string }>;

const PROVIDERS: Record<string, Provider> = {
  openai: async (key, text, lang) => {
    const res = await fetch('https://api.openai.com/v1/audio/speech', {
      method: 'POST', headers: { Authorization: 'Bearer ' + key, 'content-type': 'application/json' },
      body: JSON.stringify({
        model: Deno.env.get('TTS_MODEL') || 'tts-1',
        voice: Deno.env.get(lang === 'hi' ? 'TTS_VOICE_HI' : 'TTS_VOICE_EN') || 'nova',
        input: text, response_format: 'mp3',
      }),
    });
    if (res.status === 429) throw Object.assign(new Error('rate limited'), { status: 429 });
    if (!res.ok) throw new Error('openai tts ' + res.status + ' ' + (await res.text()).slice(0, 160));
    return { audio: toB64(new Uint8Array(await res.arrayBuffer())), mimeType: 'audio/mpeg' };
  },

  google: async (key, text, lang) => {
    const voiceName = Deno.env.get(lang === 'hi' ? 'TTS_VOICE_HI' : 'TTS_VOICE_EN');
    const res = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', {
      method: 'POST', headers: { 'x-goog-api-key': key, 'content-type': 'application/json' },
      body: JSON.stringify({
        input: { text },
        voice: voiceName ? { languageCode: lang === 'hi' ? 'hi-IN' : 'en-IN', name: voiceName } : { languageCode: lang === 'hi' ? 'hi-IN' : 'en-IN', ssmlGender: 'FEMALE' },
        audioConfig: { audioEncoding: 'MP3', speakingRate: 0.95 },
      }),
    });
    if (res.status === 429) throw Object.assign(new Error('rate limited'), { status: 429 });
    if (!res.ok) throw new Error('google tts ' + res.status + ' ' + (await res.text()).slice(0, 160));
    return { audio: String((await res.json()).audioContent || ''), mimeType: 'audio/mpeg' };
  },
};

// Only signed-in PharmaSaathi users may call this function. It asks Supabase Auth whether the caller's
// access token belongs to a real user — the app's public key alone (which anyone can copy from the page) is refused.
async function requireUser(req: Request): Promise<boolean> {
  const token = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '').trim();
  const url = Deno.env.get('SUPABASE_URL');
  const apikey = req.headers.get('apikey') || Deno.env.get('SUPABASE_ANON_KEY') || '';
  if (!token || !url || !apikey) return false;
  try {
    const r = await fetch(url + '/auth/v1/user', { headers: { apikey, Authorization: 'Bearer ' + token } });
    return r.ok;
  } catch { return false; }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405);
  if (!(await requireUser(req))) return json({ error: 'Sign in required', code: 'auth_required' }, 401);

  const key = Deno.env.get('TTS_API_KEY');
  const provider = PROVIDERS[(Deno.env.get('TTS_PROVIDER') || 'openai').toLowerCase()];
  if (!key || !provider) return json({ error: 'Text-to-speech is not configured on the server', code: 'not_configured' }, 503);

  let body: { text?: string; lang?: string };
  try { body = await req.json(); } catch { return json({ error: 'Invalid request' }, 400); }

  const text = String(body.text || '').replace(/[<>]/g, ' ').replace(/\s+/g, ' ').trim();
  if (!text || text.length > 700) return json({ error: 'Text must be 1-700 characters', code: 'invalid_text' }, 400);
  const lang = body.lang === 'hi' ? 'hi' : 'en';

  try {
    const out = await provider(key, text, lang);
    if (!out.audio) throw new Error('empty audio');
    return json(out);
  } catch (e) {
    console.error('tts error', String(e).slice(0, 300));
    if ((e as { status?: number }).status === 429) return json({ error: 'Too many requests, try again shortly', code: 'rate_limited' }, 429);
    return json({ error: 'Text-to-speech failed', code: 'tts_failed' }, 502);
  }
});
