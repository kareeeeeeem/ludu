import { AppSetting } from './models.js';

export const phonePattern = /^01[0125][0-9]{8}$/;

export async function paymentSettings(config = {}) {
  return AppSetting.findOneAndUpdate(
    { key: 'payment' },
    { $setOnInsert: { vodafoneCashReceivingNumber: config.vodafoneReceivingNumber || '' } },
    { upsert: true, new: true },
  );
}
