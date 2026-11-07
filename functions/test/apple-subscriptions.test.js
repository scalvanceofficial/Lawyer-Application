const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { SignedDataVerifier, Environment } = require('@apple/app-store-server-library');
const { entitlementFor, summarize } = require('../apple-subscription-state');

const now = Date.now();
const token = '12345678-1234-4123-8123-123456789abc';
const base = {
  type: 'Auto-Renewable Subscription', inAppOwnershipType: 'PURCHASED',
  productId: 'app.monthly', transactionId: '12345', originalTransactionId: '12345',
  appAccountToken: token, expiresDate: now + 60000, signedDate: now,
};

test('only active and grace-period subscriptions grant access', () => {
  assert.equal(entitlementFor(base, null, 1, now).active, true);
  for (const status of [2, 3, 5, undefined]) {
    assert.equal(entitlementFor(base, null, status, now).active, false);
  }
  const grace = entitlementFor({ ...base, expiresDate: now - 1 },
    { gracePeriodExpiresDate: now + 10000 }, 4, now);
  assert.equal(grace.active, true);
  assert.equal(grace.endMillis, now + 10000);
  assert.equal(entitlementFor(base, null, 4, now).active, false);
});

test('refunds, upgrades, shared purchases, and expiry revoke access', () => {
  for (const override of [
    { revocationDate: now }, { isUpgraded: true },
    { inAppOwnershipType: 'FAMILY_SHARED' }, { type: 'Consumable' },
    { expiresDate: now }, { expiresDate: undefined },
  ]) assert.equal(entitlementFor({ ...base, ...override }, null, 1, now).active, false);
});

test('aggregation preserves a second valid subscription and ignores expired chains', () => {
  const valid = { active: true, endMillis: now + 5000 };
  assert.equal(summarize({ refunded: { active: false, endMillis: now + 10000 }, valid }, now), valid);
  assert.equal(summarize({ expired: { active: true, endMillis: now - 1 } }, now), null);
});

test('the real Apple verifier rejects an unsigned transaction', async () => {
  const verifier = new SignedDataVerifier([
    fs.readFileSync(path.join(__dirname, '../certs/AppleRootCA-G3.cer')),
  ], false, Environment.SANDBOX, 'com.aapkelawyer.app');
  const fake = `${Buffer.from('{"alg":"none"}').toString('base64url')}.${Buffer.from(JSON.stringify(base)).toString('base64url')}.`;
  await assert.rejects(verifier.verifyAndDecodeTransaction(fake));
  await assert.rejects(verifier.verifyAndDecodeNotification(fake));
});

// Exercise the actual callable/notification handlers with external Apple and
// Firestore I/O replaced. Cryptographic rejection is tested above using Apple SDK.
function harness({ transaction = base, status = 1, productionError, renewal = {}, notify } = {}) {
  const records = new Map([
    ['applePurchaseAccounts/user1', { appAccountToken: token }],
    [`applePurchaseTokens/${token}`, { uid: 'user1' }],
  ]);
  const environments = [];
  let lookups = 0;
  const snapshot = (key) => ({ exists: records.has(key), data: () => records.get(key) });
  const db = {
    collection: (collection) => ({
      doc: (id) => ({ key: `${collection}/${id}`, get: async () => snapshot(`${collection}/${id}`) }),
      get: async () => ({ docs: [{ data: () => ({ appleProductId: 'app.monthly' }) }] }),
    }),
    runTransaction: async (fn) => fn({
      get: async (ref) => snapshot(ref.key),
      set: (ref, data) => records.set(ref.key, data),
      create: (ref, data) => { assert.equal(records.has(ref.key), false); records.set(ref.key, data); },
    }),
  };
  class FakeClient {
    constructor(_key, _id, _issuer, _bundle, environment) { this.environment = environment; }
    async getTransactionInfo() {
      lookups++;
      environments.push(this.environment);
      if (this.environment === Environment.PRODUCTION && productionError) throw productionError;
      return { signedTransactionInfo: 'transaction' };
    }
    async getAllSubscriptionStatuses() {
      return { data: [{ lastTransactions: [{ signedTransactionInfo: 'transaction', signedRenewalInfo: 'renewal', status }] }] };
    }
  }
  class FakeVerifier {
    async verifyAndDecodeTransaction() { return transaction; }
    async verifyAndDecodeRenewalInfo() { return renewal; }
    async verifyAndDecodeNotification(payload) {
      if (payload !== 'valid') throw new Error('Invalid signature');
      return notify || { notificationType: 'DID_RENEW', data: { signedTransactionInfo: 'transaction' } };
    }
  }
  class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
  const mocks = {
    './account-lifecycle': { assertAccountActive: async (uid, tx) => {
      const ref = db.collection('accountDeletionJobs').doc(uid);
      const job = tx ? await tx.get(ref) : await ref.get();
      if (job.exists) throw new HttpsError('failed-precondition', 'Account deletion in progress');
    } },
    'firebase-functions/v2/https': { onCall: (_options, fn) => fn, onRequest: (_options, fn) => fn, HttpsError },
    'firebase-functions/params': {
      defineSecret: () => ({ value: () => 'test-key' }),
      defineString: () => ({ value: () => '123' }),
    },
    'firebase-admin/firestore': {
      getFirestore: () => db, FieldValue: { serverTimestamp: () => now },
      Timestamp: { fromMillis: (value) => ({ toMillis: () => value }) },
    },
    'firebase-functions': { logger: { error() {}, warn() {} } },
    '@apple/app-store-server-library': {
      AppStoreServerAPIClient: FakeClient, SignedDataVerifier: FakeVerifier, Environment,
    },
  };
  const module = { exports: {} };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../apple-subscriptions.js'), 'utf8'), {
    exports: module.exports, module, __dirname: path.join(__dirname, '..'),
    require: (name) => mocks[name] || require(name.startsWith('./') ? `../${name.slice(2)}` : name),
  });
  return { ...module.exports, records, environments, lookups: () => lookups };
}

