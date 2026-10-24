const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');

const keyId = defineSecret('RAZORPAY_KEY_ID');
const keySecret = defineSecret('RAZORPAY_KEY_SECRET');

function addMonths(date, months) {
  const result = new Date(date);
  const day = result.getUTCDate();
  result.setUTCDate(1);
  result.setUTCMonth(result.getUTCMonth() + months);
  const last = new Date(Date.UTC(result.getUTCFullYear(), result.getUTCMonth() + 1, 0)).getUTCDate();
  result.setUTCDate(Math.min(day, last));
  return result;
}

exports.verifyRazorpaySubscription = onCall({
  region: 'asia-south1', secrets: [keyId, keySecret],
}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  const uid = request.auth.uid;
  const { paymentId, planDocumentId, role } = request.data || {};
  if (typeof paymentId !== 'string' || !/^pay_[a-zA-Z0-9]+$/.test(paymentId) ||
      typeof planDocumentId !== 'string' || !planDocumentId || planDocumentId.includes('/') ||
      !['client', 'lawyer'].includes(role)) {
    throw new HttpsError('invalid-argument', 'Invalid payment details.');
  }
  const db = getFirestore();
  const planDoc = await db.collection('plans').doc(planDocumentId).get();
  const plan = planDoc.data();
  const price = Number(plan?.price ?? plan?.Price);
  const duration = String(plan?.duration ?? plan?.Duration ?? '');
  const months = Number(plan?.months ?? plan?.Months ?? duration.match(/\d+/)?.[0]);
  if (!plan || plan.active === false || plan.Active === false || !(price > 0) ||
      !Number.isInteger(months) || months < 1 || months > 120) {
    throw new HttpsError('failed-precondition', 'This plan is unavailable.');
  }
  const response = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}`, {
    headers: { Authorization: `Basic ${Buffer.from(`${keyId.value()}:${keySecret.value()}`).toString('base64')}` },
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new HttpsError('unavailable', 'Payment verification failed. Please retry.');
  const payment = await response.json();
  if (payment.status !== 'captured' || payment.amount !== price * 100 || payment.currency !== 'INR' ||
      payment.notes?.user_id !== uid || payment.notes?.purpose !== 'subscription' ||
      payment.notes?.reference_id !== planDocumentId || payment.amount_refunded > 0) {
    throw new HttpsError('failed-precondition', 'This payment cannot activate this subscription.');
  }
  return db.runTransaction(async (tx) => {
    const usedRef = db.collection('verifiedSubscriptionPayments').doc(paymentId);
    const ref = db.collection('subscriptions').doc(uid);
    const [used, existing, lawyer] = await Promise.all([
      tx.get(usedRef), tx.get(ref), tx.get(db.collection('lawyers').doc(uid)),
    ]);
    if (used.exists) {
      if (used.data().userId !== uid) throw new HttpsError('permission-denied', 'Payment already used.');
      return { endDate: existing.data()?.endDate?.toMillis() || 0 };
    }
    const trialStart = lawyer.data()?.date ?? lawyer.data()?.createdAt;
    const trialDate = trialStart?.toDate ? trialStart.toDate() : new Date(trialStart || 0);
    const trialEnd = role === 'lawyer' && lawyer.exists && Number.isFinite(trialDate.getTime())
      ? addMonths(trialDate, 1).getTime() : 0;
    const startsAt = Math.max(Date.now(), existing.data()?.endDate?.toMillis() || 0, trialEnd);
    const endDate = addMonths(new Date(startsAt), months);
    tx.set(ref, {
      userId: uid, userType: role, provider: 'razorpay', planDocumentId,
      planId: Number(plan.id ?? plan.planId ?? 0), duration, price,
      features: plan.features ?? plan.Features ?? [], paymentId,
      status: 'active', subscriptionDate: FieldValue.serverTimestamp(),
      accessStartsAt: Timestamp.fromMillis(startsAt), endDate: Timestamp.fromDate(endDate),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(usedRef, { userId: uid, planDocumentId, verifiedAt: FieldValue.serverTimestamp() });
    return { endDate: endDate.getTime() };
  });
});
