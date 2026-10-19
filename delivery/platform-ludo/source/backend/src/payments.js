// Integration boundary for future regulated payment and payout providers.
// A provider implementation must verify signed server-to-server events before
// crediting a wallet, and must expose idempotent payout status reconciliation.
export class PaymentProvider {
  async createPayment() { throw new Error('Payment provider is not configured'); }
  async verifyWebhook() { throw new Error('Payment provider is not configured'); }
  async requestPayout() { throw new Error('Payout provider is not configured'); }
  async reconcilePayout() { throw new Error('Payout provider is not configured'); }
}

export const unavailablePaymentProvider = Object.freeze({
  status: 'BLOCKED_EXTERNAL_INTEGRATION',
  blocked: operation => ({
    error: `${operation} requires a configured and verified external provider`,
    code: 'BLOCKED_EXTERNAL_INTEGRATION',
  }),
});
