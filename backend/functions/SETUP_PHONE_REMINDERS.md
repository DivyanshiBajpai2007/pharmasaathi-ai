# Reminders that arrive when the app is closed

A web page cannot run when it is closed, so the server sends the reminder as a push notification.

1. Supabase -> SQL Editor: run `backend/push.sql` (two small tables).
2. On your computer: `node tools/make_vapid_keys.mjs` -> a PUBLIC and a PRIVATE key. The private key is a secret.
3. Supabase -> Edge Functions -> Secrets, add:
   - `CRON_SECRET`  = a long random text you make up
   - `VAPID_PUBLIC_KEY`  = the public key
   - `VAPID_PRIVATE_KEY` = the private key
   - `VAPID_SUBJECT` = `mailto:you@example.com` (optional)
4. Edge Functions -> Deploy a new function named `send-reminders`, paste `backend/functions/send-reminders/index.ts`,
   turn **Verify JWT OFF**, deploy.
5. Put the PUBLIC key into the app: `VAPID_PUBLIC_KEY = '...'` in `pharmasaathi_prototype.html`, deploy the app.
6. Supabase -> SQL Editor: run `backend/push_cron.sql` after replacing `PUT-YOUR-CRON-SECRET-HERE` with your CRON_SECRET.
7. On the phone: sign in -> Profile -> Alarm sound -> Allow notifications. Add a dose 2-3 minutes ahead, close the app, wait.

Limits: it is a notification (system sound + vibration), not a looping alarm. Android Chrome works when the app is closed;
iPhone needs the app added to the Home Screen (iOS 16.4+). Battery-saver modes can delay notifications.
