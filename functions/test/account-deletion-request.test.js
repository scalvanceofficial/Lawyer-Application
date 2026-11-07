const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');

function harness() {
  const records = new Map();
  let erased = 0, fail = false;
  const snapshot = key => ({ exists: records.has(key), data: () => records.get(key) });
  const ref = key => ({ key, get: async () => snapshot(key), update: async data => Object.assign(records.get(key), data) });
  const db = {
    collection: name => ({ doc: id => ref(`${name}/${id}`) }),
    runTransaction: async fn => fn({
      get: async target => snapshot(target.key),
      create: (target, data) => records.set(target.key, data),
      update: (target, data) => Object.assign(records.get(target.key), data),
    }),
  };
  class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
  const v1 = { region: () => ({ runWith: () => ({ auth: { user: () => ({ onDelete: fn => fn }) } }) }) };
  const mocks = {
    'firebase-functions/v2/https': { onCall: (_options, fn) => fn, HttpsError },
    'firebase-functions/v2/firestore': { onDocumentCreated: (_options, fn) => fn },
    'firebase-functions/v1': v1,
    'firebase-admin/firestore': {
      getFirestore: () => db,
      FieldValue: { serverTimestamp: () => Date.now(), increment: v => v, delete: () => null },
      Timestamp: { fromMillis: value => ({ toMillis: () => value }) },
    },
    'firebase-admin/auth': { getAuth: () => ({}) },
    'firebase-admin/storage': { getStorage: () => ({ bucket: () => ({}) }) },
    'firebase-admin/messaging': { getMessaging: () => ({}) },
    'firebase-functions': { logger: { error() {} } },
    './account-deletion-core': { createAccountEraser: () => async (_uid, phase) => {
      if (fail) throw Object.assign(new Error('temporary storage failure'), { code: 'storage/unavailable' });
      await phase('removing_sign_in'); erased++;
    } },
  };
  const module = { exports: {} };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../account-deletion.js'), 'utf8'), {
    module, exports: module.exports, require: name => mocks[name],
  });
  return { ...module.exports, records, erased: () => erased, fail: value => { fail = value; } };
}
const request = () => ({ auth: { uid: 'current', token: { auth_time: Math.floor(Date.now() / 1000) } }, data: { confirmation: 'DELETE', uid: 'victim' } });
const event = { params: { uid: 'current' }, id: 'event1' };

test('only the authenticated account can be queued, ignoring a supplied victim UID', async () => {
  const app = harness();
  await app.requestAccountDeletion(request());
  assert.equal(app.records.has('accountDeletionJobs/current'), true);
  assert.equal(app.records.has('accountDeletionJobs/victim'), false);
});

test('deletion requires authentication, explicit confirmation, and recent sign-in', async () => {
  const app = harness();
  await assert.rejects(app.requestAccountDeletion({ data: { confirmation: 'DELETE' } }), { code: 'unauthenticated' });
  const missing = request(); missing.data.confirmation = '';
  await assert.rejects(app.requestAccountDeletion(missing), { code: 'invalid-argument' });
  for (const time of [undefined, 0, Math.floor(Date.now()/1000) - 301, Math.floor(Date.now()/1000) + 100]) {
    const stale = request(); stale.auth.token.auth_time = time;
    await assert.rejects(app.requestAccountDeletion(stale), { code: 'failed-precondition' });
  }
  assert.equal(app.records.size, 0);
});

test('repeated requests reuse the same job and do not require another destructive confirmation', async () => {
  const app = harness();
  await app.requestAccountDeletion(request());
  const retry = request(); retry.auth.token.auth_time = 0; retry.data.confirmation = '';
  assert.equal((await app.requestAccountDeletion(retry)).status, 'queued');
  assert.equal(app.records.size, 1);
});

test('completion is recorded only after successful cleanup, and duplicate events do nothing', async () => {
  const app = harness();
  await app.requestAccountDeletion(request());
  await app.processAccountDeletion(event);
  assert.equal(app.records.get('accountDeletionJobs/current').status, 'completed');
  await app.processAccountDeletion(event);
  assert.equal(app.erased(), 1);
});

test('failed cleanup records retrying and retries the existing job', async () => {
  const app = harness();
  await app.requestAccountDeletion(request());
  app.fail(true);
  await assert.rejects(app.processAccountDeletion(event));
  assert.equal(app.records.get('accountDeletionJobs/current').status, 'retrying');
  assert.equal(app.erased(), 0);
  app.fail(false);
  await app.processAccountDeletion(event);
  assert.equal(app.records.get('accountDeletionJobs/current').status, 'completed');
});

test('a second worker cannot acquire an unexpired lease', async () => {
  const app = harness();
  await app.requestAccountDeletion(request());
  app.records.get('accountDeletionJobs/current').leaseUntil = { toMillis: () => Date.now() + 60000 };
  await assert.rejects(app.processAccountDeletion(event));
  assert.equal(app.erased(), 0);
});

test('Firebase Auth console deletion queues cleanup without creating duplicate jobs', async () => {
  const app = harness();
  await app.cleanupDeletedAuthAccount({ uid: 'current' });
  assert.equal(app.records.get('accountDeletionJobs/current').status, 'queued');
  await app.processAccountDeletion(event);
  await app.cleanupDeletedAuthAccount({ uid: 'current' });
  assert.equal(app.records.get('accountDeletionJobs/current').status, 'completed');
});
