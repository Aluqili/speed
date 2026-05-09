const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
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
const ADMIN_PERMISSION_KEYS = [
  'dashboard',
  'finance',
  'orders',
  'map',
  'approvals',
  'support',
  'notifications',
  'config',
  'admins',
];
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
  clientDeliveryBaseFee: 5000,
  clientDeliveryBaseDistanceKm: 6,
  clientDeliveryExtraPerKm: 700,
  driverDeliveryBaseFee: 4000,
  driverDeliveryBaseDistanceKm: 6,
  driverDeliveryExtraPerKm: 500,
  deliveryPlatformMarginFixed: 700,
  deliveryPlatformMinMargin: 300,
};

let pricingRemoteConfigCache = {
  value: DEFAULT_PRICING_CONFIG,
  expiresAtMillis: 0,
};

const TELEGRAM_CHAT_ENV_KEYS_BY_CATEGORY = {
  all: ['TELEGRAM_CHAT_IDS_ALL'],
  finance: ['TELEGRAM_CHAT_IDS_FINANCE', 'TELEGRAM_CHAT_ID_FINANCE'],
  support: ['TELEGRAM_CHAT_IDS_SUPPORT', 'TELEGRAM_CHAT_ID_SUPPORT'],
  operations: ['TELEGRAM_CHAT_IDS_OPERATIONS', 'TELEGRAM_CHAT_ID_OPERATIONS', 'TELEGRAM_CHAT_IDS_OPS', 'TELEGRAM_CHAT_ID_OPS'],
};

function parseTelegramChatIds(rawValue) {
  return String(rawValue || '')
    .trim()
    .split(',')
    .map((item) => String(item || '').trim())
    .filter(Boolean);
}

function getTelegramRecipients(category = 'operations') {
  const normalizedCategory = String(category || 'operations').trim().toLowerCase();
  const allChatIds = TELEGRAM_CHAT_ENV_KEYS_BY_CATEGORY.all
    .flatMap((key) => parseTelegramChatIds(process.env[key]));
  const categoryChatIds = (TELEGRAM_CHAT_ENV_KEYS_BY_CATEGORY[normalizedCategory] || [])
    .flatMap((key) => parseTelegramChatIds(process.env[key]));
  const legacyChatIds = parseTelegramChatIds(process.env.TELEGRAM_CHAT_IDS || process.env.TELEGRAM_CHAT_ID || '');

  const resolved = [...allChatIds, ...categoryChatIds];
  if (!resolved.length) {
    return Array.from(new Set(legacyChatIds));
  }

  return Array.from(new Set(resolved));
}

function getTelegramConfig(category = 'operations') {
  const botToken = String(process.env.TELEGRAM_BOT_TOKEN || '').trim();
  const chatIds = getTelegramRecipients(category);

  return {
    botToken,
    chatIds,
    enabled: Boolean(botToken && chatIds.length),
  };
}

function escapeTelegramHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function formatTelegramMoney(value) {
  const amount = Number(value || 0);
  if (!Number.isFinite(amount)) return '-';
  return `${amount.toLocaleString('en-US')} ج.س`;
}

async function sendTelegramMessageHtml(htmlText, { category = 'operations' } = {}) {
  const config = getTelegramConfig(category);
  if (!config.enabled) {
    logger.info('Telegram alerts skipped because TELEGRAM_BOT_TOKEN or chat ids are missing for category.', { category });
    return { sent: 0, skipped: true };
  }

  const results = await Promise.allSettled(
    config.chatIds.map(async (chatId) => {
      const response = await fetch(`https://api.telegram.org/bot${config.botToken}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          text: htmlText,
          parse_mode: 'HTML',
          disable_notification: false,
          disable_web_page_preview: true,
        }),
      });

      if (!response.ok) {
        const body = await response.text().catch(() => '');
        throw new Error(`Telegram send failed (${response.status}): ${body}`);
      }
    })
  );

  const failed = results.filter((item) => item.status === 'rejected');
  if (failed.length) {
    failed.forEach((item) => logger.error('Telegram send error', item.reason));
  }

  return {
    sent: results.length - failed.length,
    failed: failed.length,
  };
}

async function sendTelegramPhotoHtml(photoUrl, htmlCaption, { category = 'operations' } = {}) {
  const config = getTelegramConfig(category);
  if (!config.enabled) {
    logger.info('Telegram photo alerts skipped because TELEGRAM_BOT_TOKEN or chat ids are missing for category.', { category });
    return { sent: 0, skipped: true };
  }

  const results = await Promise.allSettled(
    config.chatIds.map(async (chatId) => {
      const response = await fetch(`https://api.telegram.org/bot${config.botToken}/sendPhoto`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          photo: photoUrl,
          caption: htmlCaption,
          parse_mode: 'HTML',
          disable_notification: false,
        }),
      });

      if (!response.ok) {
        const body = await response.text().catch(() => '');
        throw new Error(`Telegram sendPhoto failed (${response.status}): ${body}`);
      }
    })
  );

  const failed = results.filter((item) => item.status === 'rejected');
  if (failed.length) {
    failed.forEach((item) => logger.error('Telegram sendPhoto error', item.reason));
  }

  return {
    sent: results.length - failed.length,
    failed: failed.length,
  };
}

async function sendTelegramOpsAlert(title, lines = [], { category = 'operations' } = {}) {
  const normalizedLines = Array.isArray(lines)
    ? lines.map((line) => String(line || '').trim()).filter(Boolean)
    : [];
  const html = [`<b>${escapeTelegramHtml(title)}</b>`, ...normalizedLines.map((line) => escapeTelegramHtml(line))].join('\n');
  return sendTelegramMessageHtml(html, { category });
}

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

function normalizeAdminPermissions(rawPermissions, { fallbackToAll = true } = {}) {
  const items = Array.isArray(rawPermissions) ? rawPermissions : [];
  const normalized = items
    .map((item) => String(item || '').trim().toLowerCase())
    .filter((item) => ADMIN_PERMISSION_KEYS.includes(item));

  if (normalized.length) {
    return Array.from(new Set(normalized));
  }

  return fallbackToAll ? [...ADMIN_PERMISSION_KEYS] : [];
}

async function getAdminAccessProfileByUid(uid) {
  if (!uid) {
    return { allowed: false, permissions: [] };
  }

  try {
    const userRecord = await admin.auth().getUser(uid);
    const email = String(userRecord.email || '').toLowerCase().trim();
    if (isStaticAdminEmail(email)) {
      return {
        allowed: true,
        permissions: [...ADMIN_PERMISSION_KEYS],
        isStaticAdmin: true,
      };
    }
  } catch (_) {
  }

  const adminSnap = await db.collection('admins').doc(uid).get();
  if (!adminSnap.exists) {
    return { allowed: false, permissions: [] };
  }

  const data = adminSnap.data() || {};
  const allowed = data.role === 'admin' || data.active === true;
  return {
    allowed,
    permissions: normalizeAdminPermissions(data.permissions, { fallbackToAll: true }),
    data,
    isStaticAdmin: false,
  };
}

async function isAdminUid(uid) {
  const profile = await getAdminAccessProfileByUid(uid);
  return profile.allowed === true;
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

function getKhartoumClockSnapshot(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Africa/Khartoum',
    weekday: 'long',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);

  const partMap = Object.fromEntries(
    parts
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, part.value])
  );

  const weekdayMap = {
    Saturday: 'saturday',
    Sunday: 'sunday',
    Monday: 'monday',
    Tuesday: 'tuesday',
    Wednesday: 'wednesday',
    Thursday: 'thursday',
    Friday: 'friday',
  };

  const dayKey = weekdayMap[partMap.weekday] || 'sunday';
  const hour = Number(partMap.hour || 0);
  const minute = Number(partMap.minute || 0);

  return {
    dayKey,
    nowMinutes: (hour * 60) + minute,
  };
}

function parseArabicClockTime(rawValue) {
  const raw = String(rawValue || '').trim();
  if (!raw) return null;

  const cleaned = raw.replace(/[^0-9:]/g, '');
  const parts = cleaned.split(':');
  if (parts.length !== 2) return null;

  let hour = Number(parts[0]);
  const minute = Number(parts[1]);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
  if (minute < 0 || minute > 59) return null;

  const isPm = raw.includes('م');
  const isAm = raw.includes('ص');

  if (isPm && hour < 12) hour += 12;
  if (isAm && hour === 12) hour = 0;
  if (hour < 0 || hour > 23) return null;

  return { hour, minute };
}

function getTimestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function getKhartoumDayKey(value = Date.now()) {
  const date = value instanceof Date ? value : new Date(value);
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Khartoum',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);

  const partMap = Object.fromEntries(
    parts
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, part.value])
  );

  return `${partMap.year || '0000'}-${partMap.month || '00'}-${partMap.day || '00'}`;
}

function extractWorkingHourRanges(dayData, status) {
  const ranges = [];

  const addRange = (openValue, closeValue) => {
    const open = parseArabicClockTime(openValue);
    const close = parseArabicClockTime(closeValue);
    if (!open || !close) return;
    ranges.push({ open, close });
  };

  if (
    status === 'صباحي ومسائي'
    || (dayData?.morning && typeof dayData.morning === 'object'
      && dayData?.evening && typeof dayData.evening === 'object')
  ) {
    addRange(dayData?.morning?.open, dayData?.morning?.close);
    addRange(dayData?.evening?.open, dayData?.evening?.close);
    return ranges;
  }

  addRange(dayData?.open, dayData?.close);
  return ranges;
}

function isWithinWorkingHourRange(nowMinutes, open, close) {
  const openMinutes = (open.hour * 60) + open.minute;
  const closeMinutes = (close.hour * 60) + close.minute;

  if (closeMinutes >= openMinutes) {
    return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
  }

  return nowMinutes >= openMinutes || nowMinutes <= closeMinutes;
}

