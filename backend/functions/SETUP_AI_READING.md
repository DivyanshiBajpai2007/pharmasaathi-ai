# Turn on AI handwriting reading (about 10 minutes, one time)

The app already contains the AI-reading feature. Until you do these steps, signed-in users
fall back to the on-device reader (fine for printed text, weak for handwriting).

You can use EITHER a free key (Google Gemini) OR a paid key (Anthropic). Set only one.

| | Free: Google Gemini | Paid: Anthropic |
|---|---|---|
| Cost | Free tier, limited requests per day, no card | Pay per scan (roughly a cent or two) |
| Privacy | Google's free tier may use submitted content to improve its products | Not used for training by default (check their current terms) |
| Use it for | Demos with SAMPLE / made-up prescriptions | Real patients |

Do NOT use the free key with real patients' prescriptions.

## 1a. Free option — get a Gemini key
1. Go to https://aistudio.google.com/apikey and sign in with a Google account.
2. Click **Create API key**, copy it.

## 1b. Paid option — get an Anthropic key
1. Go to https://console.anthropic.com, sign up, add a little credit under **Billing**.
2. Set a **monthly spend limit** under Settings → Limits.
3. **API keys → Create key**. Copy it (starts with `sk-ant-`).

Treat any key like a password: never paste it in the app, in chat, or in GitHub.

## 2. Create the function in Supabase
1. Open https://supabase.com/dashboard/project/snhnxfxlhcyculwqquzm/functions
2. Click **Deploy a new function → Via Editor**.
3. Name it exactly: `read-prescription`
4. Delete the sample code. Open `backend/functions/read-prescription/index.ts` from this
   project, copy everything, paste it into the editor.
5. Click **Deploy**.
6. In the function's **Settings**, make sure **Verify JWT** is ON (only signed-in users can call it).

## 3. Add the key as a secret
1. In Supabase go to **Edge Functions → Secrets**.
2. Add ONE secret:
   - free: name `GEMINI_API_KEY`, value = your Gemini key
   - paid: name `ANTHROPIC_API_KEY`, value = your Anthropic key
   (If both exist, Anthropic is used.)
3. (Optional) `AI_MODEL` changes the model. Defaults: `gemini-2.5-flash` / `claude-sonnet-5`.

To switch from free to paid later: add `ANTHROPIC_API_KEY` and delete `GEMINI_API_KEY`.
No app change needed.

## 4. Test
1. Open the app, sign in, go to Scan a prescription, choose a photo.
2. You will be asked once to allow sending the photo to the AI service. Choose
   "Yes, read it with AI".
3. Rows marked 🤖 are AI-read. Always check them against the paper.

If it says "AI reading is not available right now", the function is not deployed, the secret
is missing, or the free daily limit / credit ran out — open the function's **Logs** in Supabase.

## Notes
- The photo is sent only when a signed-in user agrees, and PharmaSaathi does not store it.
- Any signed-in user can trigger an AI call. Before a public launch, add per-user daily
  limits (ask for this) and, for the paid key, keep the spend limit in place.
- The privacy policy in the app mentions this; have it reviewed by legal counsel, and
  update it if you stay on a free tier.

## Separate keys per function (optional)
Each AI function checks its OWN secret first, then the shared one:

| Function | Own secrets (checked first) | Shared fallback |
|---|---|---|
| `read-prescription` (photo reading) | `RX_GEMINI_API_KEY`, `RX_ANTHROPIC_API_KEY`, `RX_AI_MODEL` | `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`, `AI_MODEL` |
| `dose-check` (dose second opinion) | `DOSE_GEMINI_API_KEY`, `DOSE_ANTHROPIC_API_KEY`, `DOSE_AI_MODEL` | same shared names |

So you can use one key for photos and a different key (or even a different provider) for dose checks.
Example: `RX_ANTHROPIC_API_KEY` for prescription photos and `DOSE_GEMINI_API_KEY` for dose checks.
If both an Anthropic and a Gemini key are visible to a function, Anthropic is used.

## Model list and fallback (photo reading, dose check, review)
- Gemini free-tier limits are counted per model. When one model is limited, the next one is tried automatically.
- `AI_MODELS` (optional): comma-separated list, best first, e.g. `gemini-3.8-flash, gemini-3.8-flash-lite`. `RX_AI_MODELS`, `DOSE_AI_MODELS`, `REVIEW_AI_MODELS` override it per function.
- `AI_PROVIDER_ORDER` (optional, photo reading only): default `anthropic,gemini`. If the first company fails (limit, outage) and you have a key for the second, it is tried next.
- If every method fails, the app does NOT guess: it says it could not read the prescription clearly and asks the person to retake the photo or add medicines by hand.
