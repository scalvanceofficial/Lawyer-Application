const { randomUUID } = require('node:crypto');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { logger } = require('firebase-functions');
const {
  AppStoreServerAPIClient, SignedDataVerifier, Environment,
} = require('@apple/app-store-server-library');
const { entitlementFor, summarize } = require('./apple-subscription-state');

const privateKey = defineSecret('APPLE_IAP_PRIVATE_KEY');
const keyId = defineString('APPLE_IAP_KEY_ID');
const issuerId = defineString('APPLE_IAP_ISSUER_ID');
const appleId = defineString('APPLE_IAP_APP_ID');
const bundleId = 'com.aapkelawyer.app';
const options = { region: 'asia-south1', secrets: [privateKey], timeoutSeconds: 60 };

function requireUser(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  return request.auth.uid;
}

function apple(environment) {
  const verifier = new SignedDataVerifier(
    [readFileSync(join(__dirname, 'certs/AppleRootCA-G3.cer'))],
    true, environment, bundleId,
    environment === Environment.PRODUCTION ? Number(appleId.value()) : undefined,
  );
  const client = new AppStoreServerAPIClient(
    privateKey.value(), keyId.value(), issuerId.value(), bundleId, environment,
  );
  return { client, verifier };
}

exports.prepareApplePurchase = onCall({ region: 'asia-south1' }, async (request) => {
  const uid = requireUser(request);
  const db = getFirestore();
  const ref = db.collection('applePurchaseAccounts').doc(uid);
  return db.runTransaction(async (tx) => {
    const account = await tx.get(ref);
    if (account.exists) return { appAccountToken: account.data().appAccountToken };
    const appAccountToken = randomUUID();
    tx.create(ref, { appAccountToken, createdAt: FieldValue.serverTimestamp() });
    tx.create(db.collection('applePurchaseTokens').doc(appAccountToken), { uid });
    return { appAccountToken };
  });
});

async function configuredProducts() {
  const plans = await getFirestore().collection('plans').get();
  // Keep mappings for inactive plans so existing subscribers retain access.
  return new Set(plans.docs.map((doc) => doc.data().appleProductId).filter(Boolean));
}

async function syncSubscription(uid, transactionId, environment) {
  const db = getFirestore();
  const account = await db.collection('applePurchaseAccounts').doc(uid).get();
  if (!account.exists) throw new HttpsError('failed-precondition', 'Prepare your purchase first.');
  const token = account.data().appAccountToken;
  const { client, verifier } = apple(environment);
  // Authenticate ownership of the supplied transaction BEFORE looking up the group.
  const info = await client.getTransactionInfo(transactionId);
  const original = await verifier.verifyAndDecodeTransaction(info.signedTransactionInfo);
  if (original.appAccountToken !== token) {
    throw new HttpsError('permission-denied', 'This purchase belongs to another app account.');
  }
  const products = await configuredProducts();
  if (!products.has(original.productId)) {
    throw new HttpsError('failed-precondition', 'This subscription product is not configured.');
  }
  const response = await client.getAllSubscriptionStatuses(transactionId);
  const updates = {};
  for (const group of response.data || []) {
    for (const item of group.lastTransactions || []) {
      const transaction = await verifier.verifyAndDecodeTransaction(item.signedTransactionInfo);
      if (transaction.appAccountToken !== token || !products.has(transaction.productId)) continue;
      const renewal = item.signedRenewalInfo
        ? await verifier.verifyAndDecodeRenewalInfo(item.signedRenewalInfo) : null;
      const state = entitlementFor(transaction, renewal, item.status);
      const chainId = `${environment}_${transaction.originalTransactionId}`;
      updates[chainId] = {
        ...state,
        productId: transaction.productId,
        transactionId: transaction.transactionId,
        originalTransactionId: transaction.originalTransactionId,
        environment,
        status: item.status,
        autoRenew: renewal?.autoRenewStatus === 1,
        signedDate: Number(transaction.signedDate || 0),
        renewalSignedDate: Number(renewal?.signedDate || 0),
      };
    }
  }
  if (!Object.keys(updates).length) throw new Error('No matching subscription status returned');
  const ref = db.collection('appleSubscriptions').doc(uid);
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    const chains = { ...(existing.data()?.chains || {}) };
    for (const [id, update] of Object.entries(updates)) {
      const old = chains[id];
      // A delayed API response must not undo a newer refund/renewal update.
      if (!old || (update.signedDate >= old.signedDate &&
          update.renewalSignedDate >= (old.renewalSignedDate || 0))) chains[id] = update;
    }
    const current = summarize(chains);
    tx.set(ref, {
      userId: uid, provider: 'apple', chains,
      status: current ? 'active' : 'inactive',
      endDate: Timestamp.fromMillis(current?.endMillis || 0),
      productId: current?.productId || null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { active: !!current, endDate: current?.endMillis || null };
  });
}