function shouldRestaurantBeTemporarilyClosedByHours(restaurantData, clockSnapshot) {
  const workingHours = restaurantData?.workingHours;
  if (!workingHours || typeof workingHours !== 'object') return null;

  const todayHours = workingHours[clockSnapshot.dayKey];
  if (!todayHours || typeof todayHours !== 'object') return true;

  const status = String(todayHours.status || '').trim();
  if (status === 'مغلق') return true;

  const ranges = extractWorkingHourRanges(todayHours, status);
  if (!ranges.length) return true;

  for (const range of ranges) {
    if (isWithinWorkingHourRange(clockSnapshot.nowMinutes, range.open, range.close)) {
      return false;
    }
  }

  return true;
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

function isPendingPaymentReviewOrder(order) {
  const paymentStatus = normalizePaymentStatus(order?.paymentStatus);
  const decision = String(order?.paymentReviewDecision || '').trim().toLowerCase();
  return paymentStatus === 'under_review' || decision === 'pending';
}

function isPendingWalletRechargeRequest(entry) {
  const status = String(entry?.status || '').trim().toLowerCase();
  const reviewStatus = String(entry?.reviewStatus || '').trim().toLowerCase();
  if (['approved', 'rejected', 'paid'].includes(status)) return false;
  if (['approved', 'rejected'].includes(reviewStatus)) return false;
  return status === 'pending_review' || reviewStatus === 'pending' || (!status && !reviewStatus);
}

async function sendTelegramPaymentReviewAlert(orderId, after) {
  if (!orderId || !hasPaymentEvidence(after)) return;

  const orderReference = formatUnifiedOrderCode(after.orderNumber || after.orderId, orderId);
  const clientName = String(after.clientName || after.clientId || 'غير معروف').trim();
  const storeName = String(after.restaurantName || after.restaurantId || 'غير معروف').trim();
  const paymentMethod = String(after.paymentMethod || after.method || '-').trim() || '-';
  const transactionReference = String(after.transactionReference || '-').trim() || '-';
  const amountLabel = formatTelegramMoney(
    after.totalWithDelivery || after.totalBeforeDiscount || after.total || after.totalPrice || after.orderTotal || 0
  );
  const proofImageUrl = String(after.proofImageUrl || '').trim();
  const htmlLines = [
    'تم استلام إيصال دفع جديد ويحتاج إلى مراجعة مالية من لوحة الأدمن.',
    '',
    `<b>رقم الطلب:</b> ${escapeTelegramHtml(orderReference)}`,
    `<b>العميل:</b> ${escapeTelegramHtml(clientName)}`,
    `<b>المتجر:</b> ${escapeTelegramHtml(storeName)}`,
    `<b>المبلغ:</b> ${escapeTelegramHtml(amountLabel)}`,
    `<b>طريقة الدفع:</b> ${escapeTelegramHtml(paymentMethod)}`,
    `<b>مرجع العملية:</b> ${escapeTelegramHtml(transactionReference)}`,
    '',
    'الحالة الحالية: بانتظار المراجعة المالية.',
  ];
  const htmlCaption = `<b>تنبيه مراجعة إيصال دفع</b>\n${htmlLines.join('\n')}`;

  if (proofImageUrl) {
    const photoResult = await sendTelegramPhotoHtml(proofImageUrl, htmlCaption, { category: 'finance' });
    if (!photoResult.failed) {
      return;
    }
  }

  await sendTelegramMessageHtml(`${htmlCaption}\n<b>رابط الإيصال:</b> ${escapeTelegramHtml(proofImageUrl || '-')}`, { category: 'finance' });
}

async function sendTelegramWalletRechargeAlert(rechargeId, data) {
  if (!rechargeId) return;

  await sendTelegramOpsAlert('طلب شحن محفظة جديد', [
    `رقم الطلب: ${rechargeId}`,
    `العميل: ${String(data.clientName || data.clientId || 'غير معروف')}`,
    `المبلغ: ${formatTelegramMoney(data.amount || 0)}`,
    `طريقة الدفع: ${String(data.method || data.paymentMethod || '-').trim() || '-'}`,
    'الحالة: الطلب بانتظار المراجعة في القسم المالي.',
  ], { category: 'finance' });
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
  const notificationType = String(payload?.type || '').trim().toLowerCase();
  const isPickupReadyNotice = notificationType === 'courier_pickup_ready';
  const isOrderUrgent =
    !isPickupReadyNotice && (
    notificationType.includes('order')
    || notificationType.includes('offer')
    || notificationType.includes('pickup')
    || notificationType.includes('courier'));
  const normalizedRole = String(role || '').trim().toLowerCase();
  const isStore = normalizedRole === 'store';
  const androidChannelId = normalizedRole === 'client'
    ? 'speedstar_client_alerts_v3'
    : isOrderUrgent && isStore
    ? 'speedstar_store_orders_incoming_v6'
    : 'speedstar_alerts';

  return {
    title: String(payload.title || ''),
    body: String(payload.body || ''),
    type: String(payload.type || ''),
    source: String(payload.source || ''),
    orderId: payload.orderId ? String(payload.orderId) : '',
    conversationId: payload.conversationId ? String(payload.conversationId) : '',
    chatId: payload.chatId ? String(payload.chatId) : '',
    senderId: payload.senderId ? String(payload.senderId) : '',
    senderType: payload.senderType ? String(payload.senderType) : '',
    audience: String(role || ''),
    userId: String(userId || ''),
    channelId: androidChannelId,
    playSound: normalizedRole === 'client' || isOrderUrgent ? 'true' : 'false',
    urgent: isOrderUrgent ? '1' : '0',
  };
}

async function sendPushToUser(normalizedRole, userId, userDocData, payload) {
  const tokens = extractFcmTokens(userDocData);
  if (!tokens.length) {
    logger.warn('sendPushToUser skipped: no tokens', {
      role: normalizedRole,
      userId,
    });
    return 0;
  }

  const notificationType = String(payload?.type || '').trim().toLowerCase();
  const isPickupReadyNotice = notificationType === 'courier_pickup_ready';
  const isOrderUrgent =
    !isPickupReadyNotice && (
    notificationType.includes('order')
    || notificationType.includes('offer')
    || notificationType.includes('pickup')
    || notificationType.includes('courier'));
  const storeOrdersChannelId = 'speedstar_store_orders_incoming_v6';
  const sharedOrdersChannelId = 'speedstar_orders_incoming_v1';
  const androidChannelId = normalizedRole === 'client'
    ? 'speedstar_client_alerts_v3'
    : isOrderUrgent
      ? (normalizedRole === 'store' ? storeOrdersChannelId : sharedOrdersChannelId)
      : 'speedstar_alerts';

  const message = {
    tokens,
    data: notificationPayloadToData(payload, normalizedRole, userId),
    android: {
      priority: 'high',
      ttl: 30000,
      notification: {
        channelId: androidChannelId,
        icon: 'ic_notification',
        color: '#FF6B00',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
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
    notification: {
      title: String(payload.title || ''),
      body: String(payload.body || ''),
    },
  };

  message.android.notification = {
    channelId: androidChannelId,
    visibility: 'public',
    icon: 'ic_stat_speedstar',
    color: '#FF6B00',
    defaultSound: true,
  };

  if (normalizedRole === 'client') {
    message.android.notification.sound = 'default';
  } else if (isOrderUrgent) {
    message.android.notification.sound = 'incoming_order';
  }

  try {
    const result = await admin.messaging().sendEachForMulticast(message);
    logger.info('sendPushToUser result', {
      role: normalizedRole,
      userId,
      tokenCount: tokens.length,
      successCount: Number(result.successCount || 0),
      failureCount: Number(result.failureCount || 0),
    });
    if (Number(result.failureCount || 0) > 0) {
      const errorCodes = result.responses
        .filter((response) => !response.success)
        .map((response) => response.error?.code || response.error?.message || 'unknown')
        .filter(Boolean);
      logger.warn('sendPushToUser partial failure', {
        role: normalizedRole,
        userId,
        successCount: Number(result.successCount || 0),
        failureCount: Number(result.failureCount || 0),
        errorCodes,
      });
    }
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
  return await sendPushToUser(normalizedRole, uid, userDoc.data() || {}, payload);
}

function messageNotificationPreview(data) {
  const text = String(data?.message || data?.text || '').trim();
  const preview = text || (data?.imageUrl ? 'صورة مرفقة' : 'رسالة جديدة');
  return preview.length > 90 ? `${preview.slice(0, 87)}...` : preview;
}

async function clientDocExists(clientId) {
  const uid = String(clientId || '').trim();
  if (!uid || uid === 'support') return false;
  const snap = await db.collection('clients').doc(uid).get();
  return snap.exists;
}

function supportClientIdFromConversation(conversationId) {
  const raw = String(conversationId || '').trim();
  const marker = raw.indexOf('-support');
  if (marker <= 0) return '';
  return raw.slice(0, marker).trim();
}

async function resolveClientRecipientForSupportMessage(data) {
  const senderId = String(data?.senderId || data?.actorUid || '').trim();
  const senderType = String(data?.senderType || '').trim().toLowerCase();
  if (senderType === 'client') return '';

  const candidates = [
    data?.clientId,
    data?.receiverId,
    supportClientIdFromConversation(data?.conversationId),
    ...(Array.isArray(data?.participants) ? data.participants : []),
  ];

  for (const candidate of candidates) {
    const uid = String(candidate || '').trim();
    if (!uid || uid === 'support' || uid === senderId) continue;
    if (await clientDocExists(uid)) return uid;
  }
  return '';
}

async function resolveClientRecipientForDirectMessage(data) {
  const senderId = String(data?.senderId || '').trim();
  const receiverId = String(data?.receiverId || '').trim();
  if (receiverId && receiverId !== senderId && await clientDocExists(receiverId)) {
    return receiverId;
  }

  const participants = Array.isArray(data?.participants) ? data.participants : [];
  for (const participant of participants) {
    const uid = String(participant || '').trim();
    if (!uid || uid === senderId) continue;
    if (await clientDocExists(uid)) return uid;
  }
  return '';
}

async function notifyClientAboutMessage(clientId, data, options = {}) {
  const uid = String(clientId || '').trim();
  if (!uid) return 0;

  const senderId = String(data?.senderId || data?.actorUid || '').trim();
  if (senderId && senderId === uid) return 0;

  const senderName = String(data?.senderName || options.senderFallback || '').trim();
  const preview = messageNotificationPreview(data);
  const body = senderName ? `${senderName}: ${preview}` : preview;
  const conversationId = String(data?.conversationId || '').trim();

  return await sendNotificationToSingleUser('client', uid, buildNotificationPayload({
    title: options.title || 'رسالة جديدة',
    body,
    type: options.type || 'chat_message',
    source: options.source || 'chat',
    extra: {
      conversationId,
      chatId: conversationId,
      senderId,
      senderType: String(data?.senderType || '').trim(),
      receiverId: String(data?.receiverId || '').trim(),
      messageId: String(options.messageId || '').trim(),
    },
  }));
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

function isDeliveredOrderStatus(raw) {
  return normalizeOrderStatusForNotification(raw) === 'delivered';
}

async function syncCourierWalletSummary(driverId) {
  const normalizedDriverId = String(driverId || '').trim();
  if (!normalizedDriverId) return;

  const driverRef = db.collection('drivers').doc(normalizedDriverId);
  const [driverSnap, ordersSnap] = await Promise.all([
    driverRef.get(),
    db.collection('orders').where('assignedDriverId', '==', normalizedDriverId).get(),
  ]);

  if (!driverSnap.exists) return;

  let deliveredOrdersCount = 0;
  let walletLifetimeEarnings = 0;

  ordersSnap.docs.forEach((orderSnap) => {
    const order = orderSnap.data() || {};
    if (!isDeliveredOrderStatus(order.orderStatus || order.status)) {
      return;
    }

    deliveredOrdersCount += 1;
    walletLifetimeEarnings += Math.max(
      0,
      Math.round(toSafeNumber(order.deliveryFeeForDriver ?? order.deliveryFee)),
    );
  });

  const driverData = driverSnap.data() || {};
  const walletTransferredTotal = Math.max(
    0,
    Math.round(toSafeNumber(driverData.walletTransferredTotal)),
  );

  await driverRef.set({
    walletPendingBalance: Math.max(0, walletLifetimeEarnings - walletTransferredTotal),
    walletDeliveredOrdersCount: deliveredOrdersCount,
    walletLifetimeEarnings,
    walletSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
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

  const discountScope = String(promo.discountScope || 'order_total').trim().toLowerCase();
  if (!['order_total', 'delivery_fee'].includes(discountScope)) {
    return { ok: false, reason: 'invalid-discount-scope' };
  }

  const itemName = String(promo.itemName || '').trim();
  let discountBase = discountScope === 'delivery_fee'
    ? Math.max(0, context.deliveryFee)
    : context.baseTotal;

  if (discountScope !== 'delivery_fee' && itemName) {
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

  discountAmount = Math.max(0, Math.min(discountAmount, discountBase));
  const totalAfterDiscount = Math.max(0, context.baseTotal - discountAmount);

  return {
    ok: true,
    code,
    discountAmount,
    totalAfterDiscount,
    promoSnapshot: {
      code,
      discountScope,
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

const STORE_OFFER_SCOPE_VALUES = new Set(['order_total', 'delivery_fee', 'specific_items']);
const STORE_OFFER_TYPE_VALUES = new Set(['percent', 'fixed']);
const STORE_OFFER_ADMIN_ACTIONS = new Set(['approve', 'reject', 'activate', 'deactivate']);

function parseOptionalTimestampInput(rawValue, fieldName, { required = false } = {}) {
  if (rawValue == null || rawValue === '') {
    if (required) {
      throw new HttpsError('invalid-argument', `${fieldName} is required`);
    }
    return null;
  }

  if (rawValue?.toDate && typeof rawValue.toDate === 'function') {
    return admin.firestore.Timestamp.fromDate(rawValue.toDate());
  }

  const date = new Date(rawValue);
  if (Number.isNaN(date.getTime())) {
    throw new HttpsError('invalid-argument', `${fieldName} is invalid`);
  }
  return admin.firestore.Timestamp.fromDate(date);
}

function normalizeStoreOfferTargetItems(rawItems) {
  if (!Array.isArray(rawItems)) return [];

  return rawItems
    .map((item) => ({
      itemId: String(item?.itemId || item?.id || '').trim(),
      name: String(item?.name || item?.itemName || '').trim(),
      imageUrl: String(item?.imageUrl || '').trim(),
    }))
    .filter((item) => item.itemId || item.name)
    .slice(0, 25);
}

function buildStoreOfferSummaryText(offer) {
  const scope = String(offer.discountScope || '').trim();
  const discountType = String(offer.discountType || '').trim();
  const discountValue = Math.max(0, toSafeNumber(offer.discountValue));
  const maxDiscount = Math.max(0, toSafeNumber(offer.maxDiscount));
  const minOrder = Math.max(0, toSafeNumber(offer.minOrder));
  const targetItems = normalizeStoreOfferTargetItems(offer.targetItems || []);

  let discountText = discountType === 'percent'
    ? `خصم ${discountValue}%`
    : `خصم ${Math.round(discountValue)} ج.س`;

  if (scope === 'delivery_fee') {
    discountText += ' على التوصيل';
  } else if (scope === 'specific_items') {
    const itemNames = targetItems
      .map((item) => item.name)
      .filter(Boolean)
      .slice(0, 2);
    if (itemNames.length > 0) {
      discountText += ` على ${itemNames.join(' و ')}`;
    } else {
      discountText += ' على وجبات محددة';
    }
  } else {
    discountText += ' على الطلب';
  }

  if (maxDiscount > 0) {
    discountText += ` حتى ${Math.round(maxDiscount)} ج.س`;
  }
  if (minOrder > 0) {
    discountText += ` للطلبات فوق ${Math.round(minOrder)} ج.س`;
  }

  return discountText;
}

function isStoreOfferVisible(offer, nowMillis = Date.now()) {
  if (String(offer.status || '') !== 'approved') return false;
  if (offer.isActive !== true) return false;

  const startsAtMillis = offer.startsAt?.toMillis?.() || null;
  const endsAtMillis = offer.endsAt?.toMillis?.() || null;

  if (startsAtMillis && startsAtMillis > nowMillis) return false;
  if (endsAtMillis && endsAtMillis <= nowMillis) return false;
  return true;
}

async function syncRestaurantOfferSummary(restaurantId) {
  const offersSnap = await db.collection('storeOffers')
    .where('restaurantId', '==', restaurantId)
    .get();

  const visibleOffers = offersSnap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((offer) => isStoreOfferVisible(offer))
    .sort((a, b) => {
      const aTime = a.updatedAt?.toMillis?.() || a.createdAt?.toMillis?.() || 0;
      const bTime = b.updatedAt?.toMillis?.() || b.createdAt?.toMillis?.() || 0;
      return bTime - aTime;
    });

  const highlights = visibleOffers.slice(0, 6).map((offer) => ({
    offerId: offer.id,
    title: String(offer.title || '').trim(),
    description: String(offer.description || '').trim(),
    imageUrl: String(offer.imageUrl || '').trim(),
    badgeText: String(offer.badgeText || '').trim(),
    summaryText: String(offer.summaryText || buildStoreOfferSummaryText(offer)).trim(),
    discountScope: String(offer.discountScope || '').trim(),
    discountType: String(offer.discountType || '').trim(),
    discountValue: toSafeNumber(offer.discountValue),
    maxDiscount: Math.max(0, toSafeNumber(offer.maxDiscount)) || null,
    minOrder: Math.max(0, toSafeNumber(offer.minOrder)) || null,
    targetItems: normalizeStoreOfferTargetItems(offer.targetItems || []),
    startsAt: offer.startsAt || null,
    endsAt: offer.endsAt || null,
  }));

  const summaryText = highlights.length > 0
    ? highlights.slice(0, 2).map((offer) => offer.summaryText || offer.title).filter(Boolean).join(' • ')
    : '';

  await db.collection('restaurants').doc(restaurantId).set({
    hasOffers: highlights.length > 0,
    offers: summaryText,
    activeOfferCount: highlights.length,
    offerHighlights: highlights,
    offersUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

exports.submitStoreOfferRequest = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const restaurantId = String(request.data?.restaurantId || '').trim();
  if (!restaurantId || request.auth.uid !== restaurantId) {
    throw new HttpsError('permission-denied', 'restaurantId must match the signed-in store');
  }

  const offer = request.data?.offer || {};
  const title = String(offer.title || '').trim();
  const description = String(offer.description || '').trim();
  const imageUrl = String(offer.imageUrl || '').trim();
  const badgeText = String(offer.badgeText || '').trim();
  const discountScope = String(offer.discountScope || '').trim();
  const discountType = String(offer.discountType || '').trim();
  const discountValue = Math.max(0, toSafeNumber(offer.discountValue));
  const maxDiscount = Math.max(0, toSafeNumber(offer.maxDiscount));
  const minOrder = Math.max(0, toSafeNumber(offer.minOrder));
  const targetItems = normalizeStoreOfferTargetItems(offer.targetItems || []);
  const reviewNote = String(offer.reviewNote || '').trim();
  const startsAt = parseOptionalTimestampInput(offer.startsAt, 'offer.startsAt', { required: true });
  const endsAt = parseOptionalTimestampInput(offer.endsAt, 'offer.endsAt', { required: true });

  if (!title) {
    throw new HttpsError('invalid-argument', 'offer.title is required');
  }
  if (!description) {
    throw new HttpsError('invalid-argument', 'offer.description is required');
  }
  if (!STORE_OFFER_SCOPE_VALUES.has(discountScope)) {
    throw new HttpsError('invalid-argument', 'offer.discountScope is invalid');
  }
  if (!STORE_OFFER_TYPE_VALUES.has(discountType)) {
    throw new HttpsError('invalid-argument', 'offer.discountType is invalid');
  }
  if (discountValue <= 0) {
    throw new HttpsError('invalid-argument', 'offer.discountValue must be greater than zero');
  }
  if (endsAt.toMillis() <= startsAt.toMillis()) {
    throw new HttpsError('invalid-argument', 'offer.endsAt must be after offer.startsAt');
  }
  if (discountScope === 'specific_items' && targetItems.length === 0) {
    throw new HttpsError('invalid-argument', 'offer.targetItems is required for specific_items offers');
  }

  const restaurantSnap = await db.collection('restaurants').doc(restaurantId).get();
  if (!restaurantSnap.exists) {
    throw new HttpsError('not-found', 'Restaurant not found');
  }

  const restaurantData = restaurantSnap.data() || {};
  const summaryText = buildStoreOfferSummaryText({
    discountScope,
    discountType,
    discountValue,
    maxDiscount,
    minOrder,
    targetItems,
  });

  const offerRef = await db.collection('storeOffers').add({
    restaurantId,
    restaurantName: String(restaurantData.name || '').trim(),
    title,
    description,
    imageUrl,
    badgeText,
    discountScope,
    discountType,
    discountValue,
    maxDiscount: maxDiscount || null,
    minOrder: minOrder || null,
    targetItems,
    summaryText,
    status: 'pending',
    isActive: false,
    reviewNote,
    startsAt,
    endsAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdByUid: request.auth.uid,
    reviewedAt: null,
    reviewedByUid: '',
    reviewDecision: '',
  });

  return {
    ok: true,
    offerId: offerRef.id,
  };
});

exports.reviewStoreOfferRequest = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const actorUid = String(request.auth.uid || '').trim();
  const actorEmail = String(request.auth.token?.email || '').toLowerCase().trim();
  const actorIsAdmin = (await isAdminUid(actorUid)) || isStaticAdminEmail(actorEmail);
  if (!actorIsAdmin) {
    throw new HttpsError('permission-denied', 'Only admins can review store offers');
  }

  const offerId = String(request.data?.offerId || '').trim();
  const action = String(request.data?.action || '').trim();
  const reviewNote = String(request.data?.reviewNote || '').trim();
  if (!offerId || !STORE_OFFER_ADMIN_ACTIONS.has(action)) {
    throw new HttpsError('invalid-argument', 'offerId and a valid action are required');
  }

  const offerRef = db.collection('storeOffers').doc(offerId);
  const offerSnap = await offerRef.get();
  if (!offerSnap.exists) {
    throw new HttpsError('not-found', 'Store offer not found');
  }

  const offer = offerSnap.data() || {};
  const restaurantId = String(offer.restaurantId || '').trim();
  if (!restaurantId) {
    throw new HttpsError('failed-precondition', 'Store offer restaurantId is missing');
  }

  const patch = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    reviewNote,
    reviewedByUid: actorUid,
  };

  if (action === 'approve') {
    patch.status = 'approved';
    patch.isActive = true;
    patch.reviewDecision = 'approved';
    patch.reviewedAt = admin.firestore.FieldValue.serverTimestamp();
  } else if (action === 'reject') {
    patch.status = 'rejected';
    patch.isActive = false;
    patch.reviewDecision = 'rejected';
    patch.reviewedAt = admin.firestore.FieldValue.serverTimestamp();
  } else if (action === 'activate') {
    if (String(offer.status || '') !== 'approved') {
      throw new HttpsError('failed-precondition', 'Only approved offers can be activated');
    }
    patch.isActive = true;
    patch.reviewDecision = 'activated';
  } else if (action === 'deactivate') {
    patch.isActive = false;
    patch.reviewDecision = 'deactivated';
  }

  await offerRef.set(patch, { merge: true });
  await syncRestaurantOfferSummary(restaurantId);

  return {
    ok: true,
    offerId,
    restaurantId,
    action,
  };
});

exports.adminCreateStoreOffer = onCall({ region: REGION }, async (request) => {
  await ensureAdminCallable(request, 'Only admins can create store offers', 'finance');

  const restaurantId = String(request.data?.restaurantId || '').trim();
  if (!restaurantId) {
    throw new HttpsError('invalid-argument', 'restaurantId is required');
  }

  const offer = request.data?.offer || {};
  const title = String(offer.title || '').trim();
  const description = String(offer.description || '').trim();
  const imageUrl = String(offer.imageUrl || '').trim();
  const badgeText = String(offer.badgeText || '').trim();
  const discountScope = String(offer.discountScope || '').trim();
  const discountType = String(offer.discountType || '').trim();
  const discountValue = Math.max(0, toSafeNumber(offer.discountValue));
  const maxDiscount = Math.max(0, toSafeNumber(offer.maxDiscount));
  const minOrder = Math.max(0, toSafeNumber(offer.minOrder));
  const targetItems = normalizeStoreOfferTargetItems(offer.targetItems || []);
  const reviewNote = String(offer.reviewNote || '').trim();
  const startsAt = parseOptionalTimestampInput(offer.startsAt, 'offer.startsAt', { required: true });
  const endsAt = parseOptionalTimestampInput(offer.endsAt, 'offer.endsAt', { required: true });
  const isActive = offer.isActive !== false;

  if (!title) {
    throw new HttpsError('invalid-argument', 'offer.title is required');
  }
  if (!description) {
    throw new HttpsError('invalid-argument', 'offer.description is required');
  }
  if (!STORE_OFFER_SCOPE_VALUES.has(discountScope)) {
    throw new HttpsError('invalid-argument', 'offer.discountScope is invalid');
  }
  if (!STORE_OFFER_TYPE_VALUES.has(discountType)) {
    throw new HttpsError('invalid-argument', 'offer.discountType is invalid');
  }
  if (discountValue <= 0) {
    throw new HttpsError('invalid-argument', 'offer.discountValue must be greater than zero');
  }
  if (endsAt.toMillis() <= startsAt.toMillis()) {
    throw new HttpsError('invalid-argument', 'offer.endsAt must be after offer.startsAt');
  }
  if (discountScope === 'specific_items' && targetItems.length === 0) {
    throw new HttpsError('invalid-argument', 'offer.targetItems is required for specific_items offers');
  }

  const restaurantSnap = await db.collection('restaurants').doc(restaurantId).get();
  if (!restaurantSnap.exists) {
    throw new HttpsError('not-found', 'Restaurant not found');
  }

  const restaurantData = restaurantSnap.data() || {};
  const summaryText = buildStoreOfferSummaryText({
    discountScope,
    discountType,
    discountValue,
    maxDiscount,
    minOrder,
    targetItems,
  });

  const offerRef = await db.collection('storeOffers').add({
    restaurantId,
    restaurantName: String(restaurantData.name || '').trim(),
    title,
    description,
    imageUrl,
    badgeText,
    discountScope,
    discountType,
    discountValue,
    maxDiscount: maxDiscount || null,
    minOrder: minOrder || null,
    targetItems,
    summaryText,
    status: 'approved',
    isActive,
    reviewNote,
    startsAt,
    endsAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdByUid: request.auth.uid,
    createdByRole: 'admin',
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    reviewedByUid: request.auth.uid,
    reviewDecision: isActive ? 'admin_created_active' : 'admin_created_inactive',
  });

  await syncRestaurantOfferSummary(restaurantId);

  return {
    ok: true,
    offerId: offerRef.id,
    restaurantId,
  };
});

exports.expireApprovedStoreOffers = onSchedule({
  region: SCHEDULE_REGION,
  schedule: 'every 30 minutes',
  timeZone: 'Africa/Khartoum',
}, async () => {
  const now = Date.now();
  const snap = await db.collection('storeOffers')
    .where('isActive', '==', true)
    .get();

  if (snap.empty) {
    return;
  }

  const batch = db.batch();
  const restaurantIds = new Set();

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (String(data.status || '') !== 'approved') continue;
    const endsAtMillis = data.endsAt?.toMillis?.() || null;
    if (!endsAtMillis || endsAtMillis > now) continue;
    batch.set(doc.ref, {
      isActive: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewDecision: 'expired',
    }, { merge: true });
    if (data.restaurantId) {
      restaurantIds.add(String(data.restaurantId));
    }
  }

  if (restaurantIds.size === 0) {
    return;
  }

  await batch.commit();
  await Promise.all(Array.from(restaurantIds).map((restaurantId) => syncRestaurantOfferSummary(restaurantId)));
});

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
  await ensureAdminCallable(request, 'ليس لديك صلاحية إرسال إشعارات عامة.', 'notifications');

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
  await ensureAdminCallable(request, 'ليس لديك صلاحية التحويل.', 'finance');

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

// ─── طلبات سحب المحفظة ────────────────────────────────────────────────────

exports.reviewClientWalletWithdrawal = onCall({ region: REGION }, async (request) => {
  await ensureAdminCallable(request, 'ليس لديك صلاحية مراجعة طلبات السحب.', 'finance');

  const withdrawalId = String(request.data?.withdrawalId || '').trim();
  const decision = String(request.data?.decision || '').trim().toLowerCase();
  const note = String(request.data?.note || '').trim();

  if (!withdrawalId || !['approve', 'reject'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'withdrawalId و decision(approve/reject) مطلوبان.');
  }

  const withdrawalRef = db.collection('wallet_withdrawals').doc(withdrawalId);
  const nowTs = admin.firestore.FieldValue.serverTimestamp();

  const result = await db.runTransaction(async (tx) => {
    const withdrawalSnap = await tx.get(withdrawalRef);
    if (!withdrawalSnap.exists) {
      throw new HttpsError('not-found', 'طلب السحب غير موجود.');
    }

    const withdrawal = withdrawalSnap.data() || {};
    const clientId = String(withdrawal.clientId || '').trim();
    const amount = Number(withdrawal.amount || 0);
    const currentStatus = String(withdrawal.status || '').trim().toLowerCase();

    if (!clientId) throw new HttpsError('failed-precondition', 'طلب السحب لا يحتوي على clientId.');
    if (!Number.isFinite(amount) || amount <= 0) throw new HttpsError('failed-precondition', 'قيمة السحب غير صالحة.');
    if (['approved', 'rejected', 'completed'].includes(currentStatus)) {
      throw new HttpsError('failed-precondition', 'تمت مراجعة هذا الطلب مسبقًا.');
    }

    const clientRef = db.collection('clients').doc(clientId);
    const clientSnap = await tx.get(clientRef);
    if (!clientSnap.exists) throw new HttpsError('not-found', 'العميل غير موجود.');

    const clientData = clientSnap.data() || {};
    const currentBalance = toSafeNumber(
      clientData.walletBalance ?? clientData.wallet ?? clientData.balance ?? 0
    );

    if (decision === 'approve' && currentBalance < amount) {
      throw new HttpsError('failed-precondition', `رصيد العميل (${currentBalance}) أقل من المبلغ المطلوب (${amount}).`);
    }

    tx.set(withdrawalRef, {
      status: decision === 'approve' ? 'approved' : 'rejected',
      reviewNote: note,
      reviewedAt: nowTs,
      reviewedByAdminUid: request.auth.uid,
      reviewedByAdminEmail: String(request.auth.token?.email || ''),
      updatedAt: nowTs,
    }, { merge: true });

    if (decision === 'approve') {
      const nextBalance = currentBalance - amount;
      tx.set(clientRef, {
        walletBalance: nextBalance,
        wallet: nextBalance,
        updatedAt: nowTs,
      }, { merge: true });
      tx.set(clientRef.collection('walletTransactions').doc(), {
        type: 'withdrawal',
        withdrawalId,
        amount: -amount,
        balanceBefore: currentBalance,
        balanceAfter: nextBalance,
        paymentMethod: withdrawal.paymentMethod || '',
        accountNumber: withdrawal.accountNumber || '',
        accountHolderName: withdrawal.accountHolderName || '',
        createdAt: nowTs,
      });
      return { clientId, amount, nextBalance, decision };
    }

    return { clientId, amount, nextBalance: currentBalance, decision };
  });

  const title = result.decision === 'approve'
    ? '✅ تمت الموافقة على طلب سحبك'
    : '❌ تم رفض طلب سحبك';
  const body = result.decision === 'approve'
    ? `تمت الموافقة على سحب ${result.amount} ج.س من محفظتك. سيتم تحويل المبلغ قريباً.`
    : `تم رفض طلب سحب المحفظة${note ? `: ${note}` : '.'}`;

  await sendNotificationToSingleUser('client', result.clientId, buildNotificationPayload({
    title, body,
    type: 'wallet_withdrawal_review',
    source: 'admin-finance',
    extra: { withdrawalAmount: result.amount, withdrawalDecision: result.decision },
  })).catch(() => {});

  return { ok: true, decision: result.decision, clientId: result.clientId, amount: result.amount, nextBalance: result.nextBalance };
});

exports.reviewClientWalletRecharge = onCall({ region: REGION }, async (request) => {
  await ensureAdminCallable(request, 'ليس لديك صلاحية مراجعة شحن المحفظة.', 'finance');

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
  await ensureAdminCallable(request, 'Only finance admins can review payment evidence', 'finance');

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

exports.submitOrderRatings = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً.');
  }

  const orderId = String(request.data?.orderId || '').trim();
  const restaurantRating = Number(request.data?.restaurantRating || 0);
  const courierRatingRaw = request.data?.courierRating;
  const courierRating = courierRatingRaw == null || courierRatingRaw === ''
    ? null
    : Number(courierRatingRaw);
  const restaurantComment = String(request.data?.restaurantComment || '').trim().slice(0, 500);
  const courierComment = String(request.data?.courierComment || '').trim().slice(0, 500);

  if (!orderId) {
    throw new HttpsError('invalid-argument', 'orderId مطلوب.');
  }

  if (!Number.isInteger(restaurantRating) || restaurantRating < 1 || restaurantRating > 5) {
    throw new HttpsError('invalid-argument', 'تقييم المطعم يجب أن يكون بين 1 و 5.');
  }

  if (courierRating != null && (!Number.isInteger(courierRating) || courierRating < 1 || courierRating > 5)) {
    throw new HttpsError('invalid-argument', 'تقييم المندوب يجب أن يكون بين 1 و 5.');
  }

  const orderRef = db.collection('orders').doc(orderId);
  const nowTs = admin.firestore.FieldValue.serverTimestamp();

  const result = await db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) {
      throw new HttpsError('not-found', 'الطلب غير موجود.');
    }

    const order = orderSnap.data() || {};
    const clientId = String(order.clientId || '').trim();
    const restaurantId = String(order.restaurantId || '').trim();
    const driverId = String(order.assignedDriverId || '').trim();
    const orderStatus = String(order.orderStatus || order.status || '').trim().toLowerCase();

    if (!clientId || clientId !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'لا يمكنك تقييم هذا الطلب.');
    }

    if (!restaurantId) {
      throw new HttpsError('failed-precondition', 'الطلب لا يحتوي على مطعم صالح.');
    }

    if (!['delivered', 'تم التوصيل'].includes(orderStatus)) {
      throw new HttpsError('failed-precondition', 'لا يمكن التقييم قبل اكتمال التوصيل.');
    }

    if (order.hasClientRating === true || Number(order.restaurantRating || 0) > 0) {
      throw new HttpsError('already-exists', 'تم إرسال التقييم لهذا الطلب مسبقاً.');
    }

    if (driverId && courierRating == null) {
      throw new HttpsError('invalid-argument', 'تقييم المندوب مطلوب لهذا الطلب.');
    }

    const restaurantRef = db.collection('restaurants').doc(restaurantId);
    const restaurantReviewRef = restaurantRef.collection('reviews').doc(orderId);
    const restaurantSnap = await tx.get(restaurantRef);
    if (!restaurantSnap.exists) {
      throw new HttpsError('not-found', 'المطعم المرتبط بالطلب غير موجود.');
    }

    let driverRef = null;
    let driverReviewRef = null;
    let driverSnap = null;
    if (driverId && courierRating != null) {
      driverRef = db.collection('drivers').doc(driverId);
      driverReviewRef = driverRef.collection('reviews').doc(orderId);
      driverSnap = await tx.get(driverRef);
    }

    const restaurantData = restaurantSnap.data() || {};
    const restaurantRatingCount = Number(
      restaurantData.ratingCount
      ?? restaurantData.reviewCount
      ?? 0
    ) || 0;
    const restaurantRatingTotal = Number(
      restaurantData.ratingTotal
      ?? ((Number(restaurantData.ratingAverage ?? restaurantData.averageRating ?? 0) || 0) * restaurantRatingCount)
    ) || 0;
    const nextRestaurantCount = restaurantRatingCount + 1;
    const nextRestaurantTotal = restaurantRatingTotal + restaurantRating;
    const nextRestaurantAverage = Number((nextRestaurantTotal / nextRestaurantCount).toFixed(2));

    tx.set(orderRef, {
      hasClientRating: true,
      restaurantRating,
      restaurantComment,
      courierRating: courierRating ?? admin.firestore.FieldValue.delete(),
      courierComment: courierComment || admin.firestore.FieldValue.delete(),
      ratedAt: nowTs,
      ratedByClientId: request.auth.uid,
      updatedAt: nowTs,
    }, { merge: true });

    tx.set(restaurantRef, {
      ratingAverage: nextRestaurantAverage,
      averageRating: nextRestaurantAverage,
      ratingCount: nextRestaurantCount,
      reviewCount: nextRestaurantCount,
      ratingTotal: nextRestaurantTotal,
      lastRatedAt: nowTs,
      updatedAt: nowTs,
    }, { merge: true });

    tx.set(restaurantReviewRef, {
      orderId,
      clientId,
      restaurantId,
      restaurantName: String(order.restaurantName || restaurantData.name || ''),
      rating: restaurantRating,
      comment: restaurantComment,
      createdAt: nowTs,
      updatedAt: nowTs,
    }, { merge: true });

    let nextCourierAverage = null;
    let nextCourierCount = 0;

    if (driverSnap?.exists) {
        const driverData = driverSnap.data() || {};
        const courierRatingCount = Number(
          driverData.deliveryRatingCount
          ?? driverData.ratingCount
          ?? 0
        ) || 0;
        const courierRatingTotal = Number(
          driverData.deliveryRatingTotal
          ?? ((Number(driverData.deliveryRatingAverage ?? driverData.ratingAverage ?? 0) || 0) * courierRatingCount)
        ) || 0;

        nextCourierCount = courierRatingCount + 1;
        const nextCourierTotal = courierRatingTotal + courierRating;
        nextCourierAverage = Number((nextCourierTotal / nextCourierCount).toFixed(2));

        tx.set(driverRef, {
          deliveryRatingAverage: nextCourierAverage,
          deliveryRatingCount: nextCourierCount,
          deliveryRatingTotal: nextCourierTotal,
          lastRatedAt: nowTs,
          updatedAt: nowTs,
        }, { merge: true });

        tx.set(driverReviewRef, {
          orderId,
          clientId,
          driverId,
          driverName: String(order.driverName || driverData.name || ''),
          rating: courierRating,
          comment: courierComment,
          createdAt: nowTs,
          updatedAt: nowTs,
        }, { merge: true });
    }

    return {
      orderId,
      restaurantId,
      restaurantRatingAverage: nextRestaurantAverage,
      restaurantRatingCount: nextRestaurantCount,
      driverId,
      courierRatingAverage: nextCourierAverage,
      courierRatingCount: nextCourierCount,
    };
  });

  return {
    ok: true,
    ...result,
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
  const sent = results.reduce((total, result) => {
    if (result.status !== 'fulfilled') return total;
    return total + Number(result.value || 0);
  }, 0);
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

exports.notifyOnOrderCreatedRealtime = onDocumentCreated(
  {
    region: SCHEDULE_REGION,
    document: 'orders/{orderId}',
  },
  async (event) => {
    const afterData = event.data?.data() || {};
    const afterStatus = normalizeOrderStatusForNotification(
      afterData.orderStatus || afterData.status,
    );
    const lastNotifiedStatus = String(afterData.lastNotifiedStatus || '').trim();

    if (!afterStatus) return;
    if (afterStatus === lastNotifiedStatus) return;

    const result = await dispatchOrderStatusNotifications(event.params.orderId, afterData);

    await event.data.ref.set({
      lastNotifiedStatus: afterStatus,
      lastNotificationAt: admin.firestore.FieldValue.serverTimestamp(),
      lastNotificationSentCount: Number(result.sent || 0),
    }, { merge: true });
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

exports.notifyTelegramOnPaymentReviewRequired = onDocumentUpdated(
  {
    region: REGION,
    document: 'orders/{orderId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const orderId = String(event.params?.orderId || '').trim();

    const wasPendingReview = isPendingPaymentReviewOrder(before);
    const isPendingReview = isPendingPaymentReviewOrder(after);

    if (!orderId || wasPendingReview || !isPendingReview) return;
    await sendTelegramPaymentReviewAlert(orderId, after);
  }
);

exports.notifyTelegramOnPaymentReviewCreated = onDocumentCreated(
  {
    region: REGION,
    document: 'orders/{orderId}',
  },
  async (event) => {
    const after = event.data?.data() || {};
    const orderId = String(event.params?.orderId || '').trim();
    if (!orderId || !isPendingPaymentReviewOrder(after)) return;
    await sendTelegramPaymentReviewAlert(orderId, after);
  }
);

exports.notifyTelegramOnSupportMessageCreated = onDocumentCreated(
  {
    region: REGION,
    document: 'supportMessages/{messageId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const senderType = String(data.senderType || '').trim().toLowerCase();
    const conversationId = String(data.conversationId || '').trim();

    if (!conversationId) return;
    if (senderType === 'admin') return;

    const sourceAppRaw = String(data.sourceApp || '').trim().toLowerCase();
    const sourceApp = sourceAppRaw === 'courier'
      ? 'المندوب'
      : sourceAppRaw === 'store'
        ? 'المتجر'
        : 'العميل';
    const senderName = String(data.senderName || data.senderId || 'مستخدم').trim();
    const messageText = String(data.message || '').trim();
    const preview = messageText || (data.imageUrl ? 'صورة مرفقة' : 'رسالة جديدة بدون نص');

    await sendTelegramOpsAlert('رسالة دعم جديدة', [
      `المصدر: ${sourceApp}`,
      `المرسل: ${senderName}`,
      `المحادثة: ${conversationId}`,
      `المحتوى: ${preview}`,
      'الحالة: تحتاج فتح مركز الدعم الفني في الأدمن.',
    ], { category: 'support' });
  }
);

exports.notifyClientOnSupportMessageCreated = onDocumentCreated(
  {
    region: REGION,
    document: 'supportMessages/{messageId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const clientId = await resolveClientRecipientForSupportMessage(data);
    if (!clientId) return;

    await notifyClientAboutMessage(clientId, data, {
      title: 'رسالة من الدعم الفني',
      type: 'support_message',
      source: 'support',
      senderFallback: 'الدعم الفني',
      messageId: event.params?.messageId,
    });
  }
);

exports.notifyClientOnDirectChatMessageCreated = onDocumentCreated(
  {
    region: REGION,
    document: 'chats/{messageId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const chatKind = String(data.chatKind || '').trim().toLowerCase();
    if (chatKind === 'support') return;

    const clientId = await resolveClientRecipientForDirectMessage(data);
    if (!clientId) return;

    await notifyClientAboutMessage(clientId, data, {
      title: 'رسالة من المندوب',
      type: 'courier_chat_message',
      source: 'direct-chat',
      senderFallback: 'المندوب',
      messageId: event.params?.messageId,
    });
  }
);

exports.notifyTelegramOnWalletRechargeCreated = onDocumentCreated(
  {
    region: REGION,
    document: 'wallet_recharges/{rechargeId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const rechargeId = String(event.params?.rechargeId || '').trim();
    if (!rechargeId || !isPendingWalletRechargeRequest(data)) return;
    await sendTelegramWalletRechargeAlert(rechargeId, data);
  }
);

exports.notifyTelegramOnWalletRechargeQueued = onDocumentUpdated(
  {
    region: REGION,
    document: 'wallet_recharges/{rechargeId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const rechargeId = String(event.params?.rechargeId || '').trim();
    const wasPending = isPendingWalletRechargeRequest(before);
    const isPending = isPendingWalletRechargeRequest(after);
    if (!rechargeId || wasPending || !isPending) return;
    await sendTelegramWalletRechargeAlert(rechargeId, after);
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

exports.syncCourierWalletOnOrderUpdate = onDocumentUpdated(
  {
    region: REGION,
    document: 'orders/{orderId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const beforeDriverId = String(before.assignedDriverId || '').trim();
    const afterDriverId = String(after.assignedDriverId || '').trim();
    const beforeDelivered = isDeliveredOrderStatus(before.orderStatus || before.status);
    const afterDelivered = isDeliveredOrderStatus(after.orderStatus || after.status);
    const beforeDriverFee = Math.round(toSafeNumber(before.deliveryFeeForDriver ?? before.deliveryFee));
    const afterDriverFee = Math.round(toSafeNumber(after.deliveryFeeForDriver ?? after.deliveryFee));

    const shouldSync =
      beforeDriverId !== afterDriverId
      || beforeDelivered !== afterDelivered
      || (afterDelivered && beforeDriverFee !== afterDriverFee);

    if (!shouldSync) return;

    const driverIds = Array.from(new Set([beforeDriverId, afterDriverId].filter(Boolean)));
    await Promise.all(driverIds.map((driverId) => syncCourierWalletSummary(driverId)));
  }
);

exports.repairCourierAvailabilitySessionFromHeartbeat = onDocumentUpdated(
  {
    region: REGION,
    document: 'drivers/{driverId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    if (after.available !== true) return;

    const beforeHeartbeatMs = getTimestampMillis(before.lastLocationUpdate);
    const afterHeartbeatMs = getTimestampMillis(after.lastLocationUpdate);
    const startedMs = getTimestampMillis(after.availabilityCurrentStartedAt);

    if (startedMs > 0) return;
    if (afterHeartbeatMs <= 0 || afterHeartbeatMs === beforeHeartbeatMs) return;

    const todayKey = getKhartoumDayKey(afterHeartbeatMs);
    const currentDayKey = String(after.availabilityDayKey || '').trim();
    const patch = {
      availabilityCurrentStartedAt: admin.firestore.Timestamp.fromMillis(afterHeartbeatMs),
    };

    if (currentDayKey !== todayKey) {
      patch.availabilityDayKey = todayKey;
      patch.availabilityTodayMs = 0;
    }

    await event.data.after.ref.set(patch, { merge: true });
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

function calculateDriverFeeFromOrder(order, pricingConfig) {
  const resolvedDriverFee = resolveDriverFeeForPricing(order, pricingConfig);
  if (resolvedDriverFee != null) {
    return Math.round(resolvedDriverFee);
  }

  const orderDeliveryFee = toNumberOrNull(order.deliveryFee);
  if (orderDeliveryFee != null && orderDeliveryFee > 0) {
    return Math.round(orderDeliveryFee);
  }

  return 3000;
}

function calculateDistanceRuleFee(distanceKm, baseDistanceKm, baseFee, extraPerKm) {
  const safeDistance = Number.isFinite(Number(distanceKm)) ? Math.max(0, Number(distanceKm)) : 0;
  const safeBaseDistance = Number.isFinite(Number(baseDistanceKm))
    ? Math.max(0, Number(baseDistanceKm))
    : 0;
  const safeBaseFee = Number.isFinite(Number(baseFee)) ? Math.max(0, Math.round(Number(baseFee))) : 0;
  const safeExtraPerKm = Number.isFinite(Number(extraPerKm))
    ? Math.max(0, Math.round(Number(extraPerKm)))
    : 0;

  if (safeDistance <= safeBaseDistance) {
    return safeBaseFee;
  }

  const extraKm = Math.ceil(safeDistance - safeBaseDistance);
  return safeBaseFee + (extraKm * safeExtraPerKm);
}

function calculateDistanceBasedDriverFee(distanceKm, pricingConfig) {
  const config = pricingConfig || DEFAULT_PRICING_CONFIG;
  return calculateDistanceRuleFee(
    distanceKm,
    config.driverDeliveryBaseDistanceKm,
    config.driverDeliveryBaseFee,
    config.driverDeliveryExtraPerKm
  );
}

function calculateDistanceBasedClientDeliveryFee(distanceKm, pricingConfig) {
  const config = pricingConfig || DEFAULT_PRICING_CONFIG;
  return calculateDistanceRuleFee(
    distanceKm,
    config.clientDeliveryBaseDistanceKm,
    config.clientDeliveryBaseFee,
    config.clientDeliveryExtraPerKm
  );
}

function resolveDriverFeeForPricing(order, pricingConfig) {
  const existingDriverFee = toNumberOrNull(order.deliveryFeeForDriver);
  if (existingDriverFee != null && existingDriverFee > 0) {
    return Math.round(existingDriverFee);
  }

  const routeDistanceKm = toNumberOrNull(order.routeDistanceKm ?? order.distanceKm);
  if (routeDistanceKm != null && routeDistanceKm > 0) {
    return Math.round(calculateDistanceBasedDriverFee(routeDistanceKm, pricingConfig));
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
    return Math.round(calculateDistanceBasedDriverFee(distanceKm, pricingConfig));
  }

  return null;
}

function calculateClientDeliveryFeeFromOrder(order, pricingConfig) {
  const config = pricingConfig || DEFAULT_PRICING_CONFIG;
  const driverFee = resolveDriverFeeForPricing(order, config);
  const storedDeliveryFee = Math.round(toNumberOrNull(order.deliveryFee) || 0);

  const routeDistanceKm = toNumberOrNull(order.routeDistanceKm ?? order.distanceKm);
  if (routeDistanceKm != null && routeDistanceKm > 0) {
    return Math.round(calculateDistanceBasedClientDeliveryFee(routeDistanceKm, config));
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
    return Math.round(calculateDistanceBasedClientDeliveryFee(distanceKm, config));
  }

  if (driverFee == null) {
    return Math.max(0, storedDeliveryFee);
  }

  return Math.max(0, storedDeliveryFee || driverFee);
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

async function ensureAdminCallable(request, deniedMessage, requiredPermission = '') {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const callerUid = request.auth.uid;
  const callerEmail = String(request.auth.token?.email || '').toLowerCase().trim();
  const profile = isStaticAdminEmail(callerEmail)
    ? { allowed: true, permissions: [...ADMIN_PERMISSION_KEYS] }
    : await getAdminAccessProfileByUid(callerUid);
  if (!profile.allowed) {
    throw new HttpsError('permission-denied', deniedMessage || 'Only admins can perform this action');
  }

  if (requiredPermission) {
    const permissions = normalizeAdminPermissions(profile.permissions, { fallbackToAll: true });
    if (!permissions.includes(String(requiredPermission || '').trim().toLowerCase())) {
      throw new HttpsError('permission-denied', deniedMessage || 'You do not have access to this admin action');
    }
  }
}

function isActiveOrderLifecycleStatus(statusRaw) {
  const status = String(statusRaw || '').trim().toLowerCase();
  return [
    'pending',
    'store_pending',
    'courier_searching',
    'courier_offer_pending',
    'courier_assigned',
    'accepted',
    'pickup_ready',
    'picked_up',
    'arrived_to_client',
    'قيد المراجعة',
    'بانتظار المطعم',
    'قيد التجهيز',
    'قيد التوصيل',
  ].includes(status);
}

async function deleteQueryInBatches(queryRef, batchSize = 200) {
  let deleted = 0;

  while (true) {
    const snap = await queryRef.limit(batchSize).get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((docSnap) => {
      batch.delete(docSnap.ref);
    });
    await batch.commit();
    deleted += snap.size;

    if (snap.size < batchSize) break;
  }

  return deleted;
}

async function recursiveDeleteIfExists(docRef) {
  const snap = await docRef.get();
  if (!snap.exists) return false;
  await db.recursiveDelete(docRef);
  return true;
}

async function countBlockingOrdersForManagedUser(role, uid) {
  if (role === 'client') {
    const ordersSnap = await db.collection('orders').where('clientId', '==', uid).limit(300).get();
    return ordersSnap.docs.filter((docSnap) => isActiveOrderLifecycleStatus(getStatus(docSnap.data() || {}))).length;
  }

  if (role === 'courier') {
    const [assignedSnap, offeredSnap] = await Promise.all([
      db.collection('orders').where('assignedDriverId', '==', uid).limit(300).get(),
      db.collection('orders').where('offeredDriverId', '==', uid).limit(300).get(),
    ]);

    const seen = new Set();
    let count = 0;

    [...assignedSnap.docs, ...offeredSnap.docs].forEach((docSnap) => {
      if (seen.has(docSnap.id)) return;
      seen.add(docSnap.id);
      if (isActiveOrderLifecycleStatus(getStatus(docSnap.data() || {}))) {
        count += 1;
      }
    });

    return count;
  }

  return 0;
}

async function cleanupManagedUserLinkedDocuments(role, uid) {
  let deletedNotifications = 0;
  let deletedDriverNotifications = 0;
  let deletedSupportMessages = 0;

  if (role === 'client') {
    deletedSupportMessages += await deleteQueryInBatches(
      db.collection('supportMessages').where('clientId', '==', uid)
    );
  }

  if (role === 'courier') {
    deletedNotifications += await deleteQueryInBatches(
      db.collection('notifications').where('driverId', '==', uid)
    );
    deletedDriverNotifications += await deleteQueryInBatches(
      db.collection('driverNotifications').where('driverId', '==', uid)
    );
    deletedSupportMessages += await deleteQueryInBatches(
      db.collection('supportMessages').where('actorUid', '==', uid)
    );
  }

  return {
    deletedNotifications,
    deletedDriverNotifications,
    deletedSupportMessages,
  };
}

function hasOwnValue(object, key) {
  return Object.prototype.hasOwnProperty.call(object || {}, key);
}

function normalizeManagedTextValue(raw, maxLength = 500) {
  return String(raw ?? '').trim().slice(0, maxLength);
}

function normalizeManagedEmailValue(raw) {
  const email = String(raw ?? '').trim().toLowerCase();
  if (!email) return '';
  if (!email.includes('@')) {
    throw new HttpsError('invalid-argument', 'البريد الإلكتروني غير صالح');
  }
  return email;
}

function normalizeManagedNumberValue(raw, fieldLabel) {
  if (raw == null || raw === '') return null;
  const value = Number(raw);
  if (!Number.isFinite(value)) {
    throw new HttpsError('invalid-argument', `${fieldLabel} يجب أن يكون رقمًا صالحًا`);
  }
  return value;
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
      clientDeliveryBaseFee: parseRemoteNumberParam(
        parameters.pricing_client_delivery_base_fee,
        DEFAULT_PRICING_CONFIG.clientDeliveryBaseFee
      ),
      clientDeliveryBaseDistanceKm: parseRemoteNumberParam(
        parameters.pricing_client_delivery_base_distance_km,
        DEFAULT_PRICING_CONFIG.clientDeliveryBaseDistanceKm
      ),
      clientDeliveryExtraPerKm: parseRemoteNumberParam(
        parameters.pricing_client_delivery_extra_per_km,
        DEFAULT_PRICING_CONFIG.clientDeliveryExtraPerKm
      ),
      driverDeliveryBaseFee: parseRemoteNumberParam(
        parameters.pricing_driver_delivery_base_fee,
        DEFAULT_PRICING_CONFIG.driverDeliveryBaseFee
      ),
      driverDeliveryBaseDistanceKm: parseRemoteNumberParam(
        parameters.pricing_driver_delivery_base_distance_km,
        DEFAULT_PRICING_CONFIG.driverDeliveryBaseDistanceKm
      ),
      driverDeliveryExtraPerKm: parseRemoteNumberParam(
        parameters.pricing_driver_delivery_extra_per_km,
        DEFAULT_PRICING_CONFIG.driverDeliveryExtraPerKm
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

function parseRoutePoint(raw, name) {
  const lat = Number(raw?.lat ?? raw?.latitude);
  const lng = Number(raw?.lng ?? raw?.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    throw new HttpsError('invalid-argument', `${name} coordinates are required`);
  }
  if (Math.abs(lat) > 90 || Math.abs(lng) > 180) {
    throw new HttpsError('invalid-argument', `${name} coordinates are invalid`);
  }
  return { lat, lng };
}

function routeCacheKey(origin, destination) {
  const round = (n) => Number(n).toFixed(4);
  return crypto
    .createHash('sha1')
    .update(`${round(origin.lat)},${round(origin.lng)}:${round(destination.lat)},${round(destination.lng)}:driving`)
    .digest('hex');
}

function fallbackRoute(origin, destination, reason = 'fallback') {
  const distanceKm = haversineKm(origin.lat, origin.lng, destination.lat, destination.lng);
  return {
    ok: true,
    source: reason,
    isRoadRoute: false,
    distanceKm,
    distanceMeters: Math.round(distanceKm * 1000),
    durationSeconds: Math.max(60, Math.round((distanceKm / 25) * 3600)),
    durationMinutes: Math.max(1, Math.ceil((distanceKm / 25) * 60)),
    encodedPolyline: '',
  };
}

async function fetchGoogleDirectionsRoute(origin, destination) {
  const apiKey = String(
    process.env.GOOGLE_DIRECTIONS_API_KEY ||
      process.env.GOOGLE_MAPS_API_KEY ||
      process.env.MAPS_API_KEY ||
      ''
  ).trim();

  if (!apiKey) {
    return fallbackRoute(origin, destination, 'missing-api-key');
  }

  const cacheKey = routeCacheKey(origin, destination);
  const cacheRef = db.collection('route_cache').doc(cacheKey);
  const now = Date.now();
  const cacheSnap = await cacheRef.get();
  if (cacheSnap.exists) {
    const cached = cacheSnap.data() || {};
    const expiresAt = Number(cached.expiresAtMillis || 0);
    if (expiresAt > now && Number.isFinite(Number(cached.distanceMeters))) {
      const durationSeconds = Number(cached.durationSeconds || 0);
      return {
        ok: true,
        source: 'cache',
        isRoadRoute: cached.isRoadRoute === true,
        distanceKm: Number(cached.distanceMeters) / 1000,
        distanceMeters: Number(cached.distanceMeters),
        durationSeconds,
        durationMinutes: Math.max(1, Math.ceil(durationSeconds / 60)),
        encodedPolyline: String(cached.encodedPolyline || ''),
      };
    }
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 4500);
  try {
    const url = new URL('https://maps.googleapis.com/maps/api/directions/json');
    url.searchParams.set('origin', `${origin.lat},${origin.lng}`);
    url.searchParams.set('destination', `${destination.lat},${destination.lng}`);
    url.searchParams.set('mode', 'driving');
    url.searchParams.set('language', 'ar');
    url.searchParams.set('key', apiKey);

    const response = await fetch(url, { signal: controller.signal });
    const body = await response.json().catch(() => ({}));
    const route = Array.isArray(body.routes) ? body.routes[0] : null;
    const leg = Array.isArray(route?.legs) ? route.legs[0] : null;
    const distanceMeters = Number(leg?.distance?.value);
    const durationSeconds = Number(leg?.duration?.value);
    const encodedPolyline = String(route?.overview_polyline?.points || '');

    if (!response.ok || body.status !== 'OK' || !Number.isFinite(distanceMeters)) {
      logger.warn('Directions route fallback', {
        status: body.status,
        httpStatus: response.status,
        errorMessage: body.error_message,
      });
      return fallbackRoute(origin, destination, `directions-${body.status || response.status}`);
    }

    const result = {
      ok: true,
      source: 'google-directions',
      isRoadRoute: true,
      distanceKm: distanceMeters / 1000,
      distanceMeters,
      durationSeconds: Number.isFinite(durationSeconds) ? durationSeconds : 0,
      durationMinutes: Math.max(1, Math.ceil((Number.isFinite(durationSeconds) ? durationSeconds : 60) / 60)),
      encodedPolyline,
    };

    await cacheRef.set({
      ...result,
      origin,
      destination,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAtMillis: now + 7 * 24 * 60 * 60 * 1000,
    }, { merge: true });

    return result;
  } catch (error) {
    logger.warn('Directions fetch failed', { message: error?.message || String(error) });
    return fallbackRoute(origin, destination, 'directions-error');
  } finally {
    clearTimeout(timeout);
  }
}

exports.estimateRoute = onCall({ region: REGION, timeoutSeconds: 12, memory: '256MiB' }, async (request) => {
  const origin = parseRoutePoint(request.data?.origin, 'origin');
  const destination = parseRoutePoint(request.data?.destination, 'destination');
  return fetchGoogleDirectionsRoute(origin, destination);
});

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

exports.syncRestaurantClosuresFromWorkingHours = onSchedule({
  schedule: 'every 1 minutes',
  region: SCHEDULE_REGION,
  timeZone: 'Africa/Khartoum',
}, async () => {
  const clockSnapshot = getKhartoumClockSnapshot();
  let scanned = 0;
  let changed = 0;
  let skipped = 0;
  let lastDoc = null;

  while (true) {
    let restaurantsQuery = db
      .collection('restaurants')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(250);

    if (lastDoc) {
      restaurantsQuery = restaurantsQuery.startAfter(lastDoc);
    }

    const page = await restaurantsQuery.get();
    if (page.empty) break;

    let batch = db.batch();
    let batchOps = 0;

    for (const restaurantDoc of page.docs) {
      lastDoc = restaurantDoc;
      scanned += 1;

      const restaurantData = restaurantDoc.data() || {};
      if (restaurantData.workingHoursSyncEnabled === false) {
        skipped += 1;
        continue;
      }

      const nextClosed = shouldRestaurantBeTemporarilyClosedByHours(
        restaurantData,
        clockSnapshot
      );

      if (nextClosed == null) {
        skipped += 1;
        continue;
      }

      const currentClosed = restaurantData.temporarilyClosed === true;
      if (currentClosed === nextClosed) {
        continue;
      }

      batch.update(restaurantDoc.ref, {
        temporarilyClosed: nextClosed,
        workingHoursLastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
        workingHoursClosureSource: 'schedule',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batchOps += 1;
      changed += 1;

      if (batchOps >= 400) {
        await batch.commit();
        batch = db.batch();
        batchOps = 0;
      }
    }

    if (batchOps > 0) {
      await batch.commit();
    }
  }

  logger.info('syncRestaurantClosuresFromWorkingHours complete', {
    scanned,
    changed,
    skipped,
    dayKey: clockSnapshot.dayKey,
    nowMinutes: clockSnapshot.nowMinutes,
  });
});

exports.courierRespondToOffer = onCall({ region: REGION }, async (request) => {
  const { orderId, driverId, decision } = request.data || {};
  const pricingConfig = await getPricingConfigCached();
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
      const driverFee = calculateDriverFeeFromOrder(order, pricingConfig);
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

exports.adminManageOrder = onCall({ region: REGION }, async (request) => {
  await ensureAdminCallable(request, 'Only order admins can manage orders', 'orders');

  const orderId = String(request.data?.orderId || '').trim();
  const action = String(request.data?.action || '').trim().toLowerCase();
  const nextDriverId = String(request.data?.nextDriverId || '').trim();
  const note = String(request.data?.note || '').trim();

  if (!orderId || !['cancel', 'unassign_courier', 'reassign_auto', 'assign_specific'].includes(action)) {
    throw new HttpsError('invalid-argument', 'orderId and a valid action are required');
  }

  const orderRef = db.collection('orders').doc(orderId);
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) {
    throw new HttpsError('not-found', 'Order not found');
  }

  const order = orderSnap.data() || {};
  const currentStatus = getStatus(order);
  const immutableStatuses = new Set(['delivered', 'completed']);
  if (immutableStatuses.has(currentStatus)) {
    throw new HttpsError('failed-precondition', 'This order can no longer be managed from admin');
  }

  const previousAssignedDriverId = String(order.assignedDriverId || '').trim();
  const previousOfferedDriverId = String(order.offeredDriverId || '').trim();
  const previousDriverId = previousAssignedDriverId || previousOfferedDriverId;
  const adminPatch = {
    adminOrderAction: action,
    adminOrderActionAt: admin.firestore.FieldValue.serverTimestamp(),
    adminOrderActionByUid: request.auth.uid,
    adminOrderActionByEmail: String(request.auth.token?.email || ''),
    adminOrderActionNote: note,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  let result = {
    ok: true,
    orderId,
    action,
    status: currentStatus,
    assignedDriverId: previousAssignedDriverId,
  };

  if (action === 'cancel') {
    if (currentStatus === 'cancelled') {
      throw new HttpsError('failed-precondition', 'Order is already cancelled');
    }

    await orderRef.set({
      ...adminPatch,
      orderStatus: 'cancelled',
      status: 'cancelled',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledByRole: 'admin',
      cancelledByAdminUid: request.auth.uid,
      cancellationReason: note || 'admin_cancelled',
      offeredDriverId: admin.firestore.FieldValue.delete(),
      offerStartedAt: admin.firestore.FieldValue.delete(),
      offerExpiresAt: admin.firestore.FieldValue.delete(),
    }, { merge: true });

    // ─── استرداد تلقائي للمحفظة إذا كان الطلب مدفوعاً ──────────────────
    const walletUsed = Math.max(0, Math.round(toSafeNumber(order.walletUsedAmount || order.walletRequestedAmount || 0)));
    const payMethod = String(order.paymentMethod || '').trim().toLowerCase();
    const payStatus = normalizePaymentStatus(order.paymentStatus);
    const isPrepaid = payStatus === 'paid' || payStatus === 'under_review';
    const clientId = String(order.clientId || '').trim();

    if (clientId && isPrepaid && (walletUsed > 0 || payMethod === 'wallet')) {
      const refundAmount = walletUsed > 0 ? walletUsed : Math.round(toSafeNumber(order.totalWithDelivery || order.total || 0));
      if (refundAmount > 0) {
        try {
          const clientRef = db.collection('clients').doc(clientId);
          await db.runTransaction(async (tx) => {
            const clientSnap = await tx.get(clientRef);
            const clientData = clientSnap.data() || {};
            const currentBalance = toSafeNumber(
              clientData.walletBalance ?? clientData.wallet ?? clientData.balance ?? 0
            );
            const nextBalance = currentBalance + refundAmount;
            tx.set(clientRef, {
              walletBalance: nextBalance,
              wallet: nextBalance,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            tx.set(db.collection('clients').doc(clientId).collection('walletTransactions').doc(), {
              type: 'refund',
              orderId,
              amount: refundAmount,
              balanceBefore: currentBalance,
              balanceAfter: nextBalance,
              reason: 'order_cancelled',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          });
          await orderRef.set({ walletRefundedAmount: refundAmount, walletRefundedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
          await sendNotificationToSingleUser('client', clientId, buildNotificationPayload({
            title: '💰 تم استرداد المبلغ إلى محفظتك',
            body: `تم إلغاء طلبك وإعادة ${refundAmount} ج.س إلى محفظتك.`,
            type: 'wallet_refund',
            source: 'admin-order-cancel',
            orderId,
          })).catch(() => {});
        } catch (refundErr) {
          logger.warn('adminManageOrder wallet refund failed', { orderId, clientId, refundAmount, error: refundErr?.message });
        }
      }
    }

    result = {
      ...result,
      status: 'cancelled',
      assignedDriverId: '',
    };
  }

  if (action === 'unassign_courier' || action === 'reassign_auto') {
    if (!previousDriverId) {
      throw new HttpsError('failed-precondition', 'There is no courier assigned or offered for this order');
    }

    await orderRef.set({
      ...adminPatch,
      assignedDriverId: admin.firestore.FieldValue.delete(),
      offeredDriverId: admin.firestore.FieldValue.delete(),
      offerStartedAt: admin.firestore.FieldValue.delete(),
      offerExpiresAt: admin.firestore.FieldValue.delete(),
      acceptedAt: admin.firestore.FieldValue.delete(),
      offerAcceptedAt: admin.firestore.FieldValue.delete(),
      deliveryFeeForDriver: admin.firestore.FieldValue.delete(),
      orderStatus: 'courier_searching',
      status: 'courier_searching',
      reassignedByAdminAt: admin.firestore.FieldValue.serverTimestamp(),
      assignmentBackoffReason: admin.firestore.FieldValue.delete(),
    }, { merge: true });

    result = {
      ...result,
      status: 'courier_searching',
      assignedDriverId: '',
    };

    if (action === 'reassign_auto') {
      const assignResult = await assignNextCourier(orderRef);
      const refreshed = await orderRef.get();
      const refreshedData = refreshed.data() || {};
      result = {
        ...result,
        status: getStatus(refreshedData),
        assignedDriverId: String(refreshedData.assignedDriverId || refreshedData.offeredDriverId || ''),
        autoAssigned: Boolean(assignResult.assigned),
      };
    }
  }

  if (action === 'assign_specific') {
    if (!nextDriverId) {
      throw new HttpsError('invalid-argument', 'nextDriverId is required for assign_specific');
    }

    const allowedStatuses = new Set([
      'courier_searching',
      'courier_offer_pending',
      'courier_assigned',
      'pickup_ready',
      'store_pending',
      'قيد التجهيز',
    ]);

    if (!allowedStatuses.has(currentStatus)) {
      throw new HttpsError('failed-precondition', 'This order status cannot be reassigned right now');
    }

    const driverRef = db.collection('drivers').doc(nextDriverId);
    const driverSnap = await driverRef.get();
    if (!driverSnap.exists) {
      throw new HttpsError('not-found', 'Target driver not found');
    }

    const driverData = driverSnap.data() || {};
    const driverApprovalStatus = String(driverData.approvalStatus || '').trim().toLowerCase();
    if (driverApprovalStatus && driverApprovalStatus !== 'approved') {
      throw new HttpsError('failed-precondition', 'Target driver is not approved');
    }

    const pricingConfig = await getPricingConfigCached();
    const driverFee = calculateDriverFeeFromOrder(order, pricingConfig);
    await orderRef.set({
      ...adminPatch,
      assignedDriverId: nextDriverId,
      offeredDriverId: admin.firestore.FieldValue.delete(),
      offerStartedAt: admin.firestore.FieldValue.delete(),
      offerExpiresAt: admin.firestore.FieldValue.delete(),
      deliveryFeeForDriver: driverFee,
      orderStatus: 'courier_assigned',
      status: 'courier_assigned',
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      offerAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      assignmentBackoffReason: admin.firestore.FieldValue.delete(),
      rejectedByDrivers: admin.firestore.FieldValue.arrayRemove(nextDriverId),
      reassignedByAdminAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    result = {
      ...result,
      status: 'courier_assigned',
      assignedDriverId: nextDriverId,
    };
  }

  if (previousDriverId && previousDriverId !== result.assignedDriverId) {
    await sendNotificationToSingleUser(
      'courier',
      previousDriverId,
      buildNotificationPayload({
        title: action === 'cancel' ? 'تم إلغاء الطلب' : 'تم سحب الطلب منك',
        body: action === 'cancel'
          ? `تم إلغاء الطلب رقم ${orderId} من لوحة التحكم.`
          : `تم نقل الطلب رقم ${orderId} إلى مسار تشغيل آخر بواسطة الإدارة.`,
        type: 'admin_order_reassignment',
        source: 'admin-order-control',
        orderId,
      })
    ).catch((error) => {
      logger.warn('adminManageOrder previous courier notify failed', { orderId, previousDriverId, error: error?.message || error });
    });
  }

  if (action === 'assign_specific' && result.assignedDriverId) {
    await sendNotificationToSingleUser(
      'courier',
      result.assignedDriverId,
      buildNotificationPayload({
        title: 'تم تحويل طلب إليك',
        body: `قامت الإدارة بتحويل الطلب رقم ${orderId} إليك مباشرة.`,
        type: 'admin_order_assigned',
        source: 'admin-order-control',
        orderId,
      })
    ).catch((error) => {
      logger.warn('adminManageOrder next courier notify failed', { orderId, nextDriverId: result.assignedDriverId, error: error?.message || error });
    });
  }

  return result;
});

exports.deleteManagedUserAccount = onCall({ region: REGION }, async (request) => {
  await ensureAdminCallable(request, 'Only order admins can delete managed accounts', 'orders');

  const role = normalizeAudienceRole(request.data?.role);
  const uid = String(request.data?.uid || '').trim();

  if (!uid || !['client', 'courier'].includes(role)) {
    throw new HttpsError('invalid-argument', 'role and uid are required');
  }

  const collectionName = role === 'client' ? 'clients' : 'drivers';
  const roleRef = db.collection(collectionName).doc(uid);
  const roleSnap = await roleRef.get();

  let authRecord = null;
  try {
    authRecord = await admin.auth().getUser(uid);
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  if (!roleSnap.exists && !authRecord) {
    throw new HttpsError('not-found', 'User account was not found');
  }

  const authEmail = String(authRecord?.email || '').toLowerCase().trim();
  const adminSnap = await db.collection('admins').doc(uid).get();
  if (adminSnap.exists || isStaticAdminEmail(authEmail)) {
    throw new HttpsError('failed-precondition', 'This account is protected and cannot be deleted here');
  }

  const blockingOrders = await countBlockingOrdersForManagedUser(role, uid);
  if (blockingOrders > 0) {
    throw new HttpsError('failed-precondition', 'لا يمكن حذف الحساب لوجود طلبات نشطة مرتبطة به');
  }

  const linkedCleanup = await cleanupManagedUserLinkedDocuments(role, uid);
  const [roleDeleted, userDocDeleted] = await Promise.all([
    recursiveDeleteIfExists(roleRef),
    recursiveDeleteIfExists(db.collection('users').doc(uid)),
  ]);

  let authDeleted = false;
  if (authRecord) {
    await admin.auth().deleteUser(uid);
    authDeleted = true;
  }

  logger.info('deleteManagedUserAccount completed', {
    role,
    uid,
    requestedBy: request.auth?.uid || '',
    roleDeleted,
    userDocDeleted,
    authDeleted,
    ...linkedCleanup,
  });

  return {
    ok: true,
    role,
    uid,
    roleDeleted,
    userDocDeleted,
    authDeleted,
    ...linkedCleanup,
  };
});

exports.updateManagedUserProfile = onCall({ region: REGION }, async (request) => {
  await ensureAdminCallable(request, 'Only order admins can update managed accounts', 'orders');

  const role = normalizeAudienceRole(request.data?.role);
  const uid = String(request.data?.uid || '').trim();
  const rawFields = request.data?.fields;

  if (!uid || !['client', 'courier', 'store'].includes(role)) {
    throw new HttpsError('invalid-argument', 'role and uid are required');
  }

  if (!rawFields || typeof rawFields !== 'object' || Array.isArray(rawFields)) {
    throw new HttpsError('invalid-argument', 'fields object is required');
  }

  const collectionName = role === 'client'
    ? 'clients'
    : role === 'courier'
      ? 'drivers'
      : 'restaurants';
  const roleRef = db.collection(collectionName).doc(uid);
  const roleSnap = await roleRef.get();
  if (!roleSnap.exists) {
    throw new HttpsError('not-found', 'Managed account was not found');
  }

  const roleData = roleSnap.data() || {};
  const authUid = role === 'store'
    ? String(roleData.ownerUid || uid).trim() || uid
    : uid;

  let authRecord = null;
  if (authUid) {
    try {
      authRecord = await admin.auth().getUser(authUid);
    } catch (error) {
      if (error?.code !== 'auth/user-not-found') {
        throw error;
      }
    }
  }

  const rolePatch = {};
  const userPatch = {};
  const applicationPatch = {};
  let authEmail = '';
  let authDisplayName = '';
  let addressNameToSync = null;

  if (hasOwnValue(rawFields, 'name')) {
    const value = normalizeManagedTextValue(rawFields.name, 160);
    rolePatch.name = value;
    userPatch.name = value;
    userPatch.displayName = value;
    applicationPatch.name = value;
    authDisplayName = value;
    if (role === 'client') {
      rolePatch.displayName = value;
    }
  }

  if (hasOwnValue(rawFields, 'phone')) {
    const value = normalizeManagedTextValue(rawFields.phone, 40);
    rolePatch.phone = value;
    userPatch.phone = value;
    applicationPatch.phone = value;
  }

  if (hasOwnValue(rawFields, 'email')) {
    const value = normalizeManagedEmailValue(rawFields.email);
    rolePatch.email = value;
    userPatch.email = value;
    applicationPatch.email = value;
    authEmail = value;
  }

  if (role === 'client') {
    if (hasOwnValue(rawFields, 'address')) {
      const value = normalizeManagedTextValue(rawFields.address, 300);
      rolePatch.defaultAddressText = value;
      rolePatch.address = value;
      userPatch.defaultAddressText = value;
      userPatch.address = value;
      addressNameToSync = value;
    }
  }

  if (role === 'courier') {
    if (hasOwnValue(rawFields, 'vehicleType')) {
      const value = normalizeManagedTextValue(rawFields.vehicleType, 120);
      rolePatch.vehicleType = value;
      applicationPatch.vehicleType = value;
    }
    if (hasOwnValue(rawFields, 'vehiclePlate')) {
      const value = normalizeManagedTextValue(rawFields.vehiclePlate, 80);
      rolePatch.vehiclePlate = value;
      applicationPatch.vehiclePlate = value;
    }
    if (hasOwnValue(rawFields, 'nationalIdNumber')) {
      const value = normalizeManagedTextValue(rawFields.nationalIdNumber, 80);
      rolePatch.nationalIdNumber = value;
      applicationPatch.nationalIdNumber = value;
    }
    if (hasOwnValue(rawFields, 'region')) {
      const value = normalizeManagedTextValue(rawFields.region, 120);
      rolePatch.region = value;
    }
    if (hasOwnValue(rawFields, 'idImageUrl')) {
      const value = normalizeManagedTextValue(rawFields.idImageUrl, 2000);
      rolePatch.idImageUrl = value;
      applicationPatch.idImageUrl = value;
    }
  }

  if (role === 'store') {
    if (hasOwnValue(rawFields, 'commercialRecordNumber')) {
      const value = normalizeManagedTextValue(rawFields.commercialRecordNumber, 120);
      rolePatch.commercialRecordNumber = value;
      applicationPatch.commercialRecordNumber = value;
    }
    if (hasOwnValue(rawFields, 'address')) {
      const value = normalizeManagedTextValue(rawFields.address, 300);
      rolePatch.address = value;
      userPatch.address = value;
      addressNameToSync = value;
    }
    if (hasOwnValue(rawFields, 'deliveryDiscountPercentage')) {
      rolePatch.deliveryDiscountPercentage = normalizeManagedNumberValue(
        rawFields.deliveryDiscountPercentage,
        'نسبة الخصم'
      );
    }
    if (hasOwnValue(rawFields, 'coverImageUrl')) {
      rolePatch.coverImageUrl = normalizeManagedTextValue(rawFields.coverImageUrl, 2000);
    }
    if (hasOwnValue(rawFields, 'logoImageUrl')) {
      rolePatch.logoImageUrl = normalizeManagedTextValue(rawFields.logoImageUrl, 2000);
    }
  }

  const updatedFieldNames = Object.keys(rolePatch);
  if (!updatedFieldNames.length) {
    throw new HttpsError('invalid-argument', 'No supported fields were provided');
  }

  if (authEmail && !authRecord) {
    throw new HttpsError('failed-precondition', 'لا يمكن تحديث البريد لأن حساب Auth غير موجود');
  }

  if (authRecord && (authEmail || hasOwnValue(rawFields, 'name'))) {
    try {
      await admin.auth().updateUser(authUid, {
        ...(authEmail ? { email: authEmail } : {}),
        ...(hasOwnValue(rawFields, 'name') ? { displayName: authDisplayName || null } : {}),
      });
    } catch (error) {
      const message = String(error?.message || error || 'Failed to update Firebase Auth');
      throw new HttpsError('failed-precondition', message);
    }
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  await roleRef.set({
    ...rolePatch,
    updatedAt: now,
    updatedByAdminUid: request.auth.uid,
    updatedByAdminEmail: String(request.auth.token?.email || '').trim().toLowerCase(),
  }, { merge: true });

  let userDocUpdated = false;
  if (Object.keys(userPatch).length) {
    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();
    if (userSnap.exists) {
      await userRef.set({
        ...userPatch,
        updatedAt: now,
      }, { merge: true });
      userDocUpdated = true;
    }
  }

  let applicationUpdated = false;
  if (Object.keys(applicationPatch).length) {
    const applicationCollectionName = role === 'courier'
      ? 'courierApplications'
      : role === 'store'
        ? 'restaurantApplications'
        : '';
    if (applicationCollectionName) {
      const appRef = db.collection(applicationCollectionName).doc(uid);
      const appSnap = await appRef.get();
      if (appSnap.exists) {
        await appRef.set({
          ...applicationPatch,
          updatedAt: now,
        }, { merge: true });
        applicationUpdated = true;
      }
    }
  }

  let addressUpdated = false;
  if (addressNameToSync != null) {
    const defaultAddressId = String(roleData.defaultAddressId || '').trim();
    if (defaultAddressId) {
      const addressRef = roleRef.collection('addresses').doc(defaultAddressId);
      const addressSnap = await addressRef.get();
      if (addressSnap.exists) {
        await addressRef.set({
          addressName: addressNameToSync,
          updatedAt: now,
        }, { merge: true });
        addressUpdated = true;
      }
    }
  }

  return {
    ok: true,
    role,
    uid,
    updatedFields: updatedFieldNames,
    authUpdated: Boolean(authRecord && (authEmail || hasOwnValue(rawFields, 'name'))),
    userDocUpdated,
    applicationUpdated,
    addressUpdated,
  };
});

exports.setUserAdminRole = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }

  const callerUid = request.auth.uid;
  const callerEmail = String(request.auth.token?.email || '').toLowerCase().trim();
  const { email, uid, active } = request.data || {};
  const permissions = normalizeAdminPermissions(request.data?.permissions, { fallbackToAll: false });
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
  if (!bootstrapAllowed) {
    await ensureAdminCallable(request, 'Only privileged admins can manage admin roles', 'admins');
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
    permissions: permissions.length ? permissions : [...ADMIN_PERMISSION_KEYS],
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
    availabilityDayKey: '',
    availabilityTodayMs: 0,
    availabilityCurrentStartedAt: null,
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
  await ensureAdminCallable(request, 'Only approval admins can approve applications', 'approvals');

  const callerUid = request.auth.uid;

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
  await ensureAdminCallable(request, 'Only approval admins can approve applications', 'approvals');

  const callerUid = request.auth.uid;

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
    availabilityDayKey: '',
    availabilityTodayMs: 0,
    availabilityCurrentStartedAt: null,
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
  await ensureAdminCallable(request, 'Only config admins can normalize states', 'config');

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
  await ensureAdminCallable(request, 'Only config admins can read remote config', 'config');

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
  await ensureAdminCallable(request, 'Only config admins can update remote config', 'config');

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
