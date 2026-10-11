# AI dose second opinion (optional, warnings only)

The app already checks daily doses with built-in limits (about 50 medicines) and flags clearly
unusual amounts for any medicine. This optional function adds an **AI second opinion** for medicines
that have no limit on file. It can only ADD a warning ("AI second opinion (unverified) ... may be
higher than the usual adult amount"). It never shows "OK", "safe" or any reassurance.

What is sent: one generic medicine name, the amount per dose (mg), and doses per day. No patient
name, no ID, no other medicines. Only signed-in users trigger it, results are cached in the browser,
and it stops calling if the function is missing or failing.

## Deploy (about 3 minutes — same key as prescription reading)
1. Supabase -> Edge Functions -> **Deploy a new function -> Via Editor**.
2. Name it exactly `dose-check`.
3. Paste all of `backend/functions/dose-check/index.ts` and click **Deploy** (keep **Verify JWT** ON).
4. No new secret is needed: it uses the `ANTHROPIC_API_KEY` or `GEMINI_API_KEY` you already set for
   `read-prescription`. (Free Gemini key: demos only — Google's free tier may use submitted content.
   The data here is only a generic medicine name and numbers.)

If you skip this, nothing breaks: the built-in dose checks keep working.

## Limits
- AI can be wrong; this is a safety net that only raises warnings. Pharmacist review of the built-in limits is still needed before public launch.
- Any signed-in user can trigger calls (max about 25 per browser session). Keep a spend limit with a paid provider.

## Separate keys per function (optional)
Each AI function checks its OWN secret first, then the shared one:

| Function | Own secrets (checked first) | Shared fallback |
|---|---|---|
| `read-prescription` (photo reading) | `RX_GEMINI_API_KEY`, `RX_ANTHROPIC_API_KEY`, `RX_AI_MODEL` | `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`, `AI_MODEL` |
| `dose-check` (dose second opinion) | `DOSE_GEMINI_API_KEY`, `DOSE_ANTHROPIC_API_KEY`, `DOSE_AI_MODEL` | same shared names |

So you can use one key for photos and a different key (or even a different provider) for dose checks.
Example: `RX_ANTHROPIC_API_KEY` for prescription photos and `DOSE_GEMINI_API_KEY` for dose checks.
If both an Anthropic and a Gemini key are visible to a function, Anthropic is used.
