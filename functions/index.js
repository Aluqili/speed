const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();
const DEPLOY_MARKER_NODE22 = '2026-02-23-node22';
const REGION = 'me-central1';
const SCHEDULE_REGION = 'us-central1';

const COURIER_OFFER_TIMEOUT_SECONDS = 40;
const ASSIGNMENT_CYCLE_RESET_SECONDS = 120;
const MAX_DRIVER_RESTAURANT_DISTANCE_KM = 20;
const BOOTSTRAP_ADMIN_EMAILS = ['admin@speedstar.com', 'speedstarapp0@gmail.com'];
const PRICING_RECALC_WINDOW_MINUTES = 180;
const PRICING_RECALC_LIMIT = 250;
const PRICING_REMOTE_CACHE_MS = 60 * 1000;
const LANDING_PUBLIC_EVENTS = new Set([
  'page_view',
  'download_client_android',
  'download_store_android',
  'download_courier_android',
  'contact_phone',
  'contact_email',
  'contact_whatsapp',
  'contact_instagram',
  'contact_facebook',
  'contact_tiktok',
]);
const ENFORCE_MANUAL_PAYMENT_REVIEW = true;
const PAYMENT_REVIEW_STATUS = 'قيد المراجعة';
const PAYMENT_REJECTED_STATUS = 'مرفوض';

const DEFAULT_PRICING_CONFIG = {
  largeItemFeeEnabled: true,
  largeItemThreshold: 10000,
  largeItemFeeBase: 500,
  largeItemStepAmount: 5000,
  largeItemStepFee: 500,
  largeItemFeeCapPerUnit: 2500,
  deliveryPlatformMarginFixed: 700,
  deliveryPlatformMinMargin: 300,
};

let pricingRemoteConfigCache = {
  value: DEFAULT_PRICING_CONFIG,
  expiresAtMillis: 0,
};

function createTemporaryPassword() {
  return `${crypto.randomBytes(6).toString('base64url')}Aa1!`;
}

function isStaticAdminEmail(email) {
  return BOOTSTRAP_ADMIN_EMAILS.includes(String(email || '').toLowerCase().trim());
}

function isAdminAuth(auth) {
  if (!auth?.uid) return false;
  const email = String(auth.token?.email || '').toLowerCase().trim();
  return isStaticAdminEmail(email);
}

async function isAdminUid(uid) {
  if (!uid) return false;

  try {
    const userRecord = await admin.auth().getUser(uid);
    const email = String(userRecord.email || '').toLowerCase().trim();
    if (isStaticAdminEmail(email)) {
      return true;
    }
  } catch (_) {
  }

  const adminSnap = await db.collection('admins').doc(uid).get();
  if (!adminSnap.exists) return false;
  const data = adminSnap.data() || {};
  return data.role === 'admin' || data.active === true;
}

async function canBootstrapFirstAdmin(auth) {
  if (!auth?.uid || !auth?.token?.email) return false;
  const existing = await db.collection('admins').limit(1).get();
  if (!existing.empty) return false;
  const email = String(auth.token.email || '').toLowerCase().trim();
  return BOOTSTRAP_ADMIN_EMAILS.includes(email);
}

function buildNotificationPayload({
  title,
  body,
  type = 'manual',
  source = 'admin-web',
  orderId = null,
  extra = {},
}) {
  return {
    title,
    body,
    type,
    source,
    orderId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    ...extra,
  };
}

function normalizeAudienceRole(raw) {
  const role = String(raw || '').trim().toLowerCase();
  if (role === 'client') return 'client';
  if (role === 'courier' || role === 'driver') return 'courier';
  if (role === 'store' || role === 'restaurant') return 'store';
  return '';
}

function normalizePaymentStatus(raw) {
  const normalized = String(raw || '').trim().toLowerCase();
  if (normalized === 'paid' || normalized === 'تم الدفع') return 'paid';
  if (normalized === 'pending' || normalized === 'انتظار الدفع') return 'pending';
  if (normalized === 'قيد المراجعة' || normalized === 'under_review') return 'under_review';
  if (normalized === 'مرفوض' || normalized === 'رفض الدفع' || normalized === 'rejected') return 'rejected';
  return normalized;
}

function hasPaymentEvidence(order) {
  return Boolean(
    String(order?.proofImageUrl || '').trim()
    && String(order?.transactionReference || '').trim()
  );
}

function roleCollectionRef(normalizedRole) {
  if (normalizedRole === 'client') return db.collection('clients');
  if (normalizedRole === 'courier') return db.collection('drivers');
  if (normalizedRole === 'store') return db.collection('restaurants');
  return null;
}

function notificationWriteDataForRole(normalizedRole, uid, payload) {
  if (normalizedRole === 'client') {
    return {
      ref: db.collection('clients').doc(uid).collection('notifications').doc(),
      data: { ...payload, userId: uid, audience: 'client' },
    };
  }

  if (normalizedRole === 'courier') {
    return {
      ref: db.collection('notifications').doc(),
      data: { ...payload, userId: uid, driverId: uid, audience: 'courier' },
    };
  }

  if (normalizedRole === 'store') {
    return {
      ref: db.collection('notifications').doc(),
      data: { ...payload, userId: uid, restaurantId: uid, audience: 'store' },
    };
  }

  return null;
}

function extractFcmTokens(data) {
  const raw = data || {};
  const values = [
    raw.fcmToken,
    raw.messagingToken,
    raw.deviceToken,
    raw.token,
    ...(Array.isArray(raw.fcmTokens) ? raw.fcmTokens : []),
    ...(Array.isArray(raw.deviceTokens) ? raw.deviceTokens : []),
  ];

  const valid = values
    .map((item) => String(item || '').trim())
    .filter((item) => item.length > 20);

  return [...new Set(valid)];
}

function notificationPayloadToData(payload, role, userId) {
  return {
    title: String(payload.title || ''),
    body: String(payload.body || ''),
    type: String(payload.type || ''),
    source: String(payload.source || ''),
    orderId: payload.orderId ? String(payload.orderId) : '',
    audience: String(role || ''),
    userId: String(userId || ''),
  };
}

async function sendPushToUser(normalizedRole, userId, userDocData, payload) {
  const tokens = extractFcmTokens(userDocData);
  if (!tokens.length) return 0;

  const notificationType = String(payload?.type || '').trim().toLowerCase();
  const isOrderUrgent =
    notificationType.includes('order')
    || notificationType.includes('offer')
    || notificationType.includes('pickup')
    || notificationType.includes('courier');
  const storeOrdersChannelId = 'speedstar_store_orders_incoming_v2';
  const sharedOrdersChannelId = 'speedstar_orders_incoming_v1';
  const androidChannelId = isOrderUrgent
    ? (normalizedRole === 'store' ? storeOrdersChannelId : sharedOrdersChannelId)
    : 'speedstar_alerts';

  const message = {
    tokens,
    notification: {
      title: String(payload.title || ''),
      body: String(payload.body || ''),
    },
    data: notificationPayloadToData(payload, normalizedRole, userId),
    android: {
      priority: 'high',
      ttl: '30s',
      notification: {
        channelId: androidChannelId,
        priority: 'high',
        defaultSound: true,
        sound: isOrderUrgent ? 'incoming_order' : 'default',
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          sound: 'default',
          contentAvailable: true,
        },
      },
    },
  };

  try {
    const result = await admin.messaging().sendEachForMulticast(message);
    return Number(result.successCount || 0);
  } catch (error) {
    logger.error('sendPushToUser failed', {
      role: normalizedRole,
      userId,
      error: error?.message || String(error),
    });
    return 0;
  }
}

async function sendNotificationToSingleUser(role, userId, payload) {
  const normalizedRole = normalizeAudienceRole(role);
  const uid = String(userId || '').trim();
  if (!normalizedRole || !uid) return 0;

  const roleRef = roleCollectionRef(normalizedRole);
  const writePayload = notificationWriteDataForRole(normalizedRole, uid, payload);
  if (!roleRef || !writePayload) return 0;

  const userDoc = await roleRef.doc(uid).get();
  await writePayload.ref.set(writePayload.data);
  await sendPushToUser(normalizedRole, uid, userDoc.data() || {}, payload);
  return 1;
}

async function sendNotificationToRole(role, payload, maxRecipients = 500) {
  const normalizedRole = normalizeAudienceRole(role);
  if (!normalizedRole) return 0;

  const roleRef = roleCollectionRef(normalizedRole);
  if (!roleRef) return 0;

  let targetSnap;
  targetSnap = await roleRef.limit(maxRecipients).get();

  let count = 0;
  let batch = db.batch();
  let opCount = 0;
  const pushTasks = [];

  for (const snap of targetSnap.docs) {
    const uid = snap.id;
    const writePayload = notificationWriteDataForRole(normalizedRole, uid, payload);
    if (!writePayload) continue;

    batch.set(writePayload.ref, writePayload.data);
    opCount += 1;
    count += 1;

    pushTasks.push(sendPushToUser(normalizedRole, uid, snap.data() || {}, payload));

    if (opCount >= 400) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
    }
  }

  if (opCount > 0) {
    await batch.commit();
  }

  if (pushTasks.length) {
    await Promise.allSettled(pushTasks);
  }

  return count;
}

function normalizeWalletTargetRole(raw) {
  const role = String(raw || '').trim().toLowerCase();
  if (role === 'store' || role === 'restaurant') return 'store';
  if (role === 'courier' || role === 'driver') return 'courier';
  return '';
}

function walletDocRefByRole(role, targetId) {
  if (role === 'store') return db.collection('restaurants').doc(targetId);
  if (role === 'courier') return db.collection('drivers').doc(targetId);
  return null;
}

function walletTransactionCollection(role, targetId) {
  if (role === 'store') return db.collection('restaurants').doc(targetId).collection('walletTransactions');
  if (role === 'courier') return db.collection('drivers').doc(targetId).collection('walletTransactions');
  return null;
}

function normalizeOrderStatusForNotification(raw) {
  const status = String(raw || '').trim();
  const map = {
    'قيد المراجعة': 'store_pending',
    'قيد التجهيز': 'courier_searching',
    'قيد التوصيل': 'picked_up',
    'بانتظار المطعم': 'store_pending',
    'تم التوصيل': 'delivered',
    'ملغي': 'cancelled',
  };
  return map[status] || status;
}

function getStatus(order) {
  return String(order.orderStatus || order.status || '').trim();
}

function normalizePromoCode(rawCode) {
  return String(rawCode || '').trim().toUpperCase();
}

