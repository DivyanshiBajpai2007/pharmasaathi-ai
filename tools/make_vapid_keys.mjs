// Makes the key pair that lets the server send reminders to phones (Web Push / VAPID).
// Run it on YOUR computer:   node tools/make_vapid_keys.mjs
// - The PUBLIC key is printed (safe to share; it goes into the app and into the VAPID_PUBLIC_KEY secret).
// - The PRIVATE key is NOT printed. It is copied to your clipboard so you can paste it straight into
//   Supabase -> Edge Functions -> Secrets as VAPID_PRIVATE_KEY. Never paste it in a chat, message or screenshot.
import { generateKeyPairSync } from 'node:crypto';
import { spawnSync } from 'node:child_process';

const { publicKey, privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const pub = publicKey.export({ format: 'jwk' });
const priv = privateKey.export({ format: 'jwk' });
const b64u = (s) => Buffer.from(s, 'base64url');
const publicText = Buffer.concat([Buffer.from([4]), b64u(pub.x), b64u(pub.y)]).toString('base64url');

let copied = false;
if (process.platform === 'win32') copied = spawnSync('clip', { input: priv.d }).status === 0;
else if (process.platform === 'darwin') copied = spawnSync('pbcopy', { input: priv.d }).status === 0;

console.log('');
console.log('VAPID_PUBLIC_KEY  (safe to share):');
console.log(publicText);
console.log('');
if (copied) {
  console.log('The PRIVATE key is on your clipboard (not shown). Paste it now into Supabase -> Secrets -> VAPID_PRIVATE_KEY.');
} else {
  console.log('Could not use the clipboard. The private key is written to vapid_private_key.txt next to this file;');
  console.log('copy it into Supabase Secrets, then DELETE that file.');
  import('node:fs').then((fs) => fs.writeFileSync(new URL('./vapid_private_key.txt', import.meta.url), priv.d));
}
console.log('');