async function syncInEitherEnvironment(uid, transactionId) {
  try {
    return await syncSubscription(uid, transactionId, Environment.PRODUCTION);
  } catch (error) {
    // Only Apple's explicit transaction-not-found response permits sandbox fallback.
    if (error.apiError !== 4040010) throw error;
    return syncSubscription(uid, transactionId, Environment.SANDBOX);
  }
}

exports.verifyApplePurchase = onCall(options, async (request) => {
  const uid = requireUser(request);
  const transactionId = request.data?.transactionId;
  if (typeof transactionId !== 'string' || !/^\d{1,32}$/.test(transactionId)) {
    throw new HttpsError('invalid-argument', 'A valid Apple transaction ID is required.');
  }
  try {
    return await syncInEitherEnvironment(uid, transactionId);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('Apple purchase verification failed', { code: error.apiError || error.name });
    throw new HttpsError('unavailable', 'Apple verification is unavailable. Restore purchases to retry; do not pay again.');
  }
});

exports.refreshAppleSubscription = onCall(options, async (request) => {
  const uid = requireUser(request);
  const existing = await getFirestore().collection('appleSubscriptions').doc(uid).get();
  if (!existing.exists) return { active: false };
  // Recover from missed notifications, including refunds and expired renewals.
  const chains = Object.values(existing.data().chains || {});
  for (const chain of chains) {
    await syncSubscription(uid, chain.transactionId, chain.environment);
  }
  return { refreshed: true };
});

exports.appleSubscriptionNotifications = onRequest({ ...options, invoker: 'public' }, async (req, res) => {
  if (req.method !== 'POST') return res.sendStatus(405);
  const payload = req.body?.signedPayload;
  if (typeof payload !== 'string' || payload.length > 100000) return res.sendStatus(400);
  let notification;
  let environment;
  for (const candidate of [Environment.PRODUCTION, Environment.SANDBOX]) {
    try {
      notification = await apple(candidate).verifier.verifyAndDecodeNotification(payload);
      environment = candidate;
      break;
    } catch (_) { /* Never trust an unverified payload to choose an environment. */ }
  }
  if (!notification) return res.sendStatus(400);
  if (notification.notificationType === 'TEST') return res.sendStatus(200);
  try {
    const signedTransaction = notification.data?.signedTransactionInfo;
    if (!signedTransaction) return res.sendStatus(200);
    const transaction = await apple(environment).verifier.verifyAndDecodeTransaction(signedTransaction);
    if (!/^[0-9a-f-]{36}$/i.test(transaction.appAccountToken || '')) return res.sendStatus(200);
    const owner = await getFirestore().collection('applePurchaseTokens')
      .doc(transaction.appAccountToken).get();
    if (!owner.exists) {
      logger.warn('Apple notification has no mapped app account');
      return res.sendStatus(200);
    }
    // Fetch current state instead of applying events in their delivery order.
    await syncSubscription(owner.data().uid, transaction.transactionId, environment);
    return res.sendStatus(200);
  } catch (error) {
    logger.error('Apple notification processing failed', { code: error.apiError || error.name });
    return res.sendStatus(503); // Ask Apple to retry transient failures.
  }
});
