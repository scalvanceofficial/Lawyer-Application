const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { assertAccountActive } = require('./account-lifecycle');

const keyId = defineSecret('RAZORPAY_KEY_ID');
const keySecret = defineSecret('RAZORPAY_KEY_SECRET');
const PLATFORM_FEE = 149;

// Clients can no longer mark a case paid themselves: this function confirms the
// payment with Razorpay before activating the case.
exports.verifyCasePayment = onCall({
  region: 'asia-south1', secrets: [keyId, keySecret],
}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  const uid = request.auth.uid;
  await assertAccountActive(uid);
  const { paymentId, caseId } = request.data || {};
  if (typeof paymentId !== 'string' || !/^pay_[a-zA-Z0-9]+$/.test(paymentId) ||
      typeof caseId !== 'string' || !caseId || caseId.includes('/')) {
    throw new HttpsError('invalid-argument', 'Invalid payment details.');
  }
  const db = getFirestore();
  const caseRef = db.collection('cases').doc(caseId);
  const caseDoc = await caseRef.get();
  if (!caseDoc.exists || caseDoc.data().clientId !== uid) {
    throw new HttpsError('not-found', 'Case no longer exists.');
  }
  const accepted = await db.collection('consultationRequests')
    .where('caseId', '==', caseId).get();
  if (!accepted.docs.some((d) => d.data().clientId === uid && d.data().status === 'accepted')) {
    throw new HttpsError('failed-precondition',
      'Payment is available after at least one advocate accepts this case.');
  }

  const response = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}`, {
    headers: { Authorization: `Basic ${Buffer.from(`${keyId.value()}:${keySecret.value()}`).toString('base64')}` },
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new HttpsError('unavailable', 'Payment verification failed. Please retry.');
  const payment = await response.json();
  if (payment.status !== 'captured' || payment.amount !== PLATFORM_FEE * 100 ||
      payment.currency !== 'INR' || payment.amount_refunded > 0 ||
      payment.notes?.user_id !== uid || payment.notes?.purpose !== 'case_activation' ||
      payment.notes?.reference_id !== caseId) {
    throw new HttpsError('failed-precondition', 'This payment cannot activate this case.');
  }

  return db.runTransaction(async (tx) => {
    await assertAccountActive(uid, tx);
    const paymentRef = db.collection('casePayments').doc(paymentId);
    const [current, used] = await Promise.all([tx.get(caseRef), tx.get(paymentRef)]);
    if (!current.exists || current.data().clientId !== uid) {
      throw new HttpsError('not-found', 'Case no longer exists.');
    }
    if (used.exists) {
      if (used.data().caseId !== caseId || used.data().clientId !== uid) {
        throw new HttpsError('permission-denied', 'This payment has already been used.');
      }
      return { activated: true };
    }
    const data = current.data();
    if (data.paymentStatus === 'paid' && data.isActive === true) return { activated: true };
    tx.create(paymentRef, {
      paymentId, caseId, clientId: uid, amount: PLATFORM_FEE,
      amountPaise: PLATFORM_FEE * 100, currency: 'INR', status: 'success',
      paidAt: FieldValue.serverTimestamp(),
    });
    tx.update(caseRef, {
      paymentStatus: 'paid', status: 'active', isActive: true,
      casePaymentId: paymentId, activatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(db.collection('caseTimeline').doc(), {
      caseId, clientId: uid, actorId: uid, type: 'payment_successful',
      message: `₹${PLATFORM_FEE} platform fee paid — case activated`,
      createdAt: FieldValue.serverTimestamp(),
    });
    return { activated: true };
  });
});
