// All operations are idempotent. Parent records are removed only after their
// children so a retried job can still discover unfinished work.
function createAccountEraser({ db, bucket, auth, fieldValue, messaging }) {
  async function each(query, handle) {
    let cursor;
    for (;;) {
      let page = query.orderBy('__name__').limit(100);
      if (cursor) page = page.startAfter(cursor);
      const result = await page.get();
      if (result.empty) return;
      for (const doc of result.docs) await handle(doc);
      cursor = result.docs.at(-1);
    }
  }

  const remove = (query) => each(query, (doc) => db.recursiveDelete(doc.ref));
  const matching = (collection, field, value) => db.collection(collection).where(field, '==', value);

  async function files(prefix) {
    for (;;) {
      const [page] = await bucket.getFiles({ prefix, maxResults: 100, autoPaginate: false });
      if (!page.length) return;
      await Promise.all(page.map((file) => file.delete({ ignoreNotFound: true })));
    }
  }

  async function review(doc) {
    await db.runTransaction(async (tx) => {
      const fresh = await tx.get(doc.ref);
      if (!fresh.exists) return;
      const data = fresh.data();
      const lawyerRef = db.collection('lawyers').doc(data.lawyerId);
      const lawyer = await tx.get(lawyerRef);
      if (data.aggregatedAt && lawyer.exists) {
        const count = Math.max(0, Number(lawyer.data().reviewCount || 0) - 1);
        const sum = Math.max(0, Number(lawyer.data().ratingSum || 0) - Number(data.rating || 0));
        tx.update(lawyerRef, {
          reviewCount: count, ratingSum: count ? sum : 0,
          rating: count ? Math.round(sum / count * 10) / 10 : 0,
          ratingUpdatedAt: fieldValue.serverTimestamp(),
        });
      }
      tx.delete(doc.ref);
    });
  }

  async function request(doc, uid) {
    const data = doc.data();
    await db.recursiveDelete(db.collection('caseChats').doc(doc.id));
    await remove(matching('notifications', 'requestId', doc.id));
    await each(matching('lawyerReviews', 'requestId', doc.id), review);
    if (data.clientId !== uid && data.caseId) {
      // Other clients keep their case and documents. Remove generated history
      // for this consultation rather than leaving the departing lawyer's name.
      await each(matching('caseTimeline', 'caseId', data.caseId), async (event) => {
        const item = event.data();
        if (item.actorId === uid || item.requestId === doc.id ||
            (data.lawyerName && String(item.message || '').includes(data.lawyerName))) {
          await event.ref.delete();
        }
      });
    }
    await db.recursiveDelete(doc.ref);
  }

  return async function erase(uid, phase = async () => {}) {
    if (typeof uid !== 'string' || !uid || uid.includes('/')) throw new Error('Invalid account identifier');
    await phase('securing_account');
    try {
      await auth.updateUser(uid, { disabled: true });
      await auth.revokeRefreshTokens(uid);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
    for (const collection of ['users', 'lawyers']) {
      const profile = await db.collection(collection).doc(uid).get();
      if (profile.exists) {
        const token = profile.data().token;
        if (token && messaging) {
          const response = await messaging.unsubscribeFromTopic([token], 'announcements');
          const unexpected = (response.errors || []).find(item => ![
            'messaging/registration-token-not-registered', 'messaging/invalid-registration-token',
            'messaging/invalid-argument',
          ].includes(item.error?.code));
          if (unexpected) throw unexpected.error;
        }
        await profile.ref.update({ accountDeleting: true, token: '' });
      }
    }

    await phase('removing_cases');
    await each(matching('cases', 'clientId', uid), async (doc) => {
      await each(matching('consultationRequests', 'caseId', doc.id), (item) => request(item, uid));
      await each(matching('lawyerReviews', 'caseId', doc.id), review);
      await remove(matching('caseChats', 'caseId', doc.id));
      for (const collection of ['caseDocuments', 'caseTimeline', 'casePayments', 'notifications']) {
        await remove(matching(collection, 'caseId', doc.id));
      }
      await files(`case_documents/${doc.id}/`);
      await db.recursiveDelete(doc.ref);
    });
    for (const field of ['clientId', 'lawyerId']) {
      await each(matching('consultationRequests', field, uid), (doc) => request(doc, uid));
      await remove(matching('caseChats', field, uid));
      await each(matching('lawyerReviews', field, uid), review);
    }

    await phase('removing_support_and_activity');
    await each(matching('support_tickets', 'userId', uid), async (doc) => {
      await remove(matching('support_ticket_messages', 'ticketId', doc.id));
      await remove(matching('notifications', 'ticketId', doc.id));
      await db.recursiveDelete(doc.ref);
    });
    const fields = {
      support_ticket_messages: ['senderId'], notifications: ['recipientId', 'senderId'],
      caseDocuments: ['clientId', 'uploadedBy'], caseTimeline: ['clientId', 'actorId'],
      casePayments: ['clientId'], payments: ['userId'], bug_reports: ['userId'],
      feedback: ['userId'], feature_requests: ['createdBy'],
      verifiedSubscriptionPayments: ['userId'],
    };
    // Remove files belonging to orphan document metadata as well as live cases.
    for (const key of ['clientId', 'uploadedBy']) {
      await each(matching('caseDocuments', key, uid), async (doc) => {
        const data = doc.data();
        const prefix = `case_documents/${data.caseId}/${doc.id}_`;
        if (typeof data.caseId === 'string' && !data.caseId.includes('/') &&
            typeof data.storagePath === 'string' && data.storagePath.startsWith(prefix)) {
          await bucket.file(data.storagePath).delete({ ignoreNotFound: true });
        }
        await db.recursiveDelete(doc.ref);
      });
    }
    for (const [collection, keys] of Object.entries(fields)) {
      for (const key of keys) await remove(matching(collection, key, uid));
    }
    await each(db.collection('feature_requests').where('votes', 'array-contains', uid),
      (doc) => doc.ref.update({ votes: fieldValue.arrayRemove(uid) }));
    await each(db.collectionGroup('lawyers').where('lawyerId', '==', uid), async (doc) => {
      // Restrict collection-group cleanup to the app's known saved-lawyer path.
      if (/^saved_lawyers\/[^/]+\/lawyers\/[^/]+$/.test(doc.ref.path)) await doc.ref.delete();
    });
    await db.recursiveDelete(db.collection('saved_lawyers').doc(uid));

    await phase('removing_files_and_subscriptions');
    await bucket.file(`profile_pictures/${uid}.jpg`).delete({ ignoreNotFound: true });
    await files(`profile_pictures/${uid}/`);
    await files(`support_attachments/${uid}/`);
    // Query token ownership too: a previous attempt may already have removed
    // the account mapping before failing to remove another token record.
    await remove(matching('applePurchaseTokens', 'uid', uid));
    for (const collection of ['subscriptions', 'appleSubscriptions', 'applePurchaseAccounts']) {
      await db.recursiveDelete(db.collection(collection).doc(uid));
    }

    await phase('removing_profile');
    for (const collection of ['users', 'lawyers']) {
      await remove(matching(collection, 'uid', uid));
      await db.recursiveDelete(db.collection(collection).doc(uid));
    }
    await phase('removing_sign_in');
    try {
      await auth.deleteUser(uid);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
  };
}

module.exports = { createAccountEraser };
