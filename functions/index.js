const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

Object.assign(exports, require('./apple-subscriptions'));
Object.assign(exports, require('./razorpay-subscriptions'));
Object.assign(exports, require('./case-payments'));
Object.assign(exports, require('./account-deletion'));
const { setActiveNotification, assertAccountActive } = require('./account-lifecycle');

exports.sendCaseNotification = onDocumentCreated(
  {
    document: "notifications/{notificationId}",
    region: "asia-south1",
    retry: true,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const notification = snapshot.data();
    const recipientId = notification.recipientId;
    if (!recipientId) return;

    const db = getFirestore();
    const current = await snapshot.ref.get();
    if (!current.exists) return;
    try { await assertAccountActive(recipientId); } catch (_) { return; }
    let profile = await db.collection("users").doc(recipientId).get();
    if (!profile.exists) {
      profile = await db.collection("lawyers").doc(recipientId).get();
    }
    const token = profile.data()?.token;
    if (!token) {
      await snapshot.ref.update({
        deliveryStatus: "no_token",
        deliveryUpdatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    try {
      const messageId = await getMessaging().send({
        token,
        notification: {
          title: String(notification.title || "Aapke Lawyer"),
          body: String(notification.body || "You have a case update."),
        },
        data: {
          type: String(notification.type || "case_update"),
          caseId: String(notification.caseId || ""),
          requestId: String(notification.requestId || ""),
          senderId: String(notification.senderId || ""),
          title: String(notification.title || "Aapke Lawyer"),
          body: String(notification.body || "You have a case update."),
        },
        android: {
          priority: "high",
          notification: { channelId: "important_notifications" },
        },
        apns: {
          payload: {
            aps: { sound: "default", contentAvailable: true },
          },
        },
      });
      await snapshot.ref.update({
        deliveryStatus: "sent",
        messageId,
        deliveryUpdatedAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      await snapshot.ref.update({
        deliveryStatus: "failed",
        deliveryError: String(error?.code || error?.message || error),
        deliveryUpdatedAt: FieldValue.serverTimestamp(),
      });
      throw error;
    }
  },
);

exports.notifyOnChatMessage = onDocumentCreated(
  {
    document: "caseChats/{requestId}/messages/{messageId}",
    region: "asia-south1",
    retry: true,
  },
  async (event) => {
    const message = event.data?.data();
    if (!message?.senderId || !message?.receiverId) return;
    const db = getFirestore();
    const requestId = event.params.requestId;
    const request = await db.collection("consultationRequests").doc(requestId).get();
    if (!request.exists) return;
    const data = request.data();
    if (![data.clientId, data.lawyerId].includes(message.senderId) ||
        ![data.clientId, data.lawyerId].includes(message.receiverId)) return;
    const senderName = message.senderId === data.clientId
      ? String(data.clientName || "Client")
      : String(data.lawyerName || "Lawyer");
    const text = String(message.message || "New message").trim();
    await setActiveNotification(db.collection("notifications").doc(`chat_${event.params.messageId}`), {
      recipientId: message.receiverId,
      senderId: message.senderId,
      caseId: String(data.caseId || ""),
      requestId,
      title: `New message from ${senderName}`,
      body: text.length > 120 ? `${text.slice(0, 117)}...` : text,
      type: "chat_message",
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  },
);

exports.notifyLawyersOnCasePayment = onDocumentCreated(
  {
    document: "casePayments/{paymentId}",
    region: "asia-south1",
    retry: true,
  },
  async (event) => {
    const payment = event.data?.data();
    if (!payment?.caseId || payment.status !== "success") return;
    const db = getFirestore();
    const requests = await db.collection("consultationRequests")
      .where("caseId", "==", payment.caseId)
      .get();
    for (const request of requests.docs) {
      const data = request.data();
      if (data.status !== "accepted" || !data.lawyerId) continue;
      const notification = db.collection("notifications")
        .doc(`paid_${event.params.paymentId}_${data.lawyerId}`);
      await setActiveNotification(notification, {
        recipientId: data.lawyerId,
        senderId: payment.clientId,
        caseId: payment.caseId,
        requestId: request.id,
        title: "Communication unlocked",
        body: `${data.clientName || "Your client"} paid for ${data.caseTitle || "the case"}. Chat and calls are now available.`,
        type: "case_paid",
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  },
);

// Keep directory ratings in sync with immutable consultation reviews. The
// review document is visible in real time immediately; this aggregate is used
// by lawyer cards and profiles.
exports.updateLawyerRating = onDocumentCreated(
  {
    document: "lawyerReviews/{reviewId}",
    region: "asia-south1",
    retry: true,
  },
  async (event) => {
    const review = event.data?.data();
    const lawyerId = review?.lawyerId;
    if (!lawyerId) return;

    const db = getFirestore();
    const reviewRef = event.data.ref;
    const lawyerRef = db.collection("lawyers").doc(lawyerId);
    await db.runTransaction(async (transaction) => {
      const [freshReview, lawyer] = await Promise.all([
        transaction.get(reviewRef),
        transaction.get(lawyerRef),
      ]);
      if (!freshReview.exists || !lawyer.exists || freshReview.data().aggregatedAt) return;
      const rating = Number(freshReview.data().rating);
      if (!Number.isFinite(rating) || rating < 1 || rating > 5) return;
      const oldCount = Number(lawyer.data()?.reviewCount || 0);
      const oldSum = Number(lawyer.data()?.ratingSum || 0);
      const reviewCount = oldCount + 1;
      const ratingSum = oldSum + rating;
      transaction.update(lawyerRef, {
        rating: Math.round((ratingSum / reviewCount) * 10) / 10,
        ratingSum,
        reviewCount,
        ratingUpdatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(reviewRef, {
        aggregatedAt: FieldValue.serverTimestamp(),
      });
    });
  },
);

exports.notifyOnSupportReply = onDocumentCreated(
  {
    document: "support_ticket_messages/{messageId}",
    region: "asia-south1",
    retry: true,
  },
  async (event) => {
    const message = event.data?.data();
    if (!message?.ticketId || message.senderType === "user") return;
    const db = getFirestore();
    const ticket = await db.collection("support_tickets").doc(message.ticketId).get();
    const recipientId = ticket.data()?.userId;
    if (!recipientId) return;
    await setActiveNotification(db.collection("notifications").doc(`support_${event.params.messageId}`), {
      recipientId,
      senderId: "support",
      ticketId: message.ticketId,
      title: "Support replied",
      body: String(message.message || "You have a new support reply.").slice(0, 120),
      type: "support_reply",
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  },
);

exports.notifyOnTicketStatusChange = onDocumentUpdated(
  {
    document: "support_tickets/{ticketId}",
    region: "asia-south1",
    retry: true,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after?.userId || before?.status === after.status) return;
    const labels = {
      inProgress: "is now in progress",
      waitingUser: "needs information from you",
      resolved: "has been resolved",
      closed: "has been closed",
      open: "has been reopened",
    };
    await setActiveNotification(getFirestore().collection("notifications")
      .doc(`ticket_status_${event.params.ticketId}_${after.status}`), {
        recipientId: after.userId,
        senderId: "support",
        ticketId: event.params.ticketId,
        title: "Support ticket updated",
        body: `Your ticket ${labels[after.status] || "was updated"}.`,
        type: "support_ticket_update",
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
  },
);

exports.notifyNewAnnouncement = onDocumentCreated(
  {
    document: "announcements/{announcementId}",
    region: "asia-south1",
    retry: true,
  },
  async (event) => {
    const announcement = event.data?.data();
    if (!announcement?.isActive) return;
    await getMessaging().send({
      topic: "announcements",
      notification: {
        title: String(announcement.title || "Aapke Lawyer announcement"),
        body: String(announcement.description || "There is a new announcement."),
      },
      data: { type: "announcement", announcementId: event.params.announcementId },
      android: { priority: "high", notification: { channelId: "important_notifications" } },
      apns: { payload: { aps: { sound: "default" } } },
    });
  },
);
