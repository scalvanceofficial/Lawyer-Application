const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createAccountEraser } = require('../account-deletion-core');

function fixture(extra = {}) {
  const records = new Map(Object.entries({
    'users/deleting': { uid: 'deleting', token: 'private-token' },
    'lawyers/other': { uid: 'other', ratingSum: 9, reviewCount: 2, rating: 4.5 },
    'cases/owned': { clientId: 'deleting' },
    'cases/foreign': { clientId: 'other', description: 'Keep this client case' },
    'consultationRequests/owned_other': { caseId: 'owned', clientId: 'deleting', lawyerId: 'other' },
    'consultationRequests/foreign_deleting': { caseId: 'foreign', clientId: 'other', lawyerId: 'deleting', lawyerName: 'Departing Lawyer' },
    'caseChats/owned_other/messages/m': { senderId: 'deleting', message: 'private' },
    'caseChats/foreign_deleting': { clientId: 'other', lawyerId: 'deleting' },
    'caseChats/foreign_deleting/messages/m': { senderId: 'other', message: 'shared private' },
    'caseTimeline/foreignEvent': { caseId: 'foreign', actorId: 'other', message: 'Request sent to Departing Lawyer' },
    'caseTimeline/unrelated': { caseId: 'foreign', actorId: 'other', message: 'Case created' },
    'caseDocuments/ownedDoc': { caseId: 'owned', clientId: 'deleting' },
    'caseDocuments/orphan': { caseId: 'missing', clientId: 'deleting', storagePath: 'case_documents/missing/orphan_file.pdf' },
    'lawyerReviews/r': { requestId: 'owned_other', caseId: 'owned', clientId: 'deleting', lawyerId: 'other', rating: 4, aggregatedAt: 1 },
    'lawyerReviews/keep': { requestId: 'unrelated', caseId: 'foreign', clientId: 'another', lawyerId: 'other', rating: 5, aggregatedAt: 1 },
    'notifications/n': { recipientId: 'other', senderId: 'deleting' },
    'support_tickets/t': { userId: 'deleting' },
    'support_ticket_messages/reply': { ticketId: 't', senderId: 'admin' },
    'support_ticket_messages/orphan': { ticketId: 'missing', senderId: 'deleting' },
    'feature_requests/foreign': { createdBy: 'other', votes: ['other', 'deleting'] },
    'feature_requests/own': { createdBy: 'deleting', votes: ['deleting'] },
    'saved_lawyers/deleting/lawyers/other': { lawyerId: 'other' },
    'saved_lawyers/other/lawyers/deleting': { lawyerId: 'deleting' },
    'saved_lawyers/other/lawyers/keep': { lawyerId: 'keep' },
    'subscriptions/deleting': { status: 'active' },
    'appleSubscriptions/deleting': { status: 'active' },
    'applePurchaseAccounts/deleting': { appAccountToken: 'token' },
    'applePurchaseTokens/token': { uid: 'deleting' },
    'payments/p': { userId: 'deleting' },
    'verifiedSubscriptionPayments/p': { userId: 'deleting' },
    ...extra,
  }));
  const files = new Set([
    'profile_pictures/deleting.jpg', 'profile_pictures/deleting-extra.jpg',
    'case_documents/owned/file.pdf', 'case_documents/owned-other/file.pdf',
    'case_documents/missing/orphan_file.pdf', 'case_documents/foreign/keep.pdf',
    'support_attachments/deleting/t/file.pdf', 'support_attachments/other/t/keep.pdf',
  ]);
  const history = [];
  let failPath;
  let authDeleted = false;
  const missingUser = () => Object.assign(new Error('missing'), { code: 'auth/user-not-found' });
  const ref = (key) => ({
    path: key, id: key.split('/').at(-1),
    get: async () => snap(key),
    delete: async () => { records.delete(key); },
    update: async (data) => {
      if (!records.has(key)) throw new Error('Missing document ' + key);
      const value = records.get(key);
      for (const [k, v] of Object.entries(data)) {
        value[k] = v?.remove ? (value[k] || []).filter(x => x !== v.remove) : v;
      }
    },
  });
  const snap = (key) => ({ id: key.split('/').at(-1), ref: ref(key), exists: records.has(key), data: () => records.get(key) });
  class Query {
    constructor(collection, group = false, filters = [], cursor, count = Infinity) {
      Object.assign(this, { collection, group, filters, cursor, count });
    }
    where(field, op, value) { return new Query(this.collection, this.group, [...this.filters, [field, op, value]], this.cursor, this.count); }
    orderBy() { return this; }
    limit(count) { return new Query(this.collection, this.group, this.filters, this.cursor, count); }
    startAfter(doc) { return new Query(this.collection, this.group, this.filters, doc.ref.path, this.count); }
    doc(id) { return ref(`${this.collection}/${id}`); }
    async get() {
      const keys = [...records.keys()].filter(key => {
        const parts = key.split('/');
        if (this.group ? parts.at(-2) !== this.collection : parts.length !== 2 || parts[0] !== this.collection) return false;
        if (this.cursor && key <= this.cursor) return false;
        return this.filters.every(([field, op, value]) => op === 'array-contains'
          ? (records.get(key)[field] || []).includes(value) : records.get(key)[field] === value);
      }).sort().slice(0, this.count);
      return { empty: !keys.length, docs: keys.map(snap) };
    }
  }
  const db = {
    collection: name => new Query(name), collectionGroup: name => new Query(name, true),
    recursiveDelete: async (target) => {
      history.push('delete:' + target.path);
      for (const key of [...records.keys()]) if (key === target.path || key.startsWith(target.path + '/')) records.delete(key);
    },
    runTransaction: async fn => fn({ get: target => target.get(), update: (target, data) => target.update(data), delete: target => target.delete() }),
  };
  const file = name => ({
    delete: async () => {
      if (failPath === name) throw Object.assign(new Error('transient storage failure'), { code: 'storage/unavailable' });
      history.push('file:' + name); files.delete(name);
    },
  });
  const bucket = { file, getFiles: async ({ prefix, maxResults }) => [[...files].filter(f => f.startsWith(prefix)).slice(0, maxResults).map(file)] };
  const auth = {
    updateUser: async () => { if (authDeleted) throw missingUser(); history.push('disabled'); },
    revokeRefreshTokens: async () => { history.push('revoked'); },
    deleteUser: async () => { if (authDeleted) throw missingUser(); authDeleted = true; history.push('authDeleted'); },
  };
  const erase = createAccountEraser({ db, bucket, auth,
    messaging: { unsubscribeFromTopic: async (tokens, topic) => {
      history.push(`unsubscribe:${tokens[0]}:${topic}`);
      return { errors: [] };
    } },
    fieldValue: { serverTimestamp: () => 1, arrayRemove: value => ({ remove: value }) },
  });
  return { erase, records, files, history, fail: name => { failPath = name; }, deleted: () => authDeleted };
}

