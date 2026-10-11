# Turn on online voice for "Ask PharmaSaathi" (optional)

Without this, the assistant still works: typing and buttons always work, and voice falls back to
the browser's own speech tools. Online voice adds reliable English / Hindi / Hinglish recognition and
natural spoken replies that don't depend on the phone having a Hindi voice installed.

Two small Supabase functions do the work. **No API key is ever in the app** — keys live only in
Supabase secrets.

| Function | Job | Folder |
|---|---|---|
| `voice-stt` | audio -> text | `backend/functions/voice-stt/index.ts` |
| `voice-tts` | short text -> spoken audio | `backend/functions/voice-tts/index.ts` |

## Free options (no card, no cost)
1. **Do nothing.** Typing, the buttons, and the browser's own voice tools are free. On Android phones the browser has Hindi speech recognition and Hindi voices built in. On Windows, add a free Hindi voice in Settings -> Time & language -> Speech.
2. **Free cloud speech-to-text with Gemini** (uses the same free Gemini key as prescription reading). Deploy only `voice-stt` and set `STT_PROVIDER` = `gemini` and `STT_API_KEY` = your Gemini key. Do NOT deploy `voice-tts` — spoken replies then use the browser voice. Free-tier limits apply, and Google's free tier may use submitted audio to improve its products, so use this for demos with made-up requests only — not real patients.

OpenAI's API is not free (pay-as-you-go).

## Environment variables (Supabase -> Edge Functions -> Secrets)

| Name | Needed | Meaning |
|---|---|---|
| `STT_PROVIDER` | optional | `openai` (default), `google`, or `gemini` (free tier) |
| `STT_API_KEY` | **yes** | the speech-to-text provider's key |
| `STT_MODEL` | optional | openai default `whisper-1` (or `gpt-4o-mini-transcribe`) |
| `TTS_PROVIDER` | optional | `openai` (default) or `google` |
| `TTS_API_KEY` | **yes** | the text-to-speech provider's key |
| `TTS_MODEL` | optional | openai default `tts-1` |
| `TTS_VOICE_EN`, `TTS_VOICE_HI` | optional | voice names (openai default `nova`; google picks a default female voice) |

You can use the same provider and the same key for both (`STT_API_KEY` and `TTS_API_KEY` set to the same value).
Never paste a key into the app, chat, or GitHub.

## Setup (about 10 minutes)
1. Pick a provider and get a key
   - **OpenAI**: https://platform.openai.com -> add billing credit -> API keys. One key covers both functions. Handles English, Hindi and mixed speech.
   - **Google Cloud**: create a project, enable **Speech-to-Text API** and **Text-to-Speech API**, create an API key (restrict it to those two APIs). Needs billing enabled.
2. In Supabase -> Edge Functions -> **Deploy a new function -> Via Editor**:
   - name `voice-stt`, paste `voice-stt/index.ts`, Deploy (keep **Verify JWT** ON)
   - name `voice-tts`, paste `voice-tts/index.ts`, Deploy (keep **Verify JWT** ON)
3. Add the secrets from the table above.
4. Open the app, sign in, tap **Ask PharmaSaathi -> microphone**. You'll be asked once to allow online voice.

## How the fallbacks work
- Voice input: online speech-to-text -> browser speech recognition -> typing / buttons.
- Voice output: online text-to-speech -> browser voice -> the reply stays on screen as text.
- If online voice fails or is rate-limited, the app pauses it for a minute and uses the next option. It never blocks typing.
- Sample-data mode (not signed in) never uses online voice.

## What is sent to the voice provider
Only the microphone recording (speech-to-text) or the short reply text (text-to-speech). Never the
medical record. PharmaSaathi stores no recordings. The privacy notice in the app says this.

## Notes and limits
- Each recording is one request after the person finishes speaking (auto-stops on silence, max 15 s). Reply audio is cached in the browser so repeated phrases cost nothing.
- Any signed-in user can trigger these calls, so set a **monthly spend limit** with the provider, and add per-user daily limits before a public launch.
- Google speech-to-text can't read Safari's `audio/mp4` recordings (the app then falls back to browser speech recognition / typing); OpenAI accepts them.
- The assistant is rule-based on the patient's own data. It never diagnoses, changes doses, or calls a medicine safe.
