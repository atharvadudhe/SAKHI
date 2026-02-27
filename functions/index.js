const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const USERS_COLLECTION = "users";
const EMERGENCY_CONTACTS_SUBCOLLECTION = "emergencyContacts";
const SOS_ALERT_TYPE = "need_help";
const DEFAULT_RADIUS_KM = 2.0;
const MAX_MULTICAST_TOKENS = 500;

exports.sendSosPushNotifications = onDocumentCreated(
  "broadcasts/{broadcastId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const broadcast = snap.data();
    if (!broadcast || broadcast.alertType !== SOS_ALERT_TYPE) {
      return;
    }

    const senderUid = typeof broadcast.uid === "string" ? broadcast.uid : "";
    const location = broadcast.location || null;
    const latitude = location?.latitude;
    const longitude = location?.longitude;
    const radiusKm =
      typeof broadcast.radiusKm === "number"
        ? broadcast.radiusKm
        : DEFAULT_RADIUS_KM;

    if (!senderUid || typeof latitude !== "number" || typeof longitude !== "number") {
      logger.warn("SOS broadcast missing required fields", {
        broadcastId: event.params.broadcastId,
        senderUid,
      });
      return;
    }

    const senderDoc = await db.collection(USERS_COLLECTION).doc(senderUid).get();
    const sender = senderDoc.data() || {};
    const senderName = (broadcast.userName || sender.name || "Someone").toString();
    const senderPhone = (sender.phone || "").toString();

    const tokenSet = new Set();
    const recipientSet = new Set();

    // 1) Emergency contacts: match contact phone numbers with app users.
    const contactsSnap = await db
      .collection(USERS_COLLECTION)
      .doc(senderUid)
      .collection(EMERGENCY_CONTACTS_SUBCOLLECTION)
      .get();

    const normalizedContactPhones = new Set(
      contactsSnap.docs
        .map((doc) => doc.data()?.phone)
        .filter((phone) => typeof phone === "string" && phone.trim().length > 0)
        .map(normalizePhone)
        .filter((phone) => phone.length > 0)
    );

    if (normalizedContactPhones.size > 0) {
      const allUsersSnap = await db.collection(USERS_COLLECTION).get();
      for (const userDoc of allUsersSnap.docs) {
        const data = userDoc.data() || {};
        const uid = (data.uid || userDoc.id || "").toString();
        if (!uid || uid === senderUid) continue;

        const normalizedUserPhone = normalizePhone((data.phone || "").toString());
        if (!normalizedContactPhones.has(normalizedUserPhone)) continue;

        const token = (data.fcmToken || "").toString();
        if (!token) continue;

        tokenSet.add(token);
        recipientSet.add(uid);
      }
    }

    // 2) Nearby volunteers: verified + available + within radius.
    const volunteersSnap = await db
      .collection(USERS_COLLECTION)
      .where("role", "==", "volunteer")
      .get();

    for (const volunteerDoc of volunteersSnap.docs) {
      const data = volunteerDoc.data() || {};
      const uid = (data.uid || volunteerDoc.id || "").toString();
      if (!uid || uid === senderUid) continue;

      const verificationStatus = (data.verificationStatus || "").toString();
      const isAvailable = data.isAvailable === true;
      const vLoc = data.currentLocation;
      const vLat = vLoc?.latitude;
      const vLng = vLoc?.longitude;

      if (verificationStatus !== "verified" || !isAvailable) continue;
      if (typeof vLat !== "number" || typeof vLng !== "number") continue;

      const distanceKm = haversineDistanceKm(latitude, longitude, vLat, vLng);
      if (distanceKm > radiusKm) continue;

      const token = (data.fcmToken || "").toString();
      if (!token) continue;

      tokenSet.add(token);
      recipientSet.add(uid);
    }

    const tokens = Array.from(tokenSet);
    if (tokens.length === 0) {
      logger.info("No eligible recipients with FCM tokens for SOS broadcast", {
        broadcastId: event.params.broadcastId,
        senderUid,
      });
      return;
    }

    const body = senderPhone
      ? `${senderName} triggered SOS. Call ${senderPhone} or open SAKHI now.`
      : `${senderName} triggered SOS nearby. Open SAKHI now.`;

    const messageData = {
      type: "sos_alert",
      broadcastId: event.params.broadcastId,
      senderUid,
      senderName,
      latitude: String(latitude),
      longitude: String(longitude),
    };

    for (let i = 0; i < tokens.length; i += MAX_MULTICAST_TOKENS) {
      const chunk = tokens.slice(i, i + MAX_MULTICAST_TOKENS);
      const response = await messaging.sendEachForMulticast({
        tokens: chunk,
        notification: {
          title: "SOS Alert",
          body,
        },
        data: messageData,
        android: {
          priority: "high",
          notification: {
            channelId: "sakhi_sos_alerts",
            priority: "max",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              contentAvailable: true,
            },
          },
        },
      });

      logger.info("SOS push chunk sent", {
        broadcastId: event.params.broadcastId,
        chunkSize: chunk.length,
        successCount: response.successCount,
        failureCount: response.failureCount,
      });
    }

    await snap.ref.set(
      {
        pushNotification: {
          deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
          recipientCount: recipientSet.size,
          tokenCount: tokens.length,
        },
      },
      { merge: true }
    );
  }
);

function normalizePhone(phone) {
  // Keep digits only to handle formats like +91..., spaces, dashes, etc.
  return phone.replace(/\D/g, "");
}

function haversineDistanceKm(lat1, lon1, lat2, lon2) {
  const toRad = (deg) => (deg * Math.PI) / 180;
  const earthRadiusKm = 6371;

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}
