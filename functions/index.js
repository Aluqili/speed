const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();
const DEPLOY_MARKER_NODE22 = '2026-02-23-node22';
const REGION = 'us-central1';

const COURIER_OFFER_TIMEOUT_SECONDS = 40;
const ASSIGNMENT_CYCLE_RESET_SECONDS = 120;
const BOOTSTRAP_ADMIN_EMAILS = ['admin@speedstar.com'];
const PRICING_RECALC_WINDOW_MINUTES = 180;
const PRICING_RECALC_LIMIT = 250;
const PRICING_REMOTE_CACHE_MS = 60 * 1000;

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

async function sendNotificationToSingleUser(role, userId, payload) {
  const normalizedRole = normalizeAudienceRole(role);
  const uid = String(userId || '').trim();
  if (!normalizedRole || !uid) return 0;

  if (normalizedRole === 'client') {
    await db.collection('clients').doc(uid).collection('notifications').add({
      ...payload,
      userId: uid,
      audience: 'client',
    });
    return 1;
  }

  if (normalizedRole === 'courier') {
    await db.collection('notifications').add({
      ...payload,
      userId: uid,
      driverId: uid,
      audience: 'courier',
    });
    return 1;
  }

  if (normalizedRole === 'store') {
    await db.collection('notifications').add({
      ...payload,
      userId: uid,
      restaurantId: uid,
      audience: 'store',
    });
    return 1;
  }

  return 0;
}

async function sendNotificationToRole(role, payload, maxRecipients = 500) {
  const normalizedRole = normalizeAudienceRole(role);
  if (!normalizedRole) return 0;

  let targetSnap;
  if (normalizedRole === 'client') {
    targetSnap = await db.collection('clients').limit(maxRecipients).get();
  } else if (normalizedRole === 'courier') {
    targetSnap = await db.collection('drivers').limit(maxRecipients).get();
  } else {
    targetSnap = await db.collection('restaurants').limit(maxRecipients).get();
  }

  let count = 0;
  let batch = db.batch();
  let opCount = 0;

  for (const snap of targetSnap.docs) {
    const uid = snap.id;
    let ref;
    let data;

    if (normalizedRole === 'client') {
      ref = db.collection('clients').doc(uid).collection('notifications').doc();
      data = { ...payload, userId: uid, audience: 'client' };
    } else if (normalizedRole === 'courier') {
      ref = db.collection('notifications').doc();
      data = { ...payload, userId: uid, driverId: uid, audience: 'courier' };
    } else {
      ref = db.collection('notifications').doc();
      data = { ...payload, userId: uid, restaurantId: uid, audience: 'store' };
    }

    batch.set(ref, data);
    opCount += 1;
    count += 1;

    if (opCount >= 400) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
    }
  }

  if (opCount > 0) {
    await batch.commit();
  }

  return count;
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

async function dispatchOrderStatusNotifications(orderId, afterData) {
  const afterStatus = normalizeOrderStatusForNotification(afterData.orderStatus || afterData.status);
  if (!afterStatus) return { sent: 0, status: '' };

  const orderNumber = String(afterData.orderNumber || orderId || '');
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
    region: REGION,
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

function isWaitingCourierStatus(status) {
  return status === 'courier_searching' || status === 'قيد التجهيز';
}

function normalizeStateId(raw) {
  const value = String(raw || '').trim();
  if (!value) return '';

  const normalized = value
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .toLowerCase();

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

function driverStateId(driver) {
  return normalizeStateId(
    driver.stateId ||
    driver.region ||
    driver.state ||
    driver.city
  );
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
  const totalWithDelivery = Math.max(0, subtotal + deliveryFee + largeOrderFee);

  return {
    subtotal: Math.round(subtotal),
    deliveryFee: Math.round(deliveryFee),
    largeOrderFee,
    totalWithDelivery: Math.round(totalWithDelivery),
  };
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
    if (stateId) {
      const sameStateDrivers = remainingDrivers.filter((d) => {
        const data = d.data() || {};
        return driverStateId(data) === stateId;
      });
      if (sameStateDrivers.length > 0) {
        remainingDrivers = sameStateDrivers;
      }
    }
    let nextDriver = null;

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

        nextDriver = ranked[0]?.doc || remainingDrivers[0];
      }
    }

    if (!nextDriver) {
      tx.update(orderRef, {
        candidateDrivers: candidates,
        assignmentCycleStartedAt: cycleExpired ? now : (previousCycleStartedAt || now),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(orderRef, {
        assignmentBackoffReason: 'no-available-next-driver-in-cycle',
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
  region: REGION,
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
  region: REGION,
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
      const cleanedCandidates = activeOfferedDriverId
        ? existingCandidates.filter((id) => id !== activeOfferedDriverId)
        : existingCandidates;

      tx.update(ref, {
        assignedDriverId: admin.firestore.FieldValue.delete(),
        offeredDriverId: admin.firestore.FieldValue.delete(),
        offerStartedAt: admin.firestore.FieldValue.delete(),
        offerExpiresAt: admin.firestore.FieldValue.delete(),
        candidateDrivers: cleanedCandidates,
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
  region: REGION,
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
    const storedTotalWithDelivery = Math.round(toNumberOrNull(order.totalWithDelivery) || 0);

    if (
      storedDeliveryFee === recalculated.deliveryFee &&
      storedLargeFee === recalculated.largeOrderFee &&
      storedTotalWithDelivery === recalculated.totalWithDelivery
    ) {
      continue;
    }

    batch.update(doc.ref, {
      deliveryFee: recalculated.deliveryFee,
      largeOrderFee: recalculated.largeOrderFee,
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
