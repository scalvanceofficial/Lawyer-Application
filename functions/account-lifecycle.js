const { getFirestore } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');

async function assertAccountActive(uid, tx) {
  const ref = getFirestore().collection('accountDeletionJobs').doc(uid);
  const job = tx ? await tx.get(ref) : await ref.get();
  if (job.exists) throw new HttpsError('failed-precondition', 'This account is being permanently deleted.');
}

async function setActiveNotification(ref, data) {
  const db = getFirestore();
  return db.runTransaction(async (tx) => {
    const ids = [...new Set([data.senderId, data.recipientId].filter(Boolean))];
    const jobs = await Promise.all(ids.map((uid) => tx.get(db.collection('accountDeletionJobs').doc(uid))));
    if (jobs.some((job) => job.exists)) return;
    tx.set(ref, data);
  });
}

module.exports = { assertAccountActive, setActiveNotification };
