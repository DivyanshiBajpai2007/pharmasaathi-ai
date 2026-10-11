# AI prescription review + pharmacist verification (optional)

After a scan, the app shows a **Prescription review (draft)** card:
1. The person picks who the prescription is for: **child (under 12), adult, or older adult (65+)**.
2. **PharmaSaathi's own checks** run instantly, with no AI: dose limits, interactions, duplicate medicines,
   doubtful names, and a note that children's doses depend on weight.
3. An **AI draft review** (optional) adds: what medicines like these are commonly used for, whether each name
   looks correctly read, whether each dose is unusual for that age group, and questions for the pharmacist.
4. If anything is found -> "Please have a pharmacist verify this before you take these medicines", a
   Call-a-pharmacist button, and **Send to a pharmacist for verification** (saved in your database).
5. Adding the medicines asks for confirmation while points are still open.

The AI never diagnoses, never says why the patient is ill, never says a medicine is "safe", and never tells
anyone to change a dose. Its "nothing found" is shown as "NOT a safety guarantee".

## What is sent to the AI
Only medicine names, strengths, amounts, times per day, durations and the age group. No name, ID, photo or
other personal data. "Send to a pharmacist" saves the medicines, age group and findings in the patient's own
account (visible to them and to pharmacists you authorise).

## Setup (two parts, both optional and independent)

### A. AI draft review (Supabase function) — about 3 minutes
1. Supabase -> Edge Functions -> **Deploy a new function -> Via Editor**.
2. Name it exactly `prescription-review`.
3. Paste `backend/functions/prescription-review/index.ts`, **Deploy** (keep Verify JWT ON).
4. No new secret is needed: it reuses your existing `PhotoKey` or `dosecheck` secret. To give it its own key,
   add a secret named `ReviewKey` (or `REVIEW_GEMINI_API_KEY` / `REVIEW_ANTHROPIC_API_KEY`).
Without this, the card still shows PharmaSaathi's own checks and says the AI review is off.

### B. Pharmacist queue (database) — about 2 minutes
1. Supabase -> SQL Editor -> New query.
2. Paste all of `backend/pharmacist_reviews.sql` and click **Run**. It only adds two new tables.
3. To let a person answer reviews, add them as a pharmacist (run once, with their user id from
   Authentication -> Users): `insert into pharmacists (user_id) values ('<uuid>');`
4. Until a pharmacist portal exists, open **Table Editor -> pharmacist_reviews**, and for each pending row set
   `status` (verified / changed / rejected) and `pharmacist_note`. The patient sees it after tapping
   "Check status" in the app.

## Limits — please read
- This is a DRAFT to help a pharmacist. A real pharmacist/doctor must verify before anyone relies on it.
- The AI can be wrong in both directions; the dose ranges it uses are its own knowledge, not a verified
  database. Age-specific dosing (especially children, by weight) is not something this app can decide.
- There is no pharmacist portal yet, only the queue table. A portal, notifications, and pharmacist
  licence/identity checks are still to be built before public launch, together with legal review.