function toSafeNumber(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function extractClientWalletBalance(data) {
  const raw = data || {};
  const candidates = [raw.walletBalance, raw.wallet, raw.balance];

  for (const candidate of candidates) {
    const parsed = Number(candidate);
    if (Number.isFinite(parsed)) {
      return Math.max(0, parsed);
    }
  }

  return 0;
}

function buildPromoOrderContext(input) {
  const context = input || {};
  const subtotal = Math.max(0, Math.round(toSafeNumber(context.subtotal ?? context.total)));
  const deliveryFee = Math.max(0, Math.round(toSafeNumber(context.deliveryFee)));
  const largeOrderFee = Math.max(0, Math.round(toSafeNumber(context.largeOrderFee)));
  const baseTotal = Math.max(0, subtotal + deliveryFee + largeOrderFee);
  const restaurantId = String(context.restaurantId || '').trim();
  const orderReference = String(context.orderReference || context.orderId || context.orderNumber || '').trim();
  const isNewOrder = context.isNewOrder !== false;

  let itemNames = [];
  if (Array.isArray(context.items)) {
    itemNames = context.items
      .map((item) => String(item?.name || '').trim())
      .filter(Boolean);
  }

  return {
    subtotal,
    deliveryFee,
    largeOrderFee,
    baseTotal,
    restaurantId,
    isNewOrder,
    itemNames,
    orderReference,
  };
}

function evaluatePromocode(promo, context, userId) {
  const code = normalizePromoCode(promo.code);
  if (!code) {
    return { ok: false, reason: 'invalid-code' };
  }

  if (promo.isActive !== true) {
    return { ok: false, reason: 'inactive' };
  }

  const nowMillis = Date.now();
  const expiry = promo.expiryDate?.toMillis?.() || null;
  if (expiry && expiry <= nowMillis) {
    return { ok: false, reason: 'expired' };
  }

  const promoRestaurantId = String(promo.restaurantId || '').trim();
  if (promoRestaurantId && promoRestaurantId !== context.restaurantId) {
    return { ok: false, reason: 'restaurant-mismatch' };
  }

  const minOrder = Math.max(0, Math.round(toSafeNumber(promo.minOrder)));
  if (minOrder > 0 && context.baseTotal < minOrder) {
    return { ok: false, reason: 'min-order' };
  }

  const maxUsage = Math.max(0, Math.floor(toSafeNumber(promo.maxUsage)));
  const usedCount = Math.max(0, Math.floor(toSafeNumber(promo.usedCount)));
  if (maxUsage > 0 && usedCount >= maxUsage) {
    return { ok: false, reason: 'max-usage' };
  }

  const usersUsed = promo.usersUsed && typeof promo.usersUsed === 'object' ? promo.usersUsed : {};
  const userUsedCount = Math.max(0, Math.floor(toSafeNumber(usersUsed[userId])));
  const maxUsagePerUser = Math.max(0, Math.floor(toSafeNumber(promo.maxUsagePerUser)));
  if (maxUsagePerUser > 0 && userUsedCount >= maxUsagePerUser) {
    return { ok: false, reason: 'max-usage-per-user' };
  }

  if (promo.onlyForNewOrders === true && context.isNewOrder !== true) {
    return { ok: false, reason: 'new-orders-only' };
  }

  const itemName = String(promo.itemName || '').trim();
  let discountBase = context.baseTotal;
  if (itemName) {
    const matchedItem = context.itemNames.find((name) => name === itemName);
    if (!matchedItem) {
      return { ok: false, reason: 'item-mismatch' };
    }
    discountBase = context.subtotal;
  }

  if (discountBase <= 0) {
    return { ok: false, reason: 'invalid-base-total' };
  }

  const discountType = String(promo.discountType || '').trim().toLowerCase();
  const discountValue = toSafeNumber(promo.discountValue);
  let discountAmount = 0;
  if (discountType === 'percent') {
    const boundedPercent = Math.max(0, Math.min(100, discountValue));
    discountAmount = Math.round((discountBase * boundedPercent) / 100);
  } else {
    discountAmount = Math.round(Math.max(0, discountValue));
  }

  const maxDiscount = Math.max(0, Math.round(toSafeNumber(promo.maxDiscount)));
  if (maxDiscount > 0) {
    discountAmount = Math.min(discountAmount, maxDiscount);
  }

  discountAmount = Math.max(0, Math.min(discountAmount, context.baseTotal));
  const totalAfterDiscount = Math.max(0, context.baseTotal - discountAmount);

  return {
    ok: true,
    code,
    discountAmount,
    totalAfterDiscount,
    promoSnapshot: {
      code,
      discountType,
      discountValue,
      maxDiscount: maxDiscount || null,
      minOrder: minOrder || null,
      restaurantId: promoRestaurantId || null,
      itemName: itemName || null,
      onlyForNewOrders: promo.onlyForNewOrders === true,
      promoId: String(promo.id || ''),
    },
  };
}

exports.validatePromocodeForClient = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const code = normalizePromoCode(request.data?.code);
  if (!code) {
    throw new HttpsError('invalid-argument', 'code is required');
  }

  const context = buildPromoOrderContext(request.data?.order || {});
  if (!context.restaurantId) {
    throw new HttpsError('invalid-argument', 'order.restaurantId is required');
  }

  const promoRef = db.collection('promocodes').doc(code);
  const promoSnap = await promoRef.get();
  if (!promoSnap.exists) {
    return { ok: false, reason: 'not-found' };
  }

  const promo = promoSnap.data() || {};
  const result = evaluatePromocode({ ...promo, id: promoSnap.id }, context, request.auth.uid);
  if (!result.ok) {
    return {
      ok: false,
      reason: result.reason || 'invalid',
    };
  }

  return {
    ok: true,
    code: result.code,
    discountAmount: result.discountAmount,
    totalAfterDiscount: result.totalAfterDiscount,
    promo: result.promoSnapshot,
  };
});

exports.redeemPromocodeForClientOrder = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const uid = String(request.auth.uid || '').trim();
  const code = normalizePromoCode(request.data?.code);
  const orderInput = request.data?.order || {};
  const context = buildPromoOrderContext(orderInput);
  if (!code) {
    throw new HttpsError('invalid-argument', 'code is required');
  }
  if (!context.restaurantId) {
    throw new HttpsError('invalid-argument', 'order.restaurantId is required');
  }

  const orderReference = context.orderReference || `${uid}-${Date.now()}`;
  const redemptionKey = crypto
    .createHash('sha1')
    .update(`${uid}|${code}|${orderReference}`)
    .digest('hex');

  const promoRef = db.collection('promocodes').doc(code);
  const redemptionRef = db.collection('promocodeRedemptions').doc(redemptionKey);

  const result = await db.runTransaction(async (tx) => {
    const [promoSnap, redemptionSnap] = await Promise.all([
      tx.get(promoRef),
      tx.get(redemptionRef),
    ]);

    if (!promoSnap.exists) {
      throw new HttpsError('not-found', 'Promocode not found');
    }

    if (redemptionSnap.exists) {
      const existing = redemptionSnap.data() || {};
      return {
        ok: true,
        alreadyRedeemed: true,
        code,
        discountAmount: Math.max(0, Math.round(toSafeNumber(existing.discountAmount))),
        totalAfterDiscount: Math.max(0, Math.round(toSafeNumber(existing.totalAfterDiscount))),
        promo: existing.promo || null,
      };
    }

    const promo = promoSnap.data() || {};
    const evaluated = evaluatePromocode({ ...promo, id: promoSnap.id }, context, uid);
    if (!evaluated.ok) {
      throw new HttpsError('failed-precondition', evaluated.reason || 'invalid-promocode');
    }

    const usersUsed = promo.usersUsed && typeof promo.usersUsed === 'object'
      ? { ...promo.usersUsed }
      : {};
    usersUsed[uid] = Math.max(0, Math.floor(toSafeNumber(usersUsed[uid]))) + 1;

    tx.update(promoRef, {
      usedCount: admin.firestore.FieldValue.increment(1),
      usersUsed,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: uid,
    });

    tx.set(redemptionRef, {
      code,
      promoId: promoSnap.id,
      orderReference,
      userId: uid,
      restaurantId: context.restaurantId,
      discountAmount: evaluated.discountAmount,
      totalAfterDiscount: evaluated.totalAfterDiscount,
      promo: evaluated.promoSnapshot,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      ok: true,
      alreadyRedeemed: false,
      code,
      discountAmount: evaluated.discountAmount,
      totalAfterDiscount: evaluated.totalAfterDiscount,
      promo: evaluated.promoSnapshot,
    };
  });

  return result;
});

exports.sendAdminNotification = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً.');
  }

  const isAdminAllowed = isAdminAuth(request.auth) || await isAdminUid(request.auth.uid);
  if (!isAdminAllowed) {
    throw new HttpsError('permission-denied', 'ليس لديك صلاحية إرسال إشعارات عامة.');
  }

  const data = request.data || {};
  const targetType = String(data.targetType || 'all').trim().toLowerCase();
  const role = normalizeAudienceRole(data.role || targetType);
  const userId = String(data.userId || '').trim();
  const title = String(data.title || '').trim();
  const body = String(data.body || '').trim();

  if (!title || !body) {
    throw new HttpsError('invalid-argument', 'العنوان والرسالة مطلوبان.');
  }

  if (title.length > 120) {
    throw new HttpsError('invalid-argument', 'العنوان طويل جدًا (الحد 120 حرف).');
  }

  if (body.length > 1200) {
    throw new HttpsError('invalid-argument', 'الرسالة طويلة جدًا (الحد 1200 حرف).');
  }

  const payload = buildNotificationPayload({
    title,
    body,
    type: 'admin_manual',
    source: 'admin-web',
    extra: {
      sentByUid: request.auth.uid,
      sentByEmail: String(request.auth.token?.email || ''),
    },
  });

  let sentCount = 0;
  if (targetType === 'user') {
    if (!role || !userId) {
      throw new HttpsError('invalid-argument', 'عند الإرسال لمستخدم محدد يجب إرسال الدور و UID.');
    }
    sentCount = await sendNotificationToSingleUser(role, userId, payload);
  } else if (targetType === 'all') {
    const clientCount = await sendNotificationToRole('client', payload);
    const courierCount = await sendNotificationToRole('courier', payload);
    const storeCount = await sendNotificationToRole('store', payload);
    sentCount = clientCount + courierCount + storeCount;
  } else {
    if (!role) {
      throw new HttpsError('invalid-argument', 'نوع الوجهة غير صالح.');
    }
    sentCount = await sendNotificationToRole(role, payload);
  }

  return {
    ok: true,
    sentCount,
    targetType,
  };
});

exports.recordWalletPayout = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً.');
  }

  const isAdminAllowed = isAdminAuth(request.auth) || await isAdminUid(request.auth.uid);
  if (!isAdminAllowed) {
    throw new HttpsError('permission-denied', 'ليس لديك صلاحية التحويل.');
  }

  const role = normalizeWalletTargetRole(request.data?.role);
  const targetId = String(request.data?.targetId || '').trim();
  const amountRaw = Number(request.data?.amount);
  const note = String(request.data?.note || '').trim();

  if (!role || !targetId) {
    throw new HttpsError('invalid-argument', 'role و targetId مطلوبان.');
  }

  const roleRef = walletDocRefByRole(role, targetId);
  const transactionsRef = walletTransactionCollection(role, targetId);
  if (!roleRef || !transactionsRef) {
    throw new HttpsError('invalid-argument', 'نوع الهدف غير صالح.');
  }

  const txResult = await db.runTransaction(async (tx) => {
    const targetSnap = await tx.get(roleRef);
    if (!targetSnap.exists) {
      throw new HttpsError('not-found', 'المستفيد غير موجود.');
    }

    const targetData = targetSnap.data() || {};
    const pendingBalance = Math.max(0, Number(targetData.walletPendingBalance || 0));
    const transferredTotal = Math.max(0, Number(targetData.walletTransferredTotal || 0));
    const lifetimeEarnings = Math.max(0, Number(targetData.walletLifetimeEarnings || 0));

    const payoutAmount = Number.isFinite(amountRaw) && amountRaw > 0
      ? Math.round(amountRaw)
      : Math.round(pendingBalance);

    if (!Number.isFinite(payoutAmount) || payoutAmount <= 0) {
      throw new HttpsError('failed-precondition', 'لا توجد قيمة صالحة للتحويل.');
    }

    if (payoutAmount > pendingBalance) {
      throw new HttpsError('failed-precondition', 'قيمة التحويل أكبر من الرصيد المستحق.');
    }

    const account = targetData.payoutAccount || {};
    const accountMethod = String(account.method || targetData.payoutMethod || '').trim();
    const accountNumber = String(account.accountNumber || targetData.payoutAccountNumber || '').trim();
    const accountName = String(account.accountName || targetData.payoutAccountName || '').trim();

    const payoutTxRef = transactionsRef.doc();
    const nowTs = admin.firestore.FieldValue.serverTimestamp();

    tx.set(payoutTxRef, {
      type: 'admin_payout',
      role,
      targetId,
      amount: payoutAmount,
      note,
      accountMethod,
      accountNumber,
      accountName,
      byAdminUid: request.auth.uid,
      byAdminEmail: String(request.auth.token?.email || ''),
      createdAt: nowTs,
    });

    tx.set(db.collection('walletPayoutLogs').doc(), {
      role,
      targetId,
      amount: payoutAmount,
      note,
      accountMethod,
      accountNumber,
      accountName,
      byAdminUid: request.auth.uid,
      byAdminEmail: String(request.auth.token?.email || ''),
      createdAt: nowTs,
    });

    tx.set(roleRef, {
      walletPendingBalance: Math.max(0, pendingBalance - payoutAmount),
      walletTransferredTotal: transferredTotal + payoutAmount,
      walletLastTransferAmount: payoutAmount,
      walletLastTransferAt: nowTs,
      walletTransferCount: Number(targetData.walletTransferCount || 0) + 1,
      walletLifetimeEarnings: lifetimeEarnings,
      updatedAt: nowTs,
    }, { merge: true });

    return {
      payoutAmount,
      remainingPendingBalance: Math.max(0, pendingBalance - payoutAmount),
      accountMethod,
      accountNumber,
      beneficiaryName: String(targetData.name || targetData.fullName || targetId),
    };
  });

  const audienceRole = role === 'store' ? 'store' : 'courier';
  const title = '💸 تم تحويل مستحقاتك';
  const body = role === 'store'
    ? `تم تحويل مبلغ ${txResult.payoutAmount} ج.س إلى محفظة المتجر.`
    : `تم تحويل مبلغ ${txResult.payoutAmount} ج.س إلى محفظة المندوب.`;

  await sendNotificationToSingleUser(
    audienceRole,
    targetId,
    buildNotificationPayload({
      title,
      body,
      type: 'wallet_payout',
      source: 'admin-finance',
      extra: {
        payoutAmount: txResult.payoutAmount,
        payoutRole: role,
      },
    })
  );

  return {
    ok: true,
    role,
    targetId,
    payoutAmount: txResult.payoutAmount,
    remainingPendingBalance: txResult.remainingPendingBalance,
    accountMethod: txResult.accountMethod,
    accountNumber: txResult.accountNumber,
  };
});

