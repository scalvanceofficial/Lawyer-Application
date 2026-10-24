const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function harness(overrides = {}) {
  const records = new Map([
    ['plans/monthly', { active: true, price: 100, months: 1, id: 1, duration: '1 month', features: [] }],
  ]);
  const payment = {
    status: 'captured', amount: 10000, currency: 'INR', amount_refunded: 0,
    notes: { user_id: 'buyer', purpose: 'subscription', reference_id: 'monthly' },
    ...overrides,
  };
  const snap = (key) => ({ exists: records.has(key), data: () => records.get(key) });
  const db = {
    collection: (name) => ({ doc: (id) => ({ key: `${name}/${id}`, get: async () => snap(`${name}/${id}`) }) }),
    runTransaction: async (fn) => fn({
      get: async (ref) => snap(ref.key),
      set: (ref, data) => records.set(ref.key, data),
      create: (ref, data) => records.set(ref.key, data),
    }),
  };
  class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
  const mocks = {
    'firebase-functions/v2/https': { onCall: (_options, fn) => fn, HttpsError },
    'firebase-functions/params': { defineSecret: () => ({ value: () => 'test' }) },
    'firebase-admin/firestore': {
      getFirestore: () => db, FieldValue: { serverTimestamp: () => Date.now() },
      Timestamp: {
        fromMillis: (v) => ({ toMillis: () => v }),
        fromDate: (v) => ({ toMillis: () => v.getTime() }),
      },
    },
  };
  const module = { exports: {} };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../razorpay-subscriptions.js'), 'utf8'), {
    exports: module.exports, module, Buffer, AbortSignal,
    require: (name) => mocks[name] || require(name),
    fetch: async () => ({ ok: true, json: async () => payment }),
  });
  return { ...module.exports, records };
}
const request = { auth: { uid: 'buyer' }, data: { paymentId: 'pay_123', planDocumentId: 'monthly', role: 'client' } };

test('Razorpay activation requires authentication', async () => {
  await assert.rejects(harness().verifyRazorpaySubscription({ data: request.data }), { code: 'unauthenticated' });
});

test('only captured payments bound to the correct price, user, and plan grant access', async () => {
  for (const override of [
    { status: 'authorized' }, { amount: 100 }, { currency: 'USD' }, { amount_refunded: 1 },
    { notes: { user_id: 'other', purpose: 'subscription', reference_id: 'monthly' } },
    { notes: { user_id: 'buyer', purpose: 'subscription', reference_id: 'yearly' } },
    { notes: { user_id: 'buyer', purpose: 'case_activation', reference_id: 'monthly' } },
  ]) {
    const app = harness(override);
    await assert.rejects(app.verifyRazorpaySubscription(request), { code: 'failed-precondition' });
    assert.equal(app.records.has('subscriptions/buyer'), false);
  }
});

test('replaying a Razorpay payment does not stack an additional month', async () => {
  const app = harness();
  const first = await app.verifyRazorpaySubscription(request);
  const replay = await app.verifyRazorpaySubscription(request);
  assert.equal(first.endDate, replay.endDate);
  assert.equal(app.records.get('verifiedSubscriptionPayments/pay_123').userId, 'buyer');
});

test('Android renewal adds time after existing access and clamps the calendar date', async () => {
  const app = harness();
  const end = new Date('2027-01-31T00:00:00Z').getTime();
  app.records.set('subscriptions/buyer', { endDate: { toMillis: () => end } });
  const result = await app.verifyRazorpaySubscription(request);
  assert.equal(new Date(result.endDate).toISOString(), '2027-02-28T00:00:00.000Z');
});
