const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function harness(overrides = {}, { requests } = {}) {
  const records = new Map([
    ['cases/case1', { clientId: 'buyer', paymentStatus: 'pending', isActive: false }],
  ]);
  const consultation = requests ?? [{ caseId: 'case1', clientId: 'buyer', status: 'accepted' }];
  const payment = {
    status: 'captured', amount: 14900, currency: 'INR', amount_refunded: 0,
    notes: { user_id: 'buyer', purpose: 'case_activation', reference_id: 'case1' },
    ...overrides,
  };
  let auto = 0;
  const snap = (key) => ({ exists: records.has(key), data: () => records.get(key) });
  const db = {
    collection: (name) => ({
      doc: (id = `auto${auto++}`) => ({ key: `${name}/${id}`, get: async () => snap(`${name}/${id}`) }),
      where: (_f, _op, value) => ({
        get: async () => ({ docs: consultation.filter((r) => r.caseId === value).map((r) => ({ data: () => r })) }),
      }),
    }),
    runTransaction: async (fn) => fn({
      get: async (ref) => snap(ref.key),
      create: (ref, data) => {
        if (records.has(ref.key)) throw new Error('exists');
        records.set(ref.key, data);
      },
      update: (ref, data) => records.set(ref.key, { ...records.get(ref.key), ...data }),
    }),
  };
  class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
  const mocks = {
    './account-lifecycle': { assertAccountActive: async () => {} },
    'firebase-functions/v2/https': { onCall: (_options, fn) => fn, HttpsError },
    'firebase-functions/params': { defineSecret: () => ({ value: () => 'test' }) },
    'firebase-admin/firestore': { getFirestore: () => db, FieldValue: { serverTimestamp: () => Date.now() } },
  };
  const module = { exports: {} };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../case-payments.js'), 'utf8'), {
    exports: module.exports, module, Buffer, AbortSignal,
    require: (name) => mocks[name] || require(name),
    fetch: async () => ({ ok: true, json: async () => payment }),
  });
  return { ...module.exports, records };
}
const request = { auth: { uid: 'buyer' }, data: { paymentId: 'pay_123', caseId: 'case1' } };

test('case activation requires authentication', async () => {
  await assert.rejects(harness().verifyCasePayment({ data: request.data }), { code: 'unauthenticated' });
});

test('a verified ₹149 payment activates the case once', async () => {
  const h = harness();
  await h.verifyCasePayment(request);
  assert.equal(h.records.get('cases/case1').paymentStatus, 'paid');
  assert.equal(h.records.get('cases/case1').isActive, true);
  assert.equal(h.records.get('casePayments/pay_123').caseId, 'case1');
  await h.verifyCasePayment(request); // replay is harmless
});

test('wrong, unpaid or foreign payments cannot activate a case', async () => {
  for (const override of [
    { status: 'authorized' }, { amount: 100 }, { currency: 'USD' }, { amount_refunded: 1 },
    { notes: { user_id: 'other', purpose: 'case_activation', reference_id: 'case1' } },
    { notes: { user_id: 'buyer', purpose: 'subscription', reference_id: 'case1' } },
    { notes: { user_id: 'buyer', purpose: 'case_activation', reference_id: 'case2' } },
  ]) {
    const h = harness(override);
    await assert.rejects(h.verifyCasePayment(request), { code: 'failed-precondition' });
    assert.equal(h.records.get('cases/case1').paymentStatus, 'pending');
  }
});

test('another user cannot activate someone else\'s case', async () => {
  await assert.rejects(
    harness().verifyCasePayment({ ...request, auth: { uid: 'intruder' } }),
    { code: 'not-found' },
  );
});

test('payment requires an accepted consultation', async () => {
  await assert.rejects(harness({}, { requests: [] }).verifyCasePayment(request), { code: 'failed-precondition' });
});