exports.reviewClientWalletRecharge = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً.');
  }

  const isAdminAllowed = isAdminAuth(request.auth) || await isAdminUid(request.auth.uid);
  if (!isAdminAllowed) {
    throw new HttpsError('permission-denied', 'ليس لديك صلاحية مراجعة شحن المحفظة.');
  }

  const rechargeId = String(request.data?.rechargeId || '').trim();
  const decision = String(request.data?.decision || '').trim().toLowerCase();
  const note = String(request.data?.note || '').trim();

  if (!rechargeId || !['approve', 'reject'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'rechargeId و decision(approve/reject) مطلوبان.');
  }

  const rechargeRef = db.collection('wallet_recharges').doc(rechargeId);
  const nowTs = admin.firestore.FieldValue.serverTimestamp();

  const result = await db.runTransaction(async (tx) => {
    const rechargeSnap = await tx.get(rechargeRef);
    if (!rechargeSnap.exists) {
      throw new HttpsError('not-found', 'طلب شحن المحفظة غير موجود.');
    }

    const recharge = rechargeSnap.data() || {};
    const clientId = String(recharge.clientId || '').trim();
    const amount = Number(recharge.amount || 0);
    const currentStatus = String(recharge.status || '').trim().toLowerCase();
    const reviewStatus = String(recharge.reviewStatus || '').trim().toLowerCase();

    if (!clientId) {
      throw new HttpsError('failed-precondition', 'طلب الشحن لا يحتوي على clientId صالح.');
    }

    if (!Number.isFinite(amount) || amount <= 0) {
      throw new HttpsError('failed-precondition', 'قيمة الشحن غير صالحة.');
    }

    if (['approved', 'rejected', 'paid'].includes(currentStatus) || ['approved', 'rejected'].includes(reviewStatus)) {
      throw new HttpsError('failed-precondition', 'تمت مراجعة هذا الطلب مسبقًا.');
    }

    const clientRef = db.collection('clients').doc(clientId);
    const clientSnap = await tx.get(clientRef);
    if (!clientSnap.exists) {
      throw new HttpsError('not-found', 'العميل المرتبط بطلب الشحن غير موجود.');
    }

    const clientData = clientSnap.data() || {};
    const currentBalance = Number(
      clientData.walletBalance
      ?? clientData.wallet
      ?? clientData.balance
      ?? 0
    ) || 0;

    const rechargePatch = {
      reviewStatus: decision === 'approve' ? 'approved' : 'rejected',
      status: decision === 'approve' ? 'approved' : 'rejected',
      reviewNote: note,
      reviewedAt: nowTs,
      reviewedByAdminUid: request.auth.uid,
      reviewedByAdminEmail: String(request.auth.token?.email || ''),
      updatedAt: nowTs,
    };

    tx.set(rechargeRef, rechargePatch, { merge: true });

    if (decision === 'approve') {
      const nextBalance = currentBalance + amount;
      tx.set(clientRef, {
        walletBalance: nextBalance,
        wallet: nextBalance,
        walletLastRechargeAmount: amount,
        walletLastRechargeAt: nowTs,
        updatedAt: nowTs,
      }, { merge: true });

      return {
        clientId,
        amount,
        nextBalance,
        decision,
      };
    }

    return {
      clientId,
      amount,
      nextBalance: currentBalance,
      decision,
    };
  });

  const title = result.decision === 'approve'
    ? '💰 تمت إضافة رصيد إلى محفظتك'
    : '⚠️ تم رفض طلب شحن المحفظة';
  const body = result.decision === 'approve'
    ? `تم اعتماد شحن محفظتك بمبلغ ${result.amount} ج.س.`
    : `تم رفض طلب شحن المحفظة${note ? `: ${note}` : '.'}`;

  await sendNotificationToSingleUser(
    'client',
    result.clientId,
    buildNotificationPayload({
      title,
      body,
      type: 'client_wallet_recharge_review',
      source: 'admin-finance',
      extra: {
        rechargeAmount: result.amount,
        rechargeDecision: result.decision,
      },
    })
  );

  return {
    ok: true,
    decision: result.decision,
    clientId: result.clientId,
    amount: result.amount,
    nextBalance: result.nextBalance,
  };
});

exports.reviewOrderPaymentEvidence = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const isAdminAllowed = isAdminAuth(request.auth) || await isAdminUid(request.auth.uid);
  if (!isAdminAllowed) {
    throw new HttpsError('permission-denied', 'Only admins can review payment evidence');
  }

  const orderId = String(request.data?.orderId || '').trim();
  const decision = String(request.data?.decision || '').trim().toLowerCase();
  const note = String(request.data?.note || '').trim();

  if (!orderId || !['approve', 'reject'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'orderId and decision(approve/reject) are required');
  }

  const orderRef = db.collection('orders').doc(orderId);
  const nowTs = admin.firestore.FieldValue.serverTimestamp();

  await db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) {
      throw new HttpsError('not-found', 'Order not found');
    }

    const order = orderSnap.data() || {};
    if (!hasPaymentEvidence(order)) {
      throw new HttpsError('failed-precondition', 'Payment evidence is missing');
    }

    const transactionReference = String(order.transactionReference || '').trim();
    if (decision === 'approve' && transactionReference) {
      const duplicateSnap = await tx.get(
        db.collection('orders')
          .where('transactionReference', '==', transactionReference)
          .limit(25)
      );

      const duplicateApproved = duplicateSnap.docs.find((docSnap) => {
        if (docSnap.id === orderId) return false;
        const data = docSnap.data() || {};
        return String(data.paymentReviewDecision || '').toLowerCase() === 'approved'
          || normalizePaymentStatus(data.paymentStatus) === 'paid';
      });

      if (duplicateApproved) {
        throw new HttpsError('failed-precondition', 'Transaction reference already approved on another order');
      }
    }

    if (decision === 'approve') {
      tx.set(orderRef, {
        paymentStatus: 'paid',
        paymentReviewDecision: 'approved',
        paymentReviewRequired: false,
        paymentReviewedByAdminUid: request.auth.uid,
        paymentReviewedByAdminEmail: String(request.auth.token?.email || ''),
        paymentReviewedAt: nowTs,
        paymentReviewNote: note,
        orderStatus: 'store_pending',
        status: 'store_pending',
        paidAt: nowTs,
        updatedAt: nowTs,
      }, { merge: true });
      return;
    }

    tx.set(orderRef, {
      paymentStatus: PAYMENT_REJECTED_STATUS,
      paymentReviewDecision: 'rejected',
      paymentReviewRequired: true,
      paymentReviewedByAdminUid: request.auth.uid,
      paymentReviewedByAdminEmail: String(request.auth.token?.email || ''),
      paymentReviewedAt: nowTs,
      paymentRejectedAt: nowTs,
      paymentRejectedReason: note,
      orderStatus: 'payment_rejected',
      status: 'payment_rejected',
      paidAt: admin.firestore.FieldValue.delete(),
      updatedAt: nowTs,
    }, { merge: true });
  });

  return {
    ok: true,
    orderId,
    decision,
  };
});

async function dispatchOrderStatusNotifications(orderId, afterData) {
  const afterStatus = normalizeOrderStatusForNotification(afterData.orderStatus || afterData.status);
  if (!afterStatus) return { sent: 0, status: '' };

  const orderNumber = formatUnifiedOrderCode(afterData.orderNumber || afterData.orderId, orderId);
  const clientId = String(afterData.clientId || '').trim();
  const restaurantId = String(afterData.restaurantId || '').trim();
  const offeredDriverId = String(afterData.offeredDriverId || '').trim();
  const assignedDriverId = String(afterData.assignedDriverId || '').trim();

  const tasks = [];
  const sendClient = (title, body, type) => {
    if (!clientId) return;
    tasks.push(
      sendNotificationToSingleUser(
        'client',
        clientId,
        buildNotificationPayload({ title, body, type, source: 'order-workflow', orderId })
      )
    );
  };
  const sendCourier = (driverId, title, body, type) => {
    if (!driverId) return;
    tasks.push(
      sendNotificationToSingleUser(
        'courier',
        driverId,
        buildNotificationPayload({ title, body, type, source: 'order-workflow', orderId })
      )
    );
  };
  const sendStore = (title, body, type) => {
    if (!restaurantId) return;
    tasks.push(
      sendNotificationToSingleUser(
        'store',
        restaurantId,
        buildNotificationPayload({ title, body, type, source: 'order-workflow', orderId })
      )
    );
  };

  if (afterStatus === 'store_pending') {
    sendStore('📥 طلب جديد', `لديك طلب جديد رقم ${orderNumber} بانتظار المراجعة.`, 'store_new_order');
    sendClient('✅ تم استلام طلبك', `تم استلام طلبك رقم ${orderNumber} وجارٍ مراجعته من المتجر.`, 'client_order_received');
  }

  if (afterStatus === 'courier_offer_pending') {
    sendCourier(
      offeredDriverId || assignedDriverId,
      '🚚 عرض توصيل جديد',
      `يوجد طلب رقم ${orderNumber} بانتظار قبولك.`,
      'courier_offer_pending'
    );
  }

  if (afterStatus === 'courier_assigned') {
    sendClient('🛵 تم تعيين مندوب', `تم تعيين مندوب لطلبك رقم ${orderNumber}.`, 'client_courier_assigned');
    sendStore('🛵 تم تعيين مندوب', `تم تعيين مندوب للطلب رقم ${orderNumber}.`, 'store_courier_assigned');
    sendCourier(
      assignedDriverId || offeredDriverId,
      '✅ تم إسناد الطلب لك',
      `تم اعتمادك لتوصيل الطلب رقم ${orderNumber}.`,
      'courier_assigned'
    );
  }

  if (afterStatus === 'pickup_ready') {
    sendCourier(
      assignedDriverId || offeredDriverId,
      '📦 الطلب جاهز للاستلام',
      `الطلب رقم ${orderNumber} أصبح جاهزاً للاستلام من المطعم.`,
      'courier_pickup_ready'
    );
  }

  if (afterStatus === 'picked_up') {
    sendClient('📦 خرج طلبك للتوصيل', `طلبك رقم ${orderNumber} أصبح في طريقه إليك.`, 'client_order_picked_up');
    sendStore('📦 تم استلام الطلب', `تم استلام الطلب رقم ${orderNumber} من المتجر بواسطة المندوب.`, 'store_order_picked_up');
  }

  if (afterStatus === 'arrived_to_client') {
    sendClient('📍 المندوب وصل', `مندوب الطلب رقم ${orderNumber} وصل إلى موقعك.`, 'client_courier_arrived');
  }

  if (afterStatus === 'delivered') {
    sendClient('🎉 تم التسليم', `تم تسليم طلبك رقم ${orderNumber} بنجاح.`, 'client_order_delivered');
    sendStore('✅ تم تسليم الطلب', `تم تسليم الطلب رقم ${orderNumber} للعميل.`, 'store_order_delivered');
    sendCourier(
      assignedDriverId || offeredDriverId,
      '✅ اكتمل التوصيل',
      `اكتمل توصيل الطلب رقم ${orderNumber}.`,
      'courier_order_delivered'
    );
  }

  if (afterStatus === 'cancelled' || afterStatus === 'store_rejected') {
    sendClient('⚠️ تم إلغاء الطلب', `تم إلغاء الطلب رقم ${orderNumber}.`, 'client_order_cancelled');
    sendStore('⚠️ تم إلغاء الطلب', `تم إلغاء الطلب رقم ${orderNumber}.`, 'store_order_cancelled');
    sendCourier(
      assignedDriverId || offeredDriverId,
      '⚠️ تم إلغاء الطلب',
      `تم إلغاء الطلب رقم ${orderNumber}.`,
      'courier_order_cancelled'
    );
  }

  if (!tasks.length) {
    return { sent: 0, status: afterStatus };
  }

  const results = await Promise.allSettled(tasks);
  const sent = results.filter((r) => r.status === 'fulfilled').length;
  return { sent, status: afterStatus };
}

exports.notifyOnOrderStatusChange = onSchedule(
  {
    region: SCHEDULE_REGION,
    schedule: 'every 1 minutes',
    timeZone: 'Africa/Khartoum',
  },
  async () => {
    const windowStart = admin.firestore.Timestamp.fromMillis(Date.now() - 15 * 60 * 1000);
    const snap = await db
      .collection('orders')
      .where('updatedAt', '>=', windowStart)
      .limit(400)
      .get();

    if (snap.empty) return;

    for (const docSnap of snap.docs) {
      const data = docSnap.data() || {};
      const status = normalizeOrderStatusForNotification(data.orderStatus || data.status);
      const lastNotifiedStatus = String(data.lastNotifiedStatus || '').trim();
      if (!status || status === lastNotifiedStatus) continue;

      const result = await dispatchOrderStatusNotifications(docSnap.id, data);

      await docSnap.ref.update({
        lastNotifiedStatus: status,
        lastNotificationAt: admin.firestore.FieldValue.serverTimestamp(),
        lastNotificationSentCount: Number(result.sent || 0),
      });
    }
  }
);

