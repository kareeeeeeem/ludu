import './env.js';
import mongoose from 'mongoose';
import { createApp } from './app.js';
import { models } from './models.js';
import { paymentSettings } from './settings.js';
const platformMode = process.env.PLATFORM_MODE !== 'false';
if (!platformMode && (process.env.FINANCIAL_MODE || 'manual_vodafone') !== 'manual_vodafone') throw new Error('Only manual Vodafone Cash review mode is supported');
if (process.env.NODE_ENV === 'production') {
  if (!process.env.MONGODB_URI || !process.env.JWT_SECRET || !process.env.CORS_ORIGINS) throw new Error('Missing critical production configuration');
  if (process.env.JWT_SECRET.includes('replace-with')) throw new Error('Production secrets are not configured');
  if (platformMode && (!process.env.PLATFORM_API_URL?.startsWith('https://') || process.env.PLATFORM_API_URL.includes('.invalid') ||
    !process.env.PLATFORM_API_KEY || process.env.PLATFORM_API_KEY.startsWith('replace-with') ||
    !process.env.PLATFORM_ADMIN_API_KEY || process.env.PLATFORM_ADMIN_API_KEY.startsWith('replace-with') ||
    process.env.PLATFORM_MOCK === 'true')) throw new Error('Production platform adapter is not configured');
  if (!platformMode && (!process.env.VODAFONE_CASH_RECEIVING_NUMBER || process.env.VODAFONE_CASH_RECEIVING_NUMBER.startsWith('LOCAL_DEMO_'))) throw new Error('Production receiving number is not configured');
}
await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/ludo_club?replicaSet=ludo');
await Promise.all(models.map(m => m.init()));
if (!platformMode) await paymentSettings({ vodafoneReceivingNumber: process.env.VODAFONE_CASH_RECEIVING_NUMBER });
const instance = createApp({ secret: process.env.JWT_SECRET, origins: (process.env.CORS_ORIGINS || 'http://localhost:8080').split(','), mailKey: process.env.RESEND_API_KEY, mailFrom: process.env.MAIL_FROM, vodafoneReceivingNumber: process.env.VODAFONE_CASH_RECEIVING_NUMBER, platformMode, platformMock: process.env.PLATFORM_MOCK === 'true' && process.env.NODE_ENV !== 'production', platformApiUrl: process.env.PLATFORM_API_URL, platformApiKey: process.env.PLATFORM_API_KEY, platformAdminApiKey: process.env.PLATFORM_ADMIN_API_KEY, platformCosmeticPrices: JSON.parse(process.env.PLATFORM_COSMETIC_PRICES_JSON || '{}'), platformMatchPolicy: JSON.parse(process.env.PLATFORM_MATCH_POLICY_JSON || 'null'), matchPolicyTestMode: process.env.PLATFORM_TEST_POLICY === 'true' });
const timer = setInterval(() => instance.service.tick().catch(e => console.error('Scheduler:', e.message)), 1000);
instance.http.on('error', e => { clearInterval(timer); console.error(`Cannot start API: ${e.message}`); mongoose.disconnect().finally(() => process.exit(1)); });
instance.http.listen(Number(process.env.PORT || 3107), process.env.HOST || '127.0.0.1', () => console.log(`Ludo Club API ready on port ${process.env.PORT || 3107}`));
async function close() { clearInterval(timer); instance.io.close(); instance.http.close(); await instance.service.tail; await mongoose.disconnect(); process.exit(0); }
process.on('SIGTERM', close); process.on('SIGINT', close);