test('deletion removes Firebase profile, owned cases, nested chats, support and payment data', async () => {
  const app = fixture();
  await app.erase('deleting');
  for (const path of [
    'users/deleting', 'cases/owned', 'caseChats/owned_other/messages/m',
    'support_tickets/t', 'support_ticket_messages/reply', 'payments/p',
    'subscriptions/deleting', 'applePurchaseAccounts/deleting', 'applePurchaseTokens/token',
    'saved_lawyers/deleting/lawyers/other', 'caseDocuments/orphan',
  ]) assert.equal(app.records.has(path), false, path);
  assert.equal(app.deleted(), true);
  assert.equal(app.history.at(-1), 'authDeleted');
  assert.deepEqual(app.history.slice(0, 2), ['disabled', 'revoked']);
  assert.ok(app.history.includes('unsubscribe:private-token:announcements'));
});

test('other clients retain their cases, unrelated history, documents, and saved lawyers', async () => {
  const app = fixture();
  await app.erase('deleting');
  assert.equal(app.records.get('cases/foreign').description, 'Keep this client case');
  assert.equal(app.records.has('caseTimeline/unrelated'), true);
  assert.equal(app.records.has('caseTimeline/foreignEvent'), false);
  assert.equal(app.records.has('consultationRequests/foreign_deleting'), false);
  assert.equal(app.records.has('caseChats/foreign_deleting/messages/m'), false);
  assert.equal(app.records.has('saved_lawyers/other/lawyers/deleting'), false);
  assert.equal(app.records.has('saved_lawyers/other/lawyers/keep'), true);
  assert.equal(app.files.has('case_documents/foreign/keep.pdf'), true);
  assert.deepEqual(app.records.get('feature_requests/foreign').votes, ['other']);
});

test('reviews are removed without leaving incorrect lawyer aggregates', async () => {
  const app = fixture();
  await app.erase('deleting');
  const lawyer = app.records.get('lawyers/other');
  assert.equal(lawyer.rating, 5);
  assert.equal(lawyer.reviewCount, 1);
  assert.equal(lawyer.ratingSum, 5);
  assert.equal(app.records.has('lawyerReviews/keep'), true);
});

test('storage prefixes cannot erase similarly named users or cases', async () => {
  const app = fixture();
  await app.erase('deleting');
  assert.equal(app.files.has('profile_pictures/deleting.jpg'), false);
  assert.equal(app.files.has('profile_pictures/deleting-extra.jpg'), true);
  assert.equal(app.files.has('case_documents/owned/file.pdf'), false);
  assert.equal(app.files.has('case_documents/owned-other/file.pdf'), true);
  assert.equal(app.files.has('case_documents/missing/orphan_file.pdf'), false);
  assert.equal(app.files.has('support_attachments/other/t/keep.pdf'), true);
});

test('failed cleanup retains authentication and can retry without double-decrementing ratings', async () => {
  const app = fixture();
  app.fail('case_documents/owned/file.pdf');
  await assert.rejects(app.erase('deleting'));
  assert.equal(app.deleted(), false);
  assert.equal(app.records.has('cases/owned'), true, 'discoverable parent survives failed file cleanup');
  app.fail(null);
  await app.erase('deleting');
  assert.equal(app.deleted(), true);
  assert.equal(app.records.get('lawyers/other').reviewCount, 1);
  await app.erase('deleting');
  assert.equal(app.records.get('lawyers/other').reviewCount, 1);
});

test('queries and storage deletion process more than one page', async () => {
  const app = fixture(Object.fromEntries(Array.from({ length: 205 }, (_, i) => [`feedback/f${i}`, { userId: 'deleting' }])));
  for (let i = 0; i < 205; i++) app.files.add(`support_attachments/deleting/t/${i}.pdf`);
  await app.erase('deleting');
  assert.equal([...app.records.keys()].some(k => k.startsWith('feedback/')), false);
  assert.equal([...app.files].some(k => k.startsWith('support_attachments/deleting/')), false);
});

test('invalid account identifiers are rejected before any mutation', async () => {
  const app = fixture();
  await assert.rejects(app.erase('../other'));
  assert.deepEqual(app.history, []);
});