exports.notifyOnOrderStatusUpdatedRealtime = onDocumentUpdated(
  {
    region: SCHEDULE_REGION,
    document: 'orders/{orderId}',
  },
  async (event) => {
    const beforeData = event.data?.before?.data() || {};
    const afterData = event.data?.after?.data() || {};

    const beforeStatus = normalizeOrderStatusForNotification(beforeData.orderStatus || beforeData.status);
    const afterStatus = normalizeOrderStatusForNotification(afterData.orderStatus || afterData.status);
    const lastNotifiedStatus = String(afterData.lastNotifiedStatus || '').trim();

    if (!afterStatus) return;
    if (afterStatus === lastNotifiedStatus) return;
    if (beforeStatus === afterStatus && lastNotifiedStatus === afterStatus) return;

    const result = await dispatchOrderStatusNotifications(event.params.orderId, afterData);

    await event.data.after.ref.set({
      lastNotifiedStatus: afterStatus,
      lastNotificationAt: admin.firestore.FieldValue.serverTimestamp(),
      lastNotificationSentCount: Number(result.sent || 0),
    }, { merge: true });
  }
);

exports.enforceManualPaymentReviewOnOrderUpdate = onDocumentUpdated(
  {
    region: REGION,
    document: 'orders/{orderId}',
  },
  async (event) => {
    if (!ENFORCE_MANUAL_PAYMENT_REVIEW) return;

    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const afterPaymentStatus = normalizePaymentStatus(after.paymentStatus);

    if (afterPaymentStatus !== 'paid') return;
    if (!hasPaymentEvidence(after)) return;

    const reviewedBy = String(after.paymentReviewedByAdminUid || '').trim();
    const decision = String(after.paymentReviewDecision || '').trim().toLowerCase();
    if (reviewedBy || decision === 'approved') return;

    if (String(after.paymentStatus || '').trim() === PAYMENT_REVIEW_STATUS) return;

    const beforePaymentStatus = normalizePaymentStatus(before.paymentStatus);
    if (beforePaymentStatus === 'paid' && String(before.paymentReviewDecision || '').toLowerCase() === 'approved') {
      return;
    }

    await event.data.after.ref.set({
      paymentStatus: PAYMENT_REVIEW_STATUS,
      paymentReviewDecision: 'pending',
      paymentReviewRequired: true,
      paymentReviewAutoFlaggedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentReviewReason: 'awaiting_admin_review',
      orderStatus: 'payment_review',
      status: 'payment_review',
      paidAt: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
);

exports.syncRealtimeOrderPricing = onDocumentUpdated(
  {
    region: REGION,
    document: 'orders/{orderId}',
  },
  async (event) => {
    const after = event.data?.after?.data() || {};
    await syncOrderPricingFields(event.data.after.ref, after);
  }
);

exports.settleClientWalletOnPaidOrder = onDocumentUpdated(
  {
    region: REGION,
    document: 'orders/{orderId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const beforePaymentStatus = normalizePaymentStatus(before.paymentStatus);
    const afterPaymentStatus = normalizePaymentStatus(after.paymentStatus);

    if (afterPaymentStatus !== 'paid') return;
    if (beforePaymentStatus === 'paid' && after.walletSettledAt) return;

    const requestedWalletAmount = Math.max(0, Math.round(toSafeNumber(after.walletRequestedAmount)));
    if (requestedWalletAmount <= 0 && String(after.paymentMethod || '').trim() !== 'wallet') {
      return;
    }

    await settleClientWalletForPaidOrder(event.data.after.ref);
  }
);

function isWaitingCourierStatus(status) {
  return status === 'courier_searching' || status === 'قيد التجهيز';
}

function formatUnifiedOrderCode(orderNumber, orderId) {
  const raw = String(orderNumber || orderId || '').trim().replace(/^#/, '');
  if (!raw) return 'ORD-000000';

  if (/^ord[\s_-]*/i.test(raw)) {
    const tail = raw.replace(/^ord[\s_-]*/i, '').trim();
    return tail ? `ORD-${tail}` : 'ORD-000000';
  }

  return `ORD-${raw}`;
}

function normalizeStateId(raw) {
  const value = String(raw || '').trim();
  if (!value) return '';

  const normalized = value
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .toLowerCase();

  const compact = normalized
    .replace(/[^\p{L}\p{N}\s]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  const khartoumTokens = [
    'الخرطوم',
    'ولاية الخرطوم',
    'خرطوم',
    'khartoum',
    'khartum',
    'بحري',
    'bahri',
    'khartoum north',
    'ام درمان',
    'امدرمان',
    'ام درمان الكبرى',
    'omdurman',
    'omdorman',
    'oum durman',
  ];

  for (const token of khartoumTokens) {
    if (compact === token || compact.includes(token)) {
      return 'khartoum';
    }
  }

  const riverNileTokens = [
    'عطبره',
    'عطبرة',
    'atbara',
    'atbarah',
    'نهر النيل',
    'ولاية نهر النيل',
    'ولايه نهر النيل',
    'river nile',
    'nile river',
    'nahr al nil',
    'nahr el nil',
  ];

  for (const token of riverNileTokens) {
    if (compact === token || compact.includes(token)) {
      return 'river_nile';
    }
  }

  const khartoumAliases = new Set([
    'الخرطوم',
    'ولاية الخرطوم',
    'خرطوم',
    'khartoum',
    'khartum',
    'بحري',
    'bahri',
    'khartoum north',
    'ام درمان',
    'امدرمان',
    'ام درمان الكبرى',
    'omdurman',
    'omdorman',
    'oum durman',
  ]);

  if (khartoumAliases.has(normalized)) {
    return 'khartoum';
  }

  const riverNileAliases = new Set([
    'عطبره',
    'عطبرة',
    'atbara',
    'atbarah',
    'نهر النيل',
    'ولاية نهر النيل',
    'ولايه نهر النيل',
    'river nile',
    'nile river',
    'nahr al nil',
    'nahr el nil',
  ]);

  if (riverNileAliases.has(normalized)) {
    return 'river_nile';
  }

  return normalized;
}

function orderStateId(order) {
  return normalizeStateId(
    order.stateId ||
    order.restaurantStateId ||
    order.clientStateId ||
    order.region ||
    order.city
  );
}

function restaurantStateId(restaurant) {
  return normalizeStateId(
    restaurant.stateId ||
    restaurant.region ||
    restaurant.state ||
    restaurant.city
  );
}

function inferKhartoumStateIdFromCoords(coords) {
  if (!coords) return '';
  const lat = Number(coords.lat);
  const lng = Number(coords.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return '';

  const minLat = 15.15;
  const maxLat = 16.10;
  const minLng = 32.20;
  const maxLng = 33.10;

  const insideGreaterKhartoum =
    lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;

  return insideGreaterKhartoum ? 'khartoum' : '';
}

function driverStateId(driver) {
  const explicitState = normalizeStateId(
    driver.stateId ||
    driver.driverStateId ||
    driver.addressStateId ||
    driver.defaultAddressStateId ||
    driver.locationStateId ||
    driver.location?.stateId ||
    driver.currentLocation?.stateId ||
    driver.administrativeArea ||
    driver.stateName ||
    driver.region ||
    driver.state ||
    driver.city
  );

  if (explicitState) {
    return explicitState;
  }

  const inferredFromCoords =
    inferKhartoumStateIdFromCoords(extractLatLng(driver.location)) ||
    inferKhartoumStateIdFromCoords(extractLatLng(driver.currentLocation)) ||
    inferKhartoumStateIdFromCoords(extractLatLng(driver.lastLocation)) ||
    inferKhartoumStateIdFromCoords({
      lat: driver.latitude ?? driver.lat,
      lng: driver.longitude ?? driver.lng,
    });

  return inferredFromCoords;
}

function toNumberOrNull(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function extractLatLng(raw) {
  if (!raw) return null;
  if (typeof raw.latitude === 'number' && typeof raw.longitude === 'number') {
    return { lat: raw.latitude, lng: raw.longitude };
  }
  if (typeof raw.lat === 'number' && typeof raw.lng === 'number') {
    return { lat: raw.lat, lng: raw.lng };
  }
  return null;
}

function getOrderRestaurantCoords(order) {
  const fromGeoPoint = extractLatLng(order.restaurantLocation);
  if (fromGeoPoint) return fromGeoPoint;

  const lat = toNumberOrNull(order.restaurantLat);
  const lng = toNumberOrNull(order.restaurantLng);
  if (lat != null && lng != null) return { lat, lng };

  return null;
}

function getOrderClientCoords(order) {
  const fromGeoPoint = extractLatLng(order.clientLocation);
  if (fromGeoPoint) return fromGeoPoint;

  const lat = toNumberOrNull(order.clientLat);
  const lng = toNumberOrNull(order.clientLng);
  if (lat != null && lng != null) return { lat, lng };

  return null;
}

function calculateDriverFeeFromOrder(order) {
  const resolvedDriverFee = resolveDriverFeeForPricing(order);
  if (resolvedDriverFee != null) {
    return Math.round(resolvedDriverFee);
  }

  const orderDeliveryFee = toNumberOrNull(order.deliveryFee);
  if (orderDeliveryFee != null && orderDeliveryFee > 0) {
    return Math.round(orderDeliveryFee);
  }

  return 3000;
}

function calculateDistanceBasedDriverFee(distanceKm) {
  if (distanceKm < 2) {
    return 2000;
  }
  if (distanceKm < 5) {
    return 2500;
  }
  if (distanceKm < 10) {
    return 3000;
  }
  if (distanceKm < 14) {
    return 3500;
  }
  return Math.ceil(distanceKm) * 250;
}

function resolveDriverFeeForPricing(order) {
  const existingDriverFee = toNumberOrNull(order.deliveryFeeForDriver);
  if (existingDriverFee != null && existingDriverFee > 0) {
    return Math.round(existingDriverFee);
  }

  const restaurantCoords = getOrderRestaurantCoords(order);
  const clientCoords = getOrderClientCoords(order);

  if (restaurantCoords && clientCoords) {
    const distanceKm = haversineKm(
      restaurantCoords.lat,
      restaurantCoords.lng,
      clientCoords.lat,
      clientCoords.lng
    );
    return Math.round(calculateDistanceBasedDriverFee(distanceKm));
  }

  return null;
}

function calculateClientDeliveryFeeFromOrder(order, pricingConfig) {
  const config = pricingConfig || DEFAULT_PRICING_CONFIG;
  const fixedMargin = Number(config.deliveryPlatformMarginFixed);
  const minMargin = Number(config.deliveryPlatformMinMargin);

  const marginFixed = Number.isFinite(fixedMargin)
    ? Math.max(0, Math.round(fixedMargin))
    : DEFAULT_PRICING_CONFIG.deliveryPlatformMarginFixed;
  const minimumMargin = Number.isFinite(minMargin)
    ? Math.max(0, Math.round(minMargin))
    : DEFAULT_PRICING_CONFIG.deliveryPlatformMinMargin;

  const driverFee = resolveDriverFeeForPricing(order);
  const storedDeliveryFee = Math.round(toNumberOrNull(order.deliveryFee) || 0);

  if (driverFee == null) {
    return Math.max(0, storedDeliveryFee);
  }

  const minimumAllowed = driverFee + minimumMargin;
  const target = driverFee + marginFixed;
  return Math.max(minimumAllowed, Math.round(target));
}

function parseRemoteBooleanParam(param, fallbackValue) {
  if (!param || !Object.prototype.hasOwnProperty.call(param, 'defaultValue')) {
    return fallbackValue;
  }
  const raw = String(param.defaultValue?.value ?? '').trim().toLowerCase();
  if (raw === 'true') return true;
  if (raw === 'false') return false;
  return fallbackValue;
}

function parseRemoteNumberParam(param, fallbackValue) {
  if (!param || !Object.prototype.hasOwnProperty.call(param, 'defaultValue')) {
    return fallbackValue;
  }
  const raw = Number(param.defaultValue?.value);
  return Number.isFinite(raw) ? raw : fallbackValue;
}

async function ensureAdminCallable(request, deniedMessage) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const callerUid = request.auth.uid;
  const callerEmail = String(request.auth.token?.email || '').toLowerCase().trim();
  const callerIsAdmin = (await isAdminUid(callerUid)) || isStaticAdminEmail(callerEmail);
  if (!callerIsAdmin) {
    throw new HttpsError('permission-denied', deniedMessage || 'Only admins can perform this action');
  }
}

function normalizeRolloutToken(raw) {
  const value = String(raw || '').trim();
  if (!value) return '';
  return value
    .replaceAll('أ', 'ا')
    .replaceAll('إ', 'ا')
    .replaceAll('آ', 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .toLowerCase()
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function parseRolloutCsvToList(rawCsv) {
  const items = String(rawCsv || '')
    .split(',')
    .map((item) => normalizeRolloutToken(item))
    .filter(Boolean);
  return [...new Set(items)];
}

function parseBooleanLike(raw, fallbackValue) {
  if (typeof raw === 'boolean') return raw;
  const normalized = String(raw ?? '').trim().toLowerCase();
  if (normalized === 'true' || normalized === '1' || normalized === 'yes') return true;
  if (normalized === 'false' || normalized === '0' || normalized === 'no') return false;
  return fallbackValue;
}

function parseNumberLike(raw, fallbackValue) {
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallbackValue;
}

function stringifyRemoteValue(value) {
  if (value == null) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  try {
    return JSON.stringify(value);
  } catch (_) {
    return String(value);
  }
}

async function loadPricingConfigFromRemoteConfig() {
  try {
    const template = await admin.remoteConfig().getTemplate();
    const parameters = template?.parameters || {};
    const config = {
      largeItemFeeEnabled: parseRemoteBooleanParam(
        parameters.pricing_large_item_fee_enabled,
        DEFAULT_PRICING_CONFIG.largeItemFeeEnabled
      ),
      largeItemThreshold: parseRemoteNumberParam(
        parameters.pricing_large_item_threshold,
        DEFAULT_PRICING_CONFIG.largeItemThreshold
      ),
      largeItemFeeBase: parseRemoteNumberParam(
        parameters.pricing_large_item_fee_base,
        DEFAULT_PRICING_CONFIG.largeItemFeeBase
      ),
      largeItemStepAmount: parseRemoteNumberParam(
        parameters.pricing_large_item_step_amount,
        DEFAULT_PRICING_CONFIG.largeItemStepAmount
      ),
      largeItemStepFee: parseRemoteNumberParam(
        parameters.pricing_large_item_step_fee,
        DEFAULT_PRICING_CONFIG.largeItemStepFee
      ),
      largeItemFeeCapPerUnit: parseRemoteNumberParam(
        parameters.pricing_large_item_fee_cap_per_unit,
        DEFAULT_PRICING_CONFIG.largeItemFeeCapPerUnit
      ),
      deliveryPlatformMarginFixed: parseRemoteNumberParam(
        parameters.pricing_delivery_platform_margin_fixed,
        DEFAULT_PRICING_CONFIG.deliveryPlatformMarginFixed
      ),
      deliveryPlatformMinMargin: parseRemoteNumberParam(
        parameters.pricing_delivery_platform_min_margin,
        DEFAULT_PRICING_CONFIG.deliveryPlatformMinMargin
      ),
    };

    return {
      ...DEFAULT_PRICING_CONFIG,
      ...config,
    };
  } catch (error) {
    logger.warn('pricing remote config load failed, using defaults', {
      error: error?.message || String(error),
    });
    return DEFAULT_PRICING_CONFIG;
  }
}

async function getPricingConfigCached() {
  const now = Date.now();
  if (pricingRemoteConfigCache.expiresAtMillis > now) {
    return pricingRemoteConfigCache.value;
  }

  const loaded = await loadPricingConfigFromRemoteConfig();
  pricingRemoteConfigCache = {
    value: loaded,
    expiresAtMillis: now + PRICING_REMOTE_CACHE_MS,
  };
  return loaded;
}

function normalizeOrderItems(itemsRaw) {
  if (!Array.isArray(itemsRaw)) return [];
  return itemsRaw.map((item) => ({
    price: toNumberOrNull(item?.price) || 0,
    quantity: Math.max(1, Math.floor(toNumberOrNull(item?.quantity) || 1)),
  }));
}

function calculateLargeOrderFeeFromItems(itemsRaw, pricingConfig) {
  const config = pricingConfig || DEFAULT_PRICING_CONFIG;
  if (!config.largeItemFeeEnabled) return 0;

  const threshold = Number(config.largeItemThreshold) || DEFAULT_PRICING_CONFIG.largeItemThreshold;
  const baseFee = Number(config.largeItemFeeBase) || DEFAULT_PRICING_CONFIG.largeItemFeeBase;
  const stepAmount = Number(config.largeItemStepAmount) || DEFAULT_PRICING_CONFIG.largeItemStepAmount;
  const stepFee = Number(config.largeItemStepFee) || DEFAULT_PRICING_CONFIG.largeItemStepFee;
  const capPerUnit = Number(config.largeItemFeeCapPerUnit) || DEFAULT_PRICING_CONFIG.largeItemFeeCapPerUnit;

  let totalLargeFee = 0;
  const items = normalizeOrderItems(itemsRaw);
  for (const item of items) {
    if (item.price <= threshold) continue;

    const steps = Math.floor((item.price - threshold) / stepAmount) + 1;
    let unitFee = baseFee + Math.max(0, steps - 1) * stepFee;
    if (capPerUnit > 0 && unitFee > capPerUnit) {
      unitFee = capPerUnit;
    }
    totalLargeFee += unitFee * item.quantity;
  }

  return Math.max(0, Math.round(totalLargeFee));
}

function recalculateOrderTotals(order, pricingConfig) {
  const subtotal = toNumberOrNull(order.total) || 0;
  const deliveryFee = calculateClientDeliveryFeeFromOrder(order, pricingConfig);
  const largeOrderFee = calculateLargeOrderFeeFromItems(order.items, pricingConfig);
  const totalBeforeDiscount = Math.max(0, subtotal + deliveryFee + largeOrderFee);
  const discountAmount = Math.max(0, Math.round(toNumberOrNull(order.discountAmount) || 0));
  const totalWithDelivery = Math.max(0, totalBeforeDiscount - discountAmount);

  return {
    subtotal: Math.round(subtotal),
    deliveryFee: Math.round(deliveryFee),
    largeOrderFee,
    totalBeforeDiscount: Math.round(totalBeforeDiscount),
    discountAmount,
    totalWithDelivery: Math.round(totalWithDelivery),
  };
}

async function syncOrderPricingFields(orderRef, orderData) {
  const pricingConfig = await getPricingConfigCached();
  const recalculated = recalculateOrderTotals(orderData, pricingConfig);
  const storedDeliveryFee = Math.round(toNumberOrNull(orderData.deliveryFee) || 0);
  const storedLargeFee = Math.round(toNumberOrNull(orderData.largeOrderFee) || 0);
  const storedTotalBeforeDiscount = Math.round(
    toNumberOrNull(orderData.totalBeforeDiscount)
      || (Math.round(toNumberOrNull(orderData.totalWithDelivery) || 0)
          + Math.round(toNumberOrNull(orderData.discountAmount) || 0))
  );
  const storedTotalWithDelivery = Math.round(toNumberOrNull(orderData.totalWithDelivery) || 0);

  if (
    storedDeliveryFee === recalculated.deliveryFee &&
    storedLargeFee === recalculated.largeOrderFee &&
    storedTotalBeforeDiscount === recalculated.totalBeforeDiscount &&
    storedTotalWithDelivery === recalculated.totalWithDelivery
  ) {
    return false;
  }

  await orderRef.set({
    deliveryFee: recalculated.deliveryFee,
    largeOrderFee: recalculated.largeOrderFee,
    totalBeforeDiscount: recalculated.totalBeforeDiscount,
    totalWithDelivery: recalculated.totalWithDelivery,
    pricingLastRecalculatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return true;
}

async function settleClientWalletForPaidOrder(orderRef) {
  return db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) {
      return { settled: false, reason: 'order-not-found' };
    }

    const order = orderSnap.data() || {};
    if (normalizePaymentStatus(order.paymentStatus) !== 'paid') {
      return { settled: false, reason: 'order-not-paid' };
    }

    if (order.walletSettledAt) {
      return { settled: false, reason: 'wallet-already-settled' };
    }

    const clientId = String(order.clientId || '').trim();
    const requestedWalletAmount = Math.max(0, Math.round(toSafeNumber(order.walletRequestedAmount)));
    const payableTotal = Math.max(
      0,
      Math.round(toSafeNumber(order.totalWithDelivery ?? order.totalBeforeDiscount ?? order.total))
    );

    if (!clientId || requestedWalletAmount <= 0 || payableTotal <= 0) {
      tx.set(orderRef, {
        walletSettledAt: admin.firestore.FieldValue.serverTimestamp(),
        walletUsedAmount: 0,
        externalPaidAmount: payableTotal,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return { settled: true, usedAmount: 0 };
    }

    const clientRef = db.collection('clients').doc(clientId);
    const clientSnap = await tx.get(clientRef);
    if (!clientSnap.exists) {
      tx.set(orderRef, {
        walletSettledAt: admin.firestore.FieldValue.serverTimestamp(),
        walletUsedAmount: 0,
        externalPaidAmount: payableTotal,
        walletSettlementError: 'client-not-found',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return { settled: true, usedAmount: 0 };
    }

    const clientData = clientSnap.data() || {};
    const currentBalance = Math.round(extractClientWalletBalance(clientData));
    const appliedAmount = Math.min(currentBalance, requestedWalletAmount, payableTotal);
    const nextBalance = Math.max(0, currentBalance - appliedAmount);
    const nowTs = admin.firestore.FieldValue.serverTimestamp();

    tx.set(orderRef, {
      walletSettledAt: nowTs,
      walletBalanceBeforeDebit: currentBalance,
      walletBalanceAfterDebit: nextBalance,
      walletUsedAmount: appliedAmount,
      externalPaidAmount: Math.max(0, payableTotal - appliedAmount),
      walletSettlementError: admin.firestore.FieldValue.delete(),
      updatedAt: nowTs,
    }, { merge: true });

    if (appliedAmount > 0) {
      tx.set(clientRef, {
        walletBalance: nextBalance,
        wallet: nextBalance,
        updatedAt: nowTs,
      }, { merge: true });

      tx.set(clientRef.collection('walletTransactions').doc(), {
        type: 'order_payment',
        orderId: orderSnap.id,
        amount: appliedAmount,
        balanceBefore: currentBalance,
        balanceAfter: nextBalance,
        paymentMethod: String(order.paymentMethod || '').trim(),
        createdAt: nowTs,
      });
    }

    return {
      settled: true,
      usedAmount: appliedAmount,
      balanceAfter: nextBalance,
    };
  });
}

function getDriverCoords(driver) {
  const fromGeoPoint = extractLatLng(driver.location);
  if (fromGeoPoint) return fromGeoPoint;

  const lat = toNumberOrNull(driver.lat ?? driver.latitude);
  const lng = toNumberOrNull(driver.lng ?? driver.longitude);
  if (lat != null && lng != null) return { lat, lng };

  return null;
}

function haversineKm(lat1, lng1, lat2, lng2) {
  const toRad = (deg) => (deg * Math.PI) / 180;
  const earthRadiusKm = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}

async function setStatus(ref, status, extra = {}) {
  await ref.update({
    orderStatus: status,
    status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...extra,
  });
}

async function assignNextCourier(orderRef) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) return { assigned: false, reason: 'order-not-found' };

    const order = snap.data() || {};
    const status = getStatus(order);

    if (!isWaitingCourierStatus(status)) {
      return { assigned: false, reason: 'status-not-assignable' };
    }

    if (order.assignedDriverId) {
      return { assigned: false, reason: 'already-assigned' };
    }

    let stateId = orderStateId(order);

    const now = admin.firestore.Timestamp.now();
    const candidatesRaw = Array.isArray(order.candidateDrivers) ? order.candidateDrivers : [];
    const previousCycleStartedAt = order.assignmentCycleStartedAt;
    const cycleStartedMillis = previousCycleStartedAt?.toMillis?.() || 0;
    const cycleExpired =
      !cycleStartedMillis ||
      (now.toMillis() - cycleStartedMillis) >= ASSIGNMENT_CYCLE_RESET_SECONDS * 1000;

    let restaurantCoords = getOrderRestaurantCoords(order);

    if ((!stateId || !restaurantCoords) && order.restaurantId) {
      const restaurantRef = db.collection('restaurants').doc(String(order.restaurantId));
      const restaurantSnap = await tx.get(restaurantRef);
      if (restaurantSnap.exists) {
        const restaurantData = restaurantSnap.data() || {};
        if (!stateId) {
          const resolvedStateId = restaurantStateId(restaurantData);
          if (resolvedStateId) {
            stateId = resolvedStateId;
            tx.update(orderRef, {
              stateId,
              region: stateId,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
        if (!restaurantCoords) {
          restaurantCoords =
            extractLatLng(restaurantData.location) ||
            extractLatLng(restaurantData.defaultLocation) ||
            (() => {
              const lat = toNumberOrNull(restaurantData.latitude ?? restaurantData.lat ?? restaurantData.restaurantLat);
              const lng = toNumberOrNull(restaurantData.longitude ?? restaurantData.lng ?? restaurantData.restaurantLng);
              return lat != null && lng != null ? { lat, lng } : null;
            })();
        }
      }
    }

    const driverSnap = await tx.get(
      db.collection('drivers')
        .where('available', '==', true)
        .limit(80)
    );

    const availableDriverIds = new Set(driverSnap.docs.map((d) => d.id));
    let candidates = candidatesRaw.filter((id) => availableDriverIds.has(String(id)));
    if (cycleExpired) {
      candidates = [];
    }

    let remainingDrivers = driverSnap.docs.filter((d) => !candidates.includes(d.id));
    let assignmentBackoffReason = 'no-available-next-driver-in-cycle';
    const availableDriversCount = remainingDrivers.length;
    let sameStateDriversCount = availableDriversCount;

    if (stateId) {
      const sameStateDrivers = remainingDrivers.filter((d) => {
        const data = d.data() || {};
        return driverStateId(data) === stateId;
      });
      sameStateDriversCount = sameStateDrivers.length;
      remainingDrivers = sameStateDrivers;
      if (sameStateDrivers.length === 0) {
        assignmentBackoffReason = 'no-driver-in-same-state';
      }
    }

    let nextDriver = null;
    let nextDriverDistanceKm = null;

    if (remainingDrivers.length > 0) {
      if (!restaurantCoords) {
        nextDriver = remainingDrivers[0];
      } else {
        const ranked = remainingDrivers.map((d) => {
          const driverData = d.data() || {};
          const driverCoords = getDriverCoords(driverData);
          const distanceKm = driverCoords
            ? haversineKm(
              restaurantCoords.lat,
              restaurantCoords.lng,
              driverCoords.lat,
              driverCoords.lng
            )
            : Number.POSITIVE_INFINITY;
          return { doc: d, distanceKm };
        }).sort((a, b) => a.distanceKm - b.distanceKm);

        const withinRange = ranked.filter((item) =>
          Number.isFinite(item.distanceKm) && item.distanceKm <= MAX_DRIVER_RESTAURANT_DISTANCE_KM
        );

        if (withinRange.length > 0) {
          nextDriver = withinRange[0].doc;
          nextDriverDistanceKm = withinRange[0].distanceKm;
        } else {
          assignmentBackoffReason = 'no-driver-within-20km';
        }
      }
    }

    if (!nextDriver) {
      tx.update(orderRef, {
        candidateDrivers: candidates,
        assignmentCycleStartedAt: cycleExpired ? now : (previousCycleStartedAt || now),
        assignmentLastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        assignmentOrderStateId: stateId || '',
        assignmentAvailableDriversCount: availableDriversCount,
        assignmentSameStateDriversCount: sameStateDriversCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(orderRef, {
        assignmentBackoffReason,
      });
      return { assigned: false, reason: 'no-driver-found' };
    }

    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + COURIER_OFFER_TIMEOUT_SECONDS * 1000
    );

    const nextCandidates = [...candidates, nextDriver.id];

    tx.update(orderRef, {
      offeredDriverId: nextDriver.id,
      offerStartedAt: now,
      offerExpiresAt: expiresAt,
      assignmentAttempts: Number(order.assignmentAttempts || 0) + 1,
      candidateDrivers: nextCandidates,
      assignmentCycleStartedAt: cycleExpired ? now : (previousCycleStartedAt || now),
      orderStatus: 'courier_offer_pending',
      status: 'courier_offer_pending',
      offeredDriverDistanceKm: nextDriverDistanceKm,
      maxDriverDistanceKm: MAX_DRIVER_RESTAURANT_DISTANCE_KM,
      assignmentLastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      assignmentOrderStateId: stateId || '',
      assignmentAvailableDriversCount: availableDriversCount,
      assignmentSameStateDriversCount: sameStateDriversCount,
      assignmentBackoffReason: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(db.collection('driverNotifications').doc(), {
      driverId: nextDriver.id,
      orderId: snap.id,
      type: 'courier_offer',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt,
      read: false,
    });

    return { assigned: true, driverId: nextDriver.id };
  });
}

exports.assignWaitingOrders = onSchedule({
  schedule: 'every 1 minutes',
  region: SCHEDULE_REGION,
}, async () => {
  const waitingByOrderStatus = await db
    .collection('orders')
    .where('orderStatus', 'in', ['courier_searching', 'قيد التجهيز'])
    .limit(100)
    .get();

  const waitingByLegacyStatus = await db
    .collection('orders')
    .where('status', 'in', ['courier_searching', 'قيد التجهيز'])
    .limit(100)
    .get();

  const waitingMap = new Map();
  for (const doc of waitingByOrderStatus.docs) {
    waitingMap.set(doc.id, doc);
  }
  for (const doc of waitingByLegacyStatus.docs) {
    waitingMap.set(doc.id, doc);
  }

  const waiting = Array.from(waitingMap.values());

  let assignedCount = 0;
  for (const doc of waiting) {
    const order = doc.data() || {};
    if (order.assignedDriverId) continue;
    if (!isWaitingCourierStatus(getStatus(order))) continue;
    const result = await assignNextCourier(doc.ref);
    if (result.assigned) assignedCount += 1;
  }

  logger.info('assignWaitingOrders complete', {
    scanned: waiting.length,
    assignedCount,
  });
});

exports.handleCourierOfferTimeouts = onSchedule({
  schedule: 'every 1 minutes',
  region: SCHEDULE_REGION,
}, async () => {
  const now = admin.firestore.Timestamp.now();
  const snap = await db
    .collection('orders')
    .where('orderStatus', '==', 'courier_offer_pending')
    .limit(100)
    .get();

  let processed = 0;
  for (const doc of snap.docs) {
    const ref = doc.ref;
    const data = doc.data() || {};
    const offeredDriverId = String(data.offeredDriverId || '').trim();
    const offerExpiresAt = data.offerExpiresAt;

    let shouldReassign = false;
    if (offerExpiresAt?.toMillis?.() && offerExpiresAt.toMillis() <= now.toMillis()) {
      shouldReassign = true;
    }

    if (!shouldReassign && offeredDriverId) {
      const driverSnap = await db.collection('drivers').doc(offeredDriverId).get();
      const driverData = driverSnap.data() || {};
      if (!driverSnap.exists || driverData.available !== true) {
        shouldReassign = true;
      }
    }

    if (!shouldReassign) {
      continue;
    }

    await db.runTransaction(async (tx) => {
      const fresh = await tx.get(ref);
      if (!fresh.exists) return;
      const order = fresh.data() || {};
      if (getStatus(order) !== 'courier_offer_pending') return;

      const activeOfferedDriverId = String(order.offeredDriverId || '').trim();
      const existingCandidates = Array.isArray(order.candidateDrivers)
        ? order.candidateDrivers.map(String)
        : [];
      const nextCandidates = activeOfferedDriverId
        ? Array.from(new Set([...existingCandidates, activeOfferedDriverId]))
        : existingCandidates;

      tx.update(ref, {
        assignedDriverId: admin.firestore.FieldValue.delete(),
        offeredDriverId: admin.firestore.FieldValue.delete(),
        offerStartedAt: admin.firestore.FieldValue.delete(),
        offerExpiresAt: admin.firestore.FieldValue.delete(),
        candidateDrivers: nextCandidates,
        orderStatus: 'courier_searching',
        status: 'courier_searching',
        lastOfferTimeoutAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await assignNextCourier(ref);
    processed += 1;
  }

  logger.info('handleCourierOfferTimeouts complete', {
    scanned: snap.size,
    processed,
  });
});

exports.recalculateRecentOrderPricing = onSchedule({
  schedule: 'every 5 minutes',
  region: SCHEDULE_REGION,
}, async () => {
  const pricingConfig = await getPricingConfigCached();
  const windowStart = admin.firestore.Timestamp.fromMillis(
    Date.now() - PRICING_RECALC_WINDOW_MINUTES * 60 * 1000
  );

  const recentOrders = await db
    .collection('orders')
    .where('updatedAt', '>=', windowStart)
    .limit(PRICING_RECALC_LIMIT)
    .get();

  if (recentOrders.empty) {
    logger.info('recalculateRecentOrderPricing complete', {
      scanned: 0,
      updated: 0,
    });
    return;
  }

  let updatedCount = 0;
  let opCount = 0;
  let batch = db.batch();

  for (const doc of recentOrders.docs) {
    const order = doc.data() || {};
    const recalculated = recalculateOrderTotals(order, pricingConfig);
    const storedDeliveryFee = Math.round(toNumberOrNull(order.deliveryFee) || 0);
    const storedLargeFee = Math.round(toNumberOrNull(order.largeOrderFee) || 0);
    const storedTotalBeforeDiscount = Math.round(
      toNumberOrNull(order.totalBeforeDiscount)
        || (Math.round(toNumberOrNull(order.totalWithDelivery) || 0)
            + Math.round(toNumberOrNull(order.discountAmount) || 0))
    );
    const storedTotalWithDelivery = Math.round(toNumberOrNull(order.totalWithDelivery) || 0);

    if (
      storedDeliveryFee === recalculated.deliveryFee &&
      storedLargeFee === recalculated.largeOrderFee &&
      storedTotalBeforeDiscount === recalculated.totalBeforeDiscount &&
      storedTotalWithDelivery === recalculated.totalWithDelivery
    ) {
      continue;
    }

    batch.update(doc.ref, {
      deliveryFee: recalculated.deliveryFee,
      largeOrderFee: recalculated.largeOrderFee,
      totalBeforeDiscount: recalculated.totalBeforeDiscount,
      totalWithDelivery: recalculated.totalWithDelivery,
      pricingLastRecalculatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    opCount += 1;
    updatedCount += 1;

    if (opCount >= 400) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
    }
  }

  if (opCount > 0) {
    await batch.commit();
  }

  logger.info('recalculateRecentOrderPricing complete', {
    scanned: recentOrders.size,
    updated: updatedCount,
    pricing: pricingConfig,
  });
});

exports.courierRespondToOffer = onCall({ region: REGION }, async (request) => {
  const { orderId, driverId, decision } = request.data || {};
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }
  if (!orderId || !driverId || !decision) {
    throw new HttpsError('invalid-argument', 'orderId, driverId, decision are required');
  }
  if (String(request.auth.uid) !== String(driverId)) {
    throw new HttpsError('permission-denied', 'driverId must match authenticated user');
  }
  if (decision !== 'accept' && decision !== 'reject') {
    throw new HttpsError('invalid-argument', 'decision must be accept or reject');
  }

  const orderRef = db.collection('orders').doc(orderId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) throw new HttpsError('not-found', 'Order not found');

    const order = snap.data() || {};
    const status = getStatus(order);
    if (status !== 'courier_offer_pending') {
      throw new HttpsError('failed-precondition', 'Order is not in courier_offer_pending');
    }
    if (String(order.offeredDriverId || '') !== String(driverId)) {
      throw new HttpsError('permission-denied', 'This offer is not assigned to this driver');
    }

    if (decision === 'accept') {
      const driverFee = calculateDriverFeeFromOrder(order);
      tx.update(orderRef, {
        orderStatus: 'courier_assigned',
        status: 'courier_assigned',
        assignedDriverId: driverId,
        deliveryFeeForDriver: driverFee,
        offeredDriverId: admin.firestore.FieldValue.delete(),
        offerStartedAt: admin.firestore.FieldValue.delete(),
        offerExpiresAt: admin.firestore.FieldValue.delete(),
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        offerAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    tx.update(orderRef, {
      assignedDriverId: admin.firestore.FieldValue.delete(),
      offeredDriverId: admin.firestore.FieldValue.delete(),
      offerStartedAt: admin.firestore.FieldValue.delete(),
      offerExpiresAt: admin.firestore.FieldValue.delete(),
      orderStatus: 'courier_searching',
      status: 'courier_searching',
      rejectedByDrivers: admin.firestore.FieldValue.arrayUnion(driverId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  if (decision === 'reject') {
    await assignNextCourier(orderRef);
  }

  return { ok: true };
});

exports.setUserAdminRole = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const callerUid = request.auth.uid;
  const callerEmail = String(request.auth.token?.email || '').toLowerCase().trim();
  const { email, uid, active } = request.data || {};
  const targetEmail = String(email || '').toLowerCase().trim();
  const targetUid = String(uid || '').trim();
  const activeFlag = active !== false;

  if (!targetEmail && !targetUid) {
    throw new HttpsError('invalid-argument', 'Provide uid or email');
  }

  const callerIsAdmin = await isAdminUid(callerUid);
  const bootstrapAllowed = callerIsAdmin ? false : await canBootstrapFirstAdmin(request.auth);
  if (!callerIsAdmin && !bootstrapAllowed) {
    throw new HttpsError('permission-denied', 'Only admins can grant admin role');
  }

  let userRecord;
  try {
    if (targetUid) {
      userRecord = await admin.auth().getUser(targetUid);
    } else {
      userRecord = await admin.auth().getUserByEmail(targetEmail);
    }
  } catch (_) {
    throw new HttpsError('not-found', 'User not found in Firebase Auth');
  }

  if (bootstrapAllowed && userRecord.uid !== callerUid) {
    throw new HttpsError('permission-denied', 'Bootstrap can only promote current caller');
  }
  if (bootstrapAllowed && String(userRecord.email || '').toLowerCase().trim() !== callerEmail) {
    throw new HttpsError('permission-denied', 'Bootstrap email mismatch');
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const adminRef = db.collection('admins').doc(userRecord.uid);
  const existing = await adminRef.get();

  await adminRef.set({
    uid: userRecord.uid,
    email: String(userRecord.email || '').toLowerCase(),
    role: 'admin',
    active: activeFlag,
    updatedAt: now,
    ...(existing.exists ? {} : { createdAt: now }),
    updatedBy: callerUid,
  }, { merge: true });

  return {
    ok: true,
    uid: userRecord.uid,
    email: String(userRecord.email || '').toLowerCase(),
    bootstrapUsed: bootstrapAllowed,
  };
});

exports.submitRestaurantApplication = onCall({ region: REGION }, async (request) => {
  const data = request.data || {};
  const email = String(data.email || '').toLowerCase().trim();
  const password = String(data.password || '');
  const name = String(data.name || '').trim();
  const phone = String(data.phone || '').trim();
  const commercialRecordNumber = String(data.commercialRecordNumber || '').trim();
  const commercialRecordImageUrl = String(data.commercialRecordImageUrl || '').trim();

  if (!email || !email.includes('@')) {
    throw new HttpsError('invalid-argument', 'Valid email is required');
  }
  if (password.length < 6) {
    throw new HttpsError('invalid-argument', 'Password must be at least 6 characters');
  }
  if (!name || !phone || !commercialRecordNumber || !commercialRecordImageUrl) {
    throw new HttpsError('invalid-argument', 'Missing required application fields');
  }

  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
    if (userRecord.disabled) {
      userRecord = await admin.auth().updateUser(userRecord.uid, {
        password,
        displayName: name || undefined,
        disabled: true,
      });
    }
  } catch (err) {
    if (err instanceof HttpsError) throw err;
    const code = String(err?.code || '');
    if (code === 'auth/user-not-found') {
      userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: name || undefined,
        disabled: true,
      });
    } else {
      throw new HttpsError('internal', err?.message || 'Failed to prepare user account');
    }
  }

  const ownerUid = userRecord.uid;
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection('restaurantApplications').doc(ownerUid).set({
    name,
    phone,
    commercialRecordNumber,
    commercialRecordImageUrl,
    email,
    ownerUid,
    restaurantId: ownerUid,
    status: 'pending',
    approvalStatus: 'pending',
    isApproved: false,
    submittedAt: now,
    updatedAt: now,
  }, { merge: true });

  return {
    ok: true,
    applicationId: ownerUid,
    ownerUid,
    email,
  };
});

exports.submitCourierApplication = onCall({ region: REGION }, async (request) => {
  const data = request.data || {};
  const email = String(data.email || '').toLowerCase().trim();
  const password = String(data.password || '');
  const name = String(data.name || '').trim();
  const phone = String(data.phone || '').trim();
  const vehicleType = String(data.vehicleType || '').trim();
  const vehiclePlate = String(data.vehiclePlate || '').trim();
  const nationalIdNumber = String(data.nationalIdNumber || '').trim();
  const idImageUrl = String(data.idImageUrl || '').trim();

  if (!email || !email.includes('@')) {
    throw new HttpsError('invalid-argument', 'Valid email is required');
  }
  if (password.length < 6) {
    throw new HttpsError('invalid-argument', 'Password must be at least 6 characters');
  }
  if (!name || !phone || !vehicleType || !vehiclePlate || !nationalIdNumber || !idImageUrl) {
    throw new HttpsError('invalid-argument', 'Missing required application fields');
  }

  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
    if (userRecord.disabled) {
      userRecord = await admin.auth().updateUser(userRecord.uid, {
        password,
        displayName: name || undefined,
        disabled: true,
      });
    }
  } catch (err) {
    const code = String(err?.code || '');
    if (code === 'auth/user-not-found') {
      userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: name || undefined,
        disabled: true,
      });
    } else {
      throw new HttpsError('internal', err?.message || 'Failed to prepare user account');
    }
  }

  const ownerUid = userRecord.uid;
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection('courierApplications').doc(ownerUid).set({
    name,
    phone,
    vehicleType,
    vehiclePlate,
    nationalIdNumber,
    idImageUrl,
    email,
    ownerUid,
    driverId: ownerUid,
    status: 'pending',
    approvalStatus: 'pending',
    isApproved: false,
    available: false,
    submittedAt: now,
    updatedAt: now,
  }, { merge: true });

  return {
    ok: true,
    applicationId: ownerUid,
    ownerUid,
    email,
  };
});

exports.createStoreChangeRequest = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const callerUid = request.auth.uid;
  const callerEmail = String(request.auth.token?.email || '').toLowerCase().trim();
  const callerIsAdmin = await isAdminUid(callerUid);
  if (!callerIsAdmin && !isStaticAdminEmail(callerEmail)) {
    throw new HttpsError('permission-denied', 'Only admins can create change requests');
  }

  const restaurantId = String(request.data?.restaurantId || '').trim();
  const type = String(request.data?.type || '').trim();
  const reason = String(request.data?.reason || '').trim();
  const payload = request.data?.payload || {};

  if (!restaurantId || !type) {
    throw new HttpsError('invalid-argument', 'restaurantId and type are required');
  }

  const allowedTypes = ['updateStoreFields', 'setTemporarilyClosed', 'setAutoAcceptOrders'];
  if (!allowedTypes.includes(type)) {
    throw new HttpsError('invalid-argument', 'Unsupported change request type');
  }

  const restaurantSnap = await db.collection('restaurants').doc(restaurantId).get();
  if (!restaurantSnap.exists) {
    throw new HttpsError('not-found', 'Restaurant not found');
  }

  const restaurant = restaurantSnap.data() || {};
  const now = admin.firestore.FieldValue.serverTimestamp();

  const requestRef = await db.collection('storeChangeRequests').add({
    restaurantId,
    restaurantName: String(restaurant.name || ''),
    type,
    reason,
    payload,
    status: 'pending',
    createdByUid: callerUid,
    createdByEmail: callerEmail,
    createdAt: now,
    updatedAt: now,
  });

  return {
    ok: true,
    requestId: requestRef.id,
  };
});

exports.respondStoreChangeRequest = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const requestId = String(request.data?.requestId || '').trim();
  const decision = String(request.data?.decision || '').trim();
  if (!requestId || !['approved', 'rejected'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'requestId and decision(approved/rejected) are required');
  }

  const actorUid = request.auth.uid;
  const actorEmail = String(request.auth.token?.email || '').toLowerCase().trim();
  const actorIsAdmin = (await isAdminUid(actorUid)) || isStaticAdminEmail(actorEmail);

  const changeRef = db.collection('storeChangeRequests').doc(requestId);
  const changeSnap = await changeRef.get();
  if (!changeSnap.exists) {
    throw new HttpsError('not-found', 'Change request not found');
  }

  const change = changeSnap.data() || {};
  const restaurantId = String(change.restaurantId || '').trim();
  if (!restaurantId) {
    throw new HttpsError('failed-precondition', 'Change request restaurantId is missing');
  }

  if (!actorIsAdmin && actorUid !== restaurantId) {
    throw new HttpsError('permission-denied', 'Only target store or admin can respond');
  }

  if (String(change.status || '') !== 'pending') {
    return {
      ok: true,
      alreadyProcessed: true,
      status: change.status || '',
    };
  }

  if (decision === 'approved') {
    const type = String(change.type || '');
    const payload = change.payload || {};
    const restaurantRef = db.collection('restaurants').doc(restaurantId);
    const patch = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (type === 'setTemporarilyClosed') {
      patch.temporarilyClosed = payload.value === true;
    } else if (type === 'setAutoAcceptOrders') {
      patch.autoAcceptOrders = payload.value === true;
    } else if (type === 'updateStoreFields') {
      const fields = payload.fields || {};
      const allowedFieldKeys = [
        'name',
        'phone',
        'address',
        'deliveryDiscountPercentage',
        'temporarilyClosed',
        'autoAcceptOrders',
      ];
      for (const [key, value] of Object.entries(fields)) {
        if (allowedFieldKeys.includes(key)) {
          patch[key] = value;
        }
      }
    }

    await restaurantRef.set(patch, { merge: true });
  }

  await changeRef.set({
    status: decision,
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    reviewedByUid: actorUid,
    reviewedByEmail: actorEmail,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return {
    ok: true,
    status: decision,
  };
});

exports.approveRestaurantApplication = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const callerUid = request.auth.uid;
  const callerEmail = String(request.auth.token?.email || '').toLowerCase().trim();
  const callerIsAdmin = await isAdminUid(callerUid);
  const staticAdminAllowed = isStaticAdminEmail(callerEmail);
  if (!callerIsAdmin && !staticAdminAllowed) {
    throw new HttpsError('permission-denied', 'Only admins can approve applications');
  }

  const applicationId = String(request.data?.applicationId || '').trim();
  if (!applicationId) {
    throw new HttpsError('invalid-argument', 'applicationId is required');
  }

  const appRef = db.collection('restaurantApplications').doc(applicationId);
  const appSnap = await appRef.get();
  if (!appSnap.exists) {
    throw new HttpsError('not-found', 'Application not found');
  }

  const appData = appSnap.data() || {};
  const appEmail = String(appData.email || '').toLowerCase().trim();
  if (!appEmail) {
    throw new HttpsError('failed-precondition', 'Application email is missing');
  }

  let userRecord = null;
  const ownerUid = String(appData.ownerUid || '').trim();

  if (ownerUid) {
    try {
      userRecord = await admin.auth().getUser(ownerUid);
    } catch (_) {
      userRecord = null;
    }
  }

  if (!userRecord) {
    try {
      userRecord = await admin.auth().getUserByEmail(appEmail);
    } catch (_) {
      userRecord = null;
    }
  }

  let authCreated = false;
  if (!userRecord) {
    userRecord = await admin.auth().createUser({
      email: appEmail,
      password: createTemporaryPassword(),
      displayName: String(appData.name || '').trim() || undefined,
      disabled: true,
    });
    authCreated = true;
  }

  if (userRecord.disabled) {
    await admin.auth().updateUser(userRecord.uid, { disabled: false });
  }

  const restaurantId = userRecord.uid;
  const now = admin.firestore.FieldValue.serverTimestamp();

  await appRef.set({
    status: 'approved',
    approvalStatus: 'approved',
    isApproved: true,
    ownerUid: restaurantId,
    restaurantId,
    reviewedAt: now,
    reviewedBy: callerUid,
    updatedAt: now,
    ...(authCreated ? { authCreatedByApproval: true } : {}),
  }, { merge: true });

  await db.collection('restaurants').doc(restaurantId).set({
    name: String(appData.name || '').trim(),
    phone: String(appData.phone || '').trim(),
    email: appEmail,
    commercialRecordNumber: String(appData.commercialRecordNumber || '').trim(),
    commercialRecordImageUrl: String(appData.commercialRecordImageUrl || '').trim(),
    ownerUid: restaurantId,
    approvalStatus: 'approved',
    isApproved: true,
    temporarilyClosed: false,
    updatedAt: now,
    createdAt: now,
  }, { merge: true });

  return {
    ok: true,
    restaurantId,
    email: appEmail,
    authCreated,
  };
});

exports.approveCourierApplication = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const callerUid = request.auth.uid;
  const callerEmail = String(request.auth.token?.email || '').toLowerCase().trim();
  const callerIsAdmin = await isAdminUid(callerUid);
  const staticAdminAllowed = isStaticAdminEmail(callerEmail);
  if (!callerIsAdmin && !staticAdminAllowed) {
    throw new HttpsError('permission-denied', 'Only admins can approve applications');
  }

  const applicationId = String(request.data?.applicationId || '').trim();
  if (!applicationId) {
    throw new HttpsError('invalid-argument', 'applicationId is required');
  }

  const appRef = db.collection('courierApplications').doc(applicationId);
  const appSnap = await appRef.get();
  if (!appSnap.exists) {
    throw new HttpsError('not-found', 'Application not found');
  }

  const appData = appSnap.data() || {};
  const appEmail = String(appData.email || '').toLowerCase().trim();
  if (!appEmail) {
    throw new HttpsError('failed-precondition', 'Application email is missing');
  }

  let userRecord = null;
  const ownerUid = String(appData.ownerUid || '').trim();

  if (ownerUid) {
    try {
      userRecord = await admin.auth().getUser(ownerUid);
    } catch (_) {
      userRecord = null;
    }
  }

  if (!userRecord) {
    try {
      userRecord = await admin.auth().getUserByEmail(appEmail);
    } catch (_) {
      userRecord = null;
    }
  }

  let authCreated = false;
  if (!userRecord) {
    userRecord = await admin.auth().createUser({
      email: appEmail,
      password: createTemporaryPassword(),
      displayName: String(appData.name || '').trim() || undefined,
      disabled: true,
    });
    authCreated = true;
  }

  if (userRecord.disabled) {
    await admin.auth().updateUser(userRecord.uid, { disabled: false });
  }

  const driverId = userRecord.uid;
  const now = admin.firestore.FieldValue.serverTimestamp();

  await appRef.set({
    status: 'approved',
    approvalStatus: 'approved',
    isApproved: true,
    ownerUid: driverId,
    driverId,
    reviewedAt: now,
    reviewedBy: callerUid,
    updatedAt: now,
    ...(authCreated ? { authCreatedByApproval: true } : {}),
  }, { merge: true });

  await db.collection('drivers').doc(driverId).set({
    name: String(appData.name || '').trim(),
    phone: String(appData.phone || '').trim(),
    email: appEmail,
    vehicleType: String(appData.vehicleType || '').trim(),
    vehiclePlate: String(appData.vehiclePlate || '').trim(),
    nationalIdNumber: String(appData.nationalIdNumber || '').trim(),
    idImageUrl: String(appData.idImageUrl || '').trim(),
    ownerUid: driverId,
    approvalStatus: 'approved',
    isApproved: true,
    available: false,
    updatedAt: now,
    createdAt: now,
  }, { merge: true });

  return {
    ok: true,
    driverId,
    email: appEmail,
    authCreated,
  };
});

exports.normalizeStateIdsBatch = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const callerUid = request.auth.uid;
  const callerEmail = String(request.auth.token?.email || '').toLowerCase().trim();
  const callerIsAdmin = await isAdminUid(callerUid);
  const staticAdminAllowed = isStaticAdminEmail(callerEmail);
  if (!callerIsAdmin && !staticAdminAllowed) {
    throw new HttpsError('permission-denied', 'Only admins can normalize states');
  }

  const rawCollections = Array.isArray(request.data?.collections)
    ? request.data.collections
    : ['clients', 'restaurants', 'drivers'];
  const collections = rawCollections
    .map((v) => String(v || '').trim())
    .filter((v) => ['clients', 'restaurants', 'drivers'].includes(v));
  if (collections.length === 0) {
    throw new HttpsError('invalid-argument', 'collections must include clients/restaurants/drivers');
  }

  const requestedLimit = Number(request.data?.limit || 200);
  const limit = Number.isFinite(requestedLimit)
    ? Math.max(1, Math.min(500, Math.floor(requestedLimit)))
    : 200;

  const result = {
    ok: true,
    collections,
    scanned: 0,
    updated: 0,
    skipped: 0,
    details: {},
  };

  for (const collectionName of collections) {
    const snap = await db.collection(collectionName).limit(limit).get();
    let updated = 0;
    let skipped = 0;
    let scanned = 0;
    const batch = db.batch();

    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data() || {};

      let derivedStateId = '';
      if (collectionName === 'clients') {
        derivedStateId = normalizeStateId(
          data.stateId || data.state || data.region || data.city
        );

        if (!derivedStateId) {
          const defaultAddressId = String(data.defaultAddressId || '').trim();
          if (defaultAddressId) {
            try {
              const addressSnap = await db
                .collection('clients')
                .doc(doc.id)
                .collection('addresses')
                .doc(defaultAddressId)
                .get();
              if (addressSnap.exists) {
                const addressData = addressSnap.data() || {};
                derivedStateId = normalizeStateId(
                  addressData.stateId ||
                  addressData.state ||
                  addressData.region ||
                  addressData.city ||
                  addressData.administrativeArea
                );
              }
            } catch (_) {
              // ignore single client address read errors
            }
          }
        }
      } else {
        derivedStateId = normalizeStateId(
          data.stateId || data.state || data.region || data.city
        );
      }

      if (!derivedStateId) {
        skipped += 1;
        continue;
      }

      const currentStateId = normalizeStateId(data.stateId);
      if (currentStateId === derivedStateId && String(data.region || '').trim() === derivedStateId) {
        skipped += 1;
        continue;
      }

      batch.set(doc.ref, {
        stateId: derivedStateId,
        region: derivedStateId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      updated += 1;
    }

    if (updated > 0) {
      await batch.commit();
    }

    result.scanned += scanned;
    result.updated += updated;
    result.skipped += skipped;
    result.details[collectionName] = { scanned, updated, skipped };
  }

  return result;
});

exports.getAdminRemoteConfigSettings = onCall({ region: REGION }, async (request) => {
  await ensureAdminCallable(request, 'Only admins can read remote config');

  const includeParameters = request.data?.includeParameters !== false;
  const template = await admin.remoteConfig().getTemplate();
  const parameters = template?.parameters || {};

  const rolloutEnabled = parseRemoteBooleanParam(parameters.client_state_rollout_enabled, false);
  const guardDistance = parseRemoteNumberParam(parameters.client_state_guard_distance_km, 120);
  const enabledCitiesCsv = String(parameters.client_enabled_states_csv?.defaultValue?.value || '').trim();
  const blockMessage = String(
    parameters.client_state_rollout_block_message?.defaultValue?.value || 'لسه ما جيناكم في منطقتكم. قريبًا بإذن الله.'
  ).trim();

  const response = {
    ok: true,
    rollout: {
      enabled: rolloutEnabled,
      guardDistanceKm: guardDistance,
      enabledCitiesCsv,
      enabledCities: parseRolloutCsvToList(enabledCitiesCsv),
      blockMessage,
    },
    version: template?.version?.versionNumber || null,
    updatedBy: template?.version?.updateUser?.email || '',
    updatedAt: template?.version?.updateTime || '',
  };

  if (includeParameters) {
    response.parameters = Object.entries(parameters)
      .map(([key, param]) => ({
        key,
        value: String(param?.defaultValue?.value ?? ''),
        description: String(param?.description || ''),
        valueType: String(param?.valueType || 'STRING'),
        hasConditionalValues: !!(param?.conditionalValues && Object.keys(param.conditionalValues).length),
      }))
      .sort((a, b) => a.key.localeCompare(b.key));
  }

  return response;
});

exports.updateAdminRemoteConfigSettings = onCall({ region: REGION }, async (request) => {
  await ensureAdminCallable(request, 'Only admins can update remote config');

  const payload = request.data || {};
  const rollout = payload.rollout && typeof payload.rollout === 'object' ? payload.rollout : null;
  const rawParameters = Array.isArray(payload.parameters) ? payload.parameters : [];

  const callerUid = request.auth?.uid || '';
  const callerEmail = String(request.auth?.token?.email || '').toLowerCase().trim();

  if (!rollout && rawParameters.length === 0) {
    throw new HttpsError('invalid-argument', 'Nothing to update');
  }

  const template = await admin.remoteConfig().getTemplate();
  template.parameters = template.parameters || {};

  const touchedKeys = new Set();

  if (rollout) {
    const currentEnabled = parseRemoteBooleanParam(template.parameters.client_state_rollout_enabled, false);
    const currentGuard = parseRemoteNumberParam(template.parameters.client_state_guard_distance_km, 120);
    const currentCsv = String(template.parameters.client_enabled_states_csv?.defaultValue?.value || '').trim();
    const currentBlock = String(
      template.parameters.client_state_rollout_block_message?.defaultValue?.value || 'لسه ما جيناكم في منطقتكم. قريبًا بإذن الله.'
    ).trim();

    const enabled = parseBooleanLike(rollout.enabled, currentEnabled);
    const guardDistanceKm = Math.max(1, Math.min(500, Math.round(parseNumberLike(rollout.guardDistanceKm, currentGuard))));
    const csvList = Array.isArray(rollout.enabledCities)
      ? rollout.enabledCities.map((item) => normalizeRolloutToken(item)).filter(Boolean)
      : parseRolloutCsvToList(rollout.enabledCitiesCsv ?? currentCsv);
    const enabledCitiesCsv = [...new Set(csvList)].join(',');
    const blockMessage = String(rollout.blockMessage ?? currentBlock).trim() || currentBlock;

    template.parameters.client_state_rollout_enabled = {
      ...(template.parameters.client_state_rollout_enabled || {}),
      defaultValue: { value: enabled ? 'true' : 'false' },
      description: 'Admin controlled rollout switch for city/state gating in client app',
      valueType: 'BOOLEAN',
    };
    touchedKeys.add('client_state_rollout_enabled');

    template.parameters.client_state_guard_distance_km = {
      ...(template.parameters.client_state_guard_distance_km || {}),
      defaultValue: { value: String(guardDistanceKm) },
      description: 'Maximum distance in KM allowed between client and restaurant before blocking order',
      valueType: 'NUMBER',
    };
    touchedKeys.add('client_state_guard_distance_km');

    template.parameters.client_enabled_states_csv = {
      ...(template.parameters.client_enabled_states_csv || {}),
      defaultValue: { value: enabledCitiesCsv },
      description: 'Comma separated enabled cities/states for client rollout',
      valueType: 'STRING',
    };
    touchedKeys.add('client_enabled_states_csv');

    template.parameters.client_state_rollout_block_message = {
      ...(template.parameters.client_state_rollout_block_message || {}),
      defaultValue: { value: blockMessage },
      description: 'Message shown when city/state is outside rollout scope',
      valueType: 'STRING',
    };
    touchedKeys.add('client_state_rollout_block_message');
  }

  for (const item of rawParameters) {
    const key = String(item?.key || '').trim();
    if (!key) continue;

    const entry = template.parameters[key] || {};
    const nextValue = stringifyRemoteValue(item?.value);

    template.parameters[key] = {
      ...entry,
      defaultValue: { value: nextValue },
      valueType: String(item?.valueType || entry?.valueType || 'STRING').toUpperCase(),
    };

    if (typeof item?.description === 'string' && item.description.trim()) {
      template.parameters[key].description = item.description.trim();
    }

    touchedKeys.add(key);
  }

  template.description = [
    String(template.description || '').trim(),
    `admin-update:${new Date().toISOString()}`,
    `by:${callerEmail || callerUid}`,
  ]
    .filter(Boolean)
    .slice(-3)
    .join(' | ');

  const validated = await admin.remoteConfig().validateTemplate(template);
  const published = await admin.remoteConfig().publishTemplate(validated, { force: true });

  logger.info('updateAdminRemoteConfigSettings', {
    callerUid,
    callerEmail,
    touchedKeys: Array.from(touchedKeys),
    version: published?.version?.versionNumber || null,
  });

  return {
    ok: true,
    touchedCount: touchedKeys.size,
    touchedKeys: Array.from(touchedKeys),
    version: published?.version?.versionNumber || null,
    updatedBy: published?.version?.updateUser?.email || callerEmail,
    updatedAt: published?.version?.updateTime || new Date().toISOString(),
  };
});

function parseLandingEventFromRequest(req) {
  let rawEvent = '';

  if (req?.body && typeof req.body === 'object') {
    rawEvent = String(req.body.event || '').trim();
  }

  if (!rawEvent && typeof req?.body === 'string') {
    const bodyText = req.body.trim();
    if (bodyText) {
      try {
        const parsed = JSON.parse(bodyText);
        rawEvent = String(parsed?.event || '').trim();
      } catch (_) {
        if (bodyText.includes('=')) {
          const params = new URLSearchParams(bodyText);
          rawEvent = String(params.get('event') || '').trim();
        } else {
          rawEvent = bodyText;
        }
      }
    }
  }

  if (!rawEvent && req?.rawBody) {
    const rawText = Buffer.isBuffer(req.rawBody)
      ? req.rawBody.toString('utf8')
      : String(req.rawBody || '').trim();
    if (rawText) {
      try {
        const parsed = JSON.parse(rawText);
        rawEvent = String(parsed?.event || '').trim();
      } catch (_) {
        if (rawText.includes('=')) {
          const params = new URLSearchParams(rawText);
          rawEvent = String(params.get('event') || '').trim();
        }
      }
    }
  }

  if (!rawEvent) {
    rawEvent = String(req?.query?.event || '').trim();
  }

  return rawEvent.toLowerCase();
}

exports.trackPublicLandingEvent = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ ok: false, error: 'method-not-allowed' });
      return;
    }

    const event = parseLandingEventFromRequest(req);
    if (!LANDING_PUBLIC_EVENTS.has(event)) {
      res.status(400).json({ ok: false, error: 'invalid-event' });
      return;
    }

    const dayKey = new Date().toISOString().slice(0, 10);
    const increment = admin.firestore.FieldValue.increment(1);
    const updatedAt = admin.firestore.FieldValue.serverTimestamp();

    const rootRef = db.collection('public_metrics').doc('landing_page');
    const dailyRef = rootRef.collection('daily').doc(dayKey);

    try {
      const eventCounterField = `events.${event}`;
      await db.runTransaction(async (tx) => {
        tx.set(
          rootRef,
          {
            totalEvents: increment,
            [eventCounterField]: increment,
            updatedAt,
          },
          { merge: true }
        );

        tx.set(
          dailyRef,
          {
            date: dayKey,
            totalEvents: increment,
            [eventCounterField]: increment,
            updatedAt,
          },
          { merge: true }
        );
      });

      res.status(200).json({ ok: true });
    } catch (error) {
      logger.error('trackPublicLandingEvent failed', {
        event,
        error: error?.message || String(error),
      });
      res.status(500).json({ ok: false, error: 'internal' });
    }
  }
);