const request = { auth: { uid: 'user1' }, data: { transactionId: '12345' } };

test('callable requires authentication and a valid transaction ID', async () => {
  const app = harness();
  await assert.rejects(app.verifyApplePurchase({ data: request.data }), { code: 'unauthenticated' });
  await assert.rejects(app.verifyApplePurchase({ ...request, data: { transactionId: '../x' } }), { code: 'invalid-argument' });
  assert.equal(app.lookups(), 0);
});

test('purchase cannot be assigned to another Firebase account', async () => {
  const app = harness({ transaction: { ...base, appAccountToken: 'another-user-token' } });
  await assert.rejects(app.verifyApplePurchase(request), { code: 'permission-denied' });
  assert.equal(app.records.has('appleSubscriptions/user1'), false);
});

test('unconfigured Apple products cannot grant access', async () => {
  const app = harness({ transaction: { ...base, productId: 'unknown.product' } });
  await assert.rejects(app.verifyApplePurchase(request), { code: 'failed-precondition' });
  assert.equal(app.records.has('appleSubscriptions/user1'), false);
});

test('replaying a verified purchase never extends its Apple expiry', async () => {
  const app = harness();
  const first = await app.verifyApplePurchase(request);
  const second = await app.verifyApplePurchase(request);
  assert.equal(first.endDate, base.expiresDate);
  assert.equal(second.endDate, first.endDate);
  assert.equal(Object.keys(app.records.get('appleSubscriptions/user1').chains).length, 1);
});

test('sandbox fallback happens only on explicit transaction-not-found', async () => {
  const app = harness({ productionError: { apiError: 4040010 } });
  await app.verifyApplePurchase(request);
  assert.deepEqual(app.environments, [Environment.PRODUCTION, Environment.SANDBOX]);
  const unavailable = harness({ productionError: { apiError: 5000001 } });
  await assert.rejects(unavailable.verifyApplePurchase(request), { code: 'unavailable' });
  assert.deepEqual(unavailable.environments, [Environment.PRODUCTION]);
});

test('refund notification revokes previously active access; duplicates are safe', async () => {
  const transaction = { ...base };
  const app = harness({ transaction });
  await app.verifyApplePurchase(request);
  transaction.revocationDate = now;
  transaction.signedDate = now + 10;
  const codes = [];
  const res = { sendStatus: (code) => codes.push(code) };
  await app.appleSubscriptionNotifications({ method: 'POST', body: { signedPayload: 'valid' } }, res);
  await app.appleSubscriptionNotifications({ method: 'POST', body: { signedPayload: 'valid' } }, res);
  assert.deepEqual(codes, [200, 200]);
  assert.equal(app.records.get('appleSubscriptions/user1').status, 'inactive');
});

test('unsigned notifications do not call Apple or modify access', async () => {
  const app = harness();
  let status;
  await app.appleSubscriptionNotifications({ method: 'POST', body: { signedPayload: 'forged' } },
    { sendStatus: (code) => { status = code; } });
  assert.equal(status, 400);
  assert.equal(app.lookups(), 0);
  assert.equal(app.records.has('appleSubscriptions/user1'), false);
});

test('late verification cannot overwrite a more recent revocation', async () => {
  const app = harness();
  app.records.set('appleSubscriptions/user1', { chains: {
    Production_12345: { active: false, endMillis: 0, signedDate: now + 100, renewalSignedDate: 0 },
  } });
  await app.verifyApplePurchase(request);
  assert.equal(app.records.get('appleSubscriptions/user1').status, 'inactive');
});
