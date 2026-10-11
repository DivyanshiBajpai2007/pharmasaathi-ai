// Supabase Edge Function: send-reminders
// Runs every minute (started by pg_cron, see backend/push.sql). For every signed-in person who allowed
// notifications, it finds the doses that are due right now and sends a push notification to their phone —
// this is what makes a reminder arrive even when the PharmaSaathi app is CLOSED.
//
// Secrets (Edge Functions -> Secrets):
//   CRON_SECRET          a long random text you make up; the same text is put in the cron job (backend/push.sql)
//   VAPID_PUBLIC_KEY     } made once with:  npx web-push generate-vapid-keys
//   VAPID_PRIVATE_KEY    } (the private one never goes anywhere except this secret)
//   VAPID_SUBJECT        optional, e.g. mailto:you@example.com
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase automatically.
//
// Deploy with "Verify JWT" OFF — the caller is the cron job, which proves itself with the x-cron-secret header.

import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

const RING_EVERY_MIN = 10;   // an unanswered reminder is repeated every 10 minutes ...
const MAX_SENDS = 4;         // ... 4 times in all (same as the in-app alarm)

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

// constant-time comparison so the secret cannot be guessed from response timing
function same(a: string, b: string): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

function localParts(d: Date, tz: string): { date: string; mins: number } {
  let zone = tz || 'Asia/Kolkata';
  try { new Intl.DateTimeFormat('en-CA', { timeZone: zone }); } catch { zone = 'Asia/Kolkata'; }
  const f = new Intl.DateTimeFormat('en-CA', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
  const p: Record<string, string> = {};
  for (const x of f.formatToParts(d)) p[x.type] = x.value;
  return { date: p.year + '-' + p.month + '-' + p.day, mins: Number(p.hour) * 60 + Number(p.minute) };
}
const hhmmToMins = (t: string) => { const [h, m] = String(t).split(':'); return Number(h) * 60 + Number(m); };
function addDays(date: string, n: number): string {
  const [y, m, d] = date.split('-').map(Number);
  const t = new Date(Date.UTC(y, m - 1, d + n));
  return t.getUTCFullYear() + '-' + String(t.getUTCMonth() + 1).padStart(2, '0') + '-' + String(t.getUTCDate()).padStart(2, '0');
}
// "for 5 days" / "x 2 weeks" written on the prescription (same rule as the app)
function courseDays(text: string): number {
  const m = String(text || '').toLowerCase().match(/(?:\bx|×|\bfor)\s*(\d{1,3})\s*(days?|d\b|weeks?|wks?|months?)/);
  if (!m) return 0;
  const n = Number(m[1]);
  return m[2].charAt(0) === 'd' ? n : (m[2].charAt(0) === 'w' ? n * 7 : n * 30);
}

const TEXT = {
  en: { one: 'Time for your medicine', many: 'Time for your medicines' },
  hi: { one: 'दवा लेने का समय हो गया', many: 'दवाइयाँ लेने का समय हो गया' },
};

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405);
  if (!same(req.headers.get('x-cron-secret') || '', Deno.env.get('CRON_SECRET') || '')) return json({ error: 'Not allowed' }, 401);

  const pub = Deno.env.get('VAPID_PUBLIC_KEY'), priv = Deno.env.get('VAPID_PRIVATE_KEY');
  if (!pub || !priv) return json({ error: 'VAPID keys are not set' }, 503);
  webpush.setVapidDetails(Deno.env.get('VAPID_SUBJECT') || 'mailto:support@pharmasaathi.example', pub, priv);

  const db = createClient(Deno.env.get('SUPABASE_URL') as string, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') as string, { auth: { persistSession: false } });
  const now = new Date();

  const subsRes = await db.from('push_subscriptions').select('*');
  if (subsRes.error) return json({ error: 'subscriptions: ' + subsRes.error.message }, 500);
  const byPatient = new Map<string, any[]>();
  for (const s of subsRes.data || []) { const l = byPatient.get(s.patient_id) || []; l.push(s); byPatient.set(s.patient_id, l); }

  let sent = 0, checked = 0;
  const debug: Record<string, unknown>[] = [];      // counts only, no names: explains why nothing was sent
  for (const [pid, subs] of byPatient) {
    checked++;
    try {
      const me = subs.slice().sort((a, b) => String(b.last_seen).localeCompare(String(a.last_seen)))[0];
      const { date: today, mins: nowMins } = localParts(now, me.tz);
      const lang = me.lang === 'hi' ? 'hi' : 'en';

      const why = { at: today + ' ' + String(Math.floor(nowMins / 60)).padStart(2, '0') + ':' + String(nowMins % 60).padStart(2, '0'), tz: me.tz, phones: subs.length,
        rows: 0, notActive: 0, taken: 0, startsTomorrow: 0, courseOver: 0, notYetOrRepeatWait: 0, tooLate: 0, allSent: 0, due: 0, error: '' };
      debug.push(why);
      const sch = await db.from('dose_schedule')
        .select('id, time_of_day, active, created_at, prescription_items!inner(status, custom_name, custom_dose, medicine_catalog(name_en, name_hi), prescriptions(prescribed_date))')
        .eq('patient_id', pid).eq('active', true);
      if (sch.error) { console.error('schedule', pid, sch.error.message); why.error = String(sch.error.message).slice(0, 120); continue; }
      const rows = (sch.data || []) as any[];
      why.rows = rows.length;
      if (!rows.length) continue;
      const ids = rows.map((r) => r.id);

      let logs = await db.from('dose_logs').select('schedule_id, status, confirmed_at').eq('dose_date', today).in('schedule_id', ids);
      if (logs.error) logs = await db.from('dose_logs').select('schedule_id, status').eq('dose_date', today).in('schedule_id', ids);   // older database without confirmed_at
      const done = new Set<string>();
      for (const l of (logs.data || []) as any[]) if (l.status === 'taken' && (!('confirmed_at' in l) || l.confirmed_at)) done.add(l.schedule_id);
      const sentRes = await db.from('push_sent').select('schedule_id, sent_count').eq('dose_date', today).in('schedule_id', ids);
      const counts = new Map<string, number>();
      for (const x of (sentRes.data || []) as any[]) counts.set(x.schedule_id, x.sent_count);

      const due: { id: string; name: string; time: string }[] = [];
      for (const r of rows) {
        const item = r.prescription_items;
        if (!item || !['active', 'paused'].includes(item.status)) { why.notActive++; continue; }
        const at = hhmmToMins(String(r.time_of_day).slice(0, 5));
        if (done.has(r.id)) { why.taken++; continue; }
        // the dose time had already passed when this reminder was created -> it starts tomorrow
        const created = localParts(new Date(r.created_at), me.tz);
        const startsTomorrow = created.date === today && created.mins > at;
        if (startsTomorrow) { why.startsTomorrow++; continue; }
        // the written course ("for 5 days") is over
        const days = courseDays(item.custom_dose);
        if (days > 0) {
          const rxDate = item.prescriptions?.prescribed_date || created.date;
          const allPast = created.date === rxDate && created.mins > at;
          const start = allPast ? addDays(rxDate, 1) : rxDate;
          if (today > addDays(start, days - 1)) { why.courseOver++; continue; }
        }
        const n = counts.get(r.id) || 0;
        if (n >= MAX_SENDS) { why.allSent++; continue; }
        if (nowMins < at + n * RING_EVERY_MIN) { why.notYetOrRepeatWait++; continue; }
        if (nowMins - at > 50) { why.tooLate++; continue; }
        const cat = item.medicine_catalog;
        due.push({ id: r.id, name: (cat && (lang === 'hi' ? cat.name_hi : cat.name_en)) || item.custom_name || (lang === 'hi' ? 'दवा' : 'medicine'), time: String(r.time_of_day).slice(0, 5) });
      }
      why.due = due.length;
      if (!due.length) continue;

      const t = TEXT[lang];
      const payload = JSON.stringify({ title: due.length > 1 ? t.many : t.one, body: due.map((d) => d.name + ' ' + d.time).join(', '), tag: 'ps-dose', url: './' });
      let delivered = 0;
      for (const s of subs) {
        try {
          await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 600, urgency: 'high' });
          delivered++;
        } catch (e) {
          const code = (e as { statusCode?: number }).statusCode;
          if (code === 404 || code === 410) await db.from('push_subscriptions').delete().eq('id', s.id);      // the phone unsubscribed
          else { console.error('push failed', code, String((e as Error).message || e).slice(0, 120)); why.error = 'push ' + code + ' ' + String((e as Error).message || e).slice(0, 80); }
        }
      }
      if (delivered) {
        sent += delivered;
        await db.from('push_sent').upsert(due.map((d) => ({ schedule_id: d.id, dose_date: today, sent_count: (counts.get(d.id) || 0) + 1, last_sent_at: now.toISOString() })), { onConflict: 'schedule_id,dose_date' });
      }
    } catch (e) { console.error('patient failed', String((e as Error).message || e).slice(0, 200)); }
  }
  return json({ ok: true, people: checked, sent, debug });
});
