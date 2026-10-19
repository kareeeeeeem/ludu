// UI smoke helper, allowed values only. Never submits a transfer or changes money.
import { readFileSync } from 'node:fs';
const number = process.argv[2];
if (!['01000000000', '01004632660'].includes(number)) throw new Error('Only the controlled UI test number or final number is allowed');
const text = readFileSync('../delivery/ADMIN_CREDENTIALS.txt', 'utf8');
const email = text.match(/^Email: (.+)$/m)?.[1];
const password = text.match(/^Password: (.+)$/m)?.[1];
if (!email || !password) throw new Error('Missing handoff Admin credentials');
const base = 'http://127.0.0.1:3107/api';
const login = await fetch(`${base}/auth/admin-login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
if (!login.ok) throw new Error('Admin login failed');
const { token } = await login.json();
const changed = await fetch(`${base}/admin/settings/payment`, { method: 'PUT', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }, body: JSON.stringify({ vodafoneCashReceivingNumber: number, reason: 'Controlled Android UI dynamic setting check' }) });
if (!changed.ok) throw new Error(`Payment setting update failed: ${changed.status}`);
console.log(`Admin changed receiving number to ${number}; no APK rebuild occurred.`);
