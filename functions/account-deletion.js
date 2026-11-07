const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { getStorage } = require('firebase-admin/storage');
const { getMessaging } = require('firebase-admin/messaging');
const { logger } = require('firebase-functions');
const { createAccountEraser } = require('./account-deletion-core');

exports.requestAccountDeletion = onCall({ region: 'asia-south1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  const uid = request.auth.uid; // Never accept a target UID from the client.
  const db = getFirestore();
  const ref = db.collection('accountDeletionJobs').doc(uid);
  return db.runTransaction(async (tx) => {
    const previous = await tx.get(ref);
    if (previous.exists) return { status: previous.data().status };
    if (request.data?.confirmation !== 'DELETE') {
      throw new HttpsError('invalid-argument', 'Confirm permanent account deletion.');
    }
    const authTime = Number(request.auth.token.auth_time);
    const age = Date.now() / 1000 - authTime;
    if (!Number.isFinite(age) || age < -60 || age > 300) {
      throw new HttpsError('failed-precondition', 'Verify your password again before deleting your account.');
    }
    tx.create(ref, {
      status: 'queued', phase: 'queued', attempts: 0,
      requestedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    return { status: 'queued' };
  });
});

exports.processAccountDeletion = onDocumentCreated({
  document: 'accountDeletionJobs/{uid}', region: 'asia-south1',
  retry: true, timeoutSeconds: 540, memory: '512MiB', concurrency: 1,
}, async (event) => {
  const db = getFirestore();
  const uid = event.params.uid;
  const ref = db.collection('accountDeletionJobs').doc(uid);
  const runId = event.id;
  const acquired = await db.runTransaction(async (tx) => {
    const job = await tx.get(ref);
    if (!job.exists || job.data().status === 'completed') return false;
    if (job.data().leaseUntil?.toMillis() > Date.now()) {
      throw new Error('Deletion worker already running; retry after its lease');
    }
    tx.update(ref, {
      status: 'processing', runId, attempts: FieldValue.increment(1),
      leaseUntil: Timestamp.fromMillis(Date.now() + 10 * 60 * 1000),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
  if (!acquired) return;
  const phase = (value) => ref.update({ phase: value, updatedAt: FieldValue.serverTimestamp() });
  try {
    const erase = createAccountEraser({
      db, auth: getAuth(), fieldValue: FieldValue,
      messaging: getMessaging(),
      bucket: getStorage().bucket('lawyer-417809.firebasestorage.app'),
    });
    await erase(uid, phase);
    await ref.update({
      status: 'completed', phase: 'completed', leaseUntil: FieldValue.delete(),
      errorCode: FieldValue.delete(), completedAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000),
      updatedAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.error('Account deletion will retry', { code: String(error.code || 'cleanup-failed') });
    await ref.update({
      status: 'retrying', leaseUntil: FieldValue.delete(),
      errorCode: String(error.code || 'cleanup-failed'), updatedAt: FieldValue.serverTimestamp(),
    });
    throw error;
  }
});

// Console/Admin SDK deletions also queue cleanup. deleteUser at the end of the
// normal job does not create a second job because this record already exists.
exports.cleanupDeletedAuthAccount = require('firebase-functions/v1')
  .region('asia-south1').runWith({ failurePolicy: true }).auth.user().onDelete(async (user) => {
    const ref = getFirestore().collection('accountDeletionJobs').doc(user.uid);
    await getFirestore().runTransaction(async (tx) => {
      if ((await tx.get(ref)).exists) return;
      tx.create(ref, {
        status: 'queued', phase: 'queued', attempts: 0,
        requestedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      });
    });
  });
