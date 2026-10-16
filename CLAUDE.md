# PharmaSaathi AI

Bilingual (English/Hindi) medicine companion PWA for patients and caregivers in India: prescription scanning, plain-language medicine info, dose reminders through Web Push, safety checks, voice assistant and care team (caregiver/pharmacist). Live on GitHub Pages.

## Layout
- `index.html`: the whole patient app as a single-file PWA (~6.5k lines; search inside it rather than reading it all)
- `pharmacist.html`: pharmacist preview page. `sw.js` + `manifest.json`: service worker (offline + push) and install manifest
- `backend/*.sql`: Supabase Postgres schema, seed (EN + HI medicine catalog), feature tables, RLS policies, push + pg_cron
- `backend/functions/<name>/index.ts`: Supabase Edge Functions (Deno/TS): `read-prescription`, `dose-check`, `prescription-review`, `voice-stt`, `voice-tts`, `send-reminders`
- `backend/functions/SETUP_*.md`: per-feature setup instructions
- `tools/eval_prescriptions.mjs`: runs prescription photos through the vision model and writes `results.html` / `results.json`. `tools/make_vapid_keys.mjs`: Web Push keys

## Run / test
- Front end: serve the folder over HTTPS (voice and push need it) or over localhost for dev. "Try with sample data" works without an account.
- Eval: `$env:GEMINI_API_KEY="..."; node tools/eval_prescriptions.mjs "<photos folder>" 20`
- SQL order: `schema.sql` → `seed.sql` → other `.sql` files.

## Hard rules (safety + security)
- **No API keys in the front end, ever.** AI and voice keys live only in Edge Function secrets. The front end ships only the Supabase anon key and calls functions with the user's auth token.
- **AI can warn but never reassure.** AI output may only add warnings. Never present "no problem found" as a safety confirmation, and always show the rule-based checks alongside it. Never tell a user to change a dose.
- **Send the AI as little data as possible:** generic medicine name, amount, doses/day and age group. No patient names or IDs.
- Every new table needs row-level security policies. Check any function callable with the anon key (see the 2026-10 security patch).
- Not medical advice. Keep that disclaimer visible.
- Keep AI and voice providers selectable by environment variables (Gemini / Anthropic / OpenAI / Google).

## Conventions
- All user-facing strings need both English and Hindi.
- Commits: no Claude co-author or "Generated with Claude Code" lines.
