import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js';
import {
  getAuth,
  onAuthStateChanged,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-auth.js';
import {
  getFunctions,
  httpsCallable
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-functions.js';
import {
  getFirestore,
  collection,
  collectionGroup,
  doc,
  getDoc,
  addDoc,
  deleteDoc,
  onSnapshot,
  query,
  where,
  orderBy,
  limit,
  updateDoc,
  setDoc,
  deleteField,
  serverTimestamp,
  getDocs,
  writeBatch
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-firestore.js';

import {
  configForEnv,
  resolveAdminEnv,
  staticAdminEmails
} from './firebase-config.js?v=20260315-loginfix1';

const activeEnv = resolveAdminEnv();
const firebaseConfig = configForEnv(activeEnv);
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
const fns = getFunctions(app, 'me-central1');
const setUserAdminRole = httpsCallable(fns, 'setUserAdminRole');
const approveRestaurantApplication = httpsCallable(fns, 'approveRestaurantApplication');
const approveCourierApplication = httpsCallable(fns, 'approveCourierApplication');
const normalizeStateIdsBatch = httpsCallable(fns, 'normalizeStateIdsBatch');
const sendAdminNotification = httpsCallable(fns, 'sendAdminNotification');
const recordWalletPayout = httpsCallable(fns, 'recordWalletPayout');
const reviewOrderPaymentEvidence = httpsCallable(fns, 'reviewOrderPaymentEvidence');
const reviewClientWalletRecharge = httpsCallable(fns, 'reviewClientWalletRecharge');
const reviewClientWalletWithdrawal = httpsCallable(fns, 'reviewClientWalletWithdrawal');
const getAdminRemoteConfigSettings = httpsCallable(fns, 'getAdminRemoteConfigSettings');
const updateAdminRemoteConfigSettings = httpsCallable(fns, 'updateAdminRemoteConfigSettings');
const reviewStoreOfferRequest = httpsCallable(fns, 'reviewStoreOfferRequest');
const adminCreateStoreOffer = httpsCallable(fns, 'adminCreateStoreOffer');
const adminManageOrder = httpsCallable(fns, 'adminManageOrder');
const deleteManagedUserAccount = httpsCallable(fns, 'deleteManagedUserAccount');
const updateManagedUserProfile = httpsCallable(fns, 'updateManagedUserProfile');

const loginCard = document.getElementById('loginCard');
const appPanel = document.getElementById('appPanel');
const loginForm = document.getElementById('loginForm');
const resetPasswordBtn = document.getElementById('resetPasswordBtn');
const loginStatus = document.getElementById('loginStatus');
const logoutBtn = document.getElementById('logoutBtn');
const authState = document.getElementById('authState');
const envBadge = document.getElementById('envBadge');
const adminGlobalSearch = document.getElementById('adminGlobalSearch');
const adminSearchMeta = document.getElementById('adminSearchMeta');
const adminSearchResults = document.getElementById('adminSearchResults');
const dashboardQuickActions = document.getElementById('dashboardQuickActions');

const statsGrid = document.getElementById('statsGrid');
const opsPriorityGrid = document.getElementById('opsPriorityGrid');
const opsAlertFeed = document.getElementById('opsAlertFeed');
const opsAudioEnabledInput = document.getElementById('opsAudioEnabledInput');
const opsAudioTestBtn = document.getElementById('opsAudioTestBtn');
const opsNotificationPermissionBtn = document.getElementById('opsNotificationPermissionBtn');
const opsAudioStatus = document.getElementById('opsAudioStatus');
const publicMetricsTotalGrid = document.getElementById('publicMetricsTotalGrid');
const publicMetricsTodayGrid = document.getElementById('publicMetricsTodayGrid');
const publicMetricsUpdatedAt = document.getElementById('publicMetricsUpdatedAt');
const financeGrid = document.getElementById('financeGrid');
const activeOrdersTable = document.getElementById('activeOrdersTable');
const deliveredOrdersTable = document.getElementById('deliveredOrdersTable');
const dashboardOrderDetails = document.getElementById('dashboardOrderDetails');
const financeTotalsSummary = document.getElementById('financeTotalsSummary');
const financeOrdersTable = document.getElementById('financeOrdersTable');
const financePaymentReviewSummary = document.getElementById('financePaymentReviewSummary');
const financePaymentReviewTable = document.getElementById('financePaymentReviewTable');
const financeWalletRechargeSummary = document.getElementById('financeWalletRechargeSummary');
const financeWalletRechargeTable = document.getElementById('financeWalletRechargeTable');
const financeWalletWithdrawalSummary = document.getElementById('financeWalletWithdrawalSummary');
const financeWalletWithdrawalTable = document.getElementById('financeWalletWithdrawalTable');
const financeRangeFilter = document.getElementById('financeRangeFilter');
const financeStoresPayoutTable = document.getElementById('financeStoresPayoutTable');
const financeCouriersPayoutTable = document.getElementById('financeCouriersPayoutTable');
const paymentSettingsForm = document.getElementById('paymentSettingsForm');
const enableBankk = document.getElementById('enableBankk');
const enableOcash = document.getElementById('enableOcash');
const enableFawry = document.getElementById('enableFawry');
const bankkAccountInput = document.getElementById('bankkAccountInput');
const ocashAccountInput = document.getElementById('ocashAccountInput');
const fawryAccountInput = document.getElementById('fawryAccountInput');
const bankkAccountHolderInput = document.getElementById('bankkAccountHolderInput');
const ocashAccountHolderInput = document.getElementById('ocashAccountHolderInput');
const fawryAccountHolderInput = document.getElementById('fawryAccountHolderInput');
const bankkQrUrlInput = document.getElementById('bankkQrUrlInput');
const ocashQrUrlInput = document.getElementById('ocashQrUrlInput');
const fawryQrUrlInput = document.getElementById('fawryQrUrlInput');
const bankkQrFileInput = document.getElementById('bankkQrFileInput');
const ocashQrFileInput = document.getElementById('ocashQrFileInput');
const fawryQrFileInput = document.getElementById('fawryQrFileInput');
const bankkQrPreview = document.getElementById('bankkQrPreview');
const ocashQrPreview = document.getElementById('ocashQrPreview');
const fawryQrPreview = document.getElementById('fawryQrPreview');
const bankkInstructionsInput = document.getElementById('bankkInstructionsInput');
const ocashInstructionsInput = document.getElementById('ocashInstructionsInput');
const fawryInstructionsInput = document.getElementById('fawryInstructionsInput');
const bankkOpenUrlAndroidInput = document.getElementById('bankkOpenUrlAndroidInput');
const ocashOpenUrlAndroidInput = document.getElementById('ocashOpenUrlAndroidInput');
const fawryOpenUrlAndroidInput = document.getElementById('fawryOpenUrlAndroidInput');
const bankkOpenUrlIosInput = document.getElementById('bankkOpenUrlIosInput');
const ocashOpenUrlIosInput = document.getElementById('ocashOpenUrlIosInput');
const fawryOpenUrlIosInput = document.getElementById('fawryOpenUrlIosInput');
const bankkOpenUrlInput = document.getElementById('bankkOpenUrlInput');
const ocashOpenUrlInput = document.getElementById('ocashOpenUrlInput');
const fawryOpenUrlInput = document.getElementById('fawryOpenUrlInput');
const savePaymentSettingsBtn = document.getElementById('savePaymentSettingsBtn');
const paymentSettingsResult = document.getElementById('paymentSettingsResult');
const restaurantsTable = document.getElementById('restaurantsTable');
const couriersTable = document.getElementById('couriersTable');
const adminsTable = document.getElementById('adminsTable');
const supportRoot = document.getElementById('supportRoot');
const supportConversationList = document.getElementById('supportConversationList');
const supportConversationHeader = document.getElementById('supportConversationHeader');
const supportMessagesPane = document.getElementById('supportMessagesPane');
const supportComposer = document.getElementById('supportComposer');
const supportReplyInput = document.getElementById('supportReplyInput');
const supportAttachImageBtn = document.getElementById('supportAttachImageBtn');
const supportImageInput = document.getElementById('supportImageInput');
const supportImagePreview = document.getElementById('supportImagePreview');
const supportImagePreviewImg = document.getElementById('supportImagePreviewImg');
const supportRemoveImageBtn = document.getElementById('supportRemoveImageBtn');
const supportSendBtn = document.getElementById('supportSendBtn');
const supportToggleStatusBtn = document.getElementById('supportToggleStatusBtn');
const supportMarkReadBtn = document.getElementById('supportMarkReadBtn');
const supportMarkAllReadBtn = document.getElementById('supportMarkAllReadBtn');
const supportSearchInput = document.getElementById('supportSearchInput');
const supportAppFilter = document.getElementById('supportAppFilter');
const supportStatusFilter = document.getElementById('supportStatusFilter');
const supportSummary = document.getElementById('supportSummary');
const notificationForm = document.getElementById('notificationForm');
const notificationTargetType = document.getElementById('notificationTargetType');
const notificationUserRole = document.getElementById('notificationUserRole');
const notificationUserId = document.getElementById('notificationUserId');
const notificationTitle = document.getElementById('notificationTitle');
const notificationBody = document.getElementById('notificationBody');
const notificationSendBtn = document.getElementById('notificationSendBtn');
const notificationResult = document.getElementById('notificationResult');
const pendingTable = document.getElementById('pendingTable');
const pendingMenuTable = document.getElementById('pendingMenuTable');
const storeDetailsPanel = document.getElementById('storeDetailsPanel');
const courierDetailsPanel = document.getElementById('courierDetailsPanel');
const courierActivitySummary = document.getElementById('courierActivitySummary');
const courierActivityTable = document.getElementById('courierActivityTable');
const clientDetailsPanel = document.getElementById('clientDetailsPanel');
const operationsOrderSummary = document.getElementById('operationsOrderSummary');
const operationsOrdersTable = document.getElementById('operationsOrdersTable');
const operationsOrderDetails = document.getElementById('operationsOrderDetails');
const clientsTable = document.getElementById('clientsTable');
const orderStatusFilter = document.getElementById('orderStatusFilter');
const orderSearchInput = document.getElementById('orderSearchInput');
const ordersSegmentButtons = Array.from(document.querySelectorAll('[data-orders-segment]'));
const addAdminForm = document.getElementById('addAdminForm');
const adminEmailInput = document.getElementById('adminEmailInput');
const adminPermissionInputs = Array.from(document.querySelectorAll('input[name="adminPermission"]'));
const normalizeStateForm = document.getElementById('normalizeStateForm');
const normalizeLimitInput = document.getElementById('normalizeLimitInput');
const normalizeStateResult = document.getElementById('normalizeStateResult');
const rolloutConfigForm = document.getElementById('rolloutConfigForm');
const rolloutEnabledInput = document.getElementById('rolloutEnabledInput');
const rolloutGuardKmInput = document.getElementById('rolloutGuardKmInput');
const rolloutBlockMessageInput = document.getElementById('rolloutBlockMessageInput');
const rolloutPresetSudanBtn = document.getElementById('rolloutPresetSudanBtn');
const rolloutSelectAllBtn = document.getElementById('rolloutSelectAllBtn');
const rolloutClearAllBtn = document.getElementById('rolloutClearAllBtn');
const reloadRolloutConfigBtn = document.getElementById('reloadRolloutConfigBtn');
const rolloutCitySearchInput = document.getElementById('rolloutCitySearchInput');
const rolloutCitiesList = document.getElementById('rolloutCitiesList');
const rolloutSelectedCitiesCsv = document.getElementById('rolloutSelectedCitiesCsv');
const rolloutSelectedCount = document.getElementById('rolloutSelectedCount');
const rolloutConfigResult = document.getElementById('rolloutConfigResult');
const saveRolloutConfigBtn = document.getElementById('saveRolloutConfigBtn');
const remoteConfigBulkForm = document.getElementById('remoteConfigBulkForm');
const remoteConfigFilterInput = document.getElementById('remoteConfigFilterInput');
const remoteConfigTable = document.getElementById('remoteConfigTable');
const reloadRemoteConfigBulkBtn = document.getElementById('reloadRemoteConfigBulkBtn');
const saveRemoteConfigBulkBtn = document.getElementById('saveRemoteConfigBulkBtn');
const remoteConfigBulkResult = document.getElementById('remoteConfigBulkResult');
const appRemoteConfigForm = document.getElementById('appRemoteConfigForm');
const opsForceUpdateEnabledInput = document.getElementById('opsForceUpdateEnabledInput');
const opsMinBuildAndroidInput = document.getElementById('opsMinBuildAndroidInput');
const opsUpdateMessageInput = document.getElementById('opsUpdateMessageInput');
const opsUpdateUrlAndroidInput = document.getElementById('opsUpdateUrlAndroidInput');
const clientForceUpdateEnabledInput = document.getElementById('clientForceUpdateEnabledInput');
const clientMinBuildAndroidInput = document.getElementById('clientMinBuildAndroidInput');
const clientUpdateMessageInput = document.getElementById('clientUpdateMessageInput');
const clientUpdateUrlAndroidInput = document.getElementById('clientUpdateUrlAndroidInput');
const clientRootUrlInput = document.getElementById('clientRootUrlInput');
const storeForceUpdateEnabledInput = document.getElementById('storeForceUpdateEnabledInput');
const storeMinBuildAndroidInput = document.getElementById('storeMinBuildAndroidInput');
const storeUpdateMessageInput = document.getElementById('storeUpdateMessageInput');
const storeUpdateUrlAndroidInput = document.getElementById('storeUpdateUrlAndroidInput');
const storeRootUrlInput = document.getElementById('storeRootUrlInput');
const courierForceUpdateEnabledInput = document.getElementById('courierForceUpdateEnabledInput');
const courierMinBuildAndroidInput = document.getElementById('courierMinBuildAndroidInput');
const courierUpdateMessageInput = document.getElementById('courierUpdateMessageInput');
const courierUpdateUrlAndroidInput = document.getElementById('courierUpdateUrlAndroidInput');
const courierRootUrlInput = document.getElementById('courierRootUrlInput');
const reloadAppRemoteConfigBtn = document.getElementById('reloadAppRemoteConfigBtn');
const saveAppRemoteConfigBtn = document.getElementById('saveAppRemoteConfigBtn');
const appRemoteConfigResult = document.getElementById('appRemoteConfigResult');
const pricingConfigForm = document.getElementById('pricingConfigForm');
const pricingClientBaseFeeInput = document.getElementById('pricingClientBaseFeeInput');
const pricingClientBaseDistanceInput = document.getElementById('pricingClientBaseDistanceInput');
const pricingClientExtraPerKmInput = document.getElementById('pricingClientExtraPerKmInput');
const pricingDriverBaseFeeInput = document.getElementById('pricingDriverBaseFeeInput');
const pricingDriverBaseDistanceInput = document.getElementById('pricingDriverBaseDistanceInput');
const pricingDriverExtraPerKmInput = document.getElementById('pricingDriverExtraPerKmInput');
const pricingLargeItemFeeEnabledInput = document.getElementById('pricingLargeItemFeeEnabledInput');
const pricingLargeItemThresholdInput = document.getElementById('pricingLargeItemThresholdInput');
const pricingLargeItemFeeBaseInput = document.getElementById('pricingLargeItemFeeBaseInput');
const pricingLargeItemStepAmountInput = document.getElementById('pricingLargeItemStepAmountInput');
const pricingLargeItemStepFeeInput = document.getElementById('pricingLargeItemStepFeeInput');
const pricingLargeItemFeeCapPerUnitInput = document.getElementById('pricingLargeItemFeeCapPerUnitInput');
const reloadPricingConfigBtn = document.getElementById('reloadPricingConfigBtn');
const savePricingConfigBtn = document.getElementById('savePricingConfigBtn');
const pricingConfigResult = document.getElementById('pricingConfigResult');
const discountForm = document.getElementById('discountForm');
const discountCode = document.getElementById('discountCode');
const discountScope = document.getElementById('discountScope');
const discountType = document.getElementById('discountType');
const discountValue = document.getElementById('discountValue');
const discountMinOrder = document.getElementById('discountMinOrder');
const discountMaxUsage = document.getElementById('discountMaxUsage');
const discountMaxUsagePerUser = document.getElementById('discountMaxUsagePerUser');
const discountMaxDiscount = document.getElementById('discountMaxDiscount');
const discountRestaurantId = document.getElementById('discountRestaurantId');
const discountItemName = document.getElementById('discountItemName');
const discountExpiryDate = document.getElementById('discountExpiryDate');
const discountIsActive = document.getElementById('discountIsActive');
const discountOnlyNewOrders = document.getElementById('discountOnlyNewOrders');
const discountSaveBtn = document.getElementById('discountSaveBtn');
const discountResult = document.getElementById('discountResult');
const discountsTable = document.getElementById('discountsTable');
const adminCreateOfferForm = document.getElementById('adminCreateOfferForm');
const adminOfferRestaurantId = document.getElementById('adminOfferRestaurantId');
const adminOfferTitle = document.getElementById('adminOfferTitle');
const adminOfferDescription = document.getElementById('adminOfferDescription');
const adminOfferBadgeText = document.getElementById('adminOfferBadgeText');
const adminOfferImageUrl = document.getElementById('adminOfferImageUrl');
const adminOfferImageFile = document.getElementById('adminOfferImageFile');
const adminOfferImageStatus = document.getElementById('adminOfferImageStatus');
const adminOfferImagePreview = document.getElementById('adminOfferImagePreview');
const adminOfferDiscountScope = document.getElementById('adminOfferDiscountScope');
const adminOfferDiscountType = document.getElementById('adminOfferDiscountType');
const adminOfferDiscountValue = document.getElementById('adminOfferDiscountValue');
const adminOfferMaxDiscount = document.getElementById('adminOfferMaxDiscount');
const adminOfferMinOrder = document.getElementById('adminOfferMinOrder');
const adminOfferStartsAt = document.getElementById('adminOfferStartsAt');
const adminOfferEndsAt = document.getElementById('adminOfferEndsAt');
const adminOfferTargetItems = document.getElementById('adminOfferTargetItems');
const adminOfferReviewNote = document.getElementById('adminOfferReviewNote');
const adminOfferIsActive = document.getElementById('adminOfferIsActive');
const adminCreateOfferBtn = document.getElementById('adminCreateOfferBtn');
const adminCreateOfferResult = document.getElementById('adminCreateOfferResult');
const storeOffersSummary = document.getElementById('storeOffersSummary');
const storeOffersPendingTable = document.getElementById('storeOffersPendingTable');
const storeOffersApprovedTable = document.getElementById('storeOffersApprovedTable');
const mapDetails = document.getElementById('mapDetails');
const mapLegendBar = document.getElementById('mapLegendBar');
const mapMetrics = document.getElementById('mapMetrics');
const mapSearchInput = document.getElementById('mapSearchInput');
const mapSearchResults = document.getElementById('mapSearchResults');
const mapEventFeed = document.getElementById('mapEventFeed');
const mapSelectionBanner = document.getElementById('mapSelectionBanner');
const mapViewport = document.getElementById('mapViewport');
const mapOrderStatusFilter = document.getElementById('mapOrderStatusFilter');
const mapStyleSelect = document.getElementById('mapStyleSelect');
const mapLayerDriversInput = document.getElementById('mapLayerDriversInput');
const mapLayerClientsInput = document.getElementById('mapLayerClientsInput');
const mapLayerRestaurantsInput = document.getElementById('mapLayerRestaurantsInput');
const mapLayerOrdersInput = document.getElementById('mapLayerOrdersInput');
const mapFollowSelectedOrderInput = document.getElementById('mapFollowSelectedOrderInput');
const mapPinDetailsInput = document.getElementById('mapPinDetailsInput');
const mapFullscreenBtn = document.getElementById('mapFullscreenBtn');
const mapResetViewBtn = document.getElementById('mapResetViewBtn');
const mapFocusButtons = Array.from(document.querySelectorAll('[data-map-focus]'));

const tabs = Array.from(document.querySelectorAll('.tab'));
const tabPanels = Array.from(document.querySelectorAll('.tab-panel'));
const portalSubtabs = Array.from(document.querySelectorAll('[data-subtab]'));
const portalSubpanels = Array.from(document.querySelectorAll('[data-subpanel]'));
const baseAdminDocumentTitle = document.title || 'SpeedStar Admin';

const PORTAL_META = {
  dashboard: {
    eyebrow: 'بوابة القيادة',
    title: 'لوحة القيادة التنفيذية',
    summary: 'نقطة البداية لمتابعة مؤشرات المنصة، الوصول السريع، وآخر الطلبات القابلة للفحص فورًا.'
  },
  finance: {
    eyebrow: 'بوابة المالية',
    title: 'المسارات المالية والتحصيلات',
    summary: 'فصل واضح بين إعدادات الدفع، أكواد الخصم، المراجعات، وتحويلات المتاجر والمندوبين.'
  },
  orders: {
    eyebrow: 'مكتب الطلبات',
    title: 'متابعة الطلبات والتصعيدات التشغيلية',
    summary: 'بوابة مخصصة للطلبات نفسها مع تسلسل زمني وروابط سريعة إلى كل طرف في العملية.'
  },
  map: {
    eyebrow: 'بوابة الخريطة',
    title: 'الخريطة الحية للعمليات الميدانية',
    summary: 'عرض حي للحركة التشغيلية مع بحث مباشر وتمركز سريع على الطلبات والمندوبين والمطاعم.'
  },
  management: {
    eyebrow: 'بوابة الكيانات',
    title: 'المتاجر والمندوبون',
    summary: 'إدارة الكيانات التشغيلية الأساسية: المتاجر، القوائم، المندوبون، ونشاطهم اليومي.'
  },
  admins: {
    eyebrow: 'بوابة التحكم',
    title: 'التحكم الإداري والتوسع',
    summary: 'صلاحيات، تشغيل المدن، ومفاتيح Remote Config ضمن بوابة مستقلة للتحكم العميق.'
  },
  notifications: {
    eyebrow: 'بوابة الإشعارات',
    title: 'التواصل والتنبيهات اليدوية',
    summary: 'إرسال إشعارات دقيقة للفئات أو المستخدمين المحددين بدون تشتيت بقية أدوات الإدارة.'
  },
  support: {
    eyebrow: 'بوابة الدعم',
    title: 'إدارة المحادثات والدعم الفني',
    summary: 'مركز موحد للفرز والرد وإدارة الحالات المفتوحة والمغلقة عبر التطبيقات المختلفة.'
  },
  pending: {
    eyebrow: 'بوابة الاعتمادات',
    title: 'الطلبات المعلقة والاعتمادات الجديدة',
    summary: 'مراجعة التسجيلات واعتماد القوائم في واجهة سريعة مخصصة للمهام المؤجلة.'
  }
};

const PORTAL_THEME_MAP = {
  dashboard: { accent: '#7c3aed', soft: 'rgba(124, 58, 237, 0.12)', ink: '#4c1d95' },
  finance: { accent: '#0f766e', soft: 'rgba(15, 118, 110, 0.12)', ink: '#134e4a' },
  orders: { accent: '#c2410c', soft: 'rgba(194, 65, 12, 0.12)', ink: '#9a3412' },
  map: { accent: '#2563eb', soft: 'rgba(37, 99, 235, 0.12)', ink: '#1d4ed8' },
  management: { accent: '#059669', soft: 'rgba(5, 150, 105, 0.12)', ink: '#065f46' },
  admins: { accent: '#475569', soft: 'rgba(71, 85, 105, 0.14)', ink: '#1e293b' },
  notifications: { accent: '#db2777', soft: 'rgba(219, 39, 119, 0.12)', ink: '#9d174d' },
  support: { accent: '#0891b2', soft: 'rgba(8, 145, 178, 0.12)', ink: '#155e75' },
  pending: { accent: '#ca8a04', soft: 'rgba(202, 138, 4, 0.14)', ink: '#854d0e' },
};

const SUBPANEL_META = {
  finance: {
    'finance-overview': { title: 'الملخص والتسويات', summary: 'ملخص المدفوعات والمراجعات والتحويلات المالية.' },
    'finance-payments': { title: 'إعدادات الدفع', summary: 'إدارة الحسابات وروابط الدفع وتعليمات التحويل.' },
    'finance-discounts': { title: 'أكواد الخصم', summary: 'إنشاء الأكواد ومراجعة الخصومات النشطة والمنتهية.' },
    'finance-offers': { title: 'عروض المطاعم', summary: 'اعتماد عروض المتاجر ومتابعة حالتها.' },
  },
  management: {
    'management-stores': { title: 'المتاجر', summary: 'متابعة المتاجر المعتمدة وتفاصيل تشغيلها.' },
    'management-couriers': { title: 'المندوبون', summary: 'متابعة حالة المندوبين والدخول إلى تفاصيلهم.' },
    'management-courier-activity': { title: 'نشاط المندوبين', summary: 'تقرير تقديري لساعات النشاط اليومية والشهرية للمندوبين.' },
  },
  admins: {
    'admins-access': { title: 'الصلاحيات', summary: 'إدارة المسؤولين وتوحيد بيانات الولايات.' },
    'admins-rollout': { title: 'تشغيل المدن', summary: 'التحكم في المدن والولايات المفعّلة داخل التطبيق.' },
    'admins-remote-config': { title: 'Remote Config', summary: 'تحرير مفاتيح Remote Config والبحث فيها.' },
  },
};

const ADMIN_PERMISSION_DEFS = {
  dashboard: 'لوحة القيادة',
  finance: 'المالية والتحويلات',
  orders: 'متابعة الطلبات والتشغيل',
  map: 'الخريطة الحية',
  approvals: 'طلبات الاعتماد',
  support: 'الدعم الفني',
  notifications: 'الإشعارات',
  config: 'Remote Config وتشغيل المدن',
  admins: 'إدارة المسؤولين',
};

const ALL_ADMIN_PERMISSIONS = Object.keys(ADMIN_PERMISSION_DEFS);

const TAB_PERMISSION_REQUIREMENTS = {
  dashboard: ['dashboard'],
  finance: ['finance'],
  orders: ['orders'],
  map: ['map'],
  management: ['orders'],
  admins: ['admins', 'config'],
  notifications: ['notifications'],
  support: ['support'],
  pending: ['approvals'],
};

const SUBPANEL_PERMISSION_REQUIREMENTS = {
  'admins-access': ['admins'],
  'admins-rollout': ['config'],
  'admins-remote-config': ['config'],
};

let unsubscribers = [];
let addAdminFormBound = false;
let normalizeStateFormBound = false;
let rolloutConfigFormBound = false;
let remoteConfigBulkFormBound = false;
let appRemoteConfigFormBound = false;
let pricingConfigFormBound = false;
let discountFormBound = false;
let liveMap = null;
let mapBootstrapped = false;
let mapAutoFitted = false;
let mapLegendControlAdded = false;
let mapAddressBackfillInProgress = false;
let mapBaseLayer = null;
let mapOverlayLayer = null;
let mapRefreshTimer = null;
let mapUiBound = false;
let mapScaleControlAdded = false;
let supportConversations = [];
let supportMessagesByConversation = new Map();
let supportSelectedConversationId = '';
let supportUiBound = false;
let supportPendingImageFile = null;
let supportPendingImagePreviewUrl = '';
let supportSendInFlight = false;
let notificationFormBound = false;
let authTransitionInProgress = false;
let preservedLoginStatus = null;
let selectedOrderOnMapId = '';
let allowCompletedSelectedOrderOnMap = false;
let currentMapSelection = null;
let currentAdminProfile = null;
let currentAdminPermissions = new Set();
let financeRangeFilterBound = false;
let paymentSettingsFormBound = false;
let rolloutSelectedCityIds = new Set();
let remoteConfigParametersCache = [];
let operationsOrdersBound = false;
let operationsOrderDocsCache = [];
let courierDirectoryCache = [];
let restaurantsDirectoryCache = new Map(); // storeId → {name, ...}

const MAP_STYLE_PRESETS = {
  voyager: {
    url: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
    attribution: '&copy; OpenStreetMap &copy; CARTO',
    subdomains: 'abcd'
  },
  positron: {
    url: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    attribution: '&copy; OpenStreetMap &copy; CARTO',
    subdomains: 'abcd'
  },
  imagery: {
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: 'Tiles &copy; Esri',
    subdomains: 'abc',
    overlay: {
      url: 'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
      attribution: 'Labels &copy; Esri',
      opacity: 0.92,
      subdomains: 'abc'
    }
  },
  topo: {
    url: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    attribution: 'Map data &copy; OpenStreetMap, SRTM | Style &copy; OpenTopoMap',
    subdomains: 'abc'
  },
  osm: {
    url: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '&copy; OpenStreetMap',
    subdomains: 'abc'
  }
};

const MAP_ORDER_STATUS_LABELS = {
  active: 'كل الطلبات النشطة',
  courier_searching: 'البحث عن مندوب',
  courier_offer_pending: 'عرض معلق لمندوب',
  courier_assigned: 'مندوب معين',
  pickup_ready: 'جاهز للاستلام',
  picked_up: 'تم الاستلام',
  arrived_to_client: 'وصل للعميل'
};

const ORDER_STATUS_LABELS = {
  pending: 'قيد الانتظار',
  store_pending: 'بانتظار قبول المتجر',
  courier_searching: 'البحث عن مندوب',
  courier_offer_pending: 'عرض معلق لمندوب',
  courier_assigned: 'مندوب معين',
  accepted: 'تم القبول',
  pickup_ready: 'جاهز للاستلام',
  picked_up: 'تم الاستلام',
  arrived_to_client: 'وصل للعميل',
  delivered: 'تم التوصيل',
  completed: 'مكتمل',
  cancelled: 'ملغي',
  canceled: 'ملغي',
  rejected: 'مرفوض',
  failed: 'فشل',
  payment_review: 'مراجعة دفع',
};

const APPROVAL_STATUS_LABELS = {
  approved: 'معتمد',
  pending: 'قيد المراجعة',
  rejected: 'مرفوض',
  suspended: 'موقوف',
  inactive: 'غير نشط',
  active: 'نشط',
};

function formatOrderStatusLabel(value) {
  const raw = String(value || '').trim();
  const normalized = raw.toLowerCase();
  return ORDER_STATUS_LABELS[normalized] || raw || '-';
}

// ── Entity display helpers (name over ID) ─────────────────────────────────────

function resolveEntityDisplay(id, name) {
  if (!id) return '<span class="muted">غير معين</span>';
  const safeName = String(name || '').trim();
  const safeId   = String(id).trim();
  if (safeName && safeName !== safeId) {
    return `<span class="entity-cell"><span class="entity-cell-name">${escapeHtml(safeName)}</span><span class="entity-cell-id">${escapeHtml(safeId)}</span></span>`;
  }
  return `<span class="entity-cell"><span class="entity-cell-name entity-cell-id">${escapeHtml(safeId)}</span></span>`;
}

function resolveDriverDisplay(driverId, fallbackName = '') {
  const cached = courierDirectoryCache.find((e) => e.id === driverId);
  const name = cached?.data?.name || cached?.data?.displayName || fallbackName;
  return resolveEntityDisplay(driverId, name);
}

function resolveRestaurantDisplay(restaurantId, fallbackName = '') {
  const cached = restaurantsDirectoryCache.get(restaurantId);
  const name = cached?.name || cached?.restaurantName || fallbackName;
  return resolveEntityDisplay(restaurantId, name);
}

function resolveClientDisplay(clientId, fallbackName = '') {
  const cached = clientDirectoryCache.find((e) => e.id === clientId);
  const name = cached?.data?.name || cached?.data?.displayName || fallbackName;
  return resolveEntityDisplay(clientId, name);
}

function formatApprovalStatusLabel(value) {
  const raw = String(value || '').trim();
  const normalized = raw.toLowerCase();
  return APPROVAL_STATUS_LABELS[normalized] || raw || '-';
}

const mapUiState = {
  style: 'voyager',
  orderStatus: 'active',
  showDrivers: true,
  showClients: true,
  showRestaurants: true,
  showOrders: true,
  followSelectedOrder: false,
  pinDetails: false,
  hiddenRestaurants: [],
  events: []
};
let clientDirectoryCache = [];
const activeSubpanelByPortal = {};
const opsAlertPrefsKey = 'speedstar-admin-ops-audio-enabled';
let opsAudioContext = null;
let opsSpeechPrimed = false;
let opsAudioControlsBound = false;

const opsCenterState = {
  activeOrders: 0,
  paymentReviews: 0,
  walletRecharges: 0,
  walletWithdrawals: 0,
  supportUnread: 0,
  supportUnreadMessages: 0,
  pendingApprovals: 0,
  alerts: [],
  seenKeys: new Set(),
  paymentReviewIds: new Set(),
  walletRechargeIds: new Set(),
  supportUnreadKeys: new Set(),
  pendingApprovalIds: new Set(),
  bootstrapped: {
    paymentReviews: false,
    walletRecharges: false,
    support: false,
    pendingApprovals: false,
  },
};

const pendingRealtimeState = {
  courierApps: [],
  storeApps: [],
  fallbackDrivers: [],
  fallbackStores: [],
};

let pendingRealtimeBound = false;

function formatAttentionCount(value) {
  const count = Math.max(0, Number(value || 0));
  if (!count) return '';
  if (count > 99) return '99+';
  return count.toLocaleString('ar-EG');
}

function getFinanceAttentionCount() {
  return Math.max(0, Number(opsCenterState.paymentReviews || 0));
}

function getSupportAttentionCount() {
  return Math.max(0, Number(opsCenterState.supportUnreadMessages || opsCenterState.supportUnread || 0));
}

function getPendingAttentionCount() {
  return Math.max(0, Number(opsCenterState.pendingApprovals || 0));
}

function setTabAttentionBadge(tabId, count) {
  const badge = document.querySelector(`.tab[data-tab="${tabId}"] [data-tab-badge]`);
  if (!badge) return;
  const formatted = formatAttentionCount(count);
  badge.hidden = !formatted;
  badge.textContent = formatted || '0';
  badge.setAttribute('aria-label', formatted ? `يوجد ${formatted} تنبيه` : 'لا توجد تنبيهات');
}

function renderPortalAttentionBadges() {
  setTabAttentionBadge('finance', getFinanceAttentionCount());
  setTabAttentionBadge('support', getSupportAttentionCount());
  setTabAttentionBadge('pending', getPendingAttentionCount());
}

function renderAdminAttentionTitle() {
  const totalAttention = getFinanceAttentionCount() + getSupportAttentionCount() + getPendingAttentionCount();
  document.title = totalAttention > 0
    ? `(${formatAttentionCount(totalAttention)}) ${baseAdminDocumentTitle}`
    : baseAdminDocumentTitle;
}

function syncAdminAttentionUi() {
  renderPortalAttentionBadges();
  renderAdminAttentionTitle();
}

function resetOpsCenterAttentionState() {
  opsCenterState.activeOrders = 0;
  opsCenterState.paymentReviews = 0;
  opsCenterState.walletRecharges = 0;
  opsCenterState.supportUnread = 0;
  opsCenterState.supportUnreadMessages = 0;
  opsCenterState.pendingApprovals = 0;
  opsCenterState.alerts = [];
  opsCenterState.seenKeys = new Set();
  opsCenterState.paymentReviewIds = new Set();
  opsCenterState.walletRechargeIds = new Set();
  opsCenterState.supportUnreadKeys = new Set();
  opsCenterState.pendingApprovalIds = new Set();
  opsCenterState.bootstrapped = {
    paymentReviews: false,
    walletRecharges: false,
    support: false,
    pendingApprovals: false,
  };
  pendingRealtimeState.courierApps = [];
  pendingRealtimeState.storeApps = [];
  pendingRealtimeState.fallbackDrivers = [];
  pendingRealtimeState.fallbackStores = [];
  renderOpsAlertFeed();
  renderOpsPriorityCards();
}

function primeBrowserNotificationsPermission() {
  if (typeof window === 'undefined' || typeof Notification === 'undefined') return;
  if (Notification.permission === 'default') {
    Notification.requestPermission().catch(() => {});
  }
}

const WORKING_DAY_OPTIONS = [
  { key: 'saturday', label: 'السبت' },
  { key: 'sunday', label: 'الأحد' },
  { key: 'monday', label: 'الإثنين' },
  { key: 'tuesday', label: 'الثلاثاء' },
  { key: 'wednesday', label: 'الأربعاء' },
  { key: 'thursday', label: 'الخميس' },
  { key: 'friday', label: 'الجمعة' },
];

const REMOTE_CONFIG_METADATA = {
  ops_force_update_enabled: {
    label: 'تفعيل التحديث الإجباري العام',
    description: 'تشغيل أو إيقاف التحديث الإجباري العام على التطبيقات.',
    valueType: 'BOOLEAN',
  },
  ops_min_build_android: {
    label: 'أقل بناء أندرويد عام',
    description: 'أقل رقم بناء يُسمح به قبل إجبار المستخدم على التحديث.',
    valueType: 'NUMBER',
  },
  ops_update_message: {
    label: 'رسالة التحديث العامة',
    description: 'الرسالة العامة التي تظهر عند طلب التحديث.',
    valueType: 'STRING',
  },
  ops_update_url_android: {
    label: 'رابط التحديث العام للأندرويد',
    description: 'رابط بديل عام لتحميل آخر إصدار على أندرويد.',
    valueType: 'STRING',
  },
  client_force_update_enabled: {
    label: 'تفعيل تحديث العميل',
    description: 'تشغيل أو إيقاف التحديث الإجباري لتطبيق العميل.',
    valueType: 'BOOLEAN',
  },
  client_min_build_android: {
    label: 'أقل بناء للعميل',
    description: 'أقل رقم بناء مسموح لتطبيق العميل على أندرويد.',
    valueType: 'NUMBER',
  },
  client_update_message: {
    label: 'رسالة تحديث العميل',
    description: 'الرسالة التي تظهر لتطبيق العميل عند التحديث الإجباري.',
    valueType: 'STRING',
  },
  client_update_url_android: {
    label: 'رابط تحديث العميل',
    description: 'رابط تنزيل آخر APK أو صفحة التحديث لتطبيق العميل.',
    valueType: 'STRING',
  },
  store_force_update_enabled: {
    label: 'تفعيل تحديث المتجر',
    description: 'تشغيل أو إيقاف التحديث الإجباري لتطبيق المتجر.',
    valueType: 'BOOLEAN',
  },
  store_min_build_android: {
    label: 'أقل بناء للمتجر',
    description: 'أقل رقم بناء مسموح لتطبيق المتجر على أندرويد.',
    valueType: 'NUMBER',
  },
  store_update_message: {
    label: 'رسالة تحديث المتجر',
    description: 'الرسالة التي تظهر لتطبيق المتجر عند التحديث الإجباري.',
    valueType: 'STRING',
  },
  store_update_url_android: {
    label: 'رابط تحديث المتجر',
    description: 'رابط تنزيل آخر APK أو صفحة التحديث لتطبيق المتجر.',
    valueType: 'STRING',
  },
  courier_force_update_enabled: {
    label: 'تفعيل تحديث المندوب',
    description: 'تشغيل أو إيقاف التحديث الإجباري لتطبيق المندوب.',
    valueType: 'BOOLEAN',
  },
  courier_min_build_android: {
    label: 'أقل بناء للمندوب',
    description: 'أقل رقم بناء مسموح لتطبيق المندوب على أندرويد.',
    valueType: 'NUMBER',
  },
  courier_update_message: {
    label: 'رسالة تحديث المندوب',
    description: 'الرسالة التي تظهر لتطبيق المندوب عند التحديث الإجباري.',
    valueType: 'STRING',
  },
  courier_update_url_android: {
    label: 'رابط تحديث المندوب',
    description: 'رابط تنزيل آخر APK أو صفحة التحديث لتطبيق المندوب.',
    valueType: 'STRING',
  },
  client_root_url: {
    label: 'رابط محتوى العميل',
    description: 'الرابط الجذري الذي يجلب منه تطبيق العميل المحتوى البعيد.',
    valueType: 'STRING',
  },
  store_root_url: {
    label: 'رابط محتوى المتجر',
    description: 'الرابط الجذري الذي يجلب منه تطبيق المتجر المحتوى البعيد.',
    valueType: 'STRING',
  },
  courier_root_url: {
    label: 'رابط محتوى المندوب',
    description: 'الرابط الجذري الذي يجلب منه تطبيق المندوب المحتوى البعيد.',
    valueType: 'STRING',
  },
  client_state_guard_distance_km: {
    label: 'مسافة حراسة الولاية',
    description: 'المسافة القصوى للتحقق من تفعيل الولاية للعميل.',
    valueType: 'NUMBER',
  },
  client_state_rollout_enabled: {
    label: 'تفعيل تشغيل الولايات',
    description: 'تشغيل أو إيقاف ميزة تفعيل ولايات العميل حسب الإطلاق المرحلي.',
    valueType: 'BOOLEAN',
  },
  client_enabled_states_csv: {
    label: 'الولايات المفعلة CSV',
    description: 'قائمة الولايات أو المدن المفعلة مفصولة بفواصل.',
    valueType: 'STRING',
  },
  client_state_rollout_block_message: {
    label: 'رسالة الولايات غير المفعلة',
    description: 'الرسالة التي تظهر للمستخدم خارج النطاق المفعّل.',
    valueType: 'STRING',
  },
  pricing_client_delivery_base_fee: {
    label: 'سعر العميل الأساسي',
    description: 'سعر التوصيل للعميل حتى المسافة الأساسية.',
    valueType: 'NUMBER',
  },
  pricing_client_delivery_base_distance_km: {
    label: 'المسافة الأساسية للعميل',
    description: 'عدد الكيلومترات المشمولة في السعر الأساسي للعميل.',
    valueType: 'NUMBER',
  },
  pricing_client_delivery_extra_per_km: {
    label: 'زيادة العميل لكل كم زائد',
    description: 'الرسم الإضافي لكل كيلومتر زائد بعد المسافة الأساسية للعميل.',
    valueType: 'NUMBER',
  },
  pricing_driver_delivery_base_fee: {
    label: 'أجر المندوب الأساسي',
    description: 'أجر المندوب حتى المسافة الأساسية.',
    valueType: 'NUMBER',
  },
  pricing_driver_delivery_base_distance_km: {
    label: 'المسافة الأساسية للمندوب',
    description: 'عدد الكيلومترات المشمولة في أجر المندوب الأساسي.',
    valueType: 'NUMBER',
  },
  pricing_driver_delivery_extra_per_km: {
    label: 'زيادة المندوب لكل كم زائد',
    description: 'أجر كل كيلومتر زائد بعد المسافة الأساسية للمندوب.',
    valueType: 'NUMBER',
  },
  pricing_large_item_fee_enabled: {
    label: 'تفعيل رسوم الطلبات الكبيرة',
    description: 'تشغيل أو إيقاف رسوم الطلبات الكبيرة.',
    valueType: 'BOOLEAN',
  },
  pricing_large_item_threshold: {
    label: 'حد سعر الوجبة الكبيرة',
    description: 'السعر الذي تبدأ بعده رسوم الطلبات الكبيرة.',
    valueType: 'NUMBER',
  },
  pricing_large_item_fee_base: {
    label: 'الرسم الأساسي للطلب الكبير',
    description: 'الرسم الأساسي لكل وجبة تتجاوز الحد.',
    valueType: 'NUMBER',
  },
  pricing_large_item_step_amount: {
    label: 'شريحة الزيادة للطلب الكبير',
    description: 'مقدار الزيادة في سعر الوجبة لكل شريحة إضافية.',
    valueType: 'NUMBER',
  },
  pricing_large_item_step_fee: {
    label: 'زيادة رسم الطلب الكبير',
    description: 'الزيادة في الرسم لكل شريحة إضافية.',
    valueType: 'NUMBER',
  },
  pricing_large_item_fee_cap_per_unit: {
    label: 'سقف رسم الطلب الكبير',
    description: 'الحد الأقصى للرسم لكل وجبة.',
    valueType: 'NUMBER',
  },
};

const PRICING_REMOTE_KEYS = [
  'pricing_client_delivery_base_fee',
  'pricing_client_delivery_base_distance_km',
  'pricing_client_delivery_extra_per_km',
  'pricing_driver_delivery_base_fee',
  'pricing_driver_delivery_base_distance_km',
  'pricing_driver_delivery_extra_per_km',
  'pricing_large_item_fee_enabled',
  'pricing_large_item_threshold',
  'pricing_large_item_fee_base',
  'pricing_large_item_step_amount',
  'pricing_large_item_step_fee',
  'pricing_large_item_fee_cap_per_unit',
];

const APP_REMOTE_KEYS = [
  'ops_force_update_enabled',
  'ops_min_build_android',
  'ops_update_message',
  'ops_update_url_android',
  'client_force_update_enabled',
  'client_min_build_android',
  'client_update_message',
  'client_update_url_android',
  'client_root_url',
  'store_force_update_enabled',
  'store_min_build_android',
  'store_update_message',
  'store_update_url_android',
  'store_root_url',
  'courier_force_update_enabled',
  'courier_min_build_android',
  'courier_update_message',
  'courier_update_url_android',
  'courier_root_url',
];

function getPortalSubpanelMeta(portalId, subpanelId) {
  return SUBPANEL_META[portalId]?.[subpanelId] || { title: '', summary: '' };
}

function getPortalSubpanelNodes(portalId) {
  return portalSubpanels.filter((panel) => panel.dataset.subpanel?.startsWith(`${portalId}-`));
}

function getPortalSubtabButtons(portalId) {
  return portalSubtabs.filter((button) => button.dataset.subtab?.startsWith(`${portalId}-`));
}

function activateSubpanel(portalId, subpanelId, options = {}) {
  const { scroll = false } = options;
  const portalPanels = getPortalSubpanelNodes(portalId)
    .filter((panel) => !panel.hidden && canAccessSubpanel(String(panel.dataset.subpanel || '')));
  if (!portalPanels.length) return;

  const nextSubpanelId = portalPanels.some((panel) => panel.dataset.subpanel === subpanelId)
    ? subpanelId
    : portalPanels[0].dataset.subpanel;

  activeSubpanelByPortal[portalId] = nextSubpanelId;

  getPortalSubtabButtons(portalId).forEach((button) => {
    const isActive = button.dataset.subtab === nextSubpanelId;
    button.classList.toggle('active', isActive);
    button.setAttribute('aria-pressed', isActive ? 'true' : 'false');
  });

  portalPanels.forEach((panel) => {
    panel.classList.toggle('active', panel.dataset.subpanel === nextSubpanelId);
  });

  if (scroll) {
    const targetPanel = portalPanels.find((panel) => panel.dataset.subpanel === nextSubpanelId);
    targetPanel?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
}

function ensurePortalSubpanel(portalId) {
  const portalPanels = getPortalSubpanelNodes(portalId)
    .filter((panel) => !panel.hidden && canAccessSubpanel(String(panel.dataset.subpanel || '')));
  if (!portalPanels.length) return;
  activateSubpanel(portalId, activeSubpanelByPortal[portalId] || portalPanels[0].dataset.subpanel);
}

function applyPortalThemeAttributes() {
  tabs.forEach((tab) => {
    const portalId = String(tab.dataset.tab || '').trim();
    if (!portalId) return;
    const tone = PORTAL_THEME_MAP[portalId];
    if (!tone) return;
    tab.dataset.portalTone = portalId;
    tab.style.setProperty('--portal-accent', tone.accent);
    tab.style.setProperty('--portal-accent-soft', tone.soft);
    tab.style.setProperty('--portal-accent-ink', tone.ink);
  });

  tabPanels.forEach((panel) => {
    const portalId = String(panel.id || '').trim();
    if (!portalId) return;
    const tone = PORTAL_THEME_MAP[portalId];
    if (!tone) return;
    panel.dataset.portalTone = portalId;
    panel.style.setProperty('--portal-accent', tone.accent);
    panel.style.setProperty('--portal-accent-soft', tone.soft);
    panel.style.setProperty('--portal-accent-ink', tone.ink);
  });
}

function syncPortalPresentation(id) {
  document.body.dataset.activePortal = id;
  tabs.forEach((tab) => {
    const isActive = tab.dataset.tab === id;
    tab.setAttribute('aria-current', isActive ? 'page' : 'false');
  });
}

function summarizeSearchPreview(row) {
  const cells = Array.from(row.querySelectorAll('td'))
    .map((cell) => String(cell.textContent || '').trim())
    .filter(Boolean)
    .slice(0, 3);
  if (cells.length) return cells.join(' - ');
  return String(row.textContent || '').replace(/\s+/g, ' ').trim();
}

function renderAdminSearchResults(stats = {}) {
  if (!adminSearchResults || !adminSearchMeta) return;

  const query = String(adminGlobalSearch?.value || '').trim().toLowerCase();
  if (!query) {
    adminSearchMeta.textContent = 'اكتب أي كلمة للبحث داخل الجداول والبوابات.';
    adminSearchResults.innerHTML = '';
    return;
  }

  const matches = tabPanels
    .flatMap((panel) => {
      const scopes = Array.from(panel.querySelectorAll('[data-subpanel]'));
      const searchScopes = scopes.length ? scopes : [panel];

      return searchScopes.map((scope) => {
        const rows = Array.from(scope.querySelectorAll('table tbody tr'));
        const matchedRows = rows.filter((row) => String(row.textContent || '').toLowerCase().includes(query));
        const scopeText = String(scope.textContent || '').toLowerCase();
        if (!matchedRows.length && !scopeText.includes(query)) {
          return null;
        }

        const samples = matchedRows.slice(0, 2).map((row) => summarizeSearchPreview(row));
        const meta = PORTAL_META[panel.id] || PORTAL_META.dashboard;
        const subpanelId = scope.getAttribute('data-subpanel') || '';
        const subMeta = getPortalSubpanelMeta(panel.id, subpanelId);
        return {
          id: panel.id,
          subpanelId,
          title: meta.title,
          eyebrow: meta.eyebrow,
          subTitle: subMeta.title,
          count: matchedRows.length,
          sample: samples.join(' | ') || subMeta.summary || meta.summary,
        };
      });
    })
    .filter(Boolean)
    .slice(0, 8);

  const visibleRows = Number(stats.visibleRows || 0);
  const totalRows = Number(stats.totalRows || 0);
  adminSearchMeta.textContent = matches.length
    ? `تم العثور على ${matches.length} بوابة مطابقة${totalRows ? `، والصفوف الظاهرة في البوابة الحالية ${visibleRows}/${totalRows}` : ''}.`
    : 'لا توجد نتائج مطابقة داخل البوابات الحالية.';

  if (!matches.length) {
    adminSearchResults.innerHTML = '';
    return;
  }

  setHtml(
    adminSearchResults,
    matches.map((match) => `
      <div class="search-result-item">
        <div>
          <b>${escapeHtml(match.eyebrow)} - ${escapeHtml(match.title)}${match.subTitle ? ` / ${escapeHtml(match.subTitle)}` : ''}</b>
          <span>${escapeHtml(match.sample || 'مطابقة داخل هذه البوابة')} ${match.count ? `(${match.count})` : ''}</span>
        </div>
        <button class="btn ghost" type="button" data-search-tab="${escapeHtml(match.id)}" data-search-subpanel="${escapeHtml(match.subpanelId || '')}">فتح</button>
      </div>
    `).join('')
  );

  adminSearchResults.querySelectorAll('[data-search-tab]').forEach((button) => {
    button.addEventListener('click', () => {
      const targetTab = button.getAttribute('data-search-tab');
      const targetSubpanel = button.getAttribute('data-search-subpanel');
      if (!targetTab) return;
      activateTab(targetTab);
      if (targetSubpanel) {
        activateSubpanel(targetTab, targetSubpanel, { scroll: true });
      }
    });
  });
}

applyPortalThemeAttributes();
syncPortalPresentation('dashboard');

const guaranteedAdminEmails = new Set([
  'speedstarapp0@gmail.com',
  ...staticAdminEmails.map((email) => String(email || '').toLowerCase())
]);

const SUDAN_CITY_LABELS = [
  'الخرطوم', 'بحري', 'أم درمان', 'جبل أولياء', 'شرق النيل',
  'مدني', 'ود مدني', 'الحصاحيصا', 'رفاعة', 'المناقل',
  'بورتسودان', 'سواكن', 'سنكات', 'هيا', 'طوكر',
  'كسلا', 'حلفا الجديدة', 'القضارف', 'دوكة', 'القلابات',
  'سنار', 'سنجة', 'الدندر', 'الدمازين', 'الروصيرص',
  'كوستي', 'ربك', 'تندلتي', 'الدويم', 'القطينة',
  'الأبيض', 'الرهد', 'بارا', 'أم روابة', 'النهود',
  'الفاشر', 'نيالا', 'الجنينة', 'زالنجي', 'كتم',
  'الدلنج', 'كادوقلي', 'أبو جبيهة', 'لقاوة', 'تلودي',
  'عطبرة', 'شندي', 'الدامر', 'بربر', 'ابو حمد',
  'دنقلا', 'مروي', 'كريمة', 'حلفا', 'وادي حلفا',
  'النيل الأزرق', 'النيل الازرق', 'الجزيرة', 'القضارف', 'كسلا',
  'البحر الأحمر', 'البحر الاحمر', 'نهر النيل', 'شمال كردفان', 'غرب كردفان',
  'جنوب كردفان', 'شمال دارفور', 'جنوب دارفور', 'شرق دارفور', 'غرب دارفور',
  'وسط دارفور', 'شمال', 'الولاية الشمالية', 'الشمالية', 'شمال السودان'
];

function normalizeRolloutToken(raw) {
  const value = String(raw || '').trim();
  if (!value) return '';
  return value
    .replaceAll('أ', 'ا')
    .replaceAll('إ', 'ا')
    .replaceAll('آ', 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(/[^\p{L}\p{N}\s]+/gu, ' ')
    .replaceAll(/\s+/g, ' ')
    .toLowerCase()
    .trim();
}

const SUDAN_CITY_OPTIONS = (() => {
  const out = [];
  const seen = new Set();
  SUDAN_CITY_LABELS.forEach((label) => {
    const id = normalizeRolloutToken(label);
    if (!id || seen.has(id)) return;
    seen.add(id);
    out.push({ id, label });
  });
  return out.sort((a, b) => a.label.localeCompare(b.label, 'ar'));
})();

function csvToRolloutSet(raw) {
  const items = String(raw || '')
    .split(',')
    .map((item) => normalizeRolloutToken(item))
    .filter(Boolean);
  return new Set(items);
}

function setToCsv(setValues) {
  return Array.from(setValues)
    .filter(Boolean)
    .sort((a, b) => a.localeCompare(b, 'ar'))
    .join(',');
}

function syncEnvUi() {
  if (envBadge) {
    envBadge.textContent = `ENV: PROD | ${firebaseConfig.projectId}`;
  }
}

syncEnvUi();
bindOpsAudioControls();

function loadOpsAudioPreference() {
  try {
    const stored = window.localStorage.getItem(opsAlertPrefsKey);
    return stored == null ? true : stored === '1';
  } catch (_) {
    return true;
  }
}

function saveOpsAudioPreference(enabled) {
  try {
    window.localStorage.setItem(opsAlertPrefsKey, enabled ? '1' : '0');
  } catch (_) {
  }
}

function isOpsAudioEnabled() {
  return opsAudioEnabledInput ? opsAudioEnabledInput.checked === true : true;
}

function renderOpsAudioStatus(message) {
  if (!opsAudioStatus) return;
  if (message) {
    opsAudioStatus.textContent = message;
    return;
  }
  const browserPermission = typeof Notification === 'undefined' ? 'غير مدعوم' : Notification.permission;
  opsAudioStatus.textContent = isOpsAudioEnabled()
    ? `التنبيه الصوتي مفعل. حالة إشعارات المتصفح: ${browserPermission}. أبق الصفحة مفتوحة لسماع التنبيهات الجديدة.`
    : 'التنبيه الصوتي متوقف حاليًا. يمكنك تفعيله لسماع رسائل الدعم والإيصالات الجديدة بصوت منطوق.';
}

function ensureOpsAudioContext() {
  if (typeof window === 'undefined') return null;
  const AudioCtor = window.AudioContext || window.webkitAudioContext;
  if (!AudioCtor) return null;
  if (!opsAudioContext) {
    opsAudioContext = new AudioCtor();
  }
  if (opsAudioContext.state === 'suspended') {
    opsAudioContext.resume().catch(() => {});
  }
  return opsAudioContext;
}

function playOpsChime() {
  const ctx = ensureOpsAudioContext();
  if (!ctx) return;
  const now = ctx.currentTime;
  const oscillator = ctx.createOscillator();
  const gain = ctx.createGain();
  oscillator.type = 'sine';
  oscillator.frequency.setValueAtTime(740, now);
  oscillator.frequency.linearRampToValueAtTime(988, now + 0.16);
  gain.gain.setValueAtTime(0.0001, now);
  gain.gain.exponentialRampToValueAtTime(0.09, now + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.42);
  oscillator.connect(gain);
  gain.connect(ctx.destination);
  oscillator.start(now);
  oscillator.stop(now + 0.45);
}

function speakOpsAlert(text) {
  if (typeof window === 'undefined' || !window.speechSynthesis || !text) return;
  try {
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = 'ar-SA';
    utterance.rate = 1;
    utterance.pitch = 1;
    const voices = window.speechSynthesis.getVoices();
    const arabicVoice = voices.find((voice) => String(voice.lang || '').toLowerCase().startsWith('ar'));
    if (arabicVoice) {
      utterance.voice = arabicVoice;
      utterance.lang = arabicVoice.lang || 'ar-SA';
    }
    window.speechSynthesis.cancel();
    window.speechSynthesis.speak(utterance);
    opsSpeechPrimed = true;
  } catch (_) {
  }
}

function playOpsAlertCue(title, body) {
  if (!isOpsAudioEnabled()) return;
  playOpsChime();
  const spoken = [title, body].filter(Boolean).join('. ');
  speakOpsAlert(spoken);
}

function bindOpsAudioControls() {
  if (opsAudioControlsBound) return;
  if (opsAudioEnabledInput) {
    opsAudioEnabledInput.checked = loadOpsAudioPreference();
    opsAudioEnabledInput.addEventListener('change', () => {
      saveOpsAudioPreference(opsAudioEnabledInput.checked === true);
      if (opsAudioEnabledInput.checked) {
        ensureOpsAudioContext();
      } else if (typeof window !== 'undefined' && window.speechSynthesis) {
        window.speechSynthesis.cancel();
      }
      renderOpsAudioStatus();
    });
  }
  opsAudioTestBtn?.addEventListener('click', async () => {
    ensureOpsAudioContext();
    primeBrowserNotificationsPermission();
    playOpsAlertCue('تنبيه تجريبي من لوحة التحكم', 'سيصلك هذا الصوت عند وجود رسالة دعم جديدة أو إيصال جديد للمراجعة.');
    renderOpsAudioStatus('تم تشغيل التنبيه التجريبي. إذا سمعت الصوت والنطق فالنظام جاهز.');
  });
  opsNotificationPermissionBtn?.addEventListener('click', async () => {
    primeBrowserNotificationsPermission();
    renderOpsAudioStatus();
  });
  opsAudioControlsBound = true;
  renderOpsAudioStatus();
}

function formatOpsTime(value) {
  const date = value instanceof Date ? value : new Date();
  try {
    return date.toLocaleTimeString('ar-EG', { hour: 'numeric', minute: '2-digit' });
  } catch (_) {
    return '-';
  }
}

function maybeNotifyBrowser(title, body) {
  if (typeof window === 'undefined' || typeof Notification === 'undefined') return;
  if (Notification.permission === 'default') {
    Notification.requestPermission().catch(() => {});
    return;
  }
  if (Notification.permission !== 'granted') return;
  try {
    new Notification(title, { body });
  } catch (_) {
  }
}

function renderOpsAlertFeed() {
  if (!opsAlertFeed) return;
  if (!opsCenterState.alerts.length) {
    opsAlertFeed.innerHTML = '<div class="muted">لا توجد تنبيهات تشغيلية جديدة حاليًا.</div>';
    return;
  }

  opsAlertFeed.innerHTML = opsCenterState.alerts
    .slice(0, 10)
    .map((item) => `
      <article class="ops-alert-card ${escapeHtml(item.level || 'info')}">
        <div>
          <strong>${escapeHtml(item.title)}</strong>
          <p>${escapeHtml(item.body)}</p>
        </div>
        <time>${escapeHtml(item.timeLabel)}</time>
      </article>
    `)
    .join('');
}

function renderOpsPriorityCards() {
  if (!opsPriorityGrid) return;
  opsPriorityGrid.innerHTML = `
    <div class="stat accent-danger"><h4>إيصالات بانتظار المراجعة</h4><b>${Number(opsCenterState.paymentReviews || 0).toLocaleString('ar-EG')}</b></div>
    <div class="stat accent-amber"><h4>شحن محافظ بانتظار المراجعة</h4><b>${Number(opsCenterState.walletRecharges || 0).toLocaleString('ar-EG')}</b></div>
    <div class="stat accent-blue"><h4>محادثات دعم غير مقروءة</h4><b>${Number(opsCenterState.supportUnread || 0).toLocaleString('ar-EG')}</b></div>
    <div class="stat accent-green"><h4>طلبات نشطة قابلة للتحكم</h4><b>${Number(opsCenterState.activeOrders || 0).toLocaleString('ar-EG')}</b></div>
    <div class="stat"><h4>اعتمادات معلقة</h4><b>${Number(opsCenterState.pendingApprovals || 0).toLocaleString('ar-EG')}</b></div>
  `;
  syncAdminAttentionUi();
}

function pushOpsAlert(key, title, body, level = 'info') {
  if (!key || opsCenterState.seenKeys.has(key)) return;
  opsCenterState.seenKeys.add(key);
  const entry = {
    key,
    title,
    body,
    level,
    createdAt: Date.now(),
    timeLabel: formatOpsTime(new Date()),
  };
  opsCenterState.alerts.unshift(entry);
  opsCenterState.alerts = opsCenterState.alerts.slice(0, 20);
  renderOpsAlertFeed();
  maybeNotifyBrowser(title, body);
  playOpsAlertCue(title, body);
}

function syncOpsCollectionState(kind, nextIds, payloadBuilder) {
  const stateMap = {
    paymentReviews: 'paymentReviewIds',
    walletRecharges: 'walletRechargeIds',
    supportUnread: 'supportUnreadKeys',
  };
  const keyName = stateMap[kind];
  if (!keyName) return;

  const prev = opsCenterState[keyName];
  nextIds.forEach((id) => {
    if (!prev.has(id) && opsCenterState.bootstrapped[kind]) {
      const payload = payloadBuilder(id) || {};
      pushOpsAlert(`${kind}:${id}`, payload.title || 'تنبيه جديد', payload.body || 'يوجد عنصر جديد يحتاج المراجعة.', payload.level || 'info');
    }
  });
  opsCenterState[keyName] = nextIds;
  opsCenterState.bootstrapped[kind] = true;
  renderOpsPriorityCards();
}

function getOrderLifecycleStatus(order) {
  return String(order?.orderStatus || order?.status || '').trim().toLowerCase();
}

function isActiveOrderStatus(status) {
  return [
    'pending',
    'payment_review',
    'store_pending',
    'courier_searching',
    'courier_offer_pending',
    'courier_assigned',
    'accepted',
    'pickup_ready',
    'picked_up',
    'arrived_to_client',
  ].includes(String(status || '').trim().toLowerCase());
}

function isDeliveredOrderStatus(status) {
  return ['delivered', 'تم التوصيل', 'completed'].includes(String(status || '').trim().toLowerCase());
}

function getTimestampMillis(value) {
  if (!value) return 0;
  if (typeof value?.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function getLocalDayKey(value = new Date()) {
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, '0');
  const day = String(value.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function getCourierAvailableTodayMs(driver = {}, nowMs = Date.now()) {
  const now = new Date(nowMs);
  const todayKey = getLocalDayKey(now);
  const todayStartMs = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const dayKey = String(driver.availabilityDayKey || '').trim();
  const baseMs = dayKey === todayKey ? Math.max(0, Number(driver.availabilityTodayMs || 0)) : 0;
  const startedMs = getTimestampMillis(driver.availabilityCurrentStartedAt);

  if (driver.available === true && startedMs > 0) {
    return baseMs + Math.max(0, nowMs - Math.max(startedMs, todayStartMs));
  }

  if (baseMs <= 0 && startedMs > 0) {
    const lastSeenMs = getCourierLastActivityMillis(driver);
    const effectiveEndMs = Math.min(nowMs, lastSeenMs || 0);
    if (effectiveEndMs > 0) {
      return Math.max(0, effectiveEndMs - Math.max(startedMs, todayStartMs));
    }
  }

  return baseMs;
}

async function buildDriverAvailabilityPatch(driverId, nextAvailable) {
  const ref = doc(db, 'drivers', driverId);
  const snap = await getDoc(ref);
  const data = snap.data() || {};
  const nowMs = Date.now();
  const now = new Date(nowMs);
  const todayKey = getLocalDayKey(now);
  const todayStartMs = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const currentDayKey = String(data.availabilityDayKey || '').trim();
  const currentStartedMs = getTimestampMillis(data.availabilityCurrentStartedAt);
  let totalTodayMs = currentDayKey === todayKey ? Math.max(0, Number(data.availabilityTodayMs || 0)) : 0;

  if (!nextAvailable && currentStartedMs > 0) {
    totalTodayMs += Math.max(0, nowMs - Math.max(currentStartedMs, todayStartMs));
  }

  return {
    available: nextAvailable,
    availabilityDayKey: todayKey,
    availabilityTodayMs: Math.round(totalTodayMs),
    availabilityCurrentStartedAt: nextAvailable ? serverTimestamp() : null,
    updatedAt: serverTimestamp(),
  };
}

function getCourierLastActivityMillis(driver = {}) {
  return Math.max(
    getTimestampMillis(driver.lastUpdated),
    getTimestampMillis(driver.lastLocationUpdate),
    getTimestampMillis(driver.updatedAt),
    getTimestampMillis(driver.createdAt)
  );
}

function getCourierOrderActivityStartMillis(order = {}) {
  return [
    order.acceptedAt,
    order.offerAcceptedAt,
    order.courierAcceptedAt,
    order.pickedUpAt,
    order.arrivedToClientAt,
    order.createdAt,
    order.updatedAt,
  ].map(getTimestampMillis).find((value) => value > 0) || 0;
}

function getCourierOrderActivityEndMillis(order = {}, nowMs = Date.now()) {
  const status = getOrderLifecycleStatus(order);
  if (isActiveOrderStatus(status)) return nowMs;
  return [
    order.deliveredAt,
    order.completedAt,
    order.updatedAt,
  ].map(getTimestampMillis).find((value) => value > 0) || 0;
}

function getOverlappingDurationMs(startMs, endMs, rangeStartMs, rangeEndMs) {
  if (!startMs || !endMs || endMs <= startMs) return 0;
  const boundedStart = Math.max(startMs, rangeStartMs);
  const boundedEnd = Math.min(endMs, rangeEndMs);
  return boundedEnd > boundedStart ? boundedEnd - boundedStart : 0;
}

function formatDurationHours(durationMs) {
  const hours = Math.max(0, durationMs) / (60 * 60 * 1000);
  if (!hours) return '0 س';
  if (hours < 1) return `${Math.round(hours * 60)} د`;
  return `${hours.toLocaleString('ar-EG', { minimumFractionDigits: hours >= 10 ? 0 : 1, maximumFractionDigits: 1 })} س`;
}

function buildEntityFactsGrid(items = []) {
  const safeItems = items.filter((item) => item && item.label);
  if (!safeItems.length) return '';
  return `
    <div class="entity-facts-grid">
      ${safeItems.map((item) => `
        <div class="entity-fact${item.className ? ` ${escapeHtml(item.className)}` : ''}">
          <span>${escapeHtml(item.label)}</span>
          <strong>${escapeHtml(String(item.value ?? '-'))}</strong>
        </div>
      `).join('')}
    </div>
  `;
}

function buildEntitySection(title, body, options = {}) {
  const eyebrow = String(options.eyebrow || '').trim();
  const description = String(options.description || '').trim();
  return `
    <section class="entity-section">
      <div class="entity-section-head">
        ${eyebrow ? `<span class="entity-section-eyebrow">${escapeHtml(eyebrow)}</span>` : ''}
        <h5>${escapeHtml(title)}</h5>
        ${description ? `<p>${escapeHtml(description)}</p>` : ''}
      </div>
      <div class="entity-section-body">${body}</div>
    </section>
  `;
}

function buildBankAccountsDetailsMarkup(data) {
  const account = typeof parseAccount === 'function' ? parseAccount(data) : {
    method: String(data?.payoutMethod || '').trim(),
    accountNumber: String(data?.payoutAccountNumber || '').trim(),
    accountName: String(data?.payoutAccountName || '').trim(),
  };

  if (!account.method && !account.accountName && !account.accountNumber) {
    return '';
  }

  const methodLabelMap = {
    bankk: 'بنكك',
    ocash: 'أوكاش',
    fawry: 'فوري',
  };
  const methodLabel = methodLabelMap[String(account.method || '').trim().toLowerCase()] || account.method || '-';

  return buildEntitySection(
    'بيانات التحويل',
    buildEntityFactsGrid([
      { label: 'طريقة التحويل', value: methodLabel },
      { label: 'اسم صاحب الحساب', value: account.accountName || '-' },
      { label: 'رقم الحساب', value: account.accountNumber || '-' },
    ]),
    { eyebrow: 'المالية' }
  );
}

function formatDateTimeLabel(value) {
  const ms = getTimestampMillis(value);
  if (!ms) return '-';
  try {
    return new Date(ms).toLocaleString('ar-EG');
  } catch (_) {
    return '-';
  }
}

function buildWorkingHoursEditorMarkup(workingHours) {
  return `
    <div class="working-hours-editor">
      ${WORKING_DAY_OPTIONS.map(({ key, label }) => {
        const entry = workingHours?.[key] || {};
        const status = String(entry.status || '').trim() === 'مغلق' ? 'مغلق' : 'مفتوح';
        const open = String(entry.open || '08:00 ص').trim();
        const close = String(entry.close || '11:00 م').trim();
        return `
          <div class="working-hour-row" data-working-day="${escapeHtml(key)}">
            <strong>${escapeHtml(label)}</strong>
            <select data-working-status="${escapeHtml(key)}">
              <option value="مفتوح" ${status === 'مفتوح' ? 'selected' : ''}>مفتوح</option>
              <option value="مغلق" ${status === 'مغلق' ? 'selected' : ''}>مغلق</option>
            </select>
            <input data-working-open="${escapeHtml(key)}" type="text" value="${escapeHtml(open)}" placeholder="08:00 ص" />
            <input data-working-close="${escapeHtml(key)}" type="text" value="${escapeHtml(close)}" placeholder="11:00 م" />
          </div>
        `;
      }).join('')}
    </div>
  `;
}

function collectWorkingHoursFromPanel(storeId) {
  const result = {};
  WORKING_DAY_OPTIONS.forEach(({ key }) => {
    const status = document.querySelector(`[data-working-status="${key}"]`)?.value || 'مفتوح';
    const open = document.querySelector(`[data-working-open="${key}"]`)?.value || '08:00 ص';
    const close = document.querySelector(`[data-working-close="${key}"]`)?.value || '11:00 م';
    result[key] = {
      status: String(status).trim() === 'مغلق' ? 'مغلق' : 'مفتوح',
      open: String(open).trim() || '08:00 ص',
      close: String(close).trim() || '11:00 م',
    };
  });
  return result;
}

async function markSupportConversationRead(conversationId) {
  if (!conversationId) return;
  const q = query(collection(db, 'supportMessages'), where('conversationId', '==', conversationId));
  const result = await getDocs(q);
  if (!result.docs.length) return;
  const batch = writeBatch(db);
  result.docs.forEach((docSnap) => {
    batch.set(doc(db, 'supportMessages', docSnap.id), {
      adminReadAt: serverTimestamp(),
      adminUnread: false,
      updatedAt: serverTimestamp(),
    }, { merge: true });
  });
  await batch.commit();
}

async function markAllSupportConversationsRead() {
  const unreadConversations = supportConversations.filter((item) => item.unreadCount > 0);
  for (const convo of unreadConversations) {
    await markSupportConversationRead(convo.id);
  }
}

const mapState = {
  drivers: new Map(),
  clients: new Map(),
  restaurants: new Map(),
  restaurantAddresses: new Map(),
  orders: new Map()
};

const markerState = {
  drivers: new Map(),
  clients: new Map(),
  restaurants: new Map(),
  orders: new Map()
};

const markerLayerState = {
  drivers: null,
  clients: null,
  restaurants: null,
  orders: null,
};

const lineState = {
  orders: new Map()
};

const mapRouteCache = new Map();
const mapRoutePending = new Map();
const mapRouteFailures = new Set();

let leafletReadyPromise = null;
let leafletClusterReadyPromise = null;

const CLOUDINARY_CLOUD_NAME = 'dvnzloec6';
const CLOUDINARY_UPLOAD_PRESET = 'flutter_unsigned';

async function uploadImageToCloudinary(file) {
  if (!file) return null;
  try {
    const formData = new FormData();
    formData.append('upload_preset', CLOUDINARY_UPLOAD_PRESET);
    formData.append('file', file);

    const response = await fetch(`https://api.cloudinary.com/v1_1/${CLOUDINARY_CLOUD_NAME}/image/upload`, {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) return null;
    const payload = await response.json();
    return payload?.secure_url || null;
  } catch (_) {
    return null;
  }
}

function setQrPreview(img, src) {
  if (!img) return;
  const value = String(src || '').trim();
  if (!value) {
    img.hidden = true;
    img.removeAttribute('src');
    return;
  }
  img.src = value;
  img.hidden = false;
}

function bindQrFilePreview(fileInput, previewImg) {
  if (!fileInput || !previewImg || fileInput.dataset.previewBound === '1') {
    return;
  }

  fileInput.addEventListener('change', () => {
    const file = fileInput.files && fileInput.files.length ? fileInput.files[0] : null;
    if (!file) return;
    const objectUrl = URL.createObjectURL(file);
    setQrPreview(previewImg, objectUrl);
  });

  fileInput.dataset.previewBound = '1';
}

async function resolveUploadedQrUrl({ fileInput, currentUrl, label }) {
  const file = fileInput && fileInput.files && fileInput.files.length ? fileInput.files[0] : null;
  if (!file) {
    return String(currentUrl || '').trim();
  }

  const uploaded = await uploadImageToCloudinary(file);
  if (!uploaded) {
    throw new Error(`تعذر رفع صورة QR الخاصة بـ ${label}.`);
  }

  return uploaded;
}

function pickSingleImageFile() {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = () => {
      const file = input.files && input.files.length ? input.files[0] : null;
      resolve(file || null);
    };
    input.click();
  });
}

function loadExternalStyle(href) {
  return new Promise((resolve, reject) => {
    const existing = Array.from(document.querySelectorAll('link[rel="stylesheet"]')).find((l) => l.href.includes(href));
    if (existing) {
      resolve();
      return;
    }

    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = href;
    link.onload = () => resolve();
    link.onerror = () => reject(new Error(`failed style: ${href}`));
    document.head.appendChild(link);
  });
}

function loadExternalScript(src) {
  return new Promise((resolve, reject) => {
    const existing = Array.from(document.querySelectorAll('script')).find((s) => s.src && s.src.includes(src));
    if (existing) {
      if (window.L) {
        resolve();
      } else {
        let settled = false;
        const done = (ok, err) => {
          if (settled) return;
          settled = true;
          existing.removeEventListener('load', onLoad);
          existing.removeEventListener('error', onError);
          clearTimeout(timeoutId);
          if (ok) {
            resolve();
          } else {
            reject(err || new Error(`failed script: ${src}`));
          }
        };
        const onLoad = () => done(true);
        const onError = () => done(false, new Error(`failed script: ${src}`));
        const timeoutId = setTimeout(() => {
          if (window.L) {
            done(true);
          } else {
            done(false, new Error(`script load timeout: ${src}`));
          }
        }, 2500);

        existing.addEventListener('load', onLoad, { once: true });
        existing.addEventListener('error', onError, { once: true });
      }
      return;
    }

    const script = document.createElement('script');
    script.src = src;
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error(`failed script: ${src}`));
    document.body.appendChild(script);
  });
}

async function ensureLeaflet() {
  if (window.L) return;
  if (leafletReadyPromise) {
    await leafletReadyPromise;
    return;
  }

  leafletReadyPromise = (async () => {
    const styleCandidates = [
      'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
      'https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/leaflet.css',
      'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.css'
    ];
    const scriptCandidates = [
      'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
      'https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/leaflet.js',
      'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.js'
    ];

    let styleLoaded = Boolean(window.L);
    for (const href of styleCandidates) {
      if (styleLoaded) break;
      try {
        await loadExternalStyle(href);
        styleLoaded = true;
      } catch (_) {
      }
    }

    if (!styleLoaded) {
      throw new Error('تعذر تحميل ملف أنماط الخريطة.');
    }

    if (!window.L) {
      for (const src of scriptCandidates) {
        try {
          await loadExternalScript(src);
          if (window.L) break;
        } catch (_) {
        }
      }
    }

    if (!window.L) {
      throw new Error('تعذر تحميل مكتبة الخريطة.');
    }

    return;
  })();

  await leafletReadyPromise;
}

async function ensureLeafletMarkerCluster() {
  if (!window.L || window.L.markerClusterGroup) return;
  if (leafletClusterReadyPromise) {
    await leafletClusterReadyPromise;
    return;
  }

  leafletClusterReadyPromise = (async () => {
    const clusterStyleCandidates = [
      'https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css',
      'https://cdn.jsdelivr.net/npm/leaflet.markercluster@1.5.3/dist/MarkerCluster.css',
      'https://cdnjs.cloudflare.com/ajax/libs/leaflet.markercluster/1.5.3/MarkerCluster.css'
    ];
    const clusterDefaultStyleCandidates = [
      'https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css',
      'https://cdn.jsdelivr.net/npm/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css',
      'https://cdnjs.cloudflare.com/ajax/libs/leaflet.markercluster/1.5.3/MarkerCluster.Default.css'
    ];
    const clusterScriptCandidates = [
      'https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js',
      'https://cdn.jsdelivr.net/npm/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js',
      'https://cdnjs.cloudflare.com/ajax/libs/leaflet.markercluster/1.5.3/leaflet.markercluster.js'
    ];

    for (const href of clusterStyleCandidates) {
      try {
        await loadExternalStyle(href);
        break;
      } catch (_) {
      }
    }

    for (const href of clusterDefaultStyleCandidates) {
      try {
        await loadExternalStyle(href);
        break;
      } catch (_) {
      }
    }

    for (const clusterSrc of clusterScriptCandidates) {
      try {
        await loadExternalScript(clusterSrc);
        if (window.L?.markerClusterGroup) return;
      } catch (_) {
      }
    }
  })();

  await leafletClusterReadyPromise;
}

function createMapMarkerLayer(type) {
  if (!window.L) return null;
  if (window.L.markerClusterGroup) {
    return window.L.markerClusterGroup({
      showCoverageOnHover: false,
      spiderfyOnMaxZoom: true,
      removeOutsideVisibleBounds: true,
      chunkedLoading: true,
      maxClusterRadius: 48,
      iconCreateFunction(cluster) {
        return window.L.divIcon({
          html: `<div class="map-cluster map-cluster--${type}"><span>${cluster.getChildCount()}</span></div>`,
          className: 'map-cluster-shell',
          iconSize: [42, 42],
          iconAnchor: [21, 21],
        });
      },
    });
  }
  return window.L.layerGroup();
}

function ensureMarkerLayers() {
  if (!liveMap) return;
  ['drivers', 'clients', 'restaurants', 'orders'].forEach((type) => {
    if (markerLayerState[type]) return;
    markerLayerState[type] = createMapMarkerLayer(type);
    markerLayerState[type]?.addTo(liveMap);
  });
}

function rebuildMarkerLayers() {
  if (!liveMap) return;

  Object.keys(markerLayerState).forEach((type) => {
    const layer = markerLayerState[type];
    if (layer && liveMap.hasLayer(layer)) {
      liveMap.removeLayer(layer);
    }
    markerLayerState[type] = null;
  });

  Object.values(markerState).forEach((stateMap) => {
    stateMap.forEach((marker) => marker.remove());
    stateMap.clear();
  });

  ensureMarkerLayers();
}

function addMarkerToLayer(type, marker) {
  if (!liveMap || !marker) return;
  ensureMarkerLayers();
  const layer = markerLayerState[type];
  if (layer?.addLayer) {
    layer.addLayer(marker);
    return;
  }
  marker.addTo(liveMap);
}

function removeMarkerFromLayer(type, marker) {
  if (!marker) return;
  const layer = markerLayerState[type];
  if (layer?.removeLayer) {
    layer.removeLayer(marker);
    return;
  }
  marker.remove();
}

function buildRouteKey(points) {
  return points
    .map(([lat, lng]) => `${Number(lat).toFixed(5)},${Number(lng).toFixed(5)}`)
    .join('|');
}

async function fetchRouteGeometry(points) {
  const coords = points.map(([lat, lng]) => `${lng},${lat}`).join(';');
  const response = await fetch(`https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson`, {
    method: 'GET',
    headers: {
      Accept: 'application/json',
    },
  });
  if (!response.ok) {
    throw new Error(`route:${response.status}`);
  }
  const payload = await response.json();
  const route = payload?.routes?.[0]?.geometry?.coordinates;
  if (!Array.isArray(route) || !route.length) {
    throw new Error('route:empty');
  }
  return route.map(([lng, lat]) => [lat, lng]);
}

function resolveOrderRoutePoints(orderId, points, preferActualRoute) {
  const routeKey = buildRouteKey(points);
  if (!preferActualRoute) {
    mapRouteFailures.delete(routeKey);
    return { points, routeKey, mode: 'straight' };
  }

  if (mapRouteCache.has(routeKey)) {
    return { points: mapRouteCache.get(routeKey), routeKey, mode: 'actual' };
  }

  if (!mapRoutePending.has(routeKey) && !mapRouteFailures.has(routeKey)) {
    const promise = fetchRouteGeometry(points)
      .then((routedPoints) => {
        mapRouteCache.set(routeKey, routedPoints);
        mapRouteFailures.delete(routeKey);
      })
      .catch(() => {
        mapRouteFailures.add(routeKey);
      })
      .finally(() => {
        mapRoutePending.delete(routeKey);
        requestRefreshMapLayers();
      });
    mapRoutePending.set(routeKey, promise);
  }

  return {
    points,
    routeKey,
    mode: mapRouteFailures.has(routeKey) ? 'fallback' : 'loading',
  };
}

function withTimeout(promise, timeoutMs, message) {
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      setTimeout(() => reject(new Error(message || 'timeout')), timeoutMs);
    })
  ]);
}

function clearSubscriptions() {
  unsubscribers.forEach((fn) => fn());
  unsubscribers = [];
}

function setHtml(target, html) {
  target.innerHTML = html;
}

function addResponsiveCellLabels(rowMarkup, headers = []) {
  let cellIndex = 0;
  return String(rowMarkup || '').replace(/<td(\s[^>]*)?>/g, (match, attrs = '') => {
    const headerLabel = String(headers[cellIndex] || '')
      .replace(/<[^>]*>/g, '')
      .replace(/\s+/g, ' ')
      .trim();
    cellIndex += 1;
    return `<td${attrs || ''} data-label="${escapeHtml(headerLabel || 'القيمة')}">`;
  });
}

function table(headers, rows) {
  if (!rows.length) {
    return '<div class="table-empty-state muted">لا توجد بيانات متاحة في هذا القسم الآن.</div>';
  }

  const normalizedRows = rows.map((row) => addResponsiveCellLabels(row, headers));
  const headerCells = headers.map((h, i) => `<th data-col="${i}" class="sortable-th">${h} <span class="sort-icon"></span></th>`).join('');
  return `
    <div class="modern-table-shell">
      <div class="table-toolbar">
        <span class="table-count">${rows.length.toLocaleString('ar-EG')} نتيجة</span>
        <div class="table-toolbar-right">
          <button class="table-export-btn" title="تصدير CSV">⬇ تصدير CSV</button>
        </div>
      </div>
      <table class="modern-table">
        <thead><tr>${headerCells}</tr></thead>
        <tbody>${normalizedRows.join('')}</tbody>
      </table>
    </div>
  `;
}

function skeletonTable(headers, rowCount = 5) {
  const skeletonCells = headers.map(() => `<td><span class="skeleton" style="display:inline-block;width:${60 + Math.floor(Math.random() * 30)}%;height:12px;border-radius:4px;"></span></td>`).join('');
  const skeletonRows = Array.from({ length: rowCount }, () => `<tr>${skeletonCells}</tr>`).join('');
  return `
    <div class="modern-table-shell">
      <table class="modern-table">
        <thead><tr>${headers.map((h) => `<th>${h}</th>`).join('')}</tr></thead>
        <tbody>${skeletonRows}</tbody>
      </table>
    </div>
  `;
}

// ── Button loading helper ─────────────────────────────────────────────────────

function withBtnLoading(btn, asyncFn) {
  if (!btn) return asyncFn();
  const originalText = btn.innerHTML;
  btn.classList.add('btn-loading');
  btn.disabled = true;
  btn.innerHTML = '&nbsp;';
  return Promise.resolve(asyncFn()).finally(() => {
    btn.classList.remove('btn-loading');
    btn.disabled = false;
    btn.innerHTML = originalText;
  });
}

// ── Table sorting + CSV export via event delegation ──────────────────────────

function getTableCellText(td) {
  return (td?.textContent || '').replace(/\s+/g, ' ').trim();
}

document.addEventListener('click', (e) => {
  // Column sort
  const th = e.target.closest('th.sortable-th');
  if (th) {
    const table = th.closest('table');
    if (!table) return;
    const tbody = table.querySelector('tbody');
    if (!tbody) return;
    const colIndex = parseInt(th.dataset.col ?? '-1', 10);
    if (colIndex < 0) return;

    const wasAsc = th.classList.contains('sort-asc');
    table.querySelectorAll('th.sortable-th').forEach((t) => t.classList.remove('sort-asc', 'sort-desc'));
    th.classList.add(wasAsc ? 'sort-desc' : 'sort-asc');
    const dir = wasAsc ? -1 : 1;

    const rows = Array.from(tbody.querySelectorAll('tr'));
    rows.sort((a, b) => {
      const aText = getTableCellText(a.cells[colIndex]);
      const bText = getTableCellText(b.cells[colIndex]);
      const aNum = parseFloat(aText.replace(/[^\d.-]/g, ''));
      const bNum = parseFloat(bText.replace(/[^\d.-]/g, ''));
      if (!isNaN(aNum) && !isNaN(bNum)) return dir * (aNum - bNum);
      return dir * aText.localeCompare(bText, 'ar');
    });
    rows.forEach((r) => tbody.appendChild(r));
    return;
  }

  // CSV export
  const exportBtn = e.target.closest('.table-export-btn');
  if (exportBtn) {
    const shell = exportBtn.closest('.modern-table-shell');
    const tbl = shell?.querySelector('table.modern-table');
    if (!tbl) return;
    const headers = Array.from(tbl.querySelectorAll('thead th')).map((t) => getTableCellText(t));
    const dataRows = Array.from(tbl.querySelectorAll('tbody tr')).map((tr) =>
      Array.from(tr.cells).map((td) => {
        const text = getTableCellText(td);
        return `"${text.replace(/"/g, '""')}"`;
      }).join(',')
    );
    const csv = [headers.map((h) => `"${h}"`).join(','), ...dataRows].join('\n');
    const bom = '\uFEFF';
    const blob = new Blob([bom + csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `speedstar_export_${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }
});

// ── Keyboard shortcuts ────────────────────────────────────────────────────────

document.addEventListener('keydown', (e) => {
  // Ignore when typing in inputs
  const tag = document.activeElement?.tagName?.toLowerCase();
  if (tag === 'input' || tag === 'textarea' || tag === 'select') return;
  if (document.activeElement?.isContentEditable) return;

  // Escape → close confirmation overlays / mobile sidebar
  if (e.key === 'Escape') {
    document.querySelectorAll('.confirm-overlay').forEach((el) => el.remove());
    document.getElementById('appSidebar')?.classList.remove('open');
    return;
  }

  // Alt + 1-9 → switch tabs
  if (e.altKey && e.key >= '1' && e.key <= '9') {
    e.preventDefault();
    const index = parseInt(e.key, 10) - 1;
    const tabList = Array.from(document.querySelectorAll('.tab[data-tab]'));
    const target = tabList[index];
    if (target?.dataset?.tab) activateTab(target.dataset.tab);
  }
});

function openOrdersWorkspace(orderId = '') {
  activateTab('orders');
  if (orderId) {
    renderOperationsOrderDetails(orderId);
  }
}

function getOperationsOrderBucket(data = {}) {
  const lifecycleStatus = String(getOrderLifecycleStatus(data) || '').trim().toLowerCase();
  const paymentStatus = String(data.paymentStatus || '').trim().toLowerCase();
  const reviewDecision = String(data.paymentReviewDecision || '').trim().toLowerCase();

  if (paymentStatus === 'قيد المراجعة' || reviewDecision === 'pending' || lifecycleStatus.includes('review')) {
    return 'review';
  }

  if (
    lifecycleStatus.includes('cancel')
    || lifecycleStatus.includes('ملغي')
    || lifecycleStatus.includes('rejected')
    || lifecycleStatus.includes('رفض')
  ) {
    return 'cancelled';
  }

  if (isActiveOrderStatus(lifecycleStatus)) {
    return 'active';
  }

  return 'other';
}

function getOrderTimelineEntries(data = {}) {
  const timelineDefs = [
    ['createdAt', 'إنشاء الطلب'],
    ['acceptedAt', 'قبول الطلب'],
    ['assignedAt', 'إسناد المندوب'],
    ['pickedUpAt', 'استلام الطلب من المتجر'],
    ['deliveredAt', 'تسليم الطلب'],
    ['paidAt', 'تسجيل الدفع'],
    ['paymentReviewAutoFlaggedAt', 'إحالة الإيصال للمراجعة'],
    ['cancelledAt', 'إلغاء الطلب'],
    ['updatedAt', 'آخر تحديث'],
  ];

  const seen = new Set();
  return timelineDefs
    .map(([field, label]) => {
      const millis = getTimestampMillis(data[field]);
      if (!millis || seen.has(millis)) return null;
      seen.add(millis);
      return { field, label, millis };
    })
    .filter(Boolean)
    .sort((a, b) => a.millis - b.millis);
}

function renderOrderItemsRows(items = []) {
  if (!Array.isArray(items) || !items.length) {
    return '<div class="muted">لا توجد عناصر مفصلة داخل الطلب.</div>';
  }

  const rows = items.map((item) => `
    <tr>
      <td>${escapeHtml(String(item?.name || item?.title || 'عنصر'))}</td>
      <td>${escapeHtml(String(item?.quantity ?? 1))}</td>
      <td>${escapeHtml(String(item?.notes || item?.specialInstructions || '-'))}</td>
      <td>${escapeHtml(String(item?.price ?? '-'))}</td>
    </tr>
  `);

  return `<div class="order-items-table">${table(['الصنف', 'الكمية', 'ملاحظات', 'السعر'], rows)}</div>`;
}

async function refreshActivePortal(tabId) {
  const activeId = tabId || document.querySelector('.tab-panel.active')?.id || 'dashboard';
  const refreshButton = document.querySelector(`[data-portal-refresh="${activeId}"]`);
  const statusNode = document.querySelector(`[data-portal-refresh-status="${activeId}"]`);

  if (refreshButton) refreshButton.disabled = true;
  if (statusNode) statusNode.textContent = 'جارٍ المزامنة...';

  try {
    if (typeof mountAll === 'function') {
      clearSubscriptions();
      await mountAll();
    } else {
      applyAdminGlobalFilter();
      if (activeId === 'orders') renderOperationsOrders();
      if (activeId === 'management') renderCourierActivityReport();
    }

    activateTab(activeId);
    if (statusNode) statusNode.textContent = `آخر مزامنة: ${formatDateTimeLabel(Date.now())}`;
  } catch (err) {
    console.error('portal refresh failed', err);
    if (statusNode) statusNode.textContent = 'تعذر تحديث هذه البوابة الآن.';
  } finally {
    if (refreshButton) refreshButton.disabled = false;
  }
}

function injectPortalRefreshControls() {
  document.querySelectorAll('.portal-panel').forEach((panel) => {
    const panelId = String(panel.id || '').trim();
    if (!panelId) return;
    const header = panel.querySelector('.portal-header');
    if (!header || header.querySelector('[data-portal-refresh]')) return;

    const actions = document.createElement('div');
    actions.className = 'portal-header-actions';
    actions.innerHTML = `
      <button class="btn ghost" type="button" data-portal-refresh="${escapeHtml(panelId)}">تحديث هذه البوابة</button>
      <span class="portal-refresh-status" data-portal-refresh-status="${escapeHtml(panelId)}">مزامنة مباشرة</span>
    `;
    header.appendChild(actions);

    actions.querySelector('[data-portal-refresh]')?.addEventListener('click', async () => {
      await refreshActivePortal(panelId);
    });
  });
}

function normalizeAdminPermissions(rawPermissions, { fallbackToAll = true } = {}) {
  const items = Array.isArray(rawPermissions) ? rawPermissions : [];
  const normalized = items
    .map((item) => String(item || '').trim().toLowerCase())
    .filter((item) => ALL_ADMIN_PERMISSIONS.includes(item));

  if (normalized.length) {
    return Array.from(new Set(normalized));
  }

  return fallbackToAll ? [...ALL_ADMIN_PERMISSIONS] : [];
}

function hasAdminPermission(permission) {
  return currentAdminPermissions.has(permission);
}

function canAccessPortal(tabId) {
  const required = TAB_PERMISSION_REQUIREMENTS[tabId] || [];
  if (!required.length) return true;
  return required.some((permission) => hasAdminPermission(permission));
}

function canAccessSubpanel(subpanelId) {
  const required = SUBPANEL_PERMISSION_REQUIREMENTS[subpanelId] || [];
  if (!required.length) return true;
  return required.some((permission) => hasAdminPermission(permission));
}

function getFirstAccessibleTabId() {
  const firstVisibleTab = tabs.find((tab) => canAccessPortal(String(tab.dataset.tab || '')));
  return firstVisibleTab?.dataset.tab || 'dashboard';
}

function applyAdminAccessControl() {
  tabs.forEach((tab) => {
    const tabId = String(tab.dataset.tab || '');
    tab.hidden = !canAccessPortal(tabId);
  });

  tabPanels.forEach((panel) => {
    const panelId = String(panel.id || '');
    panel.hidden = !canAccessPortal(panelId);
  });

  portalSubtabs.forEach((button) => {
    const subpanelId = String(button.dataset.subtab || '');
    button.hidden = !canAccessSubpanel(subpanelId);
  });

  portalSubpanels.forEach((panel) => {
    const subpanelId = String(panel.dataset.subpanel || '');
    panel.hidden = !canAccessSubpanel(subpanelId);
  });

  dashboardQuickActions?.querySelectorAll('[data-quick-tab]').forEach((btn) => {
    const tabId = String(btn.getAttribute('data-quick-tab') || '');
    btn.hidden = !canAccessPortal(tabId);
  });
}

function formatAdminPermissionsSummary(rawPermissions) {
  const permissions = normalizeAdminPermissions(rawPermissions, { fallbackToAll: true });
  return permissions.map((permission) => ADMIN_PERMISSION_DEFS[permission] || permission).join('، ');
}

async function loadAdminAccessProfile(user) {
  if (!user) {
    return { allowed: false, permissions: [], isStaticAdmin: false };
  }

  const normalizedEmail = String(user.email || '').toLowerCase();
  if (guaranteedAdminEmails.has(normalizedEmail)) {
    return {
      allowed: true,
      permissions: [...ALL_ADMIN_PERMISSIONS],
      isStaticAdmin: true,
      data: {
        uid: user.uid,
        email: normalizedEmail,
        role: 'admin',
        active: true,
        permissions: [...ALL_ADMIN_PERMISSIONS],
      },
    };
  }

  const adminDoc = await getDoc(doc(db, 'admins', user.uid));
  if (!adminDoc.exists()) {
    return { allowed: false, permissions: [], isStaticAdmin: false };
  }

  const data = adminDoc.data() || {};
  const allowed = data.role === 'admin' || data.active === true;
  return {
    allowed,
    permissions: normalizeAdminPermissions(data.permissions, { fallbackToAll: true }),
    isStaticAdmin: false,
    data,
  };
}

async function isAdmin(user) {
  if (!user) return false;
  if (guaranteedAdminEmails.has((user.email || '').toLowerCase())) return true;
  try {
    const adminDoc = await getDoc(doc(db, 'admins', user.uid));
    return adminDoc.exists() && (adminDoc.data().role === 'admin' || adminDoc.data().active === true);
  } catch (err) {
    const code = String(err?.code || '').toLowerCase();
    if (code.includes('permission-denied')) {
      return false;
    }
    throw err;
  }
}

function activateTab(id) {
  if (!canAccessPortal(id)) {
    const fallbackId = getFirstAccessibleTabId();
    if (fallbackId && fallbackId !== id) {
      activateTab(fallbackId);
    }
    return;
  }

  tabs.forEach((t) => t.classList.toggle('active', t.dataset.tab === id));
  tabPanels.forEach((p) => p.classList.toggle('active', p.id === id));
  syncPortalPresentation(id);
  ensurePortalSubpanel(id);
  applyAdminGlobalFilter();

  // Update URL hash silently
  try { history.replaceState(null, '', `#${id}`); } catch (_) {}

  // Update topbar breadcrumb
  const portalNames = {
    dashboard: 'اللوحة', map: 'الخريطة', orders: 'الطلبات',
    finance: 'المالية', management: 'الكيانات', pending: 'الاعتمادات',
    support: 'الدعم', notifications: 'الإشعارات', admins: 'التحكم',
  };
  const portalNameEl = document.getElementById('topbarPortalName');
  if (portalNameEl) {
    portalNameEl.textContent = portalNames[id] || id;
    portalNameEl.hidden = false;
  }

  if (id === 'map') {
    // Re-enable auto-fit whenever map tab is reopened, unless user moves map again.
    mapAutoFitted = false;
    mountMap().finally(() => {
      renderMapSearchResults();
      if (liveMap) {
        setTimeout(() => {
          liveMap.invalidateSize();
        }, 120);
      }
    });
  }
  if (id === 'pending') {
    mountPending().catch((err) => {
      console.error('pending refresh failed', err);
    });
  }
}

// Expose activateTab for hash navigation from inline script
window.__adminActivateTab = activateTab;

tabs.forEach((tab) => tab.addEventListener('click', () => {
  if (!tab.dataset.tab) return;
  activateTab(tab.dataset.tab);
  // Close mobile sidebar on nav
  const sidebar = document.getElementById('appSidebar');
  if (sidebar) sidebar.classList.remove('open');
}));
portalSubtabs.forEach((button) => {
  button.addEventListener('click', () => {
    const subpanelId = button.dataset.subtab;
    if (!subpanelId) return;
    const [portalId] = subpanelId.split('-');
    if (!portalId) return;
    activateSubpanel(portalId, subpanelId);
    applyAdminGlobalFilter();
  });
});

function applyAdminGlobalFilter() {
  const query = String(adminGlobalSearch?.value || '').trim().toLowerCase();
  const activePanel = document.querySelector('.tab-panel.active');
  if (!activePanel) return;

  const rows = activePanel.querySelectorAll('table tbody tr');
  let visibleRows = 0;
  rows.forEach((row) => {
    const text = String(row.textContent || '').toLowerCase();
    const visible = !query || text.includes(query);
    row.style.display = visible ? '' : 'none';
    if (visible) visibleRows += 1;
  });

  const supportItems = activePanel.querySelectorAll('.support-item');
  supportItems.forEach((item) => {
    const text = String(item.textContent || '').toLowerCase();
    const visible = !query || text.includes(query);
    item.style.display = visible ? '' : 'none';
  });

  renderAdminSearchResults({ visibleRows, totalRows: rows.length });
}

if (adminGlobalSearch) {
  adminGlobalSearch.addEventListener('input', () => {
    applyAdminGlobalFilter();
  });
}

if (mapResetViewBtn) {
  mapResetViewBtn.addEventListener('click', () => {
    clearSelectedOrderOnMap();
    mapAutoFitted = false;
    refreshMapLayers();
    if (liveMap) {
      liveMap.invalidateSize();
    }
  });
}

if (mapSearchInput) {
  mapSearchInput.addEventListener('input', () => {
    renderMapSearchResults();
  });
}

mapFocusButtons.forEach((button) => {
  button.addEventListener('click', () => {
    const scope = String(button.getAttribute('data-map-focus') || 'all');
    fitMapByScope(scope);
  });
});

if (dashboardQuickActions) {
  dashboardQuickActions.querySelectorAll('[data-quick-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const tabId = String(btn.getAttribute('data-quick-tab') || 'dashboard');
      if (tabId === 'management') {
        openOrdersWorkspace();
        return;
      }
      activateTab(tabId);
    });
  });
}

ordersSegmentButtons.forEach((button) => {
  button.addEventListener('click', () => {
    const nextFilter = String(button.getAttribute('data-orders-segment') || 'active').trim().toLowerCase();
    if (orderStatusFilter) {
      orderStatusFilter.value = nextFilter;
    }
    renderOperationsOrders();
  });
});

injectPortalRefreshControls();

function setLoginStatus(message = '', tone = 'muted') {
  if (!loginStatus) return;
  const safeTone = tone === 'error' || tone === 'success' ? tone : 'muted';
  loginStatus.className = `login-status ${safeTone}`;
  loginStatus.textContent = message;
}

function showSignedOutUi() {
  authState.textContent = 'غير مسجل';
  loginCard.hidden = false;
  appPanel.hidden = true;
  logoutBtn.hidden = true;
  clearSubscriptions();
  pendingRealtimeBound = false;
  resetOpsCenterAttentionState();
}

function mapAuthErrorMessage(err) {
  const code = String(err?.code || '').toLowerCase();
  if (code.includes('invalid-credential') || code.includes('wrong-password') || code.includes('user-not-found')) {
    return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
  }
  if (code.includes('permission-denied')) {
    return 'الحساب لا يملك صلاحية الدخول كمسؤول في هذه البيئة.';
  }
  if (code.includes('too-many-requests')) {
    return 'تم حظر المحاولة مؤقتًا بسبب تكرار المحاولات. حاول بعد قليل.';
  }
  if (code.includes('network-request-failed')) {
    return 'تعذر الاتصال بالشبكة. تحقق من الإنترنت ثم حاول مجددًا.';
  }
  if (code.includes('operation-not-allowed')) {
    return 'تسجيل الدخول بالبريد وكلمة المرور غير مفعل في Firebase Auth. فعّل Email/Password من إعدادات Authentication.';
  }
  return err?.message || 'حدث خطأ غير متوقع أثناء تسجيل الدخول.';
}

async function handlePasswordReset() {
  const email = document.getElementById('emailInput').value.trim();
  if (!email) {
    setLoginStatus('أدخل البريد الإلكتروني أولًا لإرسال رابط إعادة التعيين.', 'error');
    return;
  }

  if (resetPasswordBtn) resetPasswordBtn.disabled = true;
  setLoginStatus('جاري إرسال رابط إعادة التعيين...', 'muted');
  try {
    await sendPasswordResetEmail(auth, email);
    setLoginStatus('تم إرسال رابط إعادة تعيين كلمة المرور إلى البريد الإلكتروني.', 'success');
  } catch (err) {
    setLoginStatus(`تعذر إرسال رابط إعادة التعيين: ${mapAuthErrorMessage(err)}`, 'error');
  } finally {
    if (resetPasswordBtn) resetPasswordBtn.disabled = false;
  }
}

window.__adminResetPassword = () => {
  void handlePasswordReset();
};

async function handleAuthenticatedUser(user) {
  if (!user) return;
  if (authTransitionInProgress) return;
  authTransitionInProgress = true;

  try {
    const profile = await Promise.race([
      loadAdminAccessProfile(user),
      new Promise((_, reject) => {
        setTimeout(() => reject(new Error('admin-check-timeout')), 9000);
      })
    ]);
    const allowed = profile?.allowed === true;

    if (!allowed) {
      preservedLoginStatus = {
        message: 'هذا الحساب ليس لديه صلاحيات Admin.',
        tone: 'error'
      };
      setLoginStatus(preservedLoginStatus.message, preservedLoginStatus.tone);
      await signOut(auth);
      return;
    }

    currentAdminProfile = profile?.data || null;
    currentAdminPermissions = new Set(profile?.permissions || []);
    applyAdminAccessControl();

    if (!currentAdminPermissions.size) {
      preservedLoginStatus = {
        message: 'هذا الحساب لا يملك أي صلاحية تشغيلية مفعلة.',
        tone: 'error'
      };
      setLoginStatus(preservedLoginStatus.message, preservedLoginStatus.tone);
      await signOut(auth);
      return;
    }

    authState.textContent = user.email || user.uid;
    loginCard.hidden = true;
    appPanel.hidden = false;
    logoutBtn.hidden = false;
    activateTab(getFirstAccessibleTabId());
    // Navigate to hash tab if present (e.g. link directly to #finance)
    const hashTab = (location.hash || '').replace('#', '').trim();
    if (hashTab && canAccessPortal(hashTab)) activateTab(hashTab);
    primeBrowserNotificationsPermission();
    setLoginStatus('تم تسجيل الدخول بنجاح.', 'success');

    mountAll()
      .then(() => {
        preservedLoginStatus = null;
        setLoginStatus('');
      })
      .catch((err) => {
        console.error('mountAll failed after login', err);
        setLoginStatus('تم الدخول، لكن تعذر تحميل بعض البيانات. أعد التحديث أو جرّب لاحقًا.', 'error');
      });
  } catch (err) {
    console.error('handleAuthenticatedUser failed', err);
    preservedLoginStatus = {
      message: `تعذر إكمال تسجيل الدخول: ${mapAuthErrorMessage(err)}`,
      tone: 'error'
    };
    setLoginStatus(preservedLoginStatus.message, preservedLoginStatus.tone);
    authState.textContent = 'غير مسجل';
    loginCard.hidden = false;
    appPanel.hidden = true;
    logoutBtn.hidden = true;
    try {
      await signOut(auth);
    } catch (_) {
    }
  } finally {
    authTransitionInProgress = false;
  }
}

loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  preservedLoginStatus = null;
  const email = document.getElementById('emailInput').value.trim();
  const password = document.getElementById('passwordInput').value;
  const submitBtn = loginForm.querySelector('button[type="submit"]');

  if (!email || !password) {
    setLoginStatus('الرجاء إدخال البريد الإلكتروني وكلمة المرور.', 'error');
    return;
  }

  setLoginStatus('جاري تسجيل الدخول...', 'muted');
  if (submitBtn) submitBtn.disabled = true;
  try {
    await signInWithEmailAndPassword(auth, email, password);
    setLoginStatus('تم تسجيل الدخول، جاري التحقق من الصلاحيات...', 'muted');
  } catch (err) {
    console.error('signIn failed', err);
    setLoginStatus(`فشل تسجيل الدخول: ${mapAuthErrorMessage(err)}`, 'error');
  } finally {
    if (submitBtn) submitBtn.disabled = false;
  }
});

resetPasswordBtn?.addEventListener('click', async () => {
  await handlePasswordReset();
});

logoutBtn.addEventListener('click', async () => {
  preservedLoginStatus = null;
  currentAdminProfile = null;
  currentAdminPermissions = new Set();
  await signOut(auth);
});

onAuthStateChanged(auth, (user) => {
  if (user) {
    void handleAuthenticatedUser(user);
    return;
  }

  authTransitionInProgress = false;
  currentAdminProfile = null;
  currentAdminPermissions = new Set();
  showSignedOutUi();
  if (preservedLoginStatus) {
    setLoginStatus(preservedLoginStatus.message, preservedLoginStatus.tone);
  } else {
    setLoginStatus('');
  }
});

function mountDashboard() {
  renderOpsPriorityCards();
  renderOpsAlertFeed();

  // Show skeletons while waiting for first snapshot
  const orderHeaders = ['رقم الطلب', 'العميل', 'المطعم', 'المندوب', 'الحالة', 'الإجمالي', 'إجراء'];
  if (activeOrdersTable) setHtml(activeOrdersTable, skeletonTable(orderHeaders));
  if (deliveredOrdersTable) setHtml(deliveredOrdersTable, skeletonTable(orderHeaders));

  const toMoney = (value) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  };

  const computeFinancial = (orderData) => {
    const subtotal = toMoney(orderData.total ?? orderData.subtotal);
    const deliveryFee = toMoney(orderData.deliveryFee);
    const largeOrderFee = toMoney(orderData.largeOrderFee);
    const discountAmount = toMoney(orderData.discountAmount);
    const fallbackTotal = Math.max(0, subtotal + deliveryFee + largeOrderFee - discountAmount);
    const totalWithDelivery = toMoney(orderData.totalWithDelivery || fallbackTotal);

    let restaurantShare = toMoney(orderData.restaurantShare ?? orderData.storeShare ?? subtotal);
  let driverShare = toMoney(orderData.driverShare ?? orderData.deliveryFeeForDriver ?? orderData.deliveryFee ?? 0);
    let platformShare = toMoney(orderData.platformShare);

    if (!Number.isFinite(platformShare) || platformShare <= 0) {
      platformShare = totalWithDelivery - restaurantShare - driverShare;
    }

    if (platformShare < 0) {
      platformShare = 0;
      const maxRestaurantShare = Math.max(0, totalWithDelivery - driverShare);
      if (restaurantShare > maxRestaurantShare) {
        restaurantShare = maxRestaurantShare;
      }
    }

    return {
      subtotal,
      deliveryFee,
      largeOrderFee,
      discountAmount,
      totalWithDelivery,
      restaurantShare,
      driverShare,
      platformShare,
    };
  };

  const formatMoney = (value) => `${Math.round(toMoney(value)).toLocaleString('ar-EG')} ج.س`;

  const renderDashboardOrderDetailsPanel = (orderId, data) => {
    if (!dashboardOrderDetails) return;
    const lifecycleStatus = getOrderLifecycleStatus(data);
    const canOpenMap = isActiveOrderStatus(lifecycleStatus);
    const financial = computeFinancial(data);
    const items = Array.isArray(data.items)
      ? data.items.map((item) => `
          <tr>
            <td>${escapeHtml(String(item?.name || item?.title || 'عنصر'))}</td>
            <td>${escapeHtml(String(item?.quantity ?? 1))}</td>
            <td>${formatMoney(item?.price || 0)}</td>
          </tr>
        `).join('')
      : '';

    dashboardOrderDetails.innerHTML = `
      <h4 style="margin:0 0 8px">تفاصيل الطلب ${escapeHtml(formatUnifiedOrderCode(data.orderNumber, data.orderId, orderId))}</h4>
      <div><span class="kv"><b>الحالة:</b> ${escapeHtml(formatOrderStatusLabel(data.orderStatus || data.status || '-'))}</span><span class="kv"><b>الدفع:</b> ${escapeHtml(data.paymentStatus || '-')}</span></div>
      <div><span class="kv"><b>العميل:</b> ${resolveClientDisplay(data.clientId, data.clientName)}</span><span class="kv"><b>المطعم:</b> ${resolveRestaurantDisplay(data.restaurantId, data.restaurantName)}</span></div>
      <div><span class="kv"><b>المندوب:</b> ${resolveDriverDisplay(data.assignedDriverId || data.offeredDriverId, data.assignedDriverName || '')}</span><span class="kv"><b>الهاتف:</b> ${escapeHtml(data.clientPhone || '-')}</span></div>
      <div><span class="kv"><b>الإجمالي:</b> ${formatMoney(financial.totalWithDelivery)}</span><span class="kv"><b>حصة المطعم:</b> ${formatMoney(financial.restaurantShare)}</span><span class="kv"><b>حصة المندوب:</b> ${formatMoney(financial.driverShare)}</span><span class="kv"><b>حصة المنصة:</b> ${formatMoney(financial.platformShare)}</span></div>
      ${items ? `
        <div style="margin-top:8px;"><b>العناصر:</b></div>
        <div style="overflow:auto; border:1px solid #eef2f7; border-radius:10px; margin-top:6px;">
          <table>
            <thead><tr><th>الصنف</th><th>الكمية</th><th>السعر</th></tr></thead>
            <tbody>${items}</tbody>
          </table>
        </div>
      ` : '<div style="margin-top:8px;" class="muted">لا توجد عناصر مفصلة.</div>'}
      <div style="margin-top:10px; display:flex; gap:8px; flex-wrap:wrap;">
        ${canOpenMap ? `<button class="btn primary" data-open-order-map-panel="${escapeHtml(orderId)}">فتح وتتبع الطلب على الخريطة</button>` : ''}
        <button class="btn ghost" data-open-order-management="${escapeHtml(orderId)}">فتح من الإدارة</button>
      </div>
    `;

    dashboardOrderDetails.querySelector('[data-open-order-map-panel]')?.addEventListener('click', () => {
      openOrderOnMap(orderId);
    });

    dashboardOrderDetails.querySelector('[data-open-order-management]')?.addEventListener('click', () => {
      openOrdersWorkspace(orderId);
    });
  };

  const cols = [
    ['إجمالي الطلبات', 'orders'],
    ['المتاجر', 'restaurants'],
    ['المندوبين', 'drivers'],
    ['العملاء', 'clients']
  ];

  cols.forEach(([label, col]) => {
    const cardId = `stat-${col}`;
    statsGrid.insertAdjacentHTML(
      'beforeend',
      `<div class="stat"><h4>${label}</h4><b id="${cardId}">...</b></div>`
    );
    const source = col === 'restaurants'
      ? query(collection(db, 'restaurants'), where('approvalStatus', '==', 'approved'))
      : collection(db, col);
    const unsub = onSnapshot(source, (snap) => {
      document.getElementById(cardId).textContent = snap.size;
    });
    unsubscribers.push(unsub);
  });

  // ── Today vs Yesterday KPIs ───────────────────────────────────────────────
  const todayKpiGrid = document.getElementById('todayKpiGrid');
  if (todayKpiGrid) {
    const todayStart = new Date(); todayStart.setHours(0,0,0,0);
    const yesterdayStart = new Date(todayStart); yesterdayStart.setDate(yesterdayStart.getDate() - 1);

    const renderKpi = (id, label, value, prev) => {
      const diff = prev > 0 ? ((value - prev) / prev * 100) : (value > 0 ? 100 : 0);
      const trendClass = diff > 0 ? 'up' : diff < 0 ? 'down' : 'flat';
      const trendIcon  = diff > 0 ? '↑' : diff < 0 ? '↓' : '→';
      const trendLabel = diff !== 0 ? `${trendIcon} ${Math.abs(diff).toFixed(0)}% عن الأمس` : 'لا تغيير';
      const existing = document.getElementById(id);
      const html = `<div class="kpi-label">${label}</div>
        <div class="kpi-value">${typeof value === 'number' && value > 999 ? value.toLocaleString('ar-EG') : value}</div>
        <div class="kpi-trend ${trendClass}">${trendLabel}</div>`;
      if (existing) { existing.innerHTML = html; return; }
      todayKpiGrid.insertAdjacentHTML('beforeend', `<div class="kpi-card" id="${id}">${html}</div>`);
    };

    const todayOrdersQ  = query(collection(db, 'orders'), where('createdAt', '>=', todayStart));
    const yesterdayOrdersQ = query(collection(db, 'orders'), where('createdAt', '>=', yesterdayStart), where('createdAt', '<', todayStart));

    // Seed placeholders
    ['kpi-today-orders','kpi-today-revenue','kpi-today-delivered','kpi-today-active'].forEach((id, i) => {
      const labels = ['طلبات اليوم','إيرادات اليوم (ج.س)','تسليم اليوم','نشطة الآن'];
      todayKpiGrid.insertAdjacentHTML('beforeend',`<div class="kpi-card" id="${id}"><div class="kpi-label">${labels[i]}</div><div class="kpi-value skeleton" style="width:60%;height:24px;border-radius:6px;"></div></div>`);
    });

    let yesterdayOrdersCount = 0;
    let yesterdayRevenue = 0;
    getDocs(yesterdayOrdersQ).then((snap) => {
      yesterdayOrdersCount = snap.size;
      snap.docs.forEach((d) => {
        const data = d.data() || {};
        yesterdayRevenue += Math.round(Number(data.totalWithDelivery || data.total || 0));
      });
    }).catch(() => {});

    unsubscribers.push(
      onSnapshot(todayOrdersQ, (snap) => {
        let todayRev = 0;
        let todayDelivered = 0;
        let todayActive = 0;
        snap.docs.forEach((d) => {
          const data = d.data() || {};
          const lc = getOrderLifecycleStatus(data);
          todayRev += Math.round(Number(data.totalWithDelivery || data.total || 0));
          if (isDeliveredOrderStatus(lc)) todayDelivered += 1;
          if (isActiveOrderStatus(lc)) todayActive += 1;
        });
        renderKpi('kpi-today-orders',    'طلبات اليوم',       snap.size,      yesterdayOrdersCount);
        renderKpi('kpi-today-revenue',   'إيرادات اليوم (ج.س)', todayRev,    yesterdayRevenue);
        renderKpi('kpi-today-delivered', 'تسليم اليوم',        todayDelivered, 0);
        renderKpi('kpi-today-active',    'نشطة الآن',          todayActive,    0);
      })
    );
  }

  const latestOrdersQ = query(collection(db, 'orders'), orderBy('createdAt', 'desc'), limit(60));
  unsubscribers.push(
    onSnapshot(latestOrdersQ, (snap) => {
      const activeDocs = snap.docs.filter((docSnap) => isActiveOrderStatus(getOrderLifecycleStatus(docSnap.data() || {})));
      const deliveredDocs = snap.docs.filter((docSnap) => isDeliveredOrderStatus(getOrderLifecycleStatus(docSnap.data() || {})));

      opsCenterState.activeOrders = activeDocs.length;
      renderOpsPriorityCards();

      const buildRows = (docs, { allowMap = true } = {}) => docs.map((d) => {
        const data = d.data();
        const financial = computeFinancial(data);
        return `<tr>
          <td>${formatUnifiedOrderCode(data.orderNumber, data.orderId, d.id)}</td>
          <td>${data.clientName || '-'}</td>
          <td>${resolveRestaurantDisplay(data.restaurantId, data.restaurantName)}</td>
          <td>${resolveDriverDisplay(data.assignedDriverId || data.offeredDriverId, data.assignedDriverName || '')}</td>
          <td>${formatOrderStatusLabel(data.status || data.orderStatus || '-')}</td>
          <td>${formatMoney(financial.totalWithDelivery)}</td>
          <td>
            <button class="btn ghost" data-order-details="${escapeHtml(d.id)}">تفاصيل</button>
            ${allowMap ? `<button class="btn primary" data-order-map="${escapeHtml(d.id)}">الخريطة</button>` : ''}
          </td>
        </tr>`;
      });

      if (activeOrdersTable) {
        setHtml(activeOrdersTable, table(['رقم الطلب', 'العميل', 'المطعم', 'المندوب', 'الحالة', 'الإجمالي', 'إجراء'], buildRows(activeDocs, { allowMap: true })));
      }
      if (deliveredOrdersTable) {
        setHtml(deliveredOrdersTable, table(['رقم الطلب', 'العميل', 'المطعم', 'المندوب', 'الحالة', 'الإجمالي', 'إجراء'], buildRows(deliveredDocs, { allowMap: false })));
      }

      [activeOrdersTable, deliveredOrdersTable].filter(Boolean).forEach((tableRoot) => tableRoot.querySelectorAll('[data-order-details]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.getAttribute('data-order-details');
          const doc = snap.docs.find((item) => item.id === id);
          if (!id || !doc) return;
          renderDashboardOrderDetailsPanel(id, doc.data() || {});
        });
      }));

      activeOrdersTable?.querySelectorAll('[data-order-map]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.getAttribute('data-order-map');
          if (!id) return;
          openOrderOnMap(id);
        });
      });

      if ((activeDocs.length || deliveredDocs.length) && dashboardOrderDetails && dashboardOrderDetails.classList.contains('muted')) {
        dashboardOrderDetails.classList.remove('muted');
        const first = activeDocs[0] || deliveredDocs[0];
        renderDashboardOrderDetailsPanel(first.id, first.data() || {});
      }
    })
  );
}

function mountFinance() {
  mountDiscountCodes();
  mountStoreOffersReview();
  bindQrFilePreview(bankkQrFileInput, bankkQrPreview);
  bindQrFilePreview(ocashQrFileInput, ocashQrPreview);
  bindQrFilePreview(fawryQrFileInput, fawryQrPreview);

  // Skeletons while waiting for snapshots
  if (financeOrdersTable) setHtml(financeOrdersTable, skeletonTable(['رقم الطلب', 'الدفع', 'إجمالي الطلب', 'حصة المطعم', 'حصة المندوب', 'حصة المنصة', 'الخصم', 'تتبع']));
  if (financePaymentReviewTable) setHtml(financePaymentReviewTable, skeletonTable(['رقم الطلب', 'العميل', 'المتجر', 'الطريقة', 'المبلغ', 'رقم العملية', 'الإيصال', 'آخر تحديث', 'إجراء']));
  if (financeWalletRechargeTable) setHtml(financeWalletRechargeTable, skeletonTable(['العميل', 'المبلغ', 'الطريقة', 'الحالة', 'إجراء']));
  if (financeWalletWithdrawalTable) setHtml(financeWalletWithdrawalTable, skeletonTable(['العميل', 'المبلغ', 'طريقة الاستلام', 'رقم الحساب', 'إجراء']));

  financeGrid.innerHTML = `
    <div class="stat"><h4>طلبات مدفوعة</h4><b id="paidOrders">...</b></div>
    <div class="stat"><h4>طلبات بانتظار السداد</h4><b id="pendingPay">...</b></div>
    <div class="stat"><h4>طلبات تحويل مكتمل</h4><b id="payoutDone">...</b></div>
    <div class="stat"><h4>إجمالي دخل المنصة</h4><b id="platformTotal">...</b></div>
  `;

  const toMoney = (value) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  };

  const computeFinancial = (orderData) => {
    const subtotal = toMoney(orderData.total ?? orderData.subtotal);
    const deliveryFee = toMoney(orderData.deliveryFee);
    const largeOrderFee = toMoney(orderData.largeOrderFee);
    const discountAmount = toMoney(orderData.discountAmount);
    const fallbackTotal = Math.max(0, subtotal + deliveryFee + largeOrderFee - discountAmount);
    const totalWithDelivery = toMoney(orderData.totalWithDelivery || fallbackTotal);

    let restaurantShare = toMoney(orderData.restaurantShare ?? orderData.storeShare ?? subtotal);
  let driverShare = toMoney(orderData.driverShare ?? orderData.deliveryFeeForDriver ?? orderData.deliveryFee ?? 0);
    let platformShare = toMoney(orderData.platformShare);
    if (platformShare <= 0) {
      platformShare = totalWithDelivery - restaurantShare - driverShare;
    }
    if (platformShare < 0) {
      platformShare = 0;
      const maxRestaurantShare = Math.max(0, totalWithDelivery - driverShare);
      if (restaurantShare > maxRestaurantShare) restaurantShare = maxRestaurantShare;
    }

    return {
      subtotal,
      deliveryFee,
      largeOrderFee,
      discountAmount,
      totalWithDelivery,
      restaurantShare,
      driverShare,
      platformShare,
    };
  };

  const needsFinancialUpdate = (orderData, computed) => {
    const sameRestaurant = Math.round(toMoney(orderData.restaurantShare)) === Math.round(computed.restaurantShare);
    const sameDriver = Math.round(toMoney(orderData.driverShare ?? orderData.deliveryFeeForDriver ?? orderData.deliveryFee)) === Math.round(computed.driverShare);
    const samePlatform = Math.round(toMoney(orderData.platformShare)) === Math.round(computed.platformShare);
    const sameTotal = Math.round(toMoney(orderData.totalWithDelivery)) === Math.round(computed.totalWithDelivery);
    return !(sameRestaurant && sameDriver && samePlatform && sameTotal);
  };

  const formatMoney = (value) => `${Math.round(toMoney(value)).toLocaleString('ar-EG')} ج.س`;

  const normalizeDelivered = (statusRaw) => {
    const s = String(statusRaw || '').trim().toLowerCase();
    return s === 'delivered' || s === 'تم التوصيل';
  };

  const parseAccount = (docData) => {
    const payoutAccount = docData?.payoutAccount || {};
    const method = String(payoutAccount.method || docData?.payoutMethod || '').trim();
    const accountNumber = String(payoutAccount.accountNumber || docData?.payoutAccountNumber || '').trim();
    const accountName = String(payoutAccount.accountName || docData?.payoutAccountName || '').trim();
    return { method, accountNumber, accountName };
  };

  if (paymentSettingsForm && !paymentSettingsFormBound) {
    paymentSettingsForm.addEventListener('submit', async (e) => {
      e.preventDefault();

      const enabledMethods = [];
      if (enableBankk?.checked) enabledMethods.push('bankk');
      if (enableOcash?.checked) enabledMethods.push('ocash');
      if (enableFawry?.checked) enabledMethods.push('fawry');

      if (!enabledMethods.length) {
        if (paymentSettingsResult) {
          paymentSettingsResult.textContent = 'يجب تفعيل طريقة دفع واحدة على الأقل.';
        }
        return;
      }

      let bankkQrUrl = String(bankkQrUrlInput?.value || '').trim();
      let ocashQrUrl = String(ocashQrUrlInput?.value || '').trim();
      let fawryQrUrl = String(fawryQrUrlInput?.value || '').trim();

      if (savePaymentSettingsBtn) savePaymentSettingsBtn.disabled = true;
      if (paymentSettingsResult) paymentSettingsResult.textContent = 'جارٍ رفع صور QR إن وجدت...';

      try {
        bankkQrUrl = await resolveUploadedQrUrl({ fileInput: bankkQrFileInput, currentUrl: bankkQrUrl, label: 'بنكك' });
        ocashQrUrl = await resolveUploadedQrUrl({ fileInput: ocashQrFileInput, currentUrl: ocashQrUrl, label: 'أوكاش' });
        fawryQrUrl = await resolveUploadedQrUrl({ fileInput: fawryQrFileInput, currentUrl: fawryQrUrl, label: 'فوري' });

        const payload = {
          enabledMethods,
          bankkAccount: String(bankkAccountInput?.value || '').trim(),
          ocashAccount: String(ocashAccountInput?.value || '').trim(),
          fawryAccount: String(fawryAccountInput?.value || '').trim(),
          bankkAccountHolder: String(bankkAccountHolderInput?.value || '').trim(),
          ocashAccountHolder: String(ocashAccountHolderInput?.value || '').trim(),
          fawryAccountHolder: String(fawryAccountHolderInput?.value || '').trim(),
          bankkQrUrl,
          ocashQrUrl,
          fawryQrUrl,
          bankkInstructions: String(bankkInstructionsInput?.value || '').trim(),
          ocashInstructions: String(ocashInstructionsInput?.value || '').trim(),
          fawryInstructions: String(fawryInstructionsInput?.value || '').trim(),
          bankkOpenUrlAndroid: String(bankkOpenUrlAndroidInput?.value || '').trim(),
          ocashOpenUrlAndroid: String(ocashOpenUrlAndroidInput?.value || '').trim(),
          fawryOpenUrlAndroid: String(fawryOpenUrlAndroidInput?.value || '').trim(),
          bankkOpenUrlIos: String(bankkOpenUrlIosInput?.value || '').trim(),
          ocashOpenUrlIos: String(ocashOpenUrlIosInput?.value || '').trim(),
          fawryOpenUrlIos: String(fawryOpenUrlIosInput?.value || '').trim(),
          bankkOpenUrl: String(bankkOpenUrlInput?.value || '').trim(),
          ocashOpenUrl: String(ocashOpenUrlInput?.value || '').trim(),
          fawryOpenUrl: String(fawryOpenUrlInput?.value || '').trim(),
          updatedAt: serverTimestamp(),
          updatedByAdminUid: auth.currentUser?.uid || '',
        };

        if (paymentSettingsResult) paymentSettingsResult.textContent = 'جارٍ حفظ الإعدادات...';
        await setDoc(doc(db, 'paymentSettings', 'default'), payload, { merge: true });
        if (bankkQrUrlInput) bankkQrUrlInput.value = bankkQrUrl;
        if (ocashQrUrlInput) ocashQrUrlInput.value = ocashQrUrl;
        if (fawryQrUrlInput) fawryQrUrlInput.value = fawryQrUrl;
        setQrPreview(bankkQrPreview, bankkQrUrl);
        setQrPreview(ocashQrPreview, ocashQrUrl);
        setQrPreview(fawryQrPreview, fawryQrUrl);
        if (bankkQrFileInput) bankkQrFileInput.value = '';
        if (ocashQrFileInput) ocashQrFileInput.value = '';
        if (fawryQrFileInput) fawryQrFileInput.value = '';
        if (paymentSettingsResult) {
          paymentSettingsResult.textContent = '✅ تم حفظ إعدادات الدفع بنجاح.';
        }
      } catch (err) {
        if (paymentSettingsResult) {
          paymentSettingsResult.textContent = `تعذر حفظ إعدادات الدفع: ${err.message || err}`;
        }
      } finally {
        if (savePaymentSettingsBtn) savePaymentSettingsBtn.disabled = false;
      }
    });

    paymentSettingsFormBound = true;
  }

  unsubscribers.push(
    onSnapshot(doc(db, 'paymentSettings', 'default'), (snap) => {
      const data = snap.data() || {};
      const methods = Array.isArray(data.enabledMethods) ? data.enabledMethods : [];

      if (enableBankk) enableBankk.checked = methods.includes('bankk');
      if (enableOcash) enableOcash.checked = methods.includes('ocash');
      if (enableFawry) enableFawry.checked = methods.includes('fawry');

      if (bankkAccountInput) bankkAccountInput.value = String(data.bankkAccount || '');
      if (ocashAccountInput) ocashAccountInput.value = String(data.ocashAccount || '');
      if (fawryAccountInput) fawryAccountInput.value = String(data.fawryAccount || '');
      if (bankkAccountHolderInput) bankkAccountHolderInput.value = String(data.bankkAccountHolder || '');
      if (ocashAccountHolderInput) ocashAccountHolderInput.value = String(data.ocashAccountHolder || '');
      if (fawryAccountHolderInput) fawryAccountHolderInput.value = String(data.fawryAccountHolder || '');
      if (bankkQrUrlInput) bankkQrUrlInput.value = String(data.bankkQrUrl || '');
      if (ocashQrUrlInput) ocashQrUrlInput.value = String(data.ocashQrUrl || '');
      if (fawryQrUrlInput) fawryQrUrlInput.value = String(data.fawryQrUrl || '');
      setQrPreview(bankkQrPreview, String(data.bankkQrUrl || ''));
      setQrPreview(ocashQrPreview, String(data.ocashQrUrl || ''));
      setQrPreview(fawryQrPreview, String(data.fawryQrUrl || ''));
      if (bankkInstructionsInput) bankkInstructionsInput.value = String(data.bankkInstructions || '');
      if (ocashInstructionsInput) ocashInstructionsInput.value = String(data.ocashInstructions || '');
      if (fawryInstructionsInput) fawryInstructionsInput.value = String(data.fawryInstructions || '');
      if (bankkOpenUrlAndroidInput) bankkOpenUrlAndroidInput.value = String(data.bankkOpenUrlAndroid || '');
      if (ocashOpenUrlAndroidInput) ocashOpenUrlAndroidInput.value = String(data.ocashOpenUrlAndroid || '');
      if (fawryOpenUrlAndroidInput) fawryOpenUrlAndroidInput.value = String(data.fawryOpenUrlAndroid || '');
      if (bankkOpenUrlIosInput) bankkOpenUrlIosInput.value = String(data.bankkOpenUrlIos || '');
      if (ocashOpenUrlIosInput) ocashOpenUrlIosInput.value = String(data.ocashOpenUrlIos || '');
      if (fawryOpenUrlIosInput) fawryOpenUrlIosInput.value = String(data.fawryOpenUrlIos || '');
      if (bankkOpenUrlInput) bankkOpenUrlInput.value = String(data.bankkOpenUrl || '');
      if (ocashOpenUrlInput) ocashOpenUrlInput.value = String(data.ocashOpenUrl || '');
      if (fawryOpenUrlInput) fawryOpenUrlInput.value = String(data.fawryOpenUrl || '');

      if (paymentSettingsResult && !paymentSettingsResult.textContent.includes('✅')) {
        paymentSettingsResult.textContent = 'الإعدادات الحالية محمّلة من Firebase.';
      }
    }, (err) => {
      if (paymentSettingsResult) {
        paymentSettingsResult.textContent = `تعذر تحميل إعدادات الدفع: ${err.message || err}`;
      }
    })
  );

  let latestFinanceDocs = [];

  const resolveOrderMillis = (orderData) => {
    const paidAt = orderData?.paidAt;
    if (paidAt && typeof paidAt.toMillis === 'function') return paidAt.toMillis();
    const createdAt = orderData?.createdAt;
    if (createdAt && typeof createdAt.toMillis === 'function') return createdAt.toMillis();
    const updatedAt = orderData?.updatedAt;
    if (updatedAt && typeof updatedAt.toMillis === 'function') return updatedAt.toMillis();
    return 0;
  };

  const applyFinanceRangeFilter = (docs) => {
    const range = String(financeRangeFilter?.value || 'all');
    if (range === 'all') return docs;

    const now = new Date();
    if (range === 'day') {
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
      return docs.filter((d) => resolveOrderMillis(d.data() || {}) >= start);
    }

    if (range === 'month') {
      const start = new Date(now.getFullYear(), now.getMonth(), 1).getTime();
      return docs.filter((d) => resolveOrderMillis(d.data() || {}) >= start);
    }

    return docs;
  };

  const renderPayoutTables = async (ordersDocs) => {
    const [restaurantsSnap, driversSnap] = await Promise.all([
      safeGetDocs(collection(db, 'restaurants')),
      safeGetDocs(collection(db, 'drivers')),
    ]);

    const restaurantMap = new Map();
    restaurantsSnap.docs.forEach((d) => restaurantMap.set(d.id, d.data() || {}));
    const driverMap = new Map();
    driversSnap.docs.forEach((d) => driverMap.set(d.id, d.data() || {}));

    const storeAgg = new Map();
    const courierAgg = new Map();

    ordersDocs.forEach((docSnap) => {
      const data = docSnap.data() || {};
      const isDelivered = normalizeDelivered(data.orderStatus || data.status);
      if (!isDelivered) return;

      const financial = computeFinancial(data);
      const restaurantId = String(data.restaurantId || '').trim();
      const driverId = String(data.assignedDriverId || '').trim();

      if (restaurantId) {
        const entry = storeAgg.get(restaurantId) || { ordersCount: 0, payable: 0, transferred: 0, totalEarned: 0 };
        entry.ordersCount += 1;
        entry.totalEarned += financial.restaurantShare;
        storeAgg.set(restaurantId, entry);
      }

      if (driverId) {
        const entry = courierAgg.get(driverId) || { ordersCount: 0, payable: 0, transferred: 0, totalEarned: 0 };
        entry.ordersCount += 1;
        entry.totalEarned += financial.driverShare;
        courierAgg.set(driverId, entry);
      }
    });

    storeAgg.forEach((entry, storeId) => {
      const storeData = restaurantMap.get(storeId) || {};
      const transferred = toMoney(storeData.walletTransferredTotal);
      entry.transferred = transferred;
      entry.payable = Math.max(0, entry.totalEarned - transferred);
    });

    courierAgg.forEach((entry, driverId) => {
      const driverData = driverMap.get(driverId) || {};
      const transferred = toMoney(driverData.walletTransferredTotal);
      entry.transferred = transferred;
      entry.payable = Math.max(0, entry.totalEarned - transferred);
    });

    const storeRows = Array.from(storeAgg.entries()).map(([storeId, agg]) => {
      const data = restaurantMap.get(storeId) || {};
      const account = parseAccount(data);
      return `<tr>
        <td>${escapeHtml(String(data.name || storeId))}</td>
        <td>${agg.ordersCount}</td>
        <td>${formatMoney(agg.totalEarned)}</td>
        <td>${formatMoney(agg.transferred)}</td>
        <td>${formatMoney(agg.payable)}</td>
        <td>${escapeHtml(account.method || '-')}</td>
        <td>${escapeHtml(account.accountName || '-')}</td>
        <td>${escapeHtml(account.accountNumber || '-')}</td>
        <td>
          <button class="btn primary" data-pay-store="${escapeHtml(storeId)}" data-payable="${agg.payable}">تم التحويل</button>
        </td>
      </tr>`;
    });

    const courierRows = Array.from(courierAgg.entries()).map(([driverId, agg]) => {
      const data = driverMap.get(driverId) || {};
      const account = parseAccount(data);
      return `<tr>
        <td>${escapeHtml(String(data.name || driverId))}</td>
        <td>${agg.ordersCount}</td>
        <td>${formatMoney(agg.totalEarned)}</td>
        <td>${formatMoney(agg.transferred)}</td>
        <td>${formatMoney(agg.payable)}</td>
        <td>${escapeHtml(account.method || '-')}</td>
        <td>${escapeHtml(account.accountName || '-')}</td>
        <td>${escapeHtml(account.accountNumber || '-')}</td>
        <td>
          <button class="btn primary" data-pay-courier="${escapeHtml(driverId)}" data-payable="${agg.payable}">تم التحويل</button>
        </td>
      </tr>`;
    });

    if (financeStoresPayoutTable) {
      setHtml(financeStoresPayoutTable, table(['المطعم', 'عدد الطلبات', 'المستحق الكلي', 'المحول سابقاً', 'المتبقي للتحويل', 'طريقة الدفع', 'اسم صاحب الحساب', 'رقم الحساب', 'إجراء'], storeRows));
      financeStoresPayoutTable.querySelectorAll('[data-pay-store]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const targetId = btn.getAttribute('data-pay-store');
          const payable = toMoney(btn.getAttribute('data-payable'));
          if (!targetId || payable <= 0) {
            if (window.showToast) window.showToast('لا توجد قيمة مستحقة للتحويل.', 'error');
            else alert('لا توجد قيمة مستحقة للتحويل.');
            return;
          }

          const storeName = escapeHtml(btn.closest('tr')?.querySelector('td')?.textContent?.trim() || targetId);
          const amount = Math.round(payable);

          if (window.confirmAction) {
            window.confirmAction({
              title: 'تأكيد تحويل المتجر',
              message: `تسجيل تحويل مبلغ <b>${amount.toLocaleString('ar-EG')} ج.س</b> للمتجر <b>${storeName}</b>؟`,
              confirmText: 'تأكيد التحويل',
              danger: false,
              onConfirm: async () => {
                try {
                  await recordWalletPayout({ role: 'store', targetId, amount });
                  if (window.showToast) window.showToast('تم تسجيل التحويل للمطعم وإرسال إشعار.', 'success');
                } catch (err) {
                  if (window.showToast) window.showToast(`تعذر تسجيل التحويل: ${err.message || err}`, 'error');
                }
              },
            });
          } else {
            const amountRaw = prompt('ادخل قيمة التحويل (يمكن تعديلها):', String(amount));
            if (amountRaw === null) return;
            const confirmedAmount = toMoney(amountRaw);
            if (!Number.isFinite(confirmedAmount) || confirmedAmount <= 0) { alert('قيمة التحويل غير صحيحة.'); return; }
            recordWalletPayout({ role: 'store', targetId, amount: confirmedAmount })
              .then(() => alert('تم تسجيل التحويل للمطعم وإرسال إشعار.'))
              .catch((err) => alert(`تعذر تسجيل التحويل: ${err.message || err}`));
          }
        });
      });
    }

    if (financeCouriersPayoutTable) {
      setHtml(financeCouriersPayoutTable, table(['المندوب', 'عدد الطلبات', 'المستحق الكلي', 'المحول سابقاً', 'المتبقي للتحويل', 'طريقة الدفع', 'اسم صاحب الحساب', 'رقم الحساب', 'إجراء'], courierRows));
      financeCouriersPayoutTable.querySelectorAll('[data-pay-courier]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const targetId = btn.getAttribute('data-pay-courier');
          const payable = toMoney(btn.getAttribute('data-payable'));
          if (!targetId || payable <= 0) {
            if (window.showToast) window.showToast('لا توجد قيمة مستحقة للتحويل.', 'error');
            else alert('لا توجد قيمة مستحقة للتحويل.');
            return;
          }

          const courierName = escapeHtml(btn.closest('tr')?.querySelector('td')?.textContent?.trim() || targetId);
          const amount = Math.round(payable);

          if (window.confirmAction) {
            window.confirmAction({
              title: 'تأكيد تحويل المندوب',
              message: `تسجيل تحويل مبلغ <b>${amount.toLocaleString('ar-EG')} ج.س</b> للمندوب <b>${courierName}</b>؟`,
              confirmText: 'تأكيد التحويل',
              danger: false,
              onConfirm: async () => {
                try {
                  await recordWalletPayout({ role: 'courier', targetId, amount });
                  if (window.showToast) window.showToast('تم تسجيل التحويل للمندوب وإرسال إشعار.', 'success');
                } catch (err) {
                  if (window.showToast) window.showToast(`تعذر تسجيل التحويل: ${err.message || err}`, 'error');
                }
              },
            });
          } else {
            const amountRaw = prompt('ادخل قيمة التحويل (يمكن تعديلها):', String(amount));
            if (amountRaw === null) return;
            const confirmedAmount = toMoney(amountRaw);
            if (!Number.isFinite(confirmedAmount) || confirmedAmount <= 0) { alert('قيمة التحويل غير صحيحة.'); return; }
            recordWalletPayout({ role: 'courier', targetId, amount: confirmedAmount })
              .then(() => alert('تم تسجيل التحويل للمندوب وإرسال إشعار.'))
              .catch((err) => alert(`تعذر تسجيل التحويل: ${err.message || err}`));
          }
        });
      });
    }

  };

  const syncWalletBalances = async (ordersDocs) => {
    const [restaurantsSnap, driversSnap] = await Promise.all([
      safeGetDocs(collection(db, 'restaurants')),
      safeGetDocs(collection(db, 'drivers')),
    ]);

    const restaurantMap = new Map();
    restaurantsSnap.docs.forEach((d) => restaurantMap.set(d.id, d.data() || {}));
    const driverMap = new Map();
    driversSnap.docs.forEach((d) => driverMap.set(d.id, d.data() || {}));

    const storeAgg = new Map();
    const courierAgg = new Map();

    ordersDocs.forEach((docSnap) => {
      const data = docSnap.data() || {};
      if (!normalizeDelivered(data.orderStatus || data.status)) return;
      const financial = computeFinancial(data);
      const restaurantId = String(data.restaurantId || '').trim();
      const driverId = String(data.assignedDriverId || '').trim();

      if (restaurantId) {
        const entry = storeAgg.get(restaurantId) || { ordersCount: 0, totalEarned: 0, transferred: 0, payable: 0 };
        entry.ordersCount += 1;
        entry.totalEarned += financial.restaurantShare;
        storeAgg.set(restaurantId, entry);
      }

      if (driverId) {
        const entry = courierAgg.get(driverId) || { ordersCount: 0, totalEarned: 0, transferred: 0, payable: 0 };
        entry.ordersCount += 1;
        entry.totalEarned += financial.driverShare;
        courierAgg.set(driverId, entry);
      }
    });

    const walletSyncUpdates = [];

    storeAgg.forEach((agg, storeId) => {
      const storeData = restaurantMap.get(storeId) || {};
      const transferred = toMoney(storeData.walletTransferredTotal);
      const payable = Math.max(0, agg.totalEarned - transferred);
      walletSyncUpdates.push({
        ref: doc(db, 'restaurants', storeId),
        patch: {
          walletPendingBalance: payable,
          walletDeliveredOrdersCount: agg.ordersCount,
          walletLifetimeEarnings: agg.totalEarned,
          walletSyncedAt: serverTimestamp(),
        },
      });
    });

    courierAgg.forEach((agg, driverId) => {
      const driverData = driverMap.get(driverId) || {};
      const transferred = toMoney(driverData.walletTransferredTotal);
      const payable = Math.max(0, agg.totalEarned - transferred);
      walletSyncUpdates.push({
        ref: doc(db, 'drivers', driverId),
        patch: {
          walletPendingBalance: payable,
          walletDeliveredOrdersCount: agg.ordersCount,
          walletLifetimeEarnings: agg.totalEarned,
          walletSyncedAt: serverTimestamp(),
        },
      });
    });

    for (let i = 0; i < walletSyncUpdates.length; i += 350) {
      const batch = writeBatch(db);
      walletSyncUpdates.slice(i, i + 350).forEach((entry) => {
        batch.set(entry.ref, entry.patch, { merge: true });
      });
      try {
        await batch.commit();
      } catch (err) {
        console.warn('wallet sync failed', err);
        break;
      }
    }
  };

  const formatDateTimeCell = (value) => {
    try {
      if (value && typeof value.toDate === 'function') {
        return value.toDate().toLocaleString('ar-EG');
      }
    } catch (_) {
    }
    return '-';
  };

  const renderPaymentReviewQueue = async (docs) => {
    if (!financePaymentReviewTable) return;

    const reviewDocs = docs.filter((d) => {
      const data = d.data() || {};
      const status = String(data.paymentStatus || '').trim();
      const decision = String(data.paymentReviewDecision || '').trim().toLowerCase();
      return status === 'قيد المراجعة' || decision === 'pending';
    });

    opsCenterState.paymentReviews = reviewDocs.length;
    syncOpsCollectionState(
      'paymentReviews',
      new Set(reviewDocs.map((docSnap) => docSnap.id)),
      (id) => {
        const item = reviewDocs.find((docSnap) => docSnap.id === id);
        const data = item?.data?.() || {};
        return {
          title: 'إيصال جديد بانتظار المراجعة',
          body: `الطلب ${formatUnifiedOrderCode(data.orderNumber, data.orderId, id)} يحتاج مراجعة فورية.`,
          level: 'danger',
        };
      }
    );

    if (financePaymentReviewSummary) {
      financePaymentReviewSummary.textContent = reviewDocs.length
        ? `عدد الإيصالات قيد المراجعة: ${reviewDocs.length}`
        : 'لا توجد إيصالات بانتظار المراجعة.';
    }

    const transactionRefs = new Map();
    docs.forEach((d) => {
      const data = d.data() || {};
      const ref = String(data.transactionReference || '').trim();
      if (!ref) return;
      transactionRefs.set(ref, (transactionRefs.get(ref) || 0) + 1);
    });

    const rows = reviewDocs
      .sort((a, b) => {
        const at = a.data()?.updatedAt?.toMillis?.() || a.data()?.paidAt?.toMillis?.() || 0;
        const bt = b.data()?.updatedAt?.toMillis?.() || b.data()?.paidAt?.toMillis?.() || 0;
        return bt - at;
      })
      .map((d) => {
        const data = d.data() || {};
        const txRef = String(data.transactionReference || '').trim();
        const duplicateCount = txRef ? Number(transactionRefs.get(txRef) || 0) : 0;
        const duplicateLabel = duplicateCount > 1 ? `<span class="badge open">مكرر ${duplicateCount}</span>` : '';
        const totalBeforeWallet = toMoney(data.totalBeforeWallet || data.totalWithDelivery || data.total || 0);
        const walletRequestedAmount = toMoney(data.walletRequestedAmount || 0);
        const reviewAmount = toMoney(
          data.externalPaidAmount
          ?? data.amountDueAfterWallet
          ?? data.totalWithDelivery
          ?? data.total
          ?? 0
        );
        const amountLabel = walletRequestedAmount > 0
          ? `<div>${formatMoney(reviewAmount)}</div><div class="muted">الإجمالي ${formatMoney(totalBeforeWallet)} - المحفظة ${formatMoney(walletRequestedAmount)}</div>`
          : formatMoney(reviewAmount);
        const timeline = getOrderTimelineEntries(data);
        return `<tr>
          <td>${escapeHtml(formatUnifiedOrderCode(data.orderNumber, data.orderId, d.id))}</td>
          <td>${resolveClientDisplay(data.clientId, data.clientName)}</td>
          <td>${resolveRestaurantDisplay(data.restaurantId, data.restaurantName)}</td>
          <td>${escapeHtml(String(data.paymentMethod || '-'))}</td>
          <td>${amountLabel}</td>
          <td>${escapeHtml(txRef || '-')} ${duplicateLabel}</td>
          <td>${data.proofImageUrl ? `<a class="btn ghost" href="${escapeHtml(data.proofImageUrl)}" target="_blank" rel="noopener">عرض</a>` : '-'}</td>
          <td>${formatDateTimeCell(data.paymentReviewAutoFlaggedAt || data.updatedAt || data.paidAt)}</td>
          <td>
            <details class="review-details-toggle">
              <summary>تفاصيل</summary>
              <div class="review-expand-card">
                <div class="review-expand-grid">
                  <div><strong>المندوب</strong>${resolveDriverDisplay(data.assignedDriverId || data.offeredDriverId, data.assignedDriverName || '')}</div>
                  <div><strong>هاتف العميل</strong>${escapeHtml(String(data.clientPhone || '-'))}</div>
                  <div><strong>الحالة الحالية</strong>${escapeHtml(formatOrderStatusLabel(data.orderStatus || data.status || '-'))}</div>
                  <div><strong>العنوان</strong>${escapeHtml(String(data.deliveryAddress || data.address || '-'))}</div>
                </div>
                <div>
                  <strong>التسلسل الزمني</strong>
                  <div class="order-timeline">
                    ${timeline.length ? timeline.map((item) => `<div class="order-timeline-item"><b>${escapeHtml(item.label)}</b><span>${escapeHtml(formatDateTimeLabel(item.millis))}</span></div>`).join('') : '<div class="muted">لا توجد أحداث زمنية كافية.</div>'}
                  </div>
                </div>
                <div>
                  <strong>العناصر</strong>
                  ${renderOrderItemsRows(data.items)}
                </div>
                <div class="review-expand-actions">
                  <button class="btn ghost" type="button" data-open-review-order="${escapeHtml(d.id)}">فتح الطلب</button>
                  <button class="btn primary" type="button" data-open-review-map="${escapeHtml(d.id)}">الخريطة</button>
                </div>
              </div>
            </details>
            <button class="btn ghost" data-approve-payment="${escapeHtml(d.id)}">قبول</button>
            <button class="btn danger" data-reject-payment="${escapeHtml(d.id)}">رفض</button>
          </td>
        </tr>`;
      });

    setHtml(financePaymentReviewTable, table(['رقم الطلب', 'العميل', 'المتجر', 'الطريقة', 'المبلغ', 'رقم العملية', 'الإيصال', 'آخر تحديث', 'إجراء'], rows));

    financePaymentReviewTable.querySelectorAll('[data-open-review-order]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const orderId = btn.getAttribute('data-open-review-order');
        if (!orderId) return;
        openOrdersWorkspace(orderId);
      });
    });

    financePaymentReviewTable.querySelectorAll('[data-open-review-map]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const orderId = btn.getAttribute('data-open-review-map');
        if (!orderId) return;
        openOrderOnMap(orderId, { allowCompleted: true });
      });
    });

    financePaymentReviewTable.querySelectorAll('[data-approve-payment]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const orderId = btn.getAttribute('data-approve-payment');
        if (!orderId) return;
        try {
          await reviewOrderPaymentEvidence({ orderId, decision: 'approve' });
          alert('تم اعتماد الإيصال بنجاح');
        } catch (err) {
          alert(`تعذر اعتماد الإيصال: ${err.message || err}`);
        }
      });
    });

    financePaymentReviewTable.querySelectorAll('[data-reject-payment]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const orderId = btn.getAttribute('data-reject-payment');
        if (!orderId) return;
        if (window.confirmAction) {
          window.confirmAction({
            title: 'رفض إيصال الدفع',
            message: `هل تريد رفض إيصال الطلب <b>${escapeHtml(orderId)}</b>؟ لا يمكن التراجع عن هذا الإجراء.`,
            confirmText: 'رفض',
            danger: true,
            onConfirm: async () => {
              try {
                await reviewOrderPaymentEvidence({ orderId, decision: 'reject', note: '' });
                if (window.showToast) window.showToast('تم رفض الإيصال بنجاح.', 'success');
              } catch (err) {
                if (window.showToast) window.showToast(`تعذر رفض الإيصال: ${err.message || err}`, 'error');
              }
            },
          });
        } else {
          const note = prompt('سبب الرفض (اختياري):', '') || '';
          reviewOrderPaymentEvidence({ orderId, decision: 'reject', note: note.trim() })
            .then(() => alert('تم رفض الإيصال'))
            .catch((err) => alert(`تعذر رفض الإيصال: ${err.message || err}`));
        }
      });
    });
  };

  const renderWalletRechargeQueue = async () => {
    if (!financeWalletRechargeTable) return;

    let rechargeDocs = [];
    try {
      const rechargeSnap = await getDocs(
        query(collection(db, 'wallet_recharges'), orderBy('createdAt', 'desc'), limit(300))
      );
      rechargeDocs = rechargeSnap.docs;
    } catch (err) {
      console.warn('wallet recharge queue failed', err);
      if (financeWalletRechargeSummary) {
        financeWalletRechargeSummary.textContent = 'تعذر تحميل طلبات شحن المحافظ.';
      }
      setHtml(financeWalletRechargeTable, '<div class="muted">تعذر تحميل طلبات الشحن.</div>');
      return;
    }

    const pendingDocs = rechargeDocs.filter((docSnap) => {
      const data = docSnap.data() || {};
      const status = String(data.status || '').trim().toLowerCase();
      const reviewStatus = String(data.reviewStatus || '').trim().toLowerCase();
      return ['pending', 'pending_review', 'under_review'].includes(status)
        || reviewStatus === 'pending';
    });

    opsCenterState.walletRecharges = pendingDocs.length;
    syncOpsCollectionState(
      'walletRecharges',
      new Set(pendingDocs.map((docSnap) => docSnap.id)),
      (id) => {
        const item = pendingDocs.find((docSnap) => docSnap.id === id);
        const data = item?.data?.() || {};
        return {
          title: 'طلب شحن محفظة جديد',
          body: `يوجد طلب شحن محفظة جديد للعميل ${data.clientName || data.clientId || id}.`,
          level: 'warning',
        };
      }
    );

    if (financeWalletRechargeSummary) {
      financeWalletRechargeSummary.textContent = pendingDocs.length
        ? `عدد طلبات شحن المحافظ قيد المراجعة: ${pendingDocs.length}`
        : 'لا توجد طلبات شحن محافظ بانتظار المراجعة.';
    }

    const rows = pendingDocs.map((docSnap) => {
      const data = docSnap.data() || {};
      return `<tr>
        <td>${escapeHtml(String(data.clientName || data.clientId || '-'))}</td>
        <td>${escapeHtml(String(data.clientPhone || '-'))}</td>
        <td>${formatMoney(data.amount || 0)}</td>
        <td>${escapeHtml(String(data.paymentMethod || '-'))}</td>
        <td>${escapeHtml(String(data.transactionReference || '-'))}</td>
        <td>${data.proofImageUrl ? `<a class="btn ghost" href="${escapeHtml(data.proofImageUrl)}" target="_blank" rel="noopener">عرض</a>` : '-'}</td>
        <td>${formatDateTimeCell(data.createdAt || data.updatedAt)}</td>
        <td>
          <button class="btn ghost" data-approve-wallet-recharge="${escapeHtml(docSnap.id)}">قبول</button>
          <button class="btn danger" data-reject-wallet-recharge="${escapeHtml(docSnap.id)}">رفض</button>
        </td>
      </tr>`;
    });

    setHtml(
      financeWalletRechargeTable,
      table(['العميل', 'الهاتف', 'المبلغ', 'الطريقة', 'الرقم المرجعي', 'الإيصال', 'تاريخ الطلب', 'إجراء'], rows)
    );

    financeWalletRechargeTable.querySelectorAll('[data-approve-wallet-recharge]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const rechargeId = btn.getAttribute('data-approve-wallet-recharge');
        if (!rechargeId) return;
        try {
          await reviewClientWalletRecharge({ rechargeId, decision: 'approve' });
          alert('تم اعتماد طلب شحن المحفظة وإضافة الرصيد للعميل.');
          await renderWalletRechargeQueue();
        } catch (err) {
          alert(`تعذر اعتماد طلب الشحن: ${err.message || err}`);
        }
      });
    });

    financeWalletRechargeTable.querySelectorAll('[data-reject-wallet-recharge]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const rechargeId = btn.getAttribute('data-reject-wallet-recharge');
        if (!rechargeId) return;
        if (window.confirmAction) {
          window.confirmAction({
            title: 'رفض طلب شحن المحفظة',
            message: 'هل تريد رفض طلب شحن المحفظة؟ لا يمكن التراجع عن هذا الإجراء.',
            confirmText: 'رفض',
            danger: true,
            onConfirm: async () => {
              try {
                await reviewClientWalletRecharge({ rechargeId, decision: 'reject', note: '' });
                if (window.showToast) window.showToast('تم رفض طلب شحن المحفظة.', 'success');
                await renderWalletRechargeQueue();
              } catch (err) {
                if (window.showToast) window.showToast(`تعذر رفض طلب الشحن: ${err.message || err}`, 'error');
              }
            },
          });
        } else {
          const note = prompt('سبب الرفض (اختياري):', '') || '';
          reviewClientWalletRecharge({ rechargeId, decision: 'reject', note: note.trim() })
            .then(() => { alert('تم رفض طلب شحن المحفظة.'); return renderWalletRechargeQueue(); })
            .catch((err) => alert(`تعذر رفض طلب الشحن: ${err.message || err}`));
        }
      });
    });
  };

  const renderWalletWithdrawalQueue = async () => {
    if (!financeWalletWithdrawalTable) return;

    let withdrawalDocs = [];
    try {
      const snap = await getDocs(
        query(collection(db, 'wallet_withdrawals'), orderBy('createdAt', 'desc'), limit(300))
      );
      withdrawalDocs = snap.docs;
    } catch (err) {
      console.warn('wallet withdrawal queue failed', err);
      if (financeWalletWithdrawalSummary) {
        financeWalletWithdrawalSummary.textContent = 'تعذر تحميل طلبات السحب.';
      }
      setHtml(financeWalletWithdrawalTable, '<div class="muted">تعذر تحميل طلبات السحب.</div>');
      return;
    }

    const pendingDocs = withdrawalDocs.filter((docSnap) => {
      const status = String((docSnap.data() || {}).status || '').trim().toLowerCase();
      return status === 'pending';
    });

    opsCenterState.walletWithdrawals = pendingDocs.length;
    syncOpsCollectionState(
      'walletWithdrawals',
      new Set(pendingDocs.map((docSnap) => docSnap.id)),
      (id) => {
        const item = pendingDocs.find((docSnap) => docSnap.id === id);
        const data = item?.data?.() || {};
        return {
          title: 'طلب سحب محفظة جديد',
          body: `العميل ${data.clientName || data.clientId || id} يطلب سحب ${formatMoney(data.amount || 0)}.`,
          level: 'warning',
        };
      }
    );

    if (financeWalletWithdrawalSummary) {
      financeWalletWithdrawalSummary.textContent = pendingDocs.length
        ? `عدد طلبات السحب قيد المراجعة: ${pendingDocs.length}`
        : 'لا توجد طلبات سحب بانتظار المراجعة.';
    }

    if (pendingDocs.length === 0) {
      setHtml(financeWalletWithdrawalTable, '<div class="muted">لا توجد طلبات سحب معلقة.</div>');
      return;
    }

    const rows = pendingDocs.map((docSnap) => {
      const data = docSnap.data() || {};
      return `<tr>
        <td>${escapeHtml(String(data.clientName || data.clientId || '-'))}</td>
        <td>${escapeHtml(String(data.clientPhone || '-'))}</td>
        <td>${formatMoney(data.amount || 0)}</td>
        <td>${escapeHtml(String(data.paymentMethod || '-'))}</td>
        <td>${escapeHtml(String(data.accountNumber || '-'))}</td>
        <td>${escapeHtml(String(data.accountHolderName || '-'))}</td>
        <td>${formatDateTimeCell(data.createdAt || data.updatedAt)}</td>
        <td>
          <button class="btn ghost" data-approve-withdrawal="${escapeHtml(docSnap.id)}">قبول</button>
          <button class="btn danger" data-reject-withdrawal="${escapeHtml(docSnap.id)}">رفض</button>
        </td>
      </tr>`;
    });

    setHtml(
      financeWalletWithdrawalTable,
      table(['العميل', 'الهاتف', 'المبلغ', 'طريقة الاستلام', 'رقم الحساب', 'اسم صاحب الحساب', 'تاريخ الطلب', 'إجراء'], rows)
    );

    financeWalletWithdrawalTable.querySelectorAll('[data-approve-withdrawal]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const withdrawalId = btn.getAttribute('data-approve-withdrawal');
        if (!withdrawalId) return;
        try {
          await reviewClientWalletWithdrawal({ withdrawalId, decision: 'approve' });
          if (window.showToast) window.showToast('تمت الموافقة على طلب السحب وخصم المبلغ من المحفظة.', 'success');
          else alert('تمت الموافقة على طلب السحب وخصم المبلغ من المحفظة.');
          await renderWalletWithdrawalQueue();
        } catch (err) {
          if (window.showToast) window.showToast(`تعذر قبول طلب السحب: ${err.message || err}`, 'error');
          else alert(`تعذر قبول طلب السحب: ${err.message || err}`);
        }
      });
    });

    financeWalletWithdrawalTable.querySelectorAll('[data-reject-withdrawal]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const withdrawalId = btn.getAttribute('data-reject-withdrawal');
        if (!withdrawalId) return;
        if (window.confirmAction) {
          window.confirmAction({
            title: 'رفض طلب السحب',
            message: 'هل تريد رفض طلب سحب المحفظة؟',
            confirmText: 'رفض',
            danger: true,
            onConfirm: async () => {
              try {
                await reviewClientWalletWithdrawal({ withdrawalId, decision: 'reject', note: '' });
                if (window.showToast) window.showToast('تم رفض طلب السحب.', 'success');
                await renderWalletWithdrawalQueue();
              } catch (err) {
                if (window.showToast) window.showToast(`تعذر رفض طلب السحب: ${err.message || err}`, 'error');
              }
            },
          });
        } else {
          const note = prompt('سبب الرفض (اختياري):', '') || '';
          reviewClientWalletWithdrawal({ withdrawalId, decision: 'reject', note: note.trim() })
            .then(() => { alert('تم رفض طلب السحب.'); return renderWalletWithdrawalQueue(); })
            .catch((err) => alert(`تعذر رفض طلب السحب: ${err.message || err}`));
        }
      });
    });
  };

  const renderFinanceView = async () => {
    const docs = applyFinanceRangeFilter(latestFinanceDocs);

    let totalOrdersRevenue = 0;
    let totalRestaurantShare = 0;
    let totalDriverShare = 0;
    let totalPlatformShare = 0;
    let totalPaidOrdersRevenue = 0;
    let totalPaidRestaurantShare = 0;
    let totalPaidDriverShare = 0;
    let totalPaidPlatformShare = 0;

    const rows = [];

    docs.forEach((d) => {
      const data = d.data() || {};
      const financial = computeFinancial(data);
      const isPaid = String(data.paymentStatus || '').toLowerCase() === 'paid';

      totalOrdersRevenue += financial.totalWithDelivery;
      totalRestaurantShare += financial.restaurantShare;
      totalDriverShare += financial.driverShare;
      totalPlatformShare += financial.platformShare;

      if (isPaid) {
        totalPaidOrdersRevenue += financial.totalWithDelivery;
        totalPaidRestaurantShare += financial.restaurantShare;
        totalPaidDriverShare += financial.driverShare;
        totalPaidPlatformShare += financial.platformShare;
      }

      rows.push(`<tr>
        <td>${escapeHtml(formatUnifiedOrderCode(data.orderNumber, data.orderId, d.id))}</td>
        <td>${escapeHtml(String(data.paymentStatus || '-'))}</td>
        <td>${formatMoney(financial.totalWithDelivery)}</td>
        <td>${formatMoney(financial.restaurantShare)}</td>
        <td>${formatMoney(financial.driverShare)}</td>
        <td>${formatMoney(financial.platformShare)}</td>
        <td>${formatMoney(financial.discountAmount)}</td>
        <td><button class="btn ghost" data-finance-map="${escapeHtml(d.id)}">الخريطة</button></td>
      </tr>`);
    });

    if (financeTotalsSummary) {
      financeTotalsSummary.classList.remove('muted');
      financeTotalsSummary.innerHTML = `
        <div><b>إجمالي كل الطلبات:</b> ${formatMoney(totalOrdersRevenue)} | <b>حصة المطاعم:</b> ${formatMoney(totalRestaurantShare)} | <b>حصة المندوبين:</b> ${formatMoney(totalDriverShare)} | <b>حصة المنصة:</b> ${formatMoney(totalPlatformShare)}</div>
        <div style="margin-top:6px;"><b>إجمالي الطلبات المدفوعة:</b> ${formatMoney(totalPaidOrdersRevenue)} | <b>حصة المطاعم (مدفوعة):</b> ${formatMoney(totalPaidRestaurantShare)} | <b>حصة المندوبين (مدفوعة):</b> ${formatMoney(totalPaidDriverShare)} | <b>حصة المنصة (مدفوعة):</b> ${formatMoney(totalPaidPlatformShare)}</div>
      `;
    }

    const platformTotalEl = document.getElementById('platformTotal');
    if (platformTotalEl) {
      platformTotalEl.textContent = formatMoney(totalPaidPlatformShare);
    }

    if (financeOrdersTable) {
      setHtml(financeOrdersTable, table(['رقم الطلب', 'الدفع', 'إجمالي الطلب', 'حصة المطعم', 'حصة المندوب', 'حصة المنصة', 'الخصم', 'تتبع'], rows));
      financeOrdersTable.querySelectorAll('[data-finance-map]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const orderId = btn.getAttribute('data-finance-map');
          if (!orderId) return;
          openOrderOnMap(orderId);
        });
      });
    }

    await renderPaymentReviewQueue(docs);
    await renderWalletRechargeQueue();
    await renderWalletWithdrawalQueue();

    await renderPayoutTables(latestFinanceDocs);
  };

  if (financeRangeFilter && !financeRangeFilterBound) {
    financeRangeFilter.addEventListener('change', () => {
      void renderFinanceView();
    });
    financeRangeFilterBound = true;
  }

  unsubscribers.push(
    onSnapshot(query(collection(db, 'orders'), where('paymentStatus', '==', 'paid')), (snap) => {
      document.getElementById('paidOrders').textContent = snap.size;
    })
  );
  unsubscribers.push(
    onSnapshot(query(collection(db, 'orders'), where('paymentStatus', '==', 'pending')), (snap) => {
      document.getElementById('pendingPay').textContent = snap.size;
    })
  );
  unsubscribers.push(
    onSnapshot(query(collection(db, 'orders'), where('payoutStatus', '==', 'done')), (snap) => {
      document.getElementById('payoutDone').textContent = snap.size;
    })
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'orders'), async (snap) => {
      const updates = [];

      latestFinanceDocs = snap.docs;

      snap.docs.forEach((d) => {
        const data = d.data() || {};
        const financial = computeFinancial(data);

        if (needsFinancialUpdate(data, financial)) {
          updates.push({
            ref: d.ref,
            patch: {
              totalWithDelivery: financial.totalWithDelivery,
              restaurantShare: financial.restaurantShare,
              driverShare: financial.driverShare,
              platformShare: financial.platformShare,
              financialSnapshotVersion: 1,
              financialSnapshotAt: serverTimestamp(),
              updatedAt: serverTimestamp(),
            },
          });
        }
      });

      if (updates.length) {
        for (let i = 0; i < updates.length; i += 350) {
          const batch = writeBatch(db);
          updates.slice(i, i + 350).forEach((item) => batch.set(item.ref, item.patch, { merge: true }));
          try {
            await batch.commit();
          } catch (err) {
            console.warn('finance snapshot batch failed', err);
            break;
          }
        }
      }

      await syncWalletBalances(snap.docs);
      await renderFinanceView();
    })
  );
}

function offerDateTimeLocalValue(date) {
  const pad = (value) => String(value).padStart(2, '0');
  return [
    date.getFullYear(),
    pad(date.getMonth() + 1),
    pad(date.getDate()),
  ].join('-') + `T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function parseAdminOfferTargetItems(raw) {
  return String(raw || '')
    .split(',')
    .map((name) => name.trim())
    .filter(Boolean)
    .slice(0, 25)
    .map((name) => ({ name }));
}

function setAdminOfferDefaults() {
  if (!adminOfferStartsAt || !adminOfferEndsAt) return;
  const now = new Date();
  now.setMinutes(now.getMinutes() - (now.getMinutes() % 5), 0, 0);
  const end = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  if (!adminOfferStartsAt.value) adminOfferStartsAt.value = offerDateTimeLocalValue(now);
  if (!adminOfferEndsAt.value) adminOfferEndsAt.value = offerDateTimeLocalValue(end);
}

function resetAdminOfferForm() {
  adminCreateOfferForm?.reset();
  setAdminOfferDefaults();
  if (adminOfferIsActive) adminOfferIsActive.checked = true;
  if (adminOfferImageUrl) adminOfferImageUrl.value = '';
  if (adminOfferImageStatus) adminOfferImageStatus.textContent = 'اختر صورة من الجهاز.';
  if (adminOfferImagePreview) {
    adminOfferImagePreview.hidden = true;
    adminOfferImagePreview.removeAttribute('src');
  }
}

function bindAdminCreateOfferForm() {
  if (!adminCreateOfferForm || adminCreateOfferForm.dataset.bound === '1') return;
  adminCreateOfferForm.dataset.bound = '1';
  setAdminOfferDefaults();

  adminOfferImageFile?.addEventListener('change', () => {
    const file = adminOfferImageFile.files && adminOfferImageFile.files.length
      ? adminOfferImageFile.files[0]
      : null;
    if (adminOfferImageUrl) adminOfferImageUrl.value = '';
    if (!file) {
      if (adminOfferImageStatus) adminOfferImageStatus.textContent = 'اختر صورة من الجهاز.';
      if (adminOfferImagePreview) {
        adminOfferImagePreview.hidden = true;
        adminOfferImagePreview.removeAttribute('src');
      }
      return;
    }
    if (adminOfferImageStatus) adminOfferImageStatus.textContent = file.name;
    if (adminOfferImagePreview) {
      adminOfferImagePreview.src = URL.createObjectURL(file);
      adminOfferImagePreview.hidden = false;
    }
  });

  adminCreateOfferForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (!adminOfferRestaurantId?.value) {
      if (adminCreateOfferResult) adminCreateOfferResult.textContent = 'اختر المطعم أولاً.';
      return;
    }

    const targetItems = parseAdminOfferTargetItems(adminOfferTargetItems?.value);
    if (adminOfferDiscountScope?.value === 'specific_items' && targetItems.length === 0) {
      if (adminCreateOfferResult) adminCreateOfferResult.textContent = 'اكتب أسماء الأصناف المشمولة بالعرض.';
      return;
    }

    if (adminCreateOfferBtn) adminCreateOfferBtn.disabled = true;
    if (adminCreateOfferResult) adminCreateOfferResult.textContent = 'جاري إنشاء العرض...';
    try {
      let uploadedImageUrl = adminOfferImageUrl?.value || '';
      const imageFile = adminOfferImageFile?.files && adminOfferImageFile.files.length
        ? adminOfferImageFile.files[0]
        : null;
      if (imageFile) {
        if (adminCreateOfferResult) adminCreateOfferResult.textContent = 'جاري رفع صورة العرض...';
        uploadedImageUrl = await uploadImageToCloudinary(imageFile);
        if (!uploadedImageUrl) {
          throw new Error('تعذر رفع صورة العرض. حاول بصورة أخرى.');
        }
        if (adminOfferImageUrl) adminOfferImageUrl.value = uploadedImageUrl;
      }
      if (adminCreateOfferResult) adminCreateOfferResult.textContent = 'جاري إنشاء العرض...';
      await adminCreateStoreOffer({
        restaurantId: adminOfferRestaurantId.value,
        offer: {
          title: adminOfferTitle?.value || '',
          description: adminOfferDescription?.value || '',
          badgeText: adminOfferBadgeText?.value || '',
          imageUrl: uploadedImageUrl,
          discountScope: adminOfferDiscountScope?.value || 'order_total',
          discountType: adminOfferDiscountType?.value || 'percent',
          discountValue: Number(adminOfferDiscountValue?.value || 0),
          maxDiscount: Number(adminOfferMaxDiscount?.value || 0),
          minOrder: Number(adminOfferMinOrder?.value || 0),
          startsAt: adminOfferStartsAt?.value ? new Date(adminOfferStartsAt.value).toISOString() : '',
          endsAt: adminOfferEndsAt?.value ? new Date(adminOfferEndsAt.value).toISOString() : '',
          targetItems,
          reviewNote: adminOfferReviewNote?.value || '',
          isActive: adminOfferIsActive?.checked !== false,
        },
      });
      if (adminCreateOfferResult) adminCreateOfferResult.textContent = 'تم إنشاء العرض وتحديث ظهوره للعميل.';
      resetAdminOfferForm();
    } catch (err) {
      if (adminCreateOfferResult) adminCreateOfferResult.textContent = `تعذر إنشاء العرض: ${err.message || err}`;
    } finally {
      if (adminCreateOfferBtn) adminCreateOfferBtn.disabled = false;
    }
  });
}

function mountAdminOfferRestaurantSelect() {
  if (!adminOfferRestaurantId) return;
  unsubscribers.push(
    onSnapshot(query(collection(db, 'restaurants'), limit(500)), (snap) => {
      const selected = adminOfferRestaurantId.value;
      const rows = snap.docs
        .map((docSnap) => ({ id: docSnap.id, data: docSnap.data() || {} }))
        .filter((item) => {
          const status = String(item.data.approvalStatus || '').trim().toLowerCase();
          return !status || status === 'approved' || item.data.active === true;
        })
        .sort((a, b) => String(a.data.name || a.id).localeCompare(String(b.data.name || b.id), 'ar'));

      adminOfferRestaurantId.innerHTML = [
        '<option value="">اختر المطعم</option>',
        ...rows.map((item) => {
          const name = String(item.data.name || item.data.restaurantName || item.id).trim();
          return `<option value="${escapeHtml(item.id)}">${escapeHtml(name)} - ${escapeHtml(item.id)}</option>`;
        }),
      ].join('');
      if (selected) adminOfferRestaurantId.value = selected;
    })
  );
}

function mountStoreOffersReview() {
  if (!storeOffersSummary || !storeOffersPendingTable || !storeOffersApprovedTable) return;
  bindAdminCreateOfferForm();
  mountAdminOfferRestaurantSelect();

  const formatDateTimeLocal = (value) => {
    if (!value || typeof value.toDate !== 'function') return '-';
    try {
      return value.toDate().toLocaleString('ar-EG');
    } catch (_) {
      return '-';
    }
  };

  const renderEmptyState = (message, columns) => [
    `<tr><td colspan="${columns}" class="muted">${escapeHtml(message)}</td></tr>`
  ];

  const callReview = async (offerId, action) => {
    try {
      await reviewStoreOfferRequest({ offerId, action });
    } catch (err) {
      alert(`تعذر تنفيذ الإجراء: ${err.message || err}`);
    }
  };

  unsubscribers.push(
    onSnapshot(query(collection(db, 'storeOffers'), limit(300)), (snap) => {
      const docs = snap.docs.slice().sort((a, b) => {
        const aData = a.data() || {};
        const bData = b.data() || {};
        const aTime = aData.updatedAt?.toMillis?.() || aData.createdAt?.toMillis?.() || 0;
        const bTime = bData.updatedAt?.toMillis?.() || bData.createdAt?.toMillis?.() || 0;
        return bTime - aTime;
      });

      const pendingDocs = docs.filter((doc) => String(doc.data()?.status || '') === 'pending');
      const approvedDocs = docs.filter((doc) => String(doc.data()?.status || '') === 'approved');

      setHtml(
        storeOffersSummary,
        `إجمالي العروض: <b>${docs.length}</b> - بانتظار المراجعة: <b>${pendingDocs.length}</b> - المعتمدة: <b>${approvedDocs.length}</b>`
      );

      const pendingRows = pendingDocs.length > 0
        ? pendingDocs.map((doc) => {
            const data = doc.data() || {};
            return `<tr>
              <td>${escapeHtml(String(data.restaurantName || data.restaurantId || '-'))}</td>
              <td>${escapeHtml(String(data.title || '-'))}</td>
              <td>${escapeHtml(String(data.summaryText || '-'))}</td>
              <td>${formatDateTimeLocal(data.startsAt)}<br>${formatDateTimeLocal(data.endsAt)}</td>
              <td>${formatDateTimeLocal(data.createdAt)}</td>
              <td>
                <button class="btn primary" data-offer-review="approve" data-offer-id="${escapeHtml(doc.id)}">اعتماد</button>
                <button class="btn danger" data-offer-review="reject" data-offer-id="${escapeHtml(doc.id)}">رفض</button>
              </td>
            </tr>`;
          })
        : renderEmptyState('لا توجد عروض بانتظار المراجعة.', 6);

      const approvedRows = approvedDocs.length > 0
        ? approvedDocs.map((doc) => {
            const data = doc.data() || {};
            const active = data.isActive === true;
            return `<tr>
              <td>${escapeHtml(String(data.restaurantName || data.restaurantId || '-'))}</td>
              <td>${escapeHtml(String(data.title || '-'))}</td>
              <td>${escapeHtml(String(data.summaryText || '-'))}</td>
              <td><span class="badge ${active ? 'closed' : 'open'}">${active ? 'مفعل' : 'موقوف'}</span></td>
              <td>${formatDateTimeLocal(data.endsAt)}</td>
              <td>
                <button class="btn ghost" data-offer-review="${active ? 'deactivate' : 'activate'}" data-offer-id="${escapeHtml(doc.id)}">${active ? 'إيقاف' : 'تفعيل'}</button>
              </td>
            </tr>`;
          })
        : renderEmptyState('لا توجد عروض معتمدة حالياً.', 6);

      setHtml(
        storeOffersPendingTable,
        table(['المطعم', 'عنوان العرض', 'الملخص', 'الفترة', 'أُرسل في', 'إجراء'], pendingRows)
      );
      setHtml(
        storeOffersApprovedTable,
        table(['المطعم', 'عنوان العرض', 'الملخص', 'الحالة', 'ينتهي في', 'إجراء'], approvedRows)
      );

      document.querySelectorAll('[data-offer-review]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const offerId = btn.getAttribute('data-offer-id');
          const action = btn.getAttribute('data-offer-review');
          if (!offerId || !action) return;
          btn.setAttribute('disabled', 'disabled');
          await callReview(offerId, action);
          btn.removeAttribute('disabled');
        });
      });
    })
  );
}

async function handleManagedUserDeletion({ role, uid, displayName = '' }) {
  const normalizedRole = role === 'courier' ? 'courier' : 'client';
  const roleLabel = normalizedRole === 'courier' ? 'المندوب' : 'العميل';
  const targetLabel = String(displayName || uid || '').trim() || uid;

  return new Promise((resolve) => {
    if (window.confirmAction) {
      window.confirmAction({
        title: `حذف ${roleLabel} نهائياً`,
        message: `هل تريد حذف ${roleLabel} <b>${escapeHtml(targetLabel)}</b> بشكل نهائي؟<br><small>لن يتم الحذف إذا كانت هناك طلبات نشطة مرتبطة بالحساب.</small>`,
        confirmText: 'نعم، احذف',
        danger: true,
        onConfirm: async () => {
          try {
            await deleteManagedUserAccount({ role: normalizedRole, uid });
            if (window.showToast) window.showToast(`تم حذف ${roleLabel} بنجاح.`, 'success');
            if (normalizedRole === 'courier' && courierDetailsPanel) {
              courierDetailsPanel.innerHTML = '<span class="muted">تم حذف حساب المندوب.</span>';
            }
            if (normalizedRole === 'client' && clientDetailsPanel) {
              clientDetailsPanel.innerHTML = '<span class="muted">تم حذف حساب العميل.</span>';
            }
          } catch (err) {
            if (window.showToast) window.showToast(`تعذر حذف ${roleLabel}: ${err.message || err}`, 'error');
          }
          resolve();
        },
      });
    } else {
      const confirmation = window.prompt(
        `لحذف ${roleLabel} ${targetLabel} نهائيًا اكتب كلمة حذف. لن يتم الحذف إذا كانت هناك طلبات نشطة مرتبطة بالحساب.`,
        ''
      );
      if (confirmation == null) { resolve(); return; }
      if (confirmation.trim() !== 'حذف') { alert('تم إلغاء الحذف لأن كلمة التأكيد غير صحيحة.'); resolve(); return; }
      deleteManagedUserAccount({ role: normalizedRole, uid })
        .then(() => {
          alert(`تم حذف ${roleLabel} بنجاح.`);
          if (normalizedRole === 'courier' && courierDetailsPanel) courierDetailsPanel.innerHTML = '<span class="muted">تم حذف حساب المندوب.</span>';
          if (normalizedRole === 'client' && clientDetailsPanel) clientDetailsPanel.innerHTML = '<span class="muted">تم حذف حساب العميل.</span>';
          resolve();
        })
        .catch((err) => { alert(`تعذر حذف ${roleLabel}: ${err.message || err}`); resolve(); });
    }
  });
}

function renderClientsDirectoryTable(filterText = '') {
  if (!clientsTable) return;
  const q = filterText.trim().toLowerCase();
  const filtered = q
    ? clientDirectoryCache.filter((item) => {
        const d = item.data || {};
        return [d.name, d.displayName, d.phone, d.email].some((v) => String(v || '').toLowerCase().includes(q));
      })
    : clientDirectoryCache;

  const countEl = document.getElementById('clientSearchCount');
  if (countEl) countEl.textContent = q ? `${filtered.length} من ${clientDirectoryCache.length}` : `${clientDirectoryCache.length} عميل`;

  const rows = filtered.slice(0, 80).map((item) => {
    const data = item.data || {};
    return `<tr>
      <td>${escapeHtml(String(data.name || data.displayName || item.id || '-'))}</td>
      <td>${escapeHtml(String(data.phone || '-'))}</td>
      <td>${escapeHtml(String(data.email || '-'))}</td>
      <td>${Number(data.walletBalance || 0).toLocaleString('ar-EG')} ج.س</td>
      <td>${escapeHtml(String(data.defaultAddressText || data.address || '-'))}</td>
      <td>
        <button class="btn ghost" data-view-client="${escapeHtml(item.id)}">تفاصيل</button>
        <button class="btn danger" data-delete-client="${escapeHtml(item.id)}">حذف</button>
      </td>
    </tr>`;
  });

  setHtml(clientsTable, table(['العميل', 'الهاتف', 'البريد', 'المحفظة', 'آخر عنوان', 'إجراء'], rows));

  clientsTable.querySelectorAll('[data-view-client]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const uid = btn.getAttribute('data-view-client');
      if (!uid) return;
      await loadClientDetails(uid);
    });
  });

  clientsTable.querySelectorAll('[data-delete-client]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const uid = btn.getAttribute('data-delete-client');
      if (!uid) return;
      const item = clientDirectoryCache.find((entry) => entry.id === uid);
      await handleManagedUserDeletion({
        role: 'client',
        uid,
        displayName: item?.data?.name || item?.data?.displayName || uid,
      });
    });
  });

  if (clientDirectoryCache.length && clientDetailsPanel?.classList.contains('muted')) {
    loadClientDetails(clientDirectoryCache[0].id);
  }
}

async function loadClientDetails(clientId) {
  if (!clientDetailsPanel) return;
  clientDetailsPanel.innerHTML = '<span class="muted">جاري تحميل تفاصيل العميل...</span>';

  try {
    const clientRef = doc(db, 'clients', clientId);
    const clientSnap = await getDoc(clientRef);
    if (!clientSnap.exists()) {
      clientDetailsPanel.innerHTML = '<span class="muted">لم يتم العثور على بيانات العميل.</span>';
      return;
    }

    const client = clientSnap.data() || {};
    const ordersSnap = await safeGetDocs(query(collection(db, 'orders'), where('clientId', '==', clientId)));
    const orders = ordersSnap.docs.map((d) => d.data() || {});
    const activeOrderStatuses = new Set(['pending', 'store_pending', 'courier_searching', 'courier_offer_pending', 'courier_assigned', 'pickup_ready', 'picked_up', 'arrived_to_client']);
    const activeOrdersCount = orders.filter((order) => activeOrderStatuses.has(String(order.orderStatus || order.status || '').trim().toLowerCase())).length;

    let defaultAddressName = String(client.defaultAddressText || client.address || '-');
    const defaultAddressId = String(client.defaultAddressId || '').trim();
    if (defaultAddressId) {
      const addressSnap = await getDoc(doc(db, 'clients', clientId, 'addresses', defaultAddressId));
      if (addressSnap.exists()) {
        defaultAddressName = String(addressSnap.data()?.addressName || defaultAddressName || '-');
      }
    }

    clientDetailsPanel.classList.remove('muted');
    clientDetailsPanel.innerHTML = `
      <div class="entity-details-panel">
        <div class="entity-hero">
          <div>
            <span class="entity-role-badge">العملاء</span>
            <h4>تفاصيل العميل</h4>
            <p>عرض موجز ومنظم للحساب مع مساحة تعديل سريعة دون تشتيت.</p>
          </div>
          <div class="entity-hero-side">
            <span class="entity-mini-label">${escapeHtml(clientId)}</span>
          </div>
        </div>
        ${buildEntitySection('البيانات الأساسية', buildEntityFactsGrid([
          { label: 'المعرف', value: clientId },
          { label: 'الاسم', value: client.name || client.displayName || '-' },
          { label: 'البريد', value: client.email || '-' },
          { label: 'الهاتف', value: client.phone || '-' },
          { label: 'الرصيد', value: `${Number(client.walletBalance || client.wallet || 0).toLocaleString('ar-EG')} ج.س`, className: 'entity-fact-highlight' },
          { label: 'العنوان الافتراضي', value: defaultAddressName || '-' },
        ]), { eyebrow: 'الملف' })}
        ${buildEntitySection('مؤشرات سريعة', buildEntityFactsGrid([
          { label: 'إجمالي الطلبات', value: orders.length },
          { label: 'الطلبات النشطة', value: activeOrdersCount },
        ]), { eyebrow: 'النشاط' })}
        ${buildEntitySection('تعديل بيانات العميل', `
          <div class="entity-form-grid">
            <label>الاسم<input id="clientName-${clientId}" type="text" value="${escapeHtml(client.name || client.displayName || '')}" /></label>
            <label>الهاتف<input id="clientPhone-${clientId}" type="text" value="${escapeHtml(client.phone || '')}" /></label>
            <label>البريد الإلكتروني<input id="clientEmail-${clientId}" type="email" value="${escapeHtml(client.email || '')}" /></label>
            <label>العنوان الافتراضي<input id="clientAddress-${clientId}" type="text" value="${escapeHtml(defaultAddressName === '-' ? '' : defaultAddressName)}" /></label>
          </div>
          <div class="entity-actions">
            <button class="btn primary" id="clientSave-${clientId}">حفظ التعديلات</button>
            <button class="btn danger" id="clientDelete-${clientId}">حذف الحساب</button>
          </div>
        `, { eyebrow: 'التحرير' })}
      </div>
    `;

    document.getElementById(`clientSave-${clientId}`)?.addEventListener('click', async () => {
      try {
        await updateManagedUserProfile({
          role: 'client',
          uid: clientId,
          fields: {
            name: (document.getElementById(`clientName-${clientId}`)?.value || '').trim(),
            phone: (document.getElementById(`clientPhone-${clientId}`)?.value || '').trim(),
            email: (document.getElementById(`clientEmail-${clientId}`)?.value || '').trim(),
            address: (document.getElementById(`clientAddress-${clientId}`)?.value || '').trim(),
          },
        });
        alert('تم حفظ بيانات العميل بنجاح');
        await loadClientDetails(clientId);
      } catch (err) {
        alert(`تعذر حفظ بيانات العميل: ${err.message || err}`);
      }
    });

    document.getElementById(`clientDelete-${clientId}`)?.addEventListener('click', async () => {
      await handleManagedUserDeletion({
        role: 'client',
        uid: clientId,
        displayName: client.name || client.displayName || clientId,
      });
    });
  } catch (err) {
    clientDetailsPanel.innerHTML = `<span class="muted">تعذر تحميل التفاصيل: ${escapeHtml(err.message || err)}</span>`;
  }
}

function getFilteredOperationsOrders() {
  const filter = String(orderStatusFilter?.value || 'active').trim().toLowerCase();
  const queryText = String(orderSearchInput?.value || '').trim().toLowerCase();

  return operationsOrderDocsCache
    .filter((item) => {
      const data = item.data || {};
      const status = getOrderLifecycleStatus(data);
      const bucket = getOperationsOrderBucket(data);

      if (filter === 'active' && !isActiveOrderStatus(status)) return false;
      if (filter === 'review' && bucket !== 'review') return false;
      if (filter === 'cancelled' && bucket !== 'cancelled') return false;
      if (filter === 'courier' && !(data.assignedDriverId || data.offeredDriverId)) return false;

      if (!queryText) return true;
      const haystack = [
        item.id,
        data.orderNumber,
        data.orderId,
        data.clientName,
        data.clientPhone,
        data.restaurantName,
        data.restaurantId,
        data.assignedDriverId,
        data.offeredDriverId,
      ].join(' ').toLowerCase();
      return haystack.includes(queryText);
    })
    .sort((a, b) => (b.createdAtMillis || 0) - (a.createdAtMillis || 0));
}

async function executeAdminOrderAction(orderId, action) {
  const orderEntry = operationsOrderDocsCache.find((item) => item.id === orderId);
  const order = orderEntry?.data || {};
  if (!orderId || !orderEntry) return;

  const note = String(prompt('ملاحظة إدارية داخلية (اختياري):', '') || '').trim();
  const payload = { orderId, action, note };

  if (action === 'assign_specific') {
    const driverId = String(document.getElementById(`orderAssignDriver-${orderId}`)?.value || '').trim();
    if (!driverId) {
      alert('اختر مندوبًا أولاً.');
      return;
    }
    payload.driverId = driverId;
  }

  if (action === 'cancel' && !confirm(`تأكيد إلغاء الطلب ${formatUnifiedOrderCode(order.orderNumber, order.orderId, orderId)}؟`)) {
    return;
  }

  try {
    await adminManageOrder(payload);
    alert('تم تنفيذ الإجراء بنجاح.');
    renderOperationsOrderDetails(orderId);
  } catch (err) {
    alert(`تعذر تنفيذ الإجراء: ${err.message || err}`);
  }
}

function renderOperationsOrderDetails(orderId) {
  if (!operationsOrderDetails) return;
  const entry = operationsOrderDocsCache.find((item) => item.id === orderId);
  if (!entry) {
    operationsOrderDetails.innerHTML = '<span class="muted">لم يتم العثور على الطلب المحدد.</span>';
    return;
  }

  const data = entry.data || {};
  const timeline = getOrderTimelineEntries(data);
  const availableCouriers = courierDirectoryCache.filter((item) => {
    const courier = item.data || {};
    return courier.isApproved === true || String(courier.approvalStatus || '').trim().toLowerCase() === 'approved';
  });

  operationsOrderDetails.classList.remove('muted');
  operationsOrderDetails.innerHTML = `
    <div class="order-detail-shell">
      <div class="order-detail-head">
        <div>
          <h4 style="margin:0 0 8px">${escapeHtml(formatUnifiedOrderCode(data.orderNumber, data.orderId, orderId))}</h4>
          <div><span class="kv"><b>الحالة:</b> ${escapeHtml(formatOrderStatusLabel(data.orderStatus || data.status || '-'))}</span><span class="kv"><b>الدفع:</b> ${escapeHtml(data.paymentStatus || '-')}</span></div>
        </div>
        <div class="order-actions-row">
          <button class="btn danger" data-admin-order-action="cancel" data-order-id="${escapeHtml(orderId)}">إلغاء الطلب</button>
          <button class="btn ghost" data-admin-order-action="unassign_courier" data-order-id="${escapeHtml(orderId)}">سحب المندوب</button>
          <button class="btn ghost" data-admin-order-action="reassign_auto" data-order-id="${escapeHtml(orderId)}">إعادة إسناد تلقائي</button>
          <button class="btn primary" data-open-order-map="${escapeHtml(orderId)}">الخريطة</button>
        </div>
      </div>
      <div class="order-detail-grid">
        <div class="order-detail-card"><strong>العميل</strong>${resolveClientDisplay(data.clientId, data.clientName)}<br />${escapeHtml(data.clientPhone || '-')}</div>
        <div class="order-detail-card"><strong>المتجر</strong>${resolveRestaurantDisplay(data.restaurantId, data.restaurantName)}</div>
        <div class="order-detail-card"><strong>المندوب الحالي</strong>${resolveDriverDisplay(data.assignedDriverId || data.offeredDriverId, data.assignedDriverName || '')}</div>
        <div class="order-detail-card"><strong>العنوان</strong>${escapeHtml(data.deliveryAddress || data.address || '-')}</div>
      </div>
      <div class="order-actions-row">
        <select id="orderAssignDriver-${escapeHtml(orderId)}">
          <option value="">اختر مندوبًا للتحويل اليدوي</option>
          ${availableCouriers.map((item) => `<option value="${escapeHtml(item.id)}">${escapeHtml(String(item.data?.name || item.id))}</option>`).join('')}
        </select>
        <button class="btn primary" data-admin-order-action="assign_specific" data-order-id="${escapeHtml(orderId)}">تحويل إلى المندوب المحدد</button>
        <button class="btn ghost" data-open-store-from-order="${escapeHtml(String(data.restaurantId || ''))}">فتح المتجر</button>
        <button class="btn ghost" data-open-courier-from-order="${escapeHtml(String(data.assignedDriverId || data.offeredDriverId || ''))}">فتح المندوب</button>
        <button class="btn ghost" data-open-client-from-order="${escapeHtml(String(data.clientId || ''))}">فتح العميل</button>
      </div>
      <div class="order-detail-grid">
        <div class="order-detail-card">
          <strong>التسلسل الزمني</strong>
          <div class="order-timeline">
            ${timeline.length ? timeline.map((item) => `<div class="order-timeline-item"><b>${escapeHtml(item.label)}</b><span>${escapeHtml(formatDateTimeLabel(item.millis))}</span></div>`).join('') : '<div class="muted">لا توجد نقاط زمنية كافية لهذا الطلب.</div>'}
          </div>
        </div>
        <div class="order-detail-card">
          <strong>العناصر</strong>
          ${renderOrderItemsRows(data.items)}
        </div>
      </div>
    </div>
  `;

  operationsOrderDetails.querySelectorAll('[data-admin-order-action]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const action = btn.getAttribute('data-admin-order-action');
      const targetOrderId = btn.getAttribute('data-order-id');
      if (!action || !targetOrderId) return;
      await executeAdminOrderAction(targetOrderId, action);
    });
  });

  operationsOrderDetails.querySelector('[data-open-order-map]')?.addEventListener('click', () => {
    openOrderOnMap(orderId, { allowCompleted: true });
  });

  operationsOrderDetails.querySelector('[data-open-store-from-order]')?.addEventListener('click', async () => {
    const storeId = String(data.restaurantId || '').trim();
    if (!storeId) return;
    activateTab('management');
    activateSubpanel('management', 'management-stores');
    await loadStoreDetails(storeId);
    document.getElementById('storeDetailsPanel')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });

  operationsOrderDetails.querySelector('[data-open-courier-from-order]')?.addEventListener('click', async () => {
    const driverId = String(data.assignedDriverId || data.offeredDriverId || '').trim();
    if (!driverId) return;
    activateTab('management');
    activateSubpanel('management', 'management-couriers');
    await loadCourierDetails(driverId);
    document.getElementById('courierDetailsPanel')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });

  operationsOrderDetails.querySelector('[data-open-client-from-order]')?.addEventListener('click', async () => {
    const clientId = String(data.clientId || '').trim();
    if (!clientId) return;
    openOrdersWorkspace(orderId);
    await loadClientDetails(clientId);
    document.getElementById('clientDetailsPanel')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });
}

function renderOperationsOrders() {
  if (!operationsOrdersTable) return;
  const filtered = getFilteredOperationsOrders();
  const activeCount = operationsOrderDocsCache.filter((item) => isActiveOrderStatus(getOrderLifecycleStatus(item.data || {}))).length;
  const reviewCount = operationsOrderDocsCache.filter((item) => getOperationsOrderBucket(item.data || {}) === 'review').length;
  const cancelledCount = operationsOrderDocsCache.filter((item) => getOperationsOrderBucket(item.data || {}) === 'cancelled').length;
  opsCenterState.activeOrders = activeCount;
  renderOpsPriorityCards();

  const currentFilter = String(orderStatusFilter?.value || 'active').trim().toLowerCase();
  ordersSegmentButtons.forEach((button) => {
    button.classList.toggle('active', String(button.getAttribute('data-orders-segment') || '').trim().toLowerCase() === currentFilter);
  });

  if (operationsOrderSummary) {
    operationsOrderSummary.innerHTML = `
      <div>إجمالي الطلبات المعروضة الآن: <b>${filtered.length}</b> | العملاء في الذاكرة: <b>${clientDirectoryCache.length}</b></div>
      <div class="orders-summary-stats">
        <div class="orders-summary-stat"><strong>نشطة</strong><b>${activeCount}</b></div>
        <div class="orders-summary-stat"><strong>قيد المراجعة</strong><b>${reviewCount}</b></div>
        <div class="orders-summary-stat"><strong>ملغاة</strong><b>${cancelledCount}</b></div>
        <div class="orders-summary-stat"><strong>المعروضة الآن</strong><b>${filtered.length}</b></div>
      </div>
    `;
  }

  const rows = filtered.slice(0, 150).map((item) => {
    const data = item.data || {};
    const bucket = getOperationsOrderBucket(data);
    const bucketLabel = bucket === 'review' ? 'مراجعة' : bucket === 'cancelled' ? 'ملغى' : bucket === 'active' ? 'نشط' : 'أخرى';
    return `<tr>
      <td>${escapeHtml(formatUnifiedOrderCode(data.orderNumber, data.orderId, item.id))}</td>
      <td>${resolveClientDisplay(data.clientId, data.clientName)}</td>
      <td>${resolveRestaurantDisplay(data.restaurantId, data.restaurantName)}</td>
      <td>${resolveDriverDisplay(data.assignedDriverId || data.offeredDriverId, data.assignedDriverName || '')}</td>
      <td>${escapeHtml(formatOrderStatusLabel(data.orderStatus || data.status || '-'))}</td>
      <td>${escapeHtml(String(data.paymentStatus || '-'))}</td>
      <td>${escapeHtml(bucketLabel)}<br /><span class="muted">${escapeHtml(formatDateTimeLabel(data.updatedAt || data.createdAt))}</span></td>
      <td><button class="btn ghost" data-operations-order="${escapeHtml(item.id)}">تفاصيل وتحكم</button></td>
    </tr>`;
  });

  setHtml(operationsOrdersTable, table(['الطلب', 'العميل', 'المتجر', 'المندوب', 'الحالة', 'الدفع', 'التصنيف', 'إجراء'], rows));
  operationsOrdersTable.querySelectorAll('[data-operations-order]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const orderId = btn.getAttribute('data-operations-order');
      if (!orderId) return;
      renderOperationsOrderDetails(orderId);
    });
  });

  if (filtered.length && operationsOrderDetails?.classList.contains('muted')) {
    renderOperationsOrderDetails(filtered[0].id);
  }
}

function buildCourierActivityRows(drivers = [], orders = []) {
  const nowMs = Date.now();
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const monthStart = new Date(todayStart.getFullYear(), todayStart.getMonth(), 1);
  const maxOrderActivityMs = 6 * 60 * 60 * 1000;
  const driverMap = new Map();

  drivers.forEach((entry) => {
    driverMap.set(entry.id, {
      id: entry.id,
      name: String(entry.data?.name || entry.id),
      phone: String(entry.data?.phone || entry.data?.mobile || '-'),
      approvalStatus: String(entry.data?.approvalStatus || (entry.data?.isApproved ? 'approved' : 'pending')),
      available: entry.data?.available === true,
      lastSeenMs: getCourierLastActivityMillis(entry.data || {}),
      todayMs: getCourierAvailableTodayMs(entry.data || {}, nowMs),
      monthMs: 0,
      todayOrders: 0,
      monthOrders: 0,
      activeOrders: 0,
    });
  });

  orders.forEach((entry) => {
    const order = entry.data || {};
    const driverId = String(order.assignedDriverId || '').trim();
    if (!driverId) return;

    const status = getOrderLifecycleStatus(order);
    if (!isActiveOrderStatus(status) && !isDeliveredOrderStatus(status)) return;

    const startMs = getCourierOrderActivityStartMillis(order);
    const endMs = getCourierOrderActivityEndMillis(order, nowMs);
    if (!startMs || !endMs || endMs <= startMs) return;

    const boundedEndMs = Math.min(endMs, startMs + maxOrderActivityMs);
    if (boundedEndMs <= startMs) return;

    const todayMs = getOverlappingDurationMs(startMs, boundedEndMs, todayStart.getTime(), nowMs);
    const monthMs = getOverlappingDurationMs(startMs, boundedEndMs, monthStart.getTime(), nowMs);
    const existing = driverMap.get(driverId) || {
      id: driverId,
      name: driverId,
      phone: '-',
      approvalStatus: 'غير معروف',
      available: false,
      lastSeenMs: 0,
      todayMs: 0,
      monthMs: 0,
      todayOrders: 0,
      monthOrders: 0,
      activeOrders: 0,
    };

    existing.monthMs += monthMs;
    if (todayMs > 0) existing.todayOrders += 1;
    if (monthMs > 0) existing.monthOrders += 1;
    if (isActiveOrderStatus(status)) existing.activeOrders += 1;
    driverMap.set(driverId, existing);
  });

  return Array.from(driverMap.values())
    .filter((item) => item.approvalStatus === 'approved' || item.todayMs > 0 || item.monthMs > 0 || item.activeOrders > 0)
    .sort((a, b) => {
      if (b.todayMs !== a.todayMs) return b.todayMs - a.todayMs;
      if (b.monthMs !== a.monthMs) return b.monthMs - a.monthMs;
      return String(a.name).localeCompare(String(b.name), 'ar');
    });
}

function renderCourierActivityReport() {
  if (!courierActivitySummary || !courierActivityTable) return;

  const rowsData = buildCourierActivityRows(courierDirectoryCache, operationsOrderDocsCache);
  const totalTodayMs = rowsData.reduce((sum, item) => sum + item.todayMs, 0);
  const totalMonthMs = rowsData.reduce((sum, item) => sum + item.monthMs, 0);
  const activeTodayCount = rowsData.filter((item) => item.todayMs > 0 || item.activeOrders > 0).length;

  courierActivitySummary.classList.remove('muted');
  courierActivitySummary.innerHTML = `
    <div class="stats">
      <div class="stat"><h4>إجمالي المندوبين</h4><b>${rowsData.length.toLocaleString('ar-EG')}</b></div>
      <div class="stat"><h4>نشطون اليوم</h4><b>${activeTodayCount.toLocaleString('ar-EG')}</b></div>
      <div class="stat"><h4>وقت التوفر اليوم</h4><b>${formatDurationHours(totalTodayMs)}</b></div>
      <div class="stat"><h4>ساعات الشهر</h4><b>${formatDurationHours(totalMonthMs)}</b></div>
    </div>
    <div style="margin-top:10px;">وقت اليوم هنا مبني على وقت التوفر الفعلي للمندوب. أما الشهر فيبقى تقديريًا من مدد الطلبات إلى أن نضيف سجل توفر شهري تراكمي.</div>
  `;

  if (!rowsData.length) {
    setHtml(courierActivityTable, '<p class="muted">لا توجد بيانات نشاط كافية لعرض التقرير حاليًا.</p>');
    return;
  }

  const rows = rowsData.slice(0, 150).map((item) => `
    <tr>
      <td>${escapeHtml(item.name)}</td>
      <td>${escapeHtml(item.phone)}</td>
      <td>${item.available ? 'متاح الآن' : 'غير متاح'}</td>
      <td>${formatDurationHours(item.todayMs)}</td>
      <td>${item.todayOrders.toLocaleString('ar-EG')}</td>
      <td>${formatDurationHours(item.monthMs)}</td>
      <td>${item.monthOrders.toLocaleString('ar-EG')}</td>
      <td>${item.activeOrders.toLocaleString('ar-EG')}</td>
      <td>${escapeHtml(formatDateTimeLabel(item.lastSeenMs))}</td>
      <td><button class="btn ghost" data-open-activity-driver="${escapeHtml(item.id)}">فتح المندوب</button></td>
    </tr>
  `);

  setHtml(courierActivityTable, table(['المندوب', 'الهاتف', 'الحالة الحالية', 'وقت التوفر اليوم', 'طلبات اليوم', 'نشاط الشهر', 'طلبات الشهر', 'طلبات نشطة', 'آخر ظهور', 'إجراء'], rows));
  courierActivityTable.querySelectorAll('[data-open-activity-driver]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const driverId = btn.getAttribute('data-open-activity-driver');
      if (!driverId) return;
      activateTab('management');
      activateSubpanel('management', 'management-couriers');
      await loadCourierDetails(driverId);
      document.getElementById('courierDetailsPanel')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  });
}

function mountManagement() {
  if (!operationsOrdersBound) {
    orderStatusFilter?.addEventListener('change', () => renderOperationsOrders());
    orderSearchInput?.addEventListener('input', () => renderOperationsOrders());
    operationsOrdersBound = true;
  }

  // Skeletons while waiting for Firestore data
  if (restaurantsTable) setHtml(restaurantsTable, skeletonTable(['المتجر', 'الحالة', 'حالة القائمة', 'إجراء']));
  if (couriersTable) setHtml(couriersTable, skeletonTable(['المندوب', 'الحالة', 'المركبة', 'إجراء']));

  unsubscribers.push(
    onSnapshot(query(collection(db, 'restaurants'), where('approvalStatus', '==', 'approved')), (snap) => {
      // Populate restaurants cache for name resolution across all tables
      snap.docs.forEach((d) => restaurantsDirectoryCache.set(d.id, d.data() || {}));

      const rows = snap.docs
        .slice(0, 50)
        .map((d) => {
        const data = d.data() || {};
        const closed = data.temporarilyClosed === true;
        const menuApproved = data.menuApproved !== false;
        return `<tr>
          <td>${data.name || d.id}</td>
          <td><span class="badge ${closed ? 'open' : 'closed'}">${closed ? 'مغلق مؤقتًا' : 'مفتوح'}</span></td>
          <td><span class="badge ${menuApproved ? 'closed' : 'open'}">${menuApproved ? 'القائمة معتمدة' : 'القائمة غير معتمدة'}</span></td>
          <td>
            <button class="btn ghost" data-view-store="${d.id}">تفاصيل</button>
            <button class="btn ghost" data-toggle-store="${d.id}">${closed ? 'فتح' : 'إغلاق مؤقت'}</button>
            <button class="btn ghost" data-direct-menu-approve="${d.id}">${menuApproved ? 'إعادة اعتماد القائمة' : 'اعتماد القائمة مباشرة'}</button>
            <button class="btn danger" data-direct-menu-reject="${d.id}">سحب اعتماد القائمة</button>
          </td>
        </tr>`;
        });
      setHtml(restaurantsTable, table(['المتجر', 'الحالة', 'حالة القائمة', 'إجراء'], rows));
      restaurantsTable.querySelectorAll('[data-view-store]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const id = btn.getAttribute('data-view-store');
          await loadStoreDetails(id);
        });
      });
      restaurantsTable.querySelectorAll('[data-toggle-store]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const id = btn.getAttribute('data-toggle-store');
          const ref = doc(db, 'restaurants', id);
          const snapDoc = await getDoc(ref);
          const current = snapDoc.data()?.temporarilyClosed === true;
          await updateDoc(ref, {
            temporarilyClosed: !current,
            updatedAt: serverTimestamp()
          });
        });
      });
      restaurantsTable.querySelectorAll('[data-direct-menu-approve]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const id = btn.getAttribute('data-direct-menu-approve');
          if (!id) return;
          await setMenuApprovalDirect({ restaurantId: id, approved: true });
        });
      });
      restaurantsTable.querySelectorAll('[data-direct-menu-reject]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const id = btn.getAttribute('data-direct-menu-reject');
          if (!id) return;
          await setMenuApprovalDirect({ restaurantId: id, approved: false });
        });
      });
    })
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'drivers'), (snap) => {
      courierDirectoryCache = snap.docs.map((d) => ({ id: d.id, data: d.data() || {} }));
      const rows = snap.docs.slice(0, 50).map((d) => {
        const data = d.data();
        const status = formatApprovalStatusLabel(data.approvalStatus || (data.isApproved ? 'approved' : 'pending'));
        const available = data.available === true;
        return `<tr>
          <td>${data.name || d.id}</td>
          <td>${status}</td>
          <td>${available ? 'متاح' : 'غير متاح'}</td>
          <td>
            <button class="btn ghost" data-view-driver="${d.id}">تفاصيل</button>
            <button class="btn ghost" data-approve-driver="${d.id}">قبول</button>
            <button class="btn danger" data-reject-driver="${d.id}">رفض</button>
            <button class="btn danger" data-delete-driver="${d.id}">حذف</button>
          </td>
        </tr>`;
      });
      setHtml(couriersTable, table(['المندوب', 'حالة الموافقة', 'التوفر', 'إجراء'], rows));

      couriersTable.querySelectorAll('[data-view-driver]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const id = btn.getAttribute('data-view-driver');
          await loadCourierDetails(id);
        });
      });

      couriersTable.querySelectorAll('[data-approve-driver]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.getAttribute('data-approve-driver');
          withBtnLoading(btn, () => updateDoc(doc(db, 'drivers', id), {
            approvalStatus: 'approved',
            isApproved: true,
            updatedAt: serverTimestamp()
          }));
        });
      });

      couriersTable.querySelectorAll('[data-reject-driver]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.getAttribute('data-reject-driver');
          withBtnLoading(btn, async () => {
            await updateDoc(doc(db, 'drivers', id), {
              ...(await buildDriverAvailabilityPatch(id, false)),
              approvalStatus: 'rejected',
              isApproved: false,
              updatedAt: serverTimestamp()
            });
          });
        });
      });

      couriersTable.querySelectorAll('[data-delete-driver]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const uid = btn.getAttribute('data-delete-driver');
          if (!uid) return;
          const item = courierDirectoryCache.find((entry) => entry.id === uid);
          await handleManagedUserDeletion({
            role: 'courier',
            uid,
            displayName: item?.data?.name || uid,
          });
        });
      });

      bindCourierSearchInput();

      renderCourierActivityReport();
      renderOperationsOrders();
    })
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'orders'), (snap) => {
      operationsOrderDocsCache = snap.docs.map((d) => ({
        id: d.id,
        data: d.data() || {},
        createdAtMillis: d.data()?.createdAt?.toMillis?.() || d.data()?.updatedAt?.toMillis?.() || 0,
      }));
      renderCourierActivityReport();
      renderOperationsOrders();
    })
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'clients'), (snap) => {
      clientDirectoryCache = snap.docs
        .map((d) => ({ id: d.id, data: d.data() || {} }))
        .sort((a, b) => {
          const at = a.data?.updatedAt?.toMillis?.() || a.data?.createdAt?.toMillis?.() || 0;
          const bt = b.data?.updatedAt?.toMillis?.() || b.data?.createdAt?.toMillis?.() || 0;
          return bt - at;
        });
      renderClientsDirectoryTable();
      renderOperationsOrders();

      // Wire client search input (once)
      const clientSearchInput = document.getElementById('clientSearchInput');
      if (clientSearchInput && !clientSearchInput.dataset.bound) {
        clientSearchInput.dataset.bound = '1';
        clientSearchInput.addEventListener('input', () => renderClientsDirectoryTable(clientSearchInput.value));
      }
    })
  );
}

// Wire courier search input (after couriers table is populated)
function bindCourierSearchInput() {
  const courierSearchInput = document.getElementById('courierSearchInput');
  if (!courierSearchInput || courierSearchInput.dataset.bound) return;
  courierSearchInput.dataset.bound = '1';
  courierSearchInput.addEventListener('input', () => {
    const q = courierSearchInput.value.trim().toLowerCase();
    const countEl = document.getElementById('courierSearchCount');
    const rows = couriersTable?.querySelectorAll('tbody tr') || [];
    let visible = 0;
    rows.forEach((row) => {
      const match = !q || row.textContent.toLowerCase().includes(q);
      row.style.display = match ? '' : 'none';
      if (match) visible++;
    });
    if (countEl) countEl.textContent = q ? `${visible} من ${rows.length}` : `${rows.length} مندوب`;
  });
}

async function loadCourierDetails(driverId) {
  if (!courierDetailsPanel) return;
  courierDetailsPanel.innerHTML = '<span class="muted">جاري تحميل تفاصيل المندوب...</span>';

  try {
    const driverSnap = await getDoc(doc(db, 'drivers', driverId));
    if (!driverSnap.exists()) {
      courierDetailsPanel.innerHTML = '<span class="muted">لم يتم العثور على بيانات المندوب.</span>';
      return;
    }

    const driver = driverSnap.data() || {};
    const ordersSnap = await safeGetDocs(query(collection(db, 'orders'), where('assignedDriverId', '==', driverId)));
    const orders = ordersSnap.docs.map((d) => d.data() || {});
    const activeOrderStatuses = new Set(['courier_offer_pending', 'courier_assigned', 'pickup_ready', 'picked_up', 'arrived_to_client']);
    const activeOrdersCount = orders.filter((o) => activeOrderStatuses.has(String(o.orderStatus || o.status || ''))).length;
    const todayAvailabilityMs = getCourierAvailableTodayMs(driver);

    const idImage = driver.idImageUrl
      ? `<div class="entity-media-card"><a class="btn ghost" href="${escapeHtml(driver.idImageUrl)}" target="_blank" rel="noopener">فتح صورة الهوية/الرخصة</a></div>`
      : '<div class="entity-media-card muted">لا توجد صورة هوية/رخصة</div>';

    courierDetailsPanel.innerHTML = `
      <div class="entity-details-panel">
        <div class="entity-hero">
          <div>
            <span class="entity-role-badge entity-role-badge-courier">المندوبون</span>
            <h4>تفاصيل المندوب</h4>
            <p>حالة الحساب، التشغيل، البيانات الأساسية، والتحكم السريع في شاشة واحدة أوضح.</p>
          </div>
          <div class="entity-hero-side">
            <span class="entity-state-pill ${driver.available === true ? 'live' : 'idle'}">${driver.available === true ? 'متاح الآن' : 'غير متاح'}</span>
          </div>
        </div>
        ${buildEntitySection('الملف التشغيلي', buildEntityFactsGrid([
          { label: 'المعرف', value: driverId },
          { label: 'الاسم', value: driver.name || '-' },
          { label: 'البريد', value: driver.email || '-' },
          { label: 'الهاتف', value: driver.phone || '-' },
          { label: 'نوع المركبة', value: driver.vehicleType || '-' },
          { label: 'رقم اللوحة', value: driver.vehiclePlate || '-' },
          { label: 'رقم الهوية/الرخصة', value: driver.nationalIdNumber || '-' },
          { label: 'المنطقة', value: driver.region || '-' },
          { label: 'الموافقة', value: formatApprovalStatusLabel(driver.approvalStatus || (driver.isApproved ? 'approved' : 'pending')) },
          { label: 'التوفر', value: driver.available === true ? 'متاح' : 'غير متاح', className: driver.available === true ? 'entity-fact-highlight' : '' },
        ]), { eyebrow: 'الملف' })}
        ${buildBankAccountsDetailsMarkup(driver)}
        ${buildEntitySection('الأداء الحالي', buildEntityFactsGrid([
          { label: 'إجمالي الطلبات', value: orders.length },
          { label: 'الطلبات النشطة', value: activeOrdersCount },
          { label: 'وقت التوفر اليوم', value: formatDurationHours(todayAvailabilityMs), className: 'entity-fact-highlight' },
        ]), { eyebrow: 'النشاط' })}
        ${buildEntitySection('الهوية والمرفقات', `${idImage}<div class="entity-actions"><button class="btn ghost" id="driverImageChange-${driverId}">تعديل صورة الهوية/الرخصة</button><button class="btn ghost" id="driverToggleAvailability-${driverId}">${driver.available === true ? 'إيقاف التوفر' : 'تفعيل التوفر'}</button><button class="btn ghost" id="driverApprove-${driverId}">قبول</button><button class="btn danger" id="driverReject-${driverId}">رفض</button><button class="btn danger" id="driverDelete-${driverId}">حذف الحساب</button></div>`, { eyebrow: 'الإجراءات' })}
        ${buildEntitySection('تعديل بيانات المندوب', `
          <div class="entity-form-grid">
            <label>الاسم<input id="driverName-${driverId}" type="text" value="${escapeHtml(driver.name || '')}" /></label>
            <label>الهاتف<input id="driverPhone-${driverId}" type="text" value="${escapeHtml(driver.phone || '')}" /></label>
            <label>البريد الإلكتروني<input id="driverEmail-${driverId}" type="email" value="${escapeHtml(driver.email || '')}" /></label>
            <label>نوع المركبة<input id="driverVehicleType-${driverId}" type="text" value="${escapeHtml(driver.vehicleType || '')}" /></label>
            <label>رقم اللوحة<input id="driverVehiclePlate-${driverId}" type="text" value="${escapeHtml(driver.vehiclePlate || '')}" /></label>
            <label>رقم الهوية/الرخصة<input id="driverNationalId-${driverId}" type="text" value="${escapeHtml(driver.nationalIdNumber || '')}" /></label>
            <label>المنطقة<input id="driverRegion-${driverId}" type="text" value="${escapeHtml(driver.region || '')}" /></label>
            <label>رابط صورة الهوية/الرخصة<input id="driverIdImageUrl-${driverId}" type="text" value="${escapeHtml(driver.idImageUrl || '')}" /></label>
          </div>
          <div class="entity-actions">
            <button class="btn primary" id="driverSave-${driverId}">حفظ التعديلات</button>
          </div>
        `, { eyebrow: 'التحرير' })}
      </div>
    `;

    document.getElementById(`driverSave-${driverId}`)?.addEventListener('click', async () => {
      try {
        await updateManagedUserProfile({
          role: 'courier',
          uid: driverId,
          fields: {
            name: (document.getElementById(`driverName-${driverId}`)?.value || '').trim(),
            phone: (document.getElementById(`driverPhone-${driverId}`)?.value || '').trim(),
            email: (document.getElementById(`driverEmail-${driverId}`)?.value || '').trim(),
            vehicleType: (document.getElementById(`driverVehicleType-${driverId}`)?.value || '').trim(),
            vehiclePlate: (document.getElementById(`driverVehiclePlate-${driverId}`)?.value || '').trim(),
            nationalIdNumber: (document.getElementById(`driverNationalId-${driverId}`)?.value || '').trim(),
            region: (document.getElementById(`driverRegion-${driverId}`)?.value || '').trim(),
            idImageUrl: (document.getElementById(`driverIdImageUrl-${driverId}`)?.value || '').trim(),
          },
        });
        alert('تم حفظ بيانات المندوب بنجاح');
        await loadCourierDetails(driverId);
      } catch (err) {
        alert(`تعذر حفظ البيانات: ${err.message || err}`);
      }
    });

    document.getElementById(`driverToggleAvailability-${driverId}`)?.addEventListener('click', async () => {
      try {
        await updateDoc(doc(db, 'drivers', driverId), await buildDriverAvailabilityPatch(driverId, driver.available !== true));
        await loadCourierDetails(driverId);
      } catch (err) {
        alert(`تعذر تحديث التوفر: ${err.message || err}`);
      }
    });

    document.getElementById(`driverApprove-${driverId}`)?.addEventListener('click', async () => {
      try {
        await updateDoc(doc(db, 'drivers', driverId), {
          approvalStatus: 'approved',
          isApproved: true,
          updatedAt: serverTimestamp(),
        });
        await loadCourierDetails(driverId);
      } catch (err) {
        alert(`تعذر قبول المندوب: ${err.message || err}`);
      }
    });

    document.getElementById(`driverReject-${driverId}`)?.addEventListener('click', async () => {
      try {
        await updateDoc(doc(db, 'drivers', driverId), {
          ...(await buildDriverAvailabilityPatch(driverId, false)),
          approvalStatus: 'rejected',
          isApproved: false,
          updatedAt: serverTimestamp(),
        });
        await loadCourierDetails(driverId);
      } catch (err) {
        alert(`تعذر رفض المندوب: ${err.message || err}`);
      }
    });

    document.getElementById(`driverDelete-${driverId}`)?.addEventListener('click', async () => {
      await handleManagedUserDeletion({
        role: 'courier',
        uid: driverId,
        displayName: driver.name || driverId,
      });
    });

    document.getElementById(`driverImageChange-${driverId}`)?.addEventListener('click', async () => {
      const pickedFile = await pickSingleImageFile();
      if (!pickedFile) {
        alert('لم يتم اختيار صورة');
        return;
      }
      const uploaded = await uploadImageToCloudinary(pickedFile);
      if (!uploaded) {
        alert('تعذر رفع الصورة');
        return;
      }

      try {
        await updateDoc(doc(db, 'drivers', driverId), {
          idImageUrl: uploaded,
          updatedAt: serverTimestamp(),
        });
        await loadCourierDetails(driverId);
      } catch (err) {
        alert(`تعذر تحديث الصورة: ${err.message || err}`);
      }
    });
  } catch (err) {
    courierDetailsPanel.innerHTML = `<span class="muted">تعذر تحميل التفاصيل: ${escapeHtml(err.message || err)}</span>`;
  }
}

async function loadStoreDetails(storeId) {
  if (!storeDetailsPanel) return;
  storeDetailsPanel.innerHTML = '<span class="muted">جاري تحميل تفاصيل المتجر...</span>';

  try {
    const storeSnap = await getDoc(doc(db, 'restaurants', storeId));
    if (!storeSnap.exists()) {
      storeDetailsPanel.innerHTML = '<span class="muted">لم يتم العثور على بيانات المتجر.</span>';
      return;
    }

    const store = storeSnap.data() || {};
    const [ordersSnap, addressesSnap, menuDocsSnap, fullMenuDocsSnap] = await Promise.all([
      safeGetDocs(query(collection(db, 'orders'), where('restaurantId', '==', storeId))),
      safeGetDocs(collection(db, 'restaurants', storeId, 'addresses')),
      safeGetDocs(collection(db, 'restaurants', storeId, 'menu')),
      safeGetDocs(collection(db, 'restaurants', storeId, 'full_menu')),
    ]);

    const orders = ordersSnap.docs.map((d) => d.data() || {});
    const activeOrderStatuses = new Set(['store_pending', 'courier_searching', 'courier_offer_pending', 'courier_assigned', 'pickup_ready', 'picked_up', 'arrived_to_client']);
    const activeOrdersCount = orders.filter((o) => activeOrderStatuses.has(String(o.orderStatus || o.status || ''))).length;

    const image = store.commercialRecordImageUrl
      ? `<div style="margin-top:8px"><a class="btn ghost" href="${escapeHtml(store.commercialRecordImageUrl)}" target="_blank" rel="noopener">فتح صورة السجل</a></div>`
      : '';

    const storeOpenState = store.temporarilyClosed === true ? 'مغلق' : 'مفتوح';

    storeDetailsPanel.innerHTML = `
      <div class="entity-details-panel entity-details-panel-store">
        <div class="entity-hero">
          <div>
            <span class="entity-role-badge entity-role-badge-store">المتاجر</span>
            <h4>تفاصيل المتجر</h4>
            <p>مركز تشغيل موحد للبيانات الأساسية، الظهور، الدوام، والقائمة الكاملة.</p>
          </div>
          <div class="entity-hero-side">
            <span class="entity-state-pill ${store.temporarilyClosed === true ? 'idle' : 'live'}">${escapeHtml(storeOpenState)}</span>
          </div>
        </div>
        ${buildEntitySection('الملف التجاري', buildEntityFactsGrid([
          { label: 'المعرف', value: storeId },
          { label: 'الاسم', value: store.name || '-' },
          { label: 'البريد', value: store.email || '-' },
          { label: 'الهاتف', value: store.phone || '-' },
          { label: 'صاحب الحساب', value: store.ownerUid || '-' },
          { label: 'الحالة', value: formatApprovalStatusLabel(store.approvalStatus || (store.isApproved ? 'approved' : 'pending')) },
          { label: 'السجل التجاري', value: store.commercialRecordNumber || '-' },
          { label: 'القبول التلقائي', value: store.autoAcceptOrders === true ? 'مفعل' : 'غير مفعل' },
          { label: 'حالة الظهور', value: storeOpenState, className: store.temporarilyClosed === true ? '' : 'entity-fact-highlight' },
          { label: 'العنوان', value: store.address || '-' },
          { label: 'خصم التوصيل/المتجر', value: String(store.deliveryDiscountPercentage ?? '-') },
        ]), { eyebrow: 'الملف' })}
        ${buildBankAccountsDetailsMarkup(store)}
        ${buildEntitySection('مؤشرات المتجر', buildEntityFactsGrid([
          { label: 'إجمالي الطلبات', value: orders.length },
          { label: 'الطلبات النشطة', value: activeOrdersCount },
          { label: 'عدد العناوين', value: addressesSnap.docs.length },
          { label: 'أقسام المنيو', value: menuDocsSnap.docs.length },
          { label: 'عناصر full_menu', value: fullMenuDocsSnap.docs.length, className: 'entity-fact-highlight' },
        ]), { eyebrow: 'النشاط' })}
        ${buildEntitySection('الوثائق والميديا', `${image || '<div class="entity-media-card muted">لا توجد صورة سجل تجاري</div>'}`, { eyebrow: 'المرفقات' })}
        ${buildEntitySection('تعديل بيانات المتجر', `
          <div class="entity-form-grid">
            <label>الاسم<input id="storeName-${storeId}" type="text" value="${escapeHtml(store.name || '')}" /></label>
            <label>الهاتف<input id="storePhone-${storeId}" type="text" value="${escapeHtml(store.phone || '')}" /></label>
            <label>البريد الإلكتروني<input id="storeEmail-${storeId}" type="email" value="${escapeHtml(store.email || '')}" /></label>
            <label>السجل التجاري<input id="storeCommercialRecord-${storeId}" type="text" value="${escapeHtml(store.commercialRecordNumber || '')}" /></label>
            <label>العنوان<input id="storeAddress-${storeId}" type="text" value="${escapeHtml(store.address || '')}" /></label>
            <label>نسبة الخصم<input id="storeDiscountPct-${storeId}" type="number" step="0.01" value="${escapeHtml(String(store.deliveryDiscountPercentage ?? ''))}" /></label>
            <label>رابط صورة الغلاف<input id="storeCoverImageUrl-${storeId}" type="text" value="${escapeHtml(store.coverImageUrl || '')}" /></label>
            <label>رابط الشعار<input id="storeLogoImageUrl-${storeId}" type="text" value="${escapeHtml(store.logoImageUrl || '')}" /></label>
            <label>وقت التوصيل التقديري<input id="storeDeliveryTime-${storeId}" type="text" placeholder="مثال: 20-30 دقيقة" value="${escapeHtml(store.deliveryTime || '')}" /></label>
          </div>
          <div class="entity-actions">
            <button class="btn ghost" id="storeUploadCover-${storeId}">رفع صورة غلاف</button>
            <button class="btn ghost" id="storeUploadLogo-${storeId}">رفع شعار</button>
            <button class="btn primary" id="storeSaveProfile-${storeId}">حفظ بيانات المتجر</button>
          </div>
        `, { eyebrow: 'التحرير' })}
        ${buildEntitySection('الظهور والدوام', `
          <p class="entity-inline-note">استخدم هذه الأزرار إذا أردت جعل المتجر ظاهرًا كمفتوح دائمًا أو مغلقًا مباشرة، أو عدل جدول الدوام بشكل منظم.</p>
          <div class="entity-actions">
            <button class="btn primary" id="storeSetAlwaysOpen-${storeId}">دوام كامل</button>
            <button class="btn danger" id="storeSetClosed-${storeId}">مغلق</button>
          </div>
          <div class="entity-scheduler-block">
            ${buildWorkingHoursEditorMarkup(store.workingHours || {})}
          </div>
          <div class="entity-actions">
            <button class="btn primary" id="storeSaveWorkingHours-${storeId}">حفظ ساعات الدوام</button>
            <button class="btn ghost" id="storeOpenNow-${storeId}">فتح الآن</button>
          </div>
        `, { eyebrow: 'التشغيل', description: 'تعديل الدوام والظهور من نفس اللوحة بدون الرجوع لشاشات متفرقة.' })}
        ${buildEntitySection('إدارة القائمة الكاملة', `<div id="adminMenuManager-${storeId}"><span class="muted">جاري تحميل أصناف القائمة...</span></div>`, { eyebrow: 'المنيو' })}
      </div>
    `;

    document.getElementById(`storeUploadCover-${storeId}`)?.addEventListener('click', async () => {
      const pickedFile = await pickSingleImageFile();
      if (!pickedFile) return;
      const uploaded = await uploadImageToCloudinary(pickedFile);
      if (!uploaded) {
        alert('تعذر رفع صورة الغلاف');
        return;
      }
      const input = document.getElementById(`storeCoverImageUrl-${storeId}`);
      if (input) input.value = uploaded;
    });

    document.getElementById(`storeUploadLogo-${storeId}`)?.addEventListener('click', async () => {
      const pickedFile = await pickSingleImageFile();
      if (!pickedFile) return;
      const uploaded = await uploadImageToCloudinary(pickedFile);
      if (!uploaded) {
        alert('تعذر رفع الشعار');
        return;
      }
      const input = document.getElementById(`storeLogoImageUrl-${storeId}`);
      if (input) input.value = uploaded;
    });

    document.getElementById(`storeSaveProfile-${storeId}`)?.addEventListener('click', async () => {
      try {
        await updateManagedUserProfile({
          role: 'store',
          uid: storeId,
          fields: {
            name: (document.getElementById(`storeName-${storeId}`)?.value || '').trim(),
            phone: (document.getElementById(`storePhone-${storeId}`)?.value || '').trim(),
            email: (document.getElementById(`storeEmail-${storeId}`)?.value || '').trim(),
            commercialRecordNumber: (document.getElementById(`storeCommercialRecord-${storeId}`)?.value || '').trim(),
            address: (document.getElementById(`storeAddress-${storeId}`)?.value || '').trim(),
            deliveryDiscountPercentage: (document.getElementById(`storeDiscountPct-${storeId}`)?.value || '').trim(),
            coverImageUrl: (document.getElementById(`storeCoverImageUrl-${storeId}`)?.value || '').trim(),
            logoImageUrl: (document.getElementById(`storeLogoImageUrl-${storeId}`)?.value || '').trim(),
          },
        });
        const deliveryTimeVal = (document.getElementById(`storeDeliveryTime-${storeId}`)?.value || '').trim();
        await updateDoc(doc(db, 'restaurants', storeId), {
          deliveryTime: deliveryTimeVal,
          updatedAt: serverTimestamp(),
        });
        alert('تم حفظ بيانات المتجر بنجاح');
        await loadStoreDetails(storeId);
      } catch (err) {
        alert(`تعذر حفظ بيانات المتجر: ${err.message || err}`);
      }
    });

    document.getElementById(`storeSetAlwaysOpen-${storeId}`)?.addEventListener('click', async () => {
      try {
        const fullDayHours = {
          saturday: { status: 'مفتوح', open: '12:00 ص', close: '11:59 م' },
          sunday: { status: 'مفتوح', open: '12:00 ص', close: '11:59 م' },
          monday: { status: 'مفتوح', open: '12:00 ص', close: '11:59 م' },
          tuesday: { status: 'مفتوح', open: '12:00 ص', close: '11:59 م' },
          wednesday: { status: 'مفتوح', open: '12:00 ص', close: '11:59 م' },
          thursday: { status: 'مفتوح', open: '12:00 ص', close: '11:59 م' },
          friday: { status: 'مفتوح', open: '12:00 ص', close: '11:59 م' },
        };

        await updateDoc(doc(db, 'restaurants', storeId), {
          temporarilyClosed: false,
          workingHours: fullDayHours,
          updatedAt: serverTimestamp(),
        });
        alert('تم ضبط المتجر على دوام كامل.');
        await loadStoreDetails(storeId);
      } catch (err) {
        alert(`تعذر ضبط الدوام الكامل: ${err.message || err}`);
      }
    });

    document.getElementById(`storeSetClosed-${storeId}`)?.addEventListener('click', async () => {
      try {
        await updateDoc(doc(db, 'restaurants', storeId), {
          temporarilyClosed: true,
          updatedAt: serverTimestamp(),
        });
        alert('تم ضبط المتجر كمغلق.');
        await loadStoreDetails(storeId);
      } catch (err) {
        alert(`تعذر ضبط المتجر كمغلق: ${err.message || err}`);
      }
    });

    document.getElementById(`storeSaveWorkingHours-${storeId}`)?.addEventListener('click', async () => {
      try {
        await updateDoc(doc(db, 'restaurants', storeId), {
          temporarilyClosed: false,
          workingHours: collectWorkingHoursFromPanel(storeId),
          updatedAt: serverTimestamp(),
        });
        alert('تم حفظ ساعات الدوام بنجاح.');
        await loadStoreDetails(storeId);
      } catch (err) {
        alert(`تعذر حفظ ساعات الدوام: ${err.message || err}`);
      }
    });

    document.getElementById(`storeOpenNow-${storeId}`)?.addEventListener('click', async () => {
      try {
        await updateDoc(doc(db, 'restaurants', storeId), {
          temporarilyClosed: false,
          updatedAt: serverTimestamp(),
        });
        alert('تم فتح المتجر الآن دون تعديل جدول الدوام.');
        await loadStoreDetails(storeId);
      } catch (err) {
        alert(`تعذر فتح المتجر: ${err.message || err}`);
      }
    });

    await renderAdminMenuManager(storeId);
  } catch (err) {
    storeDetailsPanel.innerHTML = `<span class="muted">تعذر تحميل التفاصيل: ${escapeHtml(err.message || err)}</span>`;
  }
}

async function renderAdminMenuManager(storeId) {
  const container = document.getElementById(`adminMenuManager-${storeId}`);
  if (!container) return;

  const parsePositiveOrNull = (raw) => {
    const normalized = String(raw || '').trim().replace(',', '.');
    if (!normalized) return null;
    const value = Number(normalized);
    if (!Number.isFinite(value) || value <= 0) return null;
    return value;
  };

  const normalizeSizes = (sizesRaw) => {
    if (!sizesRaw || typeof sizesRaw !== 'object') return null;
    const small = parsePositiveOrNull(sizesRaw.small);
    const medium = parsePositiveOrNull(sizesRaw.medium);
    const large = parsePositiveOrNull(sizesRaw.large);
    if (small == null || medium == null || large == null) return null;
    return { small, medium, large };
  };

  const buildPricePayload = ({ baseRaw, smallRaw, mediumRaw, largeRaw }) => {
    const basePrice = parsePositiveOrNull(baseRaw);
    const small = String(smallRaw || '').trim().replace(',', '.');
    const medium = String(mediumRaw || '').trim().replace(',', '.');
    const large = String(largeRaw || '').trim().replace(',', '.');

    const hasAnySize = Boolean(small || medium || large);
    let sizes = null;

    if (hasAnySize) {
      const sizeCandidate = normalizeSizes({ small, medium, large });
      if (!sizeCandidate) {
        return {
          ok: false,
          message: 'عند استخدام الأحجام يجب إدخال أسعار صغيرة/وسط/كبيرة وكلها أكبر من صفر',
        };
      }
      sizes = sizeCandidate;
    }

    if (basePrice == null && !sizes) {
      return {
        ok: false,
        message: 'أدخل السعر الأساسي أو أسعار الأحجام',
      };
    }

    const price = basePrice ?? sizes.medium;
    return { ok: true, price, sizes };
  };

  const fullMenuRef = collection(db, 'restaurants', storeId, 'full_menu');
  let snap = await safeGetDocs(fullMenuRef);
  let docs = snap.docs || [];

  if (!docs.length) {
    await importLegacyMenuItemsToFullMenu(storeId);
    snap = await safeGetDocs(fullMenuRef);
    docs = snap.docs || [];
  }

  const rows = docs.slice(0, 200).map((d) => {
    const item = d.data() || {};
    const name = escapeHtml(item.name || d.id);
    const category = escapeHtml(item.category || '-');
    const price = Number(item.price || 0);
    const imageUrl = String(item.imageUrl || '').trim();
    const available = item.available !== false;
    const sizes = normalizeSizes(item.sizes);
    const image = imageUrl
      ? `<a class="btn ghost" href="${escapeHtml(imageUrl)}" target="_blank" rel="noopener">صورة</a>`
      : '-';
    const sizesCell = sizes
      ? `ص:${sizes.small} | و:${sizes.medium} | ك:${sizes.large}`
      : '-';

    return `<tr>
      <td>${name}</td>
      <td>${category}</td>
      <td>${Number.isFinite(price) ? price : 0}</td>
      <td>${sizesCell}</td>
      <td>${image}</td>
      <td>${available ? 'متاح' : 'غير متاح'}</td>
      <td>
        <button class="btn ghost" data-menu-edit="${d.id}">تعديل</button>
        <button class="btn ghost" data-menu-image="${d.id}">تعديل الصورة</button>
        <button class="btn ghost" data-menu-toggle="${d.id}" data-available="${available ? 'true' : 'false'}">${available ? 'إيقاف' : 'تفعيل'}</button>
        <button class="btn danger" data-menu-delete="${d.id}">حذف</button>
      </td>
    </tr>`;
  });

  container.innerHTML = `
    <div class="admin-menu-manager">
      <div class="admin-menu-create-card">
        <div class="entity-section-head compact">
          <span class="entity-section-eyebrow">إضافة سريعة</span>
          <h5>إضافة صنف جديد</h5>
          <p>الحقول متقاربة ومنظمة لتقليل الحركة بين الاسم والسعر والفئة والصورة.</p>
        </div>
        <div class="admin-menu-create-grid">
          <label>اسم الصنف<input id="newItemName-${storeId}" type="text" placeholder="مثال: بيتزا خضار" /></label>
          <label>الفئة<input id="newItemCategory-${storeId}" type="text" placeholder="مثال: بيتزا" /></label>
          <label>السعر الأساسي<input id="newItemPrice-${storeId}" type="number" step="0.01" placeholder="اختياري مع الأحجام" /></label>
          <label>سعر صغير<input id="newItemSmallPrice-${storeId}" type="number" step="0.01" placeholder="صغير" /></label>
          <label>سعر وسط<input id="newItemMediumPrice-${storeId}" type="number" step="0.01" placeholder="وسط" /></label>
          <label>سعر كبير<input id="newItemLargePrice-${storeId}" type="number" step="0.01" placeholder="كبير" /></label>
          <label class="admin-menu-file-field">صورة الصنف<input id="newItemImageFile-${storeId}" type="file" accept="image/*" /></label>
        </div>
        <div class="admin-menu-toolbar">
          <button class="btn primary" id="addMenuItem-${storeId}">إضافة الصنف</button>
        </div>
      </div>
      <div class="admin-menu-bulk-card">
        <div class="entity-section-head compact">
          <span class="entity-section-eyebrow">تسعير</span>
          <h5>تعديل جماعي للأسعار</h5>
          <p>زيادة أو خفض الأسعار على كامل القائمة من مكان واحد.</p>
        </div>
        <div class="admin-menu-bulk-actions">
          <label class="admin-menu-pct-field">النسبة<input id="pricePct-${storeId}" type="number" step="0.01" placeholder="%" /></label>
          <button class="btn ghost" id="incPrices-${storeId}">زيادة الأسعار %</button>
          <button class="btn ghost" id="decPrices-${storeId}">تخفيض الأسعار %</button>
        </div>
      </div>
      <div class="admin-menu-table-wrap">
        ${table(['الصنف', 'الفئة', 'السعر', 'الأحجام', 'الصورة', 'الحالة', 'إجراء'], rows)}
      </div>
    </div>
  `;

  const addBtn = document.getElementById(`addMenuItem-${storeId}`);
  addBtn?.addEventListener('click', async () => {
    const name = (document.getElementById(`newItemName-${storeId}`)?.value || '').trim();
    const basePriceRaw = (document.getElementById(`newItemPrice-${storeId}`)?.value || '').trim();
    const smallPriceRaw = (document.getElementById(`newItemSmallPrice-${storeId}`)?.value || '').trim();
    const mediumPriceRaw = (document.getElementById(`newItemMediumPrice-${storeId}`)?.value || '').trim();
    const largePriceRaw = (document.getElementById(`newItemLargePrice-${storeId}`)?.value || '').trim();
    const category = (document.getElementById(`newItemCategory-${storeId}`)?.value || '').trim();
    const imageInput = document.getElementById(`newItemImageFile-${storeId}`);
    const imageFile = imageInput?.files && imageInput.files.length ? imageInput.files[0] : null;

    if (!name) {
      alert('أدخل اسم الصنف');
      return;
    }
    if (!category) {
      alert('أدخل اسم الفئة');
      return;
    }

    const priceResult = buildPricePayload({
      baseRaw: basePriceRaw,
      smallRaw: smallPriceRaw,
      mediumRaw: mediumPriceRaw,
      largeRaw: largePriceRaw,
    });

    if (!priceResult.ok) {
      alert(priceResult.message);
      return;
    }
    if (!imageFile) {
      alert('اختر صورة للصنف');
      return;
    }

    try {
      const imageUrl = await uploadImageToCloudinary(imageFile);
      if (!imageUrl) {
        alert('تعذر رفع الصورة');
        return;
      }

      await addDoc(fullMenuRef, {
        name,
        price: priceResult.price,
        ...(priceResult.sizes ? { sizes: priceResult.sizes } : {}),
        category,
        imageUrl,
        available: true,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        updatedByAdminUid: auth.currentUser?.uid || null,
      });
      await renderAdminMenuManager(storeId);
    } catch (err) {
      alert(`تعذر إضافة الصنف: ${err.message || err}`);
    }
  });

  const incBtn = document.getElementById(`incPrices-${storeId}`);
  const decBtn = document.getElementById(`decPrices-${storeId}`);

  const applyPercentage = async (mode) => {
    const pctRaw = (document.getElementById(`pricePct-${storeId}`)?.value || '').trim();
    const pct = Number(pctRaw);
    if (!Number.isFinite(pct) || pct <= 0) {
      alert('أدخل نسبة صحيحة أكبر من صفر');
      return;
    }

    const factor = mode === 'inc' ? (1 + (pct / 100)) : (1 - (pct / 100));
    if (factor <= 0) {
      alert('النسبة كبيرة جدًا');
      return;
    }

    try {
      const batch = writeBatch(db);
      docs.forEach((d) => {
        const item = d.data() || {};
        const oldPrice = Number(item.price || 0);
        const updates = {
          updatedAt: serverTimestamp(),
          updatedByAdminUid: auth.currentUser?.uid || null,
        };

        if (Number.isFinite(oldPrice) && oldPrice > 0) {
          updates.price = Math.round(oldPrice * factor * 100) / 100;
        }

        const sizes = normalizeSizes(item.sizes);
        if (sizes) {
          updates.sizes = {
            small: Math.round(sizes.small * factor * 100) / 100,
            medium: Math.round(sizes.medium * factor * 100) / 100,
            large: Math.round(sizes.large * factor * 100) / 100,
          };
          if (!updates.price) {
            updates.price = updates.sizes.medium;
          }
        }

        if (!updates.price) return;
        batch.update(doc(db, 'restaurants', storeId, 'full_menu', d.id), updates);
      });
      await batch.commit();
      await renderAdminMenuManager(storeId);
    } catch (err) {
      alert(`تعذر تعديل الأسعار: ${err.message || err}`);
    }
  };

  incBtn?.addEventListener('click', async () => applyPercentage('inc'));
  decBtn?.addEventListener('click', async () => applyPercentage('dec'));

  container.querySelectorAll('[data-menu-delete]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const itemId = btn.getAttribute('data-menu-delete');
      if (!itemId) return;
      if (!confirm('هل تريد حذف هذا الصنف؟')) return;

      try {
        await deleteDoc(doc(db, 'restaurants', storeId, 'full_menu', itemId));
        await renderAdminMenuManager(storeId);
      } catch (err) {
        alert(`تعذر حذف الصنف: ${err.message || err}`);
      }
    });
  });

  container.querySelectorAll('[data-menu-toggle]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const itemId = btn.getAttribute('data-menu-toggle');
      const available = btn.getAttribute('data-available') === 'true';
      if (!itemId) return;

      try {
        await updateDoc(doc(db, 'restaurants', storeId, 'full_menu', itemId), {
          available: !available,
          updatedAt: serverTimestamp(),
          updatedByAdminUid: auth.currentUser?.uid || null,
        });
        await renderAdminMenuManager(storeId);
      } catch (err) {
        alert(`تعذر تحديث حالة الصنف: ${err.message || err}`);
      }
    });
  });

  container.querySelectorAll('[data-menu-edit]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const itemId = btn.getAttribute('data-menu-edit');
      if (!itemId) return;

      const docSnap = await getDoc(doc(db, 'restaurants', storeId, 'full_menu', itemId));
      if (!docSnap.exists()) {
        alert('الصنف غير موجود');
        return;
      }
      const item = docSnap.data() || {};

      const nextName = prompt('اسم الصنف', String(item.name || ''));
      if (nextName === null) return;
      const currentSizes = normalizeSizes(item.sizes);
      const nextPriceRaw = prompt('السعر الأساسي (اختياري مع الأحجام)', String(item.price ?? ''));
      if (nextPriceRaw === null) return;
      const nextSmallRaw = prompt('سعر صغير (اختياري)', String(currentSizes?.small ?? ''));
      if (nextSmallRaw === null) return;
      const nextMediumRaw = prompt('سعر وسط (اختياري)', String(currentSizes?.medium ?? ''));
      if (nextMediumRaw === null) return;
      const nextLargeRaw = prompt('سعر كبير (اختياري)', String(currentSizes?.large ?? ''));
      if (nextLargeRaw === null) return;
      const nextCategory = prompt('الفئة', String(item.category || ''));
      if (nextCategory === null) return;

      const priceResult = buildPricePayload({
        baseRaw: nextPriceRaw,
        smallRaw: nextSmallRaw,
        mediumRaw: nextMediumRaw,
        largeRaw: nextLargeRaw,
      });
      if (!priceResult.ok) {
        alert(priceResult.message);
        return;
      }

      let nextImage = String(item.imageUrl || '');
      const wantsImageChange = confirm('هل تريد تغيير الصورة؟');
      if (wantsImageChange) {
        const pickedFile = await pickSingleImageFile();
        if (!pickedFile) {
          alert('لم يتم اختيار صورة');
          return;
        }
        const uploaded = await uploadImageToCloudinary(pickedFile);
        if (!uploaded) {
          alert('تعذر رفع الصورة الجديدة');
          return;
        }
        nextImage = uploaded;
      }

      try {
        await updateDoc(doc(db, 'restaurants', storeId, 'full_menu', itemId), {
          name: nextName.trim(),
          price: priceResult.price,
          ...(priceResult.sizes ? { sizes: priceResult.sizes } : { sizes: deleteField() }),
          category: nextCategory.trim(),
          imageUrl: nextImage.trim(),
          updatedAt: serverTimestamp(),
          updatedByAdminUid: auth.currentUser?.uid || null,
        });
        await renderAdminMenuManager(storeId);
      } catch (err) {
        alert(`تعذر تعديل الصنف: ${err.message || err}`);
      }
    });
  });

  container.querySelectorAll('[data-menu-image]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const itemId = btn.getAttribute('data-menu-image');
      if (!itemId) return;

      const pickedFile = await pickSingleImageFile();
      if (!pickedFile) {
        alert('لم يتم اختيار صورة');
        return;
      }

      const uploaded = await uploadImageToCloudinary(pickedFile);
      if (!uploaded) {
        alert('تعذر رفع الصورة');
        return;
      }

      try {
        await updateDoc(doc(db, 'restaurants', storeId, 'full_menu', itemId), {
          imageUrl: uploaded,
          updatedAt: serverTimestamp(),
          updatedByAdminUid: auth.currentUser?.uid || null,
        });
        await renderAdminMenuManager(storeId);
      } catch (err) {
        alert(`تعذر تعديل الصورة: ${err.message || err}`);
      }
    });
  });
}

async function importLegacyMenuItemsToFullMenu(storeId) {
  const menuCategoriesSnap = await safeGetDocs(collection(db, 'restaurants', storeId, 'menu'));
  if (!menuCategoriesSnap?.docs?.length) return;

  const pendingWrites = [];

  for (const categoryDoc of menuCategoriesSnap.docs) {
    const categoryDocId = categoryDoc.id;
    const itemsSnap = await safeGetDocs(collection(db, 'restaurants', storeId, 'menu', categoryDocId, 'items'));
    for (const itemDoc of (itemsSnap.docs || [])) {
      const item = itemDoc.data() || {};
      const targetRef = doc(db, 'restaurants', storeId, 'full_menu', itemDoc.id);
      pendingWrites.push({
        ref: targetRef,
        data: {
          name: String(item.name || ''),
          price: Number(item.price || 0),
          imageUrl: String(item.imageUrl || item.image || item.photoUrl || item.photo || ''),
          category: String(item.category || categoryDocId),
          available: item.available !== false,
          createdAt: item.createdAt || serverTimestamp(),
          updatedAt: serverTimestamp(),
          legacyImported: true,
          legacyCategoryDocId: categoryDocId,
        },
      });
    }
  }

  if (!pendingWrites.length) return;

  for (let index = 0; index < pendingWrites.length; index += 400) {
    const batch = writeBatch(db);
    const chunk = pendingWrites.slice(index, index + 400);
    chunk.forEach((entry) => {
      batch.set(entry.ref, entry.data, { merge: true });
    });
    await batch.commit();
  }
}

function imageCell(url) {
  if (!url) return '-';
  const safeUrl = escapeHtml(url);
  return `<a class="btn ghost" href="${safeUrl}" target="_blank" rel="noopener">عرض</a><div style="margin-top:6px"><img src="${safeUrl}" alt="doc" style="width:56px;height:56px;object-fit:cover;border-radius:8px;border:1px solid #ddd" /></div>`;
}

async function getPendingDocs(collectionName) {
  const [byStatus, byApproval] = await Promise.all([
    safeGetDocs(query(collection(db, collectionName), where('status', '==', 'pending'))),
    safeGetDocs(query(collection(db, collectionName), where('approvalStatus', '==', 'pending')))
  ]);
  const map = new Map();
  byStatus.docs.forEach((d) => map.set(d.id, d));
  byApproval.docs.forEach((d) => map.set(d.id, d));
  return Array.from(map.values());
}

async function setStoreDecision({ appId, restaurantId, decision, ownerUid, appData = {} }) {
  const approved = decision === 'approved';
  await setDoc(doc(db, 'restaurantApplications', appId), {
    status: decision,
    approvalStatus: decision,
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  }, { merge: true });

  const restaurantRef = doc(db, 'restaurants', restaurantId);
  if (approved) {
    const existing = await getDoc(restaurantRef);
    const menuEverApproved = existing.exists() && existing.data().menuEverApproved === true ? true : true;
    await setDoc(restaurantRef, {
      name: appData.name || '',
      phone: appData.phone || '',
      email: appData.email || '',
      commercialRecordNumber: appData.commercialRecordNumber || '',
      commercialRecordImageUrl: appData.commercialRecordImageUrl || '',
      approvalStatus: 'approved',
      isApproved: true,
      ownerUid: ownerUid || restaurantId,
      temporarilyClosed: false,
      updatedAt: serverTimestamp(),
      createdAt: appData.createdAt || serverTimestamp(),
      menuEverApproved: menuEverApproved,
      menuApproved: true,
      pendingApproval: false,
    }, { merge: true });
    return;
  }

  const existing = await getDoc(restaurantRef);
  if (existing.exists()) {
    await setDoc(restaurantRef, {
      approvalStatus: 'rejected',
      isApproved: false,
      temporarilyClosed: true,
      menuApproved: false,
      pendingApproval: false,
      updatedAt: serverTimestamp(),
    }, { merge: true });
  }
}

function normalizeAdminStateId(raw) {
  const value = String(raw || '').trim();
  if (!value) return '';

  const normalized = value
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .toLowerCase();

  const compact = normalized
    .replace(/[^ -\p{L}\p{N}\s]+/gu, ' ')
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

  return compact;
}

function buildRestaurantVisibilityBackfill(restaurantData = {}, addressData = {}) {
  const updates = {};
  const directGeo = extractGeo(addressData, ['location', 'currentLocation', 'geo', 'coordinates']);
  const pairGeo = extractGeoByPairs(addressData, [
    ['latitude', 'longitude'],
    ['lat', 'lng'],
    ['geo.latitude', 'geo.longitude'],
    ['coordinates.latitude', 'coordinates.longitude'],
  ]);
  const geo = directGeo || pairGeo;

  if (geo) {
    if (!restaurantData.location && getByPath(addressData, 'location')) {
      updates.location = getByPath(addressData, 'location');
    }
    if (restaurantData.latitude == null && restaurantData.lat == null && restaurantData.restaurantLat == null) {
      updates.latitude = geo.lat;
      updates.lat = geo.lat;
      updates.restaurantLat = geo.lat;
    }
    if (restaurantData.longitude == null && restaurantData.lng == null && restaurantData.restaurantLng == null) {
      updates.longitude = geo.lng;
      updates.lng = geo.lng;
      updates.restaurantLng = geo.lng;
    }
  }

  const rawState = restaurantData.stateId
    || restaurantData.state
    || restaurantData.region
    || restaurantData.city
    || addressData.stateId
    || addressData.state
    || addressData.region
    || addressData.city
    || addressData.administrativeArea
    || addressData.addressName
    || addressData.address;
  const normalizedState = normalizeAdminStateId(rawState);

  if (normalizedState) {
    if (!String(restaurantData.stateId || '').trim()) {
      updates.stateId = normalizedState;
    }
    if (!String(restaurantData.region || '').trim()) {
      updates.region = normalizedState;
    }
  }

  if (!String(restaurantData.state || '').trim() && String(addressData.state || '').trim()) {
    updates.state = String(addressData.state || '').trim();
  }
  if (!String(restaurantData.city || '').trim()) {
    const city = String(addressData.city || addressData.locality || addressData.subAdministrativeArea || '').trim();
    if (city) {
      updates.city = city;
    }
  }
  if (!String(restaurantData.address || '').trim()) {
    const address = String(addressData.addressName || addressData.address || addressData.label || '').trim();
    if (address) {
      updates.address = address;
    }
  }

  return updates;
}

async function setMenuApprovalDirect({ restaurantId, approved = true }) {
  if (!restaurantId) return;

  const restaurantRef = doc(db, 'restaurants', restaurantId);
  const restaurantSnap = await getDoc(restaurantRef);
  const restaurantData = restaurantSnap.exists() ? (restaurantSnap.data() || {}) : {};
  let addressData = {};

  if (approved) {
    const defaultAddressId = String(restaurantData.defaultAddressId || '').trim();
    if (defaultAddressId) {
      try {
        const addressSnap = await getDoc(doc(db, 'restaurants', restaurantId, 'addresses', defaultAddressId));
        if (addressSnap.exists()) {
          addressData = addressSnap.data() || {};
        }
      } catch (_) {
        // ignore missing address read failures for direct menu approval
      }
    }
  }

  const updates = {
    pendingApproval: false,
    menuApproved: approved,
    menuEverApproved: true,
    menuApprovedAt: approved ? serverTimestamp() : deleteField(),
    menuRejectedAt: approved ? deleteField() : serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  if (approved) {
    updates.approvalStatus = 'approved';
    updates.isApproved = true;
    Object.assign(updates, buildRestaurantVisibilityBackfill(restaurantData, addressData));
  }

  await updateDoc(restaurantRef, updates);
}

async function setCourierDecision({ appId, driverId, decision, ownerUid }) {
  const approved = decision === 'approved';
  await setDoc(doc(db, 'courierApplications', appId), {
    status: decision,
    approvalStatus: decision,
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  }, { merge: true });

  await setDoc(doc(db, 'drivers', driverId), {
    approvalStatus: decision,
    isApproved: approved,
    ownerUid: ownerUid || driverId,
    updatedAt: serverTimestamp()
  }, { merge: true });
}

function mountSupport() {
  if (!supportRoot || !supportConversationList || !supportMessagesPane) {
    return;
  }

  const clearSupportPendingImage = () => {
    supportPendingImageFile = null;
    if (supportPendingImagePreviewUrl) {
      URL.revokeObjectURL(supportPendingImagePreviewUrl);
      supportPendingImagePreviewUrl = '';
    }
    if (supportImageInput) {
      supportImageInput.value = '';
    }
    if (supportImagePreview) {
      supportImagePreview.hidden = true;
    }
    if (supportImagePreviewImg) {
      supportImagePreviewImg.removeAttribute('src');
    }
  };

  const renderSupportPendingImage = () => {
    if (!supportImagePreview || !supportImagePreviewImg) return;
    if (!supportPendingImageFile || !supportPendingImagePreviewUrl) {
      supportImagePreview.hidden = true;
      supportImagePreviewImg.removeAttribute('src');
      return;
    }
    supportImagePreviewImg.src = supportPendingImagePreviewUrl;
    supportImagePreview.hidden = false;
  };

  const mountComposerInActiveThread = () => {
    if (!supportComposer) return;
    const slot = supportMessagesPane.querySelector('.support-thread-composer-slot');
    if (!slot) {
      supportComposer.hidden = true;
      return;
    }
    slot.appendChild(supportComposer);
    supportComposer.hidden = false;
    supportComposer.classList.add('support-composer--inline');
    renderSupportPendingImage();
  };

  const scrollMessageNearComposer = (messageElement) => {
    if (!supportMessagesPane || !messageElement) return;
    const composerVisualGap = 28;
    const desiredTop = Math.max(
      0,
      messageElement.offsetTop - Math.max(0, supportMessagesPane.clientHeight - messageElement.offsetHeight - composerVisualGap)
    );
    supportMessagesPane.scrollTo({ top: desiredTop, behavior: 'smooth' });
  };

  const normalizeActor = (value) => {
    const v = String(value || '').toLowerCase();
    if (v.includes('client') || value === 'عميل') return 'عميل';
    if (v.includes('driver') || v.includes('courier') || value === 'مندوب') return 'مندوب';
    if (v.includes('restaurant') || v.includes('store') || value === 'مطعم') return 'مطعم';
    return 'غير مصنف';
  };

  const normalizeApp = (value) => {
    const v = String(value || '').toLowerCase();
    if (v === 'client') return 'client';
    if (v === 'courier' || v === 'driver') return 'courier';
    if (v === 'store' || v === 'restaurant') return 'store';
    return 'client';
  };

  const fmtTime = (ts) => {
    try {
      const date = ts && typeof ts.toDate === 'function' ? ts.toDate() : null;
      if (!date) return '-';
      return date.toLocaleString('ar-EG');
    } catch (_) {
      return '-';
    }
  };

  const getMillis = (ts) => {
    try {
      return ts && typeof ts.toDate === 'function' ? ts.toDate().getTime() : 0;
    } catch (_) {
      return 0;
    }
  };

  const getConversationUserId = (conversation) => {
    if (!conversation) return '';
    const conversationId = String(conversation.id || '');
    if (conversationId.endsWith('-support')) {
      return conversationId.slice(0, -'-support'.length);
    }

    const messages = supportMessagesByConversation.get(conversationId) || [];
    const adminUid = auth.currentUser?.uid || '';
    for (const msg of messages) {
      const participants = Array.isArray(msg.participants) ? msg.participants : [];
      const candidate = participants.find((p) => p && p !== 'support' && p !== adminUid);
      if (candidate) return String(candidate);

      if (msg.senderId && msg.senderId !== 'support' && msg.senderId !== adminUid && msg.senderType !== 'admin') {
        return String(msg.senderId);
      }
      if (msg.receiverId && msg.receiverId !== 'support' && msg.receiverId !== adminUid) {
        return String(msg.receiverId);
      }
    }
    return '';
  };

  const renderConversationList = () => {
    const search = String(supportSearchInput?.value || '').trim().toLowerCase();
    const appFilter = String(supportAppFilter?.value || 'all');
    const statusFilter = String(supportStatusFilter?.value || 'all');

    const rows = supportConversations
      .filter((item) => {
        if (appFilter !== 'all' && item.sourceApp !== appFilter) return false;
        if (statusFilter !== 'all' && item.status !== statusFilter) return false;
        if (!search) return true;
        const haystack = [
          item.id,
          item.senderName,
          item.preview,
          item.userId,
          item.actor,
        ]
          .join(' ')
          .toLowerCase();
        return haystack.includes(search);
      })
      .sort((a, b) => b.latestMillis - a.latestMillis);

    if (supportSummary) {
      const total = supportConversations.length;
      const openCount = supportConversations.filter((item) => item.status !== 'closed').length;
      const closedCount = total - openCount;
      const unreadCount = supportConversations.reduce((sum, item) => sum + (item.unreadCount || 0), 0);
      supportSummary.innerHTML = `
        <span class="chip">الإجمالي: ${total}</span>
        <span class="chip">مفتوحة: ${openCount}</span>
        <span class="chip">مغلقة: ${closedCount}</span>
        <span class="chip">غير مقروء: ${unreadCount}</span>
        <span class="chip">المعروض: ${rows.length}</span>
      `;
    }

    if (!rows.length) {
      supportConversationList.innerHTML = '<div class="muted" style="padding:10px;">لا توجد محادثات مطابقة.</div>';
      return;
    }

    supportConversationList.innerHTML = rows
      .map((item) => {
        const appLabel = item.sourceApp === 'client'
          ? 'العملاء'
          : item.sourceApp === 'courier'
            ? 'المندوبون'
            : 'المتاجر';
        return `
          <button class="support-item ${item.id === supportSelectedConversationId ? 'active' : ''}" data-support-conversation="${escapeHtml(item.id)}" type="button">
            <div class="support-item-top">
              <span class="badge ${item.status === 'closed' ? 'closed' : 'open'}">${item.status === 'closed' ? 'مغلقة' : 'مفتوحة'}</span>
              <span class="muted">${escapeHtml(item.latestTimeText)}</span>
            </div>
            <div class="support-item-title">${escapeHtml(item.senderName || item.userId || item.id)} ${item.unreadCount > 0 ? `<span class="support-unread">${item.unreadCount}</span>` : ''}</div>
            <div class="support-item-sub">${escapeHtml(appLabel)} · ${escapeHtml(item.actor)} · ${escapeHtml(item.userId || '-')}</div>
            <div class="support-item-preview">${escapeHtml(item.preview || '-')}</div>
          </button>
        `;
      })
      .join('');

    supportConversationList.querySelectorAll('[data-support-conversation]').forEach((btn) => {
      btn.addEventListener('click', () => {
        supportSelectedConversationId = btn.getAttribute('data-support-conversation') || '';
        renderConversationList();
        renderSelectedConversation();
      });
    });
  };

  const renderSelectedConversation = () => {
    if (!supportSelectedConversationId) {
      supportConversationHeader.textContent = 'اختر محادثة من القائمة لعرض التفاصيل.';
      supportMessagesPane.innerHTML = '<div class="muted">لا توجد محادثة محددة.</div>';
      if (supportComposer) supportComposer.hidden = true;
      supportToggleStatusBtn.disabled = true;
      if (supportMarkReadBtn) supportMarkReadBtn.disabled = true;
      supportSendBtn.disabled = true;
      return;
    }

    const convo = supportConversations.find((item) => item.id === supportSelectedConversationId);
    if (!convo) {
      supportConversationHeader.textContent = 'المحادثة غير متاحة حاليًا.';
      supportMessagesPane.innerHTML = '<div class="muted">لم يتم العثور على بيانات هذه المحادثة.</div>';
      if (supportComposer) supportComposer.hidden = true;
      supportToggleStatusBtn.disabled = true;
      if (supportMarkReadBtn) supportMarkReadBtn.disabled = true;
      supportSendBtn.disabled = true;
      return;
    }

    const messages = (supportMessagesByConversation.get(convo.id) || []).slice().sort((a, b) => a.timestampMillis - b.timestampMillis);
    const appLabel = convo.sourceApp === 'client'
      ? 'العملاء'
      : convo.sourceApp === 'courier'
        ? 'المندوبون'
        : 'المتاجر';
    const latestReadMillis = messages
      .map((msg) => getMillis(msg.adminReadAt))
      .reduce((max, current) => Math.max(max, current), 0);

    supportConversationHeader.innerHTML = `
      <b>${escapeHtml(convo.senderName || convo.userId || convo.id)}</b>
      <span class="kv"><b>المحادثة:</b> ${escapeHtml(convo.id)}</span>
      <span class="kv"><b>التطبيق:</b> ${escapeHtml(appLabel)}</span>
      <span class="kv"><b>التصنيف:</b> ${escapeHtml(convo.actor)}</span>
      <span class="kv"><b>الحالة:</b> ${convo.status === 'closed' ? 'مغلقة' : 'مفتوحة'}</span>
    `;

    const messagesMarkup = messages.length
      ? messages.map((msg, index) => {
          const mine = msg.senderType === 'admin' || msg.senderId === (auth.currentUser?.uid || '');
          const isUnreadForAdmin = !mine && (msg.timestampMillis || 0) > latestReadMillis;
          const textBody = String(msg.message || '').trim()
            ? `<div class="support-bubble-text">${escapeHtml(msg.message || '')}</div>`
            : '';
          const imageBody = msg.imageUrl
            ? `<a class="support-bubble-image-link" href="${escapeHtml(msg.imageUrl)}" target="_blank" rel="noopener"><img class="support-bubble-image" src="${escapeHtml(msg.imageUrl)}" alt="صورة مرفقة" /></a>`
            : '';
          const body = textBody || imageBody
            ? `${textBody}${imageBody}`
            : '<div class="muted">رسالة بدون محتوى.</div>';
          return `
            <div class="support-bubble ${mine ? 'mine' : ''}" data-support-message-index="${index}" ${isUnreadForAdmin ? 'data-support-unread="true"' : ''}>
              <div class="support-bubble-head">${escapeHtml(msg.senderName || msg.senderType || msg.senderId || 'مستخدم')}</div>
              <div>${body}</div>
              <div class="support-bubble-time">${escapeHtml(msg.timeText)}</div>
            </div>
          `;
        }).join('')
      : '<div class="muted">لا توجد رسائل بعد.</div>';

    supportMessagesPane.innerHTML = `
      <div class="support-thread">
        <div class="support-message-list">${messagesMarkup}</div>
        <div class="support-thread-composer-slot"></div>
      </div>
    `;
    mountComposerInActiveThread();

    const firstUnreadMessage = supportMessagesPane.querySelector('[data-support-unread="true"]');
    const latestExternalMessage = Array.from(supportMessagesPane.querySelectorAll('.support-bubble:not(.mine)')).pop();
    const targetMessage = firstUnreadMessage || latestExternalMessage;
    if (targetMessage) {
      scrollMessageNearComposer(targetMessage);
    } else {
      supportMessagesPane.scrollTop = supportMessagesPane.scrollHeight;
    }

    supportToggleStatusBtn.disabled = false;
    if (supportMarkReadBtn) supportMarkReadBtn.disabled = false;
    supportReplyInput.disabled = convo.status === 'closed';
    supportToggleStatusBtn.textContent = convo.status === 'closed' ? 'إعادة فتح المحادثة' : 'إغلاق المحادثة';
    syncComposerState();

    if (convo.status !== 'closed') {
      requestAnimationFrame(() => {
        supportReplyInput?.focus({ preventScroll: true });
      });
    }
  };

  const syncComposerState = () => {
    if (!supportSendBtn) return;
    const convo = supportConversations.find((item) => item.id === supportSelectedConversationId);
    const isClosed = !convo || convo.status === 'closed';
    const hasText = String(supportReplyInput?.value || '').trim().length > 0;
    const hasAttachment = !!supportPendingImageFile;
    if (supportReplyInput) supportReplyInput.disabled = isClosed || supportSendInFlight;
    if (supportAttachImageBtn) supportAttachImageBtn.disabled = isClosed || supportSendInFlight;
    if (supportImageInput) supportImageInput.disabled = isClosed || supportSendInFlight;
    supportSendBtn.disabled = isClosed || supportSendInFlight || (!hasText && !hasAttachment);
  };

  const sendReply = async () => {
    const text = String(supportReplyInput?.value || '').trim();
    if ((!text && !supportPendingImageFile) || !supportSelectedConversationId) return;

    const convo = supportConversations.find((item) => item.id === supportSelectedConversationId);
    if (!convo || convo.status === 'closed') return;

    const userId = getConversationUserId(convo);
    if (!userId) {
      alert('تعذر تحديد صاحب المحادثة لإرسال الرد.');
      return;
    }

    try {
      supportSendInFlight = true;
      syncComposerState();
      let imageUrl = '';
      if (supportPendingImageFile) {
        imageUrl = await uploadImageToCloudinary(supportPendingImageFile) || '';
        if (!imageUrl) {
          throw new Error('تعذر رفع الصورة المرفقة. حاول مرة أخرى.');
        }
      }
      await addDoc(collection(db, 'supportMessages'), {
        conversationId: convo.id,
        chatKind: 'support',
        sourceApp: convo.sourceApp,
        senderId: auth.currentUser?.uid || '',
        senderType: 'admin',
        senderName: 'الدعم الفني',
        receiverId: userId,
        participants: [userId, 'support', auth.currentUser?.uid || 'support'],
        participantsKey: [userId, 'support'].sort(),
        timestamp: serverTimestamp(),
        message: text,
        ...(imageUrl ? { imageUrl } : {}),
        status: 'open',
      });
      supportReplyInput.value = '';
      clearSupportPendingImage();
      syncComposerState();
      supportMessagesPane.scrollTop = supportMessagesPane.scrollHeight;
      supportReplyInput?.focus({ preventScroll: true });
    } catch (err) {
      alert(`تعذر إرسال الرد: ${err.message || err}`);
    } finally {
      supportSendInFlight = false;
      syncComposerState();
    }
  };

  const toggleStatus = async () => {
    if (!supportSelectedConversationId) return;
    const convo = supportConversations.find((item) => item.id === supportSelectedConversationId);
    if (!convo) return;
    const nextStatus = convo.status === 'closed' ? 'open' : 'closed';

    try {
      const q = query(collection(db, 'supportMessages'), where('conversationId', '==', supportSelectedConversationId));
      const result = await getDocs(q);
      const batch = writeBatch(db);
      result.docs.forEach((docSnap) => {
        batch.update(doc(db, 'supportMessages', docSnap.id), {
          status: nextStatus,
          updatedAt: serverTimestamp(),
          ...(nextStatus === 'closed' ? { closedAt: serverTimestamp() } : { reopenedAt: serverTimestamp() }),
        });
      });
      await batch.commit();
    } catch (err) {
      alert(`تعذر تحديث الحالة: ${err.message || err}`);
    }
  };

  if (!supportUiBound) {
    supportSearchInput?.addEventListener('input', () => renderConversationList());
    supportAppFilter?.addEventListener('change', () => renderConversationList());
    supportStatusFilter?.addEventListener('change', () => renderConversationList());
    supportReplyInput?.addEventListener('input', () => syncComposerState());
    supportAttachImageBtn?.addEventListener('click', () => {
      if (supportAttachImageBtn.disabled) return;
      supportImageInput?.click();
    });
    supportImageInput?.addEventListener('change', () => {
      const file = supportImageInput.files && supportImageInput.files.length ? supportImageInput.files[0] : null;
      if (!file) {
        clearSupportPendingImage();
        syncComposerState();
        return;
      }
      if (!String(file.type || '').startsWith('image/')) {
        alert('الملف المختار ليس صورة صالحة.');
        clearSupportPendingImage();
        syncComposerState();
        return;
      }
      if (supportPendingImagePreviewUrl) {
        URL.revokeObjectURL(supportPendingImagePreviewUrl);
      }
      supportPendingImageFile = file;
      supportPendingImagePreviewUrl = URL.createObjectURL(file);
      renderSupportPendingImage();
      syncComposerState();
    });
    supportRemoveImageBtn?.addEventListener('click', () => {
      clearSupportPendingImage();
      syncComposerState();
    });
    supportSendBtn?.addEventListener('click', sendReply);
    supportToggleStatusBtn?.addEventListener('click', toggleStatus);
    supportMarkReadBtn?.addEventListener('click', async () => {
      if (!supportSelectedConversationId) return;
      try {
        await markSupportConversationRead(supportSelectedConversationId);
      } catch (err) {
        alert(`تعذر تعليم المحادثة كمقروءة: ${err.message || err}`);
      }
    });
    supportMarkAllReadBtn?.addEventListener('click', async () => {
      try {
        await markAllSupportConversationsRead();
      } catch (err) {
        alert(`تعذر تعليم الكل كمقروء: ${err.message || err}`);
      }
    });
    supportReplyInput?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        sendReply();
      }
    });
    supportUiBound = true;
  }

  supportConversationList.innerHTML = '<div class="muted" style="padding:10px;">جاري تحميل المحادثات...</div>';
  supportMessagesPane.innerHTML = '<div class="muted">اختر محادثة من القائمة.</div>';
  if (supportComposer) supportComposer.hidden = true;

  const supportQ = query(collection(db, 'supportMessages'), orderBy('timestamp', 'desc'), limit(2000));
  unsubscribers.push(
    onSnapshot(supportQ, (snap) => {
      const conversationMap = new Map();
      const messagesMap = new Map();

      snap.docs.forEach((d) => {
        const data = d.data() || {};
        const conversationId = String(data.conversationId || '');
        if (!conversationId) return;

        const isSupport =
          data.chatKind === 'support'
          || data.receiverId === 'support'
          || conversationId.endsWith('-support');
        if (!isSupport) return;

        const message = {
          id: d.id,
          ...data,
          timestampMillis: getMillis(data.timestamp),
          timeText: fmtTime(data.timestamp),
        };

        if (!messagesMap.has(conversationId)) {
          messagesMap.set(conversationId, []);
        }
        messagesMap.get(conversationId).push(message);

        if (!conversationMap.has(conversationId)) {
          conversationMap.set(conversationId, message);
        }
      });

      supportMessagesByConversation = messagesMap;
      supportConversations = Array.from(conversationMap.entries())
        .map(([id, latest]) => {
          const all = messagesMap.get(id) || [];
          const latestSorted = all.slice().sort((a, b) => b.timestampMillis - a.timestampMillis);
          const latestMsg = latestSorted[0] || latest;
          const latestAdminMillis = latestSorted
            .filter((m) => m.senderType === 'admin')
            .map((m) => m.timestampMillis || 0)
            .reduce((max, current) => Math.max(max, current), 0);
          const latestReadMillis = latestSorted
            .map((m) => getMillis(m.adminReadAt))
            .reduce((max, current) => Math.max(max, current), latestAdminMillis);
          const unreadCount = latestSorted
            .filter((m) => m.senderType !== 'admin' && (m.timestampMillis || 0) > latestReadMillis)
            .length;
          const actor = normalizeActor(
            latestSorted.find((m) => m.senderType && m.senderType !== 'admin')?.senderType
              || latestMsg.senderType
          );
          const sourceApp = normalizeApp(latestMsg.sourceApp || latest.sourceApp || 'client');
          const userId = id.endsWith('-support') ? id.slice(0, -'-support'.length) : '';
          return {
            id,
            actor,
            sourceApp,
            status: String(latestMsg.status || 'open') === 'closed' ? 'closed' : 'open',
            senderName: latestMsg.senderName || latestMsg.senderId || '',
            preview: latestMsg.message || (latestMsg.imageUrl ? '📷 صورة مرفقة' : '-'),
            latestMillis: latestMsg.timestampMillis || 0,
            latestTimeText: latestMsg.timeText || '-',
            userId,
            unreadCount,
          };
        })
        .sort((a, b) => b.latestMillis - a.latestMillis);

      opsCenterState.supportUnread = supportConversations.reduce((sum, item) => sum + (item.unreadCount > 0 ? 1 : 0), 0);
      opsCenterState.supportUnreadMessages = supportConversations.reduce((sum, item) => sum + Number(item.unreadCount || 0), 0);
      syncOpsCollectionState(
        'supportUnread',
        new Set(supportConversations.filter((item) => item.unreadCount > 0).map((item) => item.id)),
        (id) => {
          const convo = supportConversations.find((item) => item.id === id);
          return {
            title: 'رسالة دعم جديدة',
            body: `محادثة ${convo?.senderName || convo?.userId || id} تحتوي رسائل غير مقروءة.`,
            level: 'info',
          };
        }
      );

      if (!supportSelectedConversationId && supportConversations.length) {
        supportSelectedConversationId = supportConversations[0].id;
      } else if (supportSelectedConversationId && !supportConversations.find((c) => c.id === supportSelectedConversationId)) {
        supportSelectedConversationId = supportConversations.length ? supportConversations[0].id : '';
      }

      renderConversationList();
      renderSelectedConversation();
      syncComposerState();
    })
  );
}

function mountDiscountCodes() {
  if (!discountForm || !discountsTable) return;

  const DISCOUNT_SCOPE_LABELS = {
    order_total: 'إجمالي الطلب',
    delivery_fee: 'التوصيل فقط',
  };

  const parseNumberOrNull = (raw) => {
    const value = Number(String(raw || '').trim());
    return Number.isFinite(value) && value >= 0 ? value : null;
  };

  const formatDateTimeLocal = (value) => {
    if (!value || typeof value.toDate !== 'function') return '-';
    try {
      return value.toDate().toLocaleString('ar-EG');
    } catch (_) {
      return '-';
    }
  };

  if (!discountFormBound) {
    discountForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const code = String(discountCode?.value || '').trim().toUpperCase();
      const scope = String(discountScope?.value || 'order_total').trim().toLowerCase();
      const type = String(discountType?.value || 'percent').trim().toLowerCase();
      const value = parseNumberOrNull(discountValue?.value);
      const expiryRaw = String(discountExpiryDate?.value || '').trim();
      const expiryMillis = Date.parse(expiryRaw);

      if (!code) {
        if (discountResult) discountResult.textContent = 'يرجى إدخال كود الخصم.';
        return;
      }
      if (type !== 'percent' && type !== 'fixed') {
        if (discountResult) discountResult.textContent = 'نوع الخصم غير صالح.';
        return;
      }
      if (!['order_total', 'delivery_fee'].includes(scope)) {
        if (discountResult) discountResult.textContent = 'نطاق الخصم غير صالح.';
        return;
      }
      if (value == null || value <= 0) {
        if (discountResult) discountResult.textContent = 'قيمة الخصم يجب أن تكون أكبر من صفر.';
        return;
      }
      if (!Number.isFinite(expiryMillis)) {
        if (discountResult) discountResult.textContent = 'يرجى إدخال تاريخ انتهاء صحيح.';
        return;
      }

      const payload = {
        code,
        discountScope: scope,
        discountType: type,
        discountValue: value,
        isActive: discountIsActive?.checked === true,
        onlyForNewOrders: discountOnlyNewOrders?.checked === true,
        restaurantId: String(discountRestaurantId?.value || '').trim(),
        itemName: scope === 'delivery_fee' ? '' : String(discountItemName?.value || '').trim(),
        minOrder: parseNumberOrNull(discountMinOrder?.value),
        maxUsage: parseNumberOrNull(discountMaxUsage?.value),
        maxUsagePerUser: parseNumberOrNull(discountMaxUsagePerUser?.value),
        maxDiscount: parseNumberOrNull(discountMaxDiscount?.value),
        expiryDate: new Date(expiryMillis),
      };

      if (discountSaveBtn) discountSaveBtn.disabled = true;
      if (discountResult) discountResult.textContent = 'جارٍ حفظ كود الخصم...';

      try {
        const ref = doc(db, 'promocodes', code);
        const existing = await getDoc(ref);
        await setDoc(ref, {
          code,
          discountScope: payload.discountScope,
          discountType: payload.discountType,
          discountValue: payload.discountValue,
          isActive: payload.isActive,
          onlyForNewOrders: payload.onlyForNewOrders,
          restaurantId: payload.restaurantId || '',
          itemName: payload.itemName || '',
          minOrder: payload.minOrder,
          maxUsage: payload.maxUsage,
          maxUsagePerUser: payload.maxUsagePerUser,
          maxDiscount: payload.maxDiscount,
          expiryDate: payload.expiryDate,
          updatedAt: serverTimestamp(),
          updatedByAdminUid: auth.currentUser?.uid || '',
          ...(existing.exists()
            ? {}
            : {
                usedCount: 0,
                usersUsed: {},
                createdAt: serverTimestamp(),
                createdBy: auth.currentUser?.uid || '',
              }),
        }, { merge: true });

        if (discountResult) discountResult.textContent = `تم حفظ الكود ${code} بنجاح.`;
        discountForm.reset();
        if (discountIsActive) discountIsActive.checked = true;
        if (discountScope) discountScope.value = 'order_total';
      } catch (err) {
        if (discountResult) discountResult.textContent = `تعذر حفظ الكود: ${err.message || err}`;
      } finally {
        if (discountSaveBtn) discountSaveBtn.disabled = false;
      }
    });
    discountFormBound = true;
  }

  unsubscribers.push(
    onSnapshot(query(collection(db, 'promocodes'), limit(200)), (snap) => {
      const docs = snap.docs.slice().sort((a, b) => {
        const aTime = a.data()?.updatedAt?.toMillis?.() || a.data()?.createdAt?.toMillis?.() || 0;
        const bTime = b.data()?.updatedAt?.toMillis?.() || b.data()?.createdAt?.toMillis?.() || 0;
        return bTime - aTime;
      });

      const rows = docs.map((d) => {
        const data = d.data() || {};
        const code = String(data.code || d.id || '');
        const active = data.isActive === true;
        const usedCount = Number(data.usedCount || 0);
        const maxUsage = Number(data.maxUsage || 0);
        const capText = Number(data.maxDiscount || 0) > 0 ? ` (سقف ${Number(data.maxDiscount)})` : '';
        const scopeLabel = DISCOUNT_SCOPE_LABELS[String(data.discountScope || 'order_total').trim().toLowerCase()] || 'إجمالي الطلب';

        return `<tr>
          <td>${escapeHtml(code)}</td>
          <td>${escapeHtml(scopeLabel)}</td>
          <td>${escapeHtml(String(data.discountType || '-'))}</td>
          <td>${Number(data.discountValue || 0)}${capText}</td>
          <td>${usedCount}${maxUsage > 0 ? ` / ${maxUsage}` : ''}</td>
          <td>${formatDateTimeLocal(data.expiryDate)}</td>
          <td><span class="badge ${active ? 'closed' : 'open'}">${active ? 'مفعل' : 'موقوف'}</span></td>
          <td>
            <button class="btn ghost" data-toggle-discount="${escapeHtml(code)}" data-active="${active ? 'true' : 'false'}">${active ? 'إيقاف' : 'تفعيل'}</button>
            <button class="btn danger" data-delete-discount="${escapeHtml(code)}">حذف</button>
          </td>
        </tr>`;
      });

      setHtml(discountsTable, table(['الكود', 'النطاق', 'النوع', 'القيمة', 'الاستخدام', 'ينتهي في', 'الحالة', 'إجراء'], rows));

      discountsTable.querySelectorAll('[data-toggle-discount]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const code = btn.getAttribute('data-toggle-discount');
          const isActive = btn.getAttribute('data-active') === 'true';
          if (!code) return;
          try {
            await updateDoc(doc(db, 'promocodes', code), {
              isActive: !isActive,
              updatedAt: serverTimestamp(),
              updatedByAdminUid: auth.currentUser?.uid || '',
            });
          } catch (err) {
            alert(`تعذر تحديث الحالة: ${err.message || err}`);
          }
        });
      });

      discountsTable.querySelectorAll('[data-delete-discount]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const code = btn.getAttribute('data-delete-discount');
          if (!code) return;
          if (!confirm(`هل تريد حذف كود ${code}؟`)) return;
          try {
            await deleteDoc(doc(db, 'promocodes', code));
          } catch (err) {
            alert(`تعذر حذف الكود: ${err.message || err}`);
          }
        });
      });
    })
  );
}

function updateRolloutSelectedCount() {
  if (rolloutSelectedCount) {
    rolloutSelectedCount.textContent = `المدن المختارة: ${rolloutSelectedCityIds.size}`;
  }
}

function syncRolloutCsvFromSet() {
  if (rolloutSelectedCitiesCsv) {
    rolloutSelectedCitiesCsv.value = setToCsv(rolloutSelectedCityIds);
  }
  updateRolloutSelectedCount();
}

function syncRolloutSetFromCsv() {
  if (!rolloutSelectedCitiesCsv) return;
  rolloutSelectedCityIds = csvToRolloutSet(rolloutSelectedCitiesCsv.value);
  updateRolloutSelectedCount();
}

function renderRolloutCityList(filterRaw = '') {
  if (!rolloutCitiesList) return;
  const filter = normalizeRolloutToken(filterRaw);
  const rows = SUDAN_CITY_OPTIONS
    .filter((item) => {
      if (!filter) return true;
      return item.id.includes(filter) || normalizeRolloutToken(item.label).includes(filter);
    })
    .map((item) => {
      const checked = rolloutSelectedCityIds.has(item.id) ? 'checked' : '';
      return `<label class="city-picker-item">
        <input type="checkbox" data-rollout-city="${escapeHtml(item.id)}" ${checked} />
        <span>${escapeHtml(item.label)}</span>
      </label>`;
    });

  setHtml(rolloutCitiesList, rows.length ? rows.join('') : '<p class="muted">لا توجد نتائج مطابقة.</p>');

  rolloutCitiesList.querySelectorAll('[data-rollout-city]').forEach((box) => {
    box.addEventListener('change', () => {
      const cityId = normalizeRolloutToken(box.getAttribute('data-rollout-city'));
      if (!cityId) return;
      if (box.checked) {
        rolloutSelectedCityIds.add(cityId);
      } else {
        rolloutSelectedCityIds.delete(cityId);
      }
      syncRolloutCsvFromSet();
    });
  });
}

function normalizeRemoteValueByType(valueRaw, valueTypeRaw) {
  const valueType = String(valueTypeRaw || 'STRING').trim().toUpperCase();
  const value = String(valueRaw ?? '').trim();

  if (valueType === 'BOOLEAN') {
    const normalized = value.toLowerCase();
    if (normalized === 'true' || normalized === '1' || normalized === 'yes') return 'true';
    if (normalized === 'false' || normalized === '0' || normalized === 'no') return 'false';
    return 'false';
  }

  if (valueType === 'NUMBER') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? String(parsed) : '0';
  }

  return value;
}

function getRemoteConfigEntry(key) {
  return remoteConfigParametersCache.find((item) => String(item.key || '') === String(key || '')) || null;
}

function fillPricingConfigForm() {
  if (!pricingConfigForm) return;
  pricingClientBaseFeeInput.value = String(getRemoteConfigEntry('pricing_client_delivery_base_fee')?.value || '5000');
  pricingClientBaseDistanceInput.value = String(getRemoteConfigEntry('pricing_client_delivery_base_distance_km')?.value || '6');
  pricingClientExtraPerKmInput.value = String(getRemoteConfigEntry('pricing_client_delivery_extra_per_km')?.value || '700');
  pricingDriverBaseFeeInput.value = String(getRemoteConfigEntry('pricing_driver_delivery_base_fee')?.value || '4000');
  pricingDriverBaseDistanceInput.value = String(getRemoteConfigEntry('pricing_driver_delivery_base_distance_km')?.value || '6');
  pricingDriverExtraPerKmInput.value = String(getRemoteConfigEntry('pricing_driver_delivery_extra_per_km')?.value || '500');
  pricingLargeItemFeeEnabledInput.value = String(getRemoteConfigEntry('pricing_large_item_fee_enabled')?.value || 'true');
  pricingLargeItemThresholdInput.value = String(getRemoteConfigEntry('pricing_large_item_threshold')?.value || '10000');
  pricingLargeItemFeeBaseInput.value = String(getRemoteConfigEntry('pricing_large_item_fee_base')?.value || '500');
  pricingLargeItemStepAmountInput.value = String(getRemoteConfigEntry('pricing_large_item_step_amount')?.value || '5000');
  pricingLargeItemStepFeeInput.value = String(getRemoteConfigEntry('pricing_large_item_step_fee')?.value || '500');
  pricingLargeItemFeeCapPerUnitInput.value = String(getRemoteConfigEntry('pricing_large_item_fee_cap_per_unit')?.value || '2500');
}

function fillAppRemoteConfigForm() {
  if (!appRemoteConfigForm) return;
  opsForceUpdateEnabledInput.value = String(getRemoteConfigEntry('ops_force_update_enabled')?.value || 'true');
  opsMinBuildAndroidInput.value = String(getRemoteConfigEntry('ops_min_build_android')?.value || '0');
  opsUpdateMessageInput.value = String(getRemoteConfigEntry('ops_update_message')?.value || 'يوجد تحديث جديد مهم لتحسين الأداء. الرجاء التحديث الآن.');
  opsUpdateUrlAndroidInput.value = String(getRemoteConfigEntry('ops_update_url_android')?.value || '');
  clientForceUpdateEnabledInput.value = String(getRemoteConfigEntry('client_force_update_enabled')?.value || 'true');
  clientMinBuildAndroidInput.value = String(getRemoteConfigEntry('client_min_build_android')?.value || '11');
  clientUpdateMessageInput.value = String(getRemoteConfigEntry('client_update_message')?.value || 'يرجى تحديث تطبيق العميل للاستمرار.');
  clientUpdateUrlAndroidInput.value = String(getRemoteConfigEntry('client_update_url_android')?.value || 'https://speedstarapp.web.app/downloads/client-android.apk');
  clientRootUrlInput.value = String(getRemoteConfigEntry('client_root_url')?.value || 'https://speedstar-prod-4c7c5.web.app/sdui/client/index.json');
  storeForceUpdateEnabledInput.value = String(getRemoteConfigEntry('store_force_update_enabled')?.value || 'true');
  storeMinBuildAndroidInput.value = String(getRemoteConfigEntry('store_min_build_android')?.value || '5');
  storeUpdateMessageInput.value = String(getRemoteConfigEntry('store_update_message')?.value || 'يرجى تحديث تطبيق المتجر للاستمرار.');
  storeUpdateUrlAndroidInput.value = String(getRemoteConfigEntry('store_update_url_android')?.value || 'https://speedstarapp.web.app/downloads/store-android.apk');
  storeRootUrlInput.value = String(getRemoteConfigEntry('store_root_url')?.value || 'https://speedstar-prod-4c7c5.web.app/sdui/store/index.json');
  courierForceUpdateEnabledInput.value = String(getRemoteConfigEntry('courier_force_update_enabled')?.value || 'false');
  courierMinBuildAndroidInput.value = String(getRemoteConfigEntry('courier_min_build_android')?.value || '1');
  courierUpdateMessageInput.value = String(getRemoteConfigEntry('courier_update_message')?.value || 'يرجى تحديث تطبيق المندوب للاستمرار.');
  courierUpdateUrlAndroidInput.value = String(getRemoteConfigEntry('courier_update_url_android')?.value || 'https://speedstarapp.web.app/downloads/courier-android.apk');
  courierRootUrlInput.value = String(getRemoteConfigEntry('courier_root_url')?.value || 'https://speedstar-prod-4c7c5.web.app/sdui/courier/index.json');
}

function renderRemoteConfigTable(filterRaw = '') {
  if (!remoteConfigTable) return;
  const filter = String(filterRaw || '').trim().toLowerCase();

  const filtered = remoteConfigParametersCache.filter((item) => {
    const meta = REMOTE_CONFIG_METADATA[String(item.key || '')] || null;
    if (!filter) return true;
    return String(item.key || '').toLowerCase().includes(filter)
      || String(item.description || '').toLowerCase().includes(filter)
      || String(meta?.label || '').toLowerCase().includes(filter)
      || String(meta?.description || '').toLowerCase().includes(filter);
  });

  if (!filtered.length) {
    setHtml(remoteConfigTable, '<p class="muted" style="padding:10px;">لا توجد مفاتيح مطابقة للبحث.</p>');
    return;
  }

  const rows = filtered.map((item) => {
    const key = String(item.key || '');
    const value = String(item.value || '');
    const meta = REMOTE_CONFIG_METADATA[key] || null;
    const valueType = String(meta?.valueType || item.valueType || 'STRING').toUpperCase();
    const desc = String(meta?.description || item.description || '').trim();
    const label = String(meta?.label || '').trim();
    const marker = item.hasConditionalValues ? ' | لديه Conditional Values' : '';

    return `<tr>
      <td>
        ${label ? `<span class="remote-key-label">${escapeHtml(label)}</span>` : ''}
        <span class="remote-key-text">${escapeHtml(key)}</span>
        <span class="remote-meta">${escapeHtml(valueType)}${escapeHtml(marker)}</span>
      </td>
      <td>
        <input class="remote-value-input" data-remote-key="${escapeHtml(key)}" data-remote-type="${escapeHtml(valueType)}" type="text" value="${escapeHtml(value)}" />
        ${desc ? `<span class="remote-meta">${escapeHtml(desc)}</span>` : ''}
      </td>
    </tr>`;
  });

  setHtml(remoteConfigTable, `<table><thead><tr><th>المفتاح</th><th>القيمة</th></tr></thead><tbody>${rows.join('')}</tbody></table>`);
}

async function loadRolloutConfigUi() {
  if (!rolloutConfigResult) return;
  rolloutConfigResult.textContent = 'جاري تحميل إعدادات تشغيل المدن...';

  try {
    const response = await getAdminRemoteConfigSettings({ includeParameters: false });
    const rollout = response?.data?.rollout || {};

    if (rolloutEnabledInput) rolloutEnabledInput.checked = rollout.enabled === true;
    if (rolloutGuardKmInput) {
      rolloutGuardKmInput.value = String(Math.max(1, Math.min(500, Number(rollout.guardDistanceKm || 120))));
    }
    if (rolloutBlockMessageInput) {
      rolloutBlockMessageInput.value = String(rollout.blockMessage || 'لسه ما جيناكم في منطقتكم. قريبًا بإذن الله.');
    }

    rolloutSelectedCityIds = csvToRolloutSet(rollout.enabledCitiesCsv || '');
    syncRolloutCsvFromSet();
    renderRolloutCityList(rolloutCitySearchInput?.value || '');

    rolloutConfigResult.textContent = `تم تحميل الإعدادات. آخر تحديث: ${response?.data?.updatedAt || '-'}`;
  } catch (err) {
    rolloutConfigResult.textContent = `تعذر تحميل إعدادات المدن: ${err.message || err}`;
  }
}

async function loadRemoteConfigEditorUi() {
  if (!remoteConfigBulkResult) return;
  remoteConfigBulkResult.textContent = 'جاري تحميل مفاتيح Remote Config...';

  try {
    const response = await getAdminRemoteConfigSettings({ includeParameters: true });
    remoteConfigParametersCache = Array.isArray(response?.data?.parameters)
      ? response.data.parameters
      : [];
    fillAppRemoteConfigForm();
    fillPricingConfigForm();
    renderRemoteConfigTable(remoteConfigFilterInput?.value || '');
    remoteConfigBulkResult.textContent = `تم تحميل ${remoteConfigParametersCache.length} مفتاح. آخر تحديث: ${response?.data?.updatedAt || '-'}`;
    if (appRemoteConfigResult) {
      appRemoteConfigResult.textContent = 'تم تحميل إعدادات التحديث والروابط من Remote Config.';
    }
    if (pricingConfigResult) {
      pricingConfigResult.textContent = 'تم تحميل مفاتيح تسعير التوصيل من Remote Config.';
    }
  } catch (err) {
    remoteConfigBulkResult.textContent = `تعذر تحميل المفاتيح: ${err.message || err}`;
    if (appRemoteConfigResult) {
      appRemoteConfigResult.textContent = `تعذر تحميل إعدادات التحديث والروابط: ${err.message || err}`;
    }
    if (pricingConfigResult) {
      pricingConfigResult.textContent = `تعذر تحميل مفاتيح التسعير: ${err.message || err}`;
    }
  }
}

function mountAdmins() {
  if (hasAdminPermission('admins') && !addAdminFormBound) {
    addAdminForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = adminEmailInput.value.trim().toLowerCase();
      const permissions = adminPermissionInputs
        .filter((input) => input.checked)
        .map((input) => String(input.value || '').trim().toLowerCase())
        .filter((value) => ALL_ADMIN_PERMISSIONS.includes(value));
      if (!email) return;
      if (!permissions.length) {
        alert('اختر صلاحية واحدة على الأقل لهذا المسؤول.');
        return;
      }
      try {
        await setUserAdminRole({ email, active: true, permissions });
        adminEmailInput.value = '';
        adminPermissionInputs.forEach((input) => {
          input.checked = true;
        });
        alert('تم حفظ صلاحيات المسؤول بنجاح');
      } catch (err) {
        alert(`تعذر حفظ صلاحيات المسؤول: ${err.message}`);
      }
    });
    addAdminFormBound = true;
  }

  if (hasAdminPermission('config') && !normalizeStateFormBound && normalizeStateForm) {
    normalizeStateForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const parsed = Number(normalizeLimitInput?.value || 500);
      const limit = Number.isFinite(parsed)
        ? Math.max(1, Math.min(500, Math.floor(parsed)))
        : 500;

      if (normalizeStateResult) {
        normalizeStateResult.textContent = 'جاري تشغيل الترحيل...';
      }

      try {
        const response = await normalizeStateIdsBatch({
          collections: ['clients', 'restaurants', 'drivers'],
          limit,
        });
        const data = response?.data || {};
        const details = data.details || {};
        if (normalizeStateResult) {
          normalizeStateResult.textContent = [
            `تم التنفيذ بنجاح`,
            `المجموعات: ${(data.collections || []).join(', ')}`,
            `المفحوص: ${data.scanned ?? 0}`,
            `المحدّث: ${data.updated ?? 0}`,
            `المتجاوز: ${data.skipped ?? 0}`,
            `تفاصيل: ${JSON.stringify(details, null, 2)}`,
          ].join('\n');
        }
      } catch (err) {
        if (normalizeStateResult) {
          normalizeStateResult.textContent = `فشل التنفيذ: ${err.message || err}`;
        }
      }
    });
    normalizeStateFormBound = true;
  }

  if (hasAdminPermission('config') && !rolloutConfigFormBound && rolloutConfigForm) {
    rolloutConfigForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      syncRolloutSetFromCsv();

      const enabled = rolloutEnabledInput?.checked === true;
      const parsedGuard = Number(rolloutGuardKmInput?.value || 120);
      const guardDistanceKm = Number.isFinite(parsedGuard)
        ? Math.max(1, Math.min(500, Math.floor(parsedGuard)))
        : 120;
      const blockMessage = String(rolloutBlockMessageInput?.value || '').trim()
        || 'لسه ما جيناكم في منطقتكم. قريبًا بإذن الله.';
      const enabledCitiesCsv = setToCsv(rolloutSelectedCityIds);

      if (!enabledCitiesCsv) {
        if (rolloutConfigResult) {
          rolloutConfigResult.textContent = 'اختر مدينة واحدة على الأقل قبل الحفظ.';
        }
        return;
      }

      if (saveRolloutConfigBtn) saveRolloutConfigBtn.disabled = true;
      if (rolloutConfigResult) rolloutConfigResult.textContent = 'جارٍ حفظ إعدادات تشغيل المدن...';

      try {
        const result = await updateAdminRemoteConfigSettings({
          rollout: {
            enabled,
            guardDistanceKm,
            enabledCitiesCsv,
            blockMessage,
          },
        });

        if (rolloutConfigResult) {
          rolloutConfigResult.textContent = `تم الحفظ بنجاح. النسخة: ${result?.data?.version || '-'} | مفاتيح محدثة: ${result?.data?.touchedCount || 0}`;
        }
      } catch (err) {
        if (rolloutConfigResult) {
          rolloutConfigResult.textContent = `تعذر حفظ إعدادات المدن: ${err.message || err}`;
        }
      } finally {
        if (saveRolloutConfigBtn) saveRolloutConfigBtn.disabled = false;
      }
    });

    rolloutPresetSudanBtn?.addEventListener('click', () => {
      rolloutSelectedCityIds = new Set(SUDAN_CITY_OPTIONS.map((item) => item.id));
      syncRolloutCsvFromSet();
      renderRolloutCityList(rolloutCitySearchInput?.value || '');
    });

    rolloutSelectAllBtn?.addEventListener('click', () => {
      SUDAN_CITY_OPTIONS.forEach((item) => rolloutSelectedCityIds.add(item.id));
      syncRolloutCsvFromSet();
      renderRolloutCityList(rolloutCitySearchInput?.value || '');
    });

    rolloutClearAllBtn?.addEventListener('click', () => {
      rolloutSelectedCityIds = new Set();
      syncRolloutCsvFromSet();
      renderRolloutCityList(rolloutCitySearchInput?.value || '');
    });

    reloadRolloutConfigBtn?.addEventListener('click', () => {
      loadRolloutConfigUi();
    });

    rolloutCitySearchInput?.addEventListener('input', () => {
      renderRolloutCityList(rolloutCitySearchInput.value || '');
    });

    rolloutSelectedCitiesCsv?.addEventListener('input', () => {
      syncRolloutSetFromCsv();
      renderRolloutCityList(rolloutCitySearchInput?.value || '');
    });

    rolloutConfigFormBound = true;
  }

  if (hasAdminPermission('config') && !remoteConfigBulkFormBound && remoteConfigBulkForm) {
    remoteConfigFilterInput?.addEventListener('input', () => {
      renderRemoteConfigTable(remoteConfigFilterInput.value || '');
    });

    reloadRemoteConfigBulkBtn?.addEventListener('click', () => {
      loadRemoteConfigEditorUi();
    });

    remoteConfigBulkForm.addEventListener('submit', async (e) => {
      e.preventDefault();

      const updates = [];
      const currentMap = new Map(remoteConfigParametersCache.map((item) => [String(item.key), item]));
      remoteConfigTable?.querySelectorAll('[data-remote-key]').forEach((input) => {
        const key = String(input.getAttribute('data-remote-key') || '').trim();
        const valueType = String(input.getAttribute('data-remote-type') || 'STRING').trim().toUpperCase();
        if (!key) return;

        const current = currentMap.get(key);
        const nextValue = normalizeRemoteValueByType(input.value, valueType);
        const prevValue = normalizeRemoteValueByType(current?.value || '', valueType);
        if (nextValue === prevValue) return;

        updates.push({
          key,
          value: nextValue,
          valueType,
          description: REMOTE_CONFIG_METADATA[key]?.description || current?.description || '',
        });
      });

      if (!updates.length) {
        if (remoteConfigBulkResult) remoteConfigBulkResult.textContent = 'لا توجد تغييرات للحفظ.';
        return;
      }

      if (saveRemoteConfigBulkBtn) saveRemoteConfigBulkBtn.disabled = true;
      if (remoteConfigBulkResult) remoteConfigBulkResult.textContent = `جارٍ حفظ ${updates.length} تعديل...`;

      try {
        const result = await updateAdminRemoteConfigSettings({ parameters: updates });
        if (remoteConfigBulkResult) {
          remoteConfigBulkResult.textContent = `تم الحفظ بنجاح. النسخة: ${result?.data?.version || '-'} | مفاتيح محدثة: ${result?.data?.touchedCount || updates.length}`;
        }
        await loadRemoteConfigEditorUi();
      } catch (err) {
        if (remoteConfigBulkResult) {
          remoteConfigBulkResult.textContent = `تعذر حفظ مفاتيح Remote Config: ${err.message || err}`;
        }
      } finally {
        if (saveRemoteConfigBulkBtn) saveRemoteConfigBulkBtn.disabled = false;
      }
    });

    remoteConfigBulkFormBound = true;
  }

  if (hasAdminPermission('config') && !appRemoteConfigFormBound && appRemoteConfigForm) {
    reloadAppRemoteConfigBtn?.addEventListener('click', () => {
      loadRemoteConfigEditorUi();
    });

    appRemoteConfigForm.addEventListener('submit', async (e) => {
      e.preventDefault();

      const nextValues = {
        ops_force_update_enabled: normalizeRemoteValueByType(opsForceUpdateEnabledInput?.value || 'true', 'BOOLEAN'),
        ops_min_build_android: normalizeRemoteValueByType(opsMinBuildAndroidInput?.value || '0', 'NUMBER'),
        ops_update_message: normalizeRemoteValueByType(opsUpdateMessageInput?.value || '', 'STRING'),
        ops_update_url_android: normalizeRemoteValueByType(opsUpdateUrlAndroidInput?.value || '', 'STRING'),
        client_force_update_enabled: normalizeRemoteValueByType(clientForceUpdateEnabledInput?.value || 'true', 'BOOLEAN'),
        client_min_build_android: normalizeRemoteValueByType(clientMinBuildAndroidInput?.value || '11', 'NUMBER'),
        client_update_message: normalizeRemoteValueByType(clientUpdateMessageInput?.value || '', 'STRING'),
        client_update_url_android: normalizeRemoteValueByType(clientUpdateUrlAndroidInput?.value || '', 'STRING'),
        client_root_url: normalizeRemoteValueByType(clientRootUrlInput?.value || '', 'STRING'),
        store_force_update_enabled: normalizeRemoteValueByType(storeForceUpdateEnabledInput?.value || 'true', 'BOOLEAN'),
        store_min_build_android: normalizeRemoteValueByType(storeMinBuildAndroidInput?.value || '5', 'NUMBER'),
        store_update_message: normalizeRemoteValueByType(storeUpdateMessageInput?.value || '', 'STRING'),
        store_update_url_android: normalizeRemoteValueByType(storeUpdateUrlAndroidInput?.value || '', 'STRING'),
        store_root_url: normalizeRemoteValueByType(storeRootUrlInput?.value || '', 'STRING'),
        courier_force_update_enabled: normalizeRemoteValueByType(courierForceUpdateEnabledInput?.value || 'false', 'BOOLEAN'),
        courier_min_build_android: normalizeRemoteValueByType(courierMinBuildAndroidInput?.value || '1', 'NUMBER'),
        courier_update_message: normalizeRemoteValueByType(courierUpdateMessageInput?.value || '', 'STRING'),
        courier_update_url_android: normalizeRemoteValueByType(courierUpdateUrlAndroidInput?.value || '', 'STRING'),
        courier_root_url: normalizeRemoteValueByType(courierRootUrlInput?.value || '', 'STRING'),
      };

      const updates = APP_REMOTE_KEYS
        .map((key) => {
          const current = getRemoteConfigEntry(key);
          const nextValue = nextValues[key];
          const valueType = String(REMOTE_CONFIG_METADATA[key]?.valueType || current?.valueType || 'STRING').toUpperCase();
          const prevValue = normalizeRemoteValueByType(current?.value || '', valueType);
          if (nextValue === prevValue) return null;
          return {
            key,
            value: nextValue,
            valueType,
            description: REMOTE_CONFIG_METADATA[key]?.description || current?.description || '',
          };
        })
        .filter(Boolean);

      if (!updates.length) {
        if (appRemoteConfigResult) appRemoteConfigResult.textContent = 'لا توجد تغييرات جديدة في إعدادات التحديث والروابط.';
        return;
      }

      if (saveAppRemoteConfigBtn) saveAppRemoteConfigBtn.disabled = true;
      if (appRemoteConfigResult) appRemoteConfigResult.textContent = `جارٍ حفظ ${updates.length} إعدادًا...`;

      try {
        const result = await updateAdminRemoteConfigSettings({ parameters: updates });
        if (appRemoteConfigResult) {
          appRemoteConfigResult.textContent = `تم حفظ إعدادات التحديث والروابط بنجاح. النسخة: ${result?.data?.version || '-'} | مفاتيح محدثة: ${result?.data?.touchedCount || updates.length}`;
        }
        await loadRemoteConfigEditorUi();
      } catch (err) {
        if (appRemoteConfigResult) {
          appRemoteConfigResult.textContent = `تعذر حفظ إعدادات التحديث والروابط: ${err.message || err}`;
        }
      } finally {
        if (saveAppRemoteConfigBtn) saveAppRemoteConfigBtn.disabled = false;
      }
    });

    appRemoteConfigFormBound = true;
  }

  if (hasAdminPermission('config') && !pricingConfigFormBound && pricingConfigForm) {
    reloadPricingConfigBtn?.addEventListener('click', () => {
      loadRemoteConfigEditorUi();
    });

    pricingConfigForm.addEventListener('submit', async (e) => {
      e.preventDefault();

      const nextValues = {
        pricing_client_delivery_base_fee: normalizeRemoteValueByType(pricingClientBaseFeeInput?.value || '5000', 'NUMBER'),
        pricing_client_delivery_base_distance_km: normalizeRemoteValueByType(pricingClientBaseDistanceInput?.value || '6', 'NUMBER'),
        pricing_client_delivery_extra_per_km: normalizeRemoteValueByType(pricingClientExtraPerKmInput?.value || '700', 'NUMBER'),
        pricing_driver_delivery_base_fee: normalizeRemoteValueByType(pricingDriverBaseFeeInput?.value || '4000', 'NUMBER'),
        pricing_driver_delivery_base_distance_km: normalizeRemoteValueByType(pricingDriverBaseDistanceInput?.value || '6', 'NUMBER'),
        pricing_driver_delivery_extra_per_km: normalizeRemoteValueByType(pricingDriverExtraPerKmInput?.value || '500', 'NUMBER'),
        pricing_large_item_fee_enabled: normalizeRemoteValueByType(pricingLargeItemFeeEnabledInput?.value || 'true', 'BOOLEAN'),
        pricing_large_item_threshold: normalizeRemoteValueByType(pricingLargeItemThresholdInput?.value || '10000', 'NUMBER'),
        pricing_large_item_fee_base: normalizeRemoteValueByType(pricingLargeItemFeeBaseInput?.value || '500', 'NUMBER'),
        pricing_large_item_step_amount: normalizeRemoteValueByType(pricingLargeItemStepAmountInput?.value || '5000', 'NUMBER'),
        pricing_large_item_step_fee: normalizeRemoteValueByType(pricingLargeItemStepFeeInput?.value || '500', 'NUMBER'),
        pricing_large_item_fee_cap_per_unit: normalizeRemoteValueByType(pricingLargeItemFeeCapPerUnitInput?.value || '2500', 'NUMBER'),
      };

      const updates = PRICING_REMOTE_KEYS
        .map((key) => {
          const current = getRemoteConfigEntry(key);
          const nextValue = nextValues[key];
          const valueType = String(REMOTE_CONFIG_METADATA[key]?.valueType || current?.valueType || 'NUMBER').toUpperCase();
          const prevValue = normalizeRemoteValueByType(current?.value || '', valueType);
          if (nextValue === prevValue) return null;
          return {
            key,
            value: nextValue,
            valueType,
            description: REMOTE_CONFIG_METADATA[key]?.description || '',
          };
        })
        .filter(Boolean);

      if (!updates.length) {
        if (pricingConfigResult) pricingConfigResult.textContent = 'لا توجد تغييرات جديدة في تسعير التوصيل.';
        return;
      }

      if (savePricingConfigBtn) savePricingConfigBtn.disabled = true;
      if (pricingConfigResult) pricingConfigResult.textContent = `جارٍ حفظ ${updates.length} مفتاح تسعير...`;

      try {
        const result = await updateAdminRemoteConfigSettings({ parameters: updates });
        if (pricingConfigResult) {
          pricingConfigResult.textContent = `تم حفظ إعدادات التسعير بنجاح. النسخة: ${result?.data?.version || '-'} | مفاتيح محدثة: ${result?.data?.touchedCount || updates.length}`;
        }
        await loadRemoteConfigEditorUi();
      } catch (err) {
        if (pricingConfigResult) {
          pricingConfigResult.textContent = `تعذر حفظ مفاتيح التسعير: ${err.message || err}`;
        }
      } finally {
        if (savePricingConfigBtn) savePricingConfigBtn.disabled = false;
      }
    });

    pricingConfigFormBound = true;
  }

  if (hasAdminPermission('config')) {
    renderRolloutCityList(rolloutCitySearchInput?.value || '');
    syncRolloutCsvFromSet();
    loadRolloutConfigUi();
    loadRemoteConfigEditorUi();
  }

  if (hasAdminPermission('admins')) {
    unsubscribers.push(
      onSnapshot(collection(db, 'admins'), (snap) => {
        const rows = snap.docs
          .map((d) => {
            const data = d.data() || {};
            const isActive = data.active === true || data.role === 'admin';
            const permissionsSummary = formatAdminPermissionsSummary(data.permissions);
            return `<tr>
              <td>${data.email || '-'}</td>
              <td>${data.uid || d.id}</td>
              <td>${data.role || '-'}</td>
              <td>${escapeHtml(permissionsSummary || 'كامل')}</td>
              <td><span class="badge ${isActive ? 'closed' : 'open'}">${isActive ? 'نشط' : 'غير نشط'}</span></td>
            </tr>`;
          });
        setHtml(adminsTable, table(['البريد', 'UID', 'الدور', 'الصلاحيات', 'الحالة'], rows));
      })
    );
  }

}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function formatUnifiedOrderCode(orderNumber, orderId, docId) {
  const normalize = (value, shortenFallback = false) => {
    let raw = String(value ?? '').trim();
    if (!raw) return '';

    if (raw.startsWith('#')) {
      raw = raw.slice(1).trim();
    }

    if (/^ord[\s_-]*/i.test(raw)) {
      const tail = raw.replace(/^ord[\s_-]*/i, '').trim();
      return tail ? `ORD-${tail}` : 'ORD-000000';
    }

    if (shortenFallback && raw.length > 8) {
      raw = raw.slice(0, 8);
    }

    return `ORD-${raw}`;
  };

  const fromOrderNumber = normalize(orderNumber);
  if (fromOrderNumber) return fromOrderNumber;

  const fromOrderId = normalize(orderId);
  if (fromOrderId) return fromOrderId;

  const fromDocId = normalize(docId, true);
  if (fromDocId) return fromDocId;

  return 'ORD-000000';
}

function getByPath(source, path) {
  if (!source || !path) return undefined;
  return path.split('.').reduce((acc, key) => (acc ? acc[key] : undefined), source);
}

function normalizeGeo(value) {
  if (!value) return null;
  const latitude = Number(value.latitude ?? value.lat ?? value._latitude);
  const longitude = Number(value.longitude ?? value.lng ?? value.lon ?? value._longitude);
  if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
    return { lat: latitude, lng: longitude };
  }
  return null;
}

function normalizeNumber(value) {
  if (value === null || value === undefined) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeGeoFromPair(latRaw, lngRaw) {
  const lat = normalizeNumber(latRaw);
  const lng = normalizeNumber(lngRaw);
  if (lat == null || lng == null) return null;
  return { lat, lng };
}

function extractGeo(data, paths) {
  for (const path of paths) {
    const raw = getByPath(data, path);
    const geo = normalizeGeo(raw);
    if (geo) return geo;
  }
  return null;
}

function extractGeoByPairs(data, pairs) {
  for (const pair of pairs) {
    const latRaw = getByPath(data, pair[0]);
    const lngRaw = getByPath(data, pair[1]);
    const geo = normalizeGeoFromPair(latRaw, lngRaw);
    if (geo) return geo;
  }
  return null;
}

function getRestaurantGeo(restaurantId, restaurantData) {
  const directGeo = extractGeo(restaurantData, [
    'location',
    'currentLocation',
    'address.location',
    'defaultAddress.location',
    'selectedAddress.location',
  ]);
  if (directGeo) return directGeo;

  const pairGeo = extractGeoByPairs(restaurantData, [
    ['latitude', 'longitude'],
    ['lat', 'lng'],
    ['address.latitude', 'address.longitude'],
    ['defaultAddress.latitude', 'defaultAddress.longitude'],
    ['selectedAddress.latitude', 'selectedAddress.longitude'],
  ]);
  if (pairGeo) return pairGeo;

  const addresses = mapState.restaurantAddresses.get(restaurantId);
  if (addresses && addresses.size) {
    const preferredId = String(restaurantData?.defaultAddressId || '').trim();
    if (preferredId && addresses.has(preferredId)) {
      return addresses.get(preferredId).geo;
    }
    const firstAddress = addresses.values().next().value;
    if (firstAddress?.geo) return firstAddress.geo;
  }

  return null;
}

function syncMapUiStateFromInputs() {
  mapUiState.orderStatus = String(mapOrderStatusFilter?.value || 'active');
  mapUiState.style = String(mapStyleSelect?.value || 'voyager');
  mapUiState.showDrivers = mapLayerDriversInput ? mapLayerDriversInput.checked : true;
  mapUiState.showClients = mapLayerClientsInput ? mapLayerClientsInput.checked : true;
  mapUiState.showRestaurants = mapLayerRestaurantsInput ? mapLayerRestaurantsInput.checked : true;
  mapUiState.showOrders = mapLayerOrdersInput ? mapLayerOrdersInput.checked : true;
  mapUiState.followSelectedOrder = mapFollowSelectedOrderInput ? mapFollowSelectedOrderInput.checked : false;
  mapUiState.pinDetails = mapPinDetailsInput ? mapPinDetailsInput.checked : false;
}

function requestRefreshMapLayers() {
  clearTimeout(mapRefreshTimer);
  mapRefreshTimer = setTimeout(() => {
    refreshMapLayers();
  }, 70);
}

function applyMapBaseLayer() {
  if (!liveMap || !window.L) return;
  const preset = MAP_STYLE_PRESETS[mapUiState.style] || MAP_STYLE_PRESETS.voyager;
  if (mapBaseLayer) {
    liveMap.removeLayer(mapBaseLayer);
  }
  if (mapOverlayLayer) {
    liveMap.removeLayer(mapOverlayLayer);
    mapOverlayLayer = null;
  }
  mapBaseLayer = window.L.tileLayer(preset.url, {
    maxZoom: 19,
    subdomains: preset.subdomains,
    attribution: preset.attribution
  });
  mapBaseLayer.addTo(liveMap);
  if (preset.overlay) {
    mapOverlayLayer = window.L.tileLayer(preset.overlay.url, {
      maxZoom: 19,
      subdomains: preset.overlay.subdomains || 'abc',
      opacity: preset.overlay.opacity ?? 1,
      attribution: preset.overlay.attribution || ''
    });
    mapOverlayLayer.addTo(liveMap);
  }
}

function updateMapFullscreenButton() {
  if (!mapFullscreenBtn) return;
  const isFullscreen = document.fullscreenElement === mapViewport;
  mapFullscreenBtn.textContent = isFullscreen ? 'إنهاء الشاشة الكاملة' : 'شاشة كاملة';
}

async function toggleMapFullscreen() {
  if (!mapViewport) return;
  if (document.fullscreenElement === mapViewport) {
    await document.exitFullscreen();
  } else {
    await mapViewport.requestFullscreen();
  }
  updateMapFullscreenButton();
  setTimeout(() => {
    if (liveMap) liveMap.invalidateSize();
  }, 180);
}

function normalizeMapOrderStatusValue(order) {
  return String(order?.orderStatus || order?.status || '').trim().toLowerCase();
}

function matchesMapOrderFilter(order) {
  const selectedStatus = String(mapUiState.orderStatus || 'active');
  if (selectedStatus === 'active') return isActiveOrder(order);
  return normalizeMapOrderStatusValue(order) === selectedStatus;
}

function shouldDisplayMapLayer(layerName) {
  if (layerName === 'drivers') return mapUiState.showDrivers;
  if (layerName === 'clients') return mapUiState.showClients;
  if (layerName === 'restaurants') return mapUiState.showRestaurants;
  if (layerName === 'orders') return mapUiState.showOrders;
  return true;
}

function updateMapSelectionBanner(text) {
  if (!mapSelectionBanner) return;
  mapSelectionBanner.textContent = text || 'لا يوجد عنصر مثبت حاليًا.';
}

function formatMapSelectionLabel(selection) {
  if (!selection) return 'لا يوجد عنصر مثبت حاليًا.';
  const pinnedLabel = mapUiState.pinDetails ? ' | البطاقة مثبتة' : '';
  return `${selection.label || 'عنصر محدد'}${pinnedLabel}`;
}

function pushMapEvent(entry) {
  if (!entry) return;
  mapUiState.events = [entry, ...mapUiState.events]
    .slice(0, 8);
  renderMapEventFeed();
}

function renderMapEventFeed() {
  if (!mapEventFeed) return;
  if (!mapUiState.events.length) {
    mapEventFeed.innerHTML = '<div class="muted">لا توجد أحداث جديدة بعد. سيتم عرض آخر التغيرات هنا.</div>';
    return;
  }
  setHtml(
    mapEventFeed,
    mapUiState.events.map((event) => `
      <div class="map-event-item">
        <div class="map-event-dot" data-level="${escapeHtml(event.level || 'info')}"></div>
        <div>
          <strong>${escapeHtml(event.title || 'حدث جديد')}</strong>
          <span>${escapeHtml(event.description || '')}</span>
        </div>
        <button class="btn ghost" type="button" data-map-event-type="${escapeHtml(event.type || '')}" data-map-event-id="${escapeHtml(event.id || '')}">فتح</button>
      </div>
    `).join('')
  );
  mapEventFeed.querySelectorAll('[data-map-event-type]').forEach((button) => {
    button.addEventListener('click', () => {
      const type = button.getAttribute('data-map-event-type');
      const id = button.getAttribute('data-map-event-id');
      if (!type || !id) return;
      focusMapSearchEntity(type, id);
    });
  });
}

function describeRestaurantMapGap(restaurantId, restaurantData) {
  const reasons = [];
  const addresses = mapState.restaurantAddresses.get(restaurantId);
  if (!extractGeo(restaurantData, ['location', 'currentLocation', 'address.location', 'defaultAddress.location', 'selectedAddress.location'])
    && !extractGeoByPairs(restaurantData, [
      ['latitude', 'longitude'],
      ['lat', 'lng'],
      ['address.latitude', 'address.longitude'],
      ['defaultAddress.latitude', 'defaultAddress.longitude'],
      ['selectedAddress.latitude', 'selectedAddress.longitude'],
    ])) {
    reasons.push('لا يوجد موقع في السجل الرئيسي');
  }
  if (!addresses || !addresses.size) {
    reasons.push('لا توجد عناوين فرعية مرتبطة');
  }
  if (addresses && addresses.size && !getRestaurantGeo(restaurantId, restaurantData)) {
    reasons.push('العناوين الفرعية لا تحتوي إحداثيات صالحة');
  }
  return reasons;
}

function bindMapDetailsActions() {
  if (!mapDetails) return;
  mapDetails.querySelectorAll('[data-map-toggle-pin-details]').forEach((button) => {
    button.addEventListener('click', () => {
      if (mapPinDetailsInput) {
        mapPinDetailsInput.checked = !mapPinDetailsInput.checked;
      }
      syncMapUiStateFromInputs();
      updateMapSelectionBanner(formatMapSelectionLabel(currentMapSelection));
    });
  });
  mapDetails.querySelectorAll('[data-map-focus-order]').forEach((button) => {
    button.addEventListener('click', () => {
      const orderId = button.getAttribute('data-map-focus-order');
      if (orderId) {
        focusMapOnOrder(orderId);
      }
    });
  });
  mapDetails.querySelectorAll('[data-map-open-order-workspace]').forEach((button) => {
    button.addEventListener('click', () => {
      const orderId = button.getAttribute('data-map-open-order-workspace');
      if (orderId) {
        openOrdersWorkspace(orderId);
      }
    });
  });
  mapDetails.querySelectorAll('[data-map-open-store]').forEach((button) => {
    button.addEventListener('click', async () => {
      const storeId = button.getAttribute('data-map-open-store');
      if (!storeId) return;
      activateTab('management');
      activateSubpanel('management', 'management-stores');
      await loadStoreDetails(storeId);
    });
  });
  mapDetails.querySelectorAll('[data-map-open-driver]').forEach((button) => {
    button.addEventListener('click', async () => {
      const driverId = button.getAttribute('data-map-open-driver');
      if (!driverId) return;
      activateTab('management');
      activateSubpanel('management', 'management-couriers');
      await loadCourierDetails(driverId);
    });
  });
  mapDetails.querySelectorAll('[data-map-open-client]').forEach((button) => {
    button.addEventListener('click', async () => {
      const clientId = button.getAttribute('data-map-open-client');
      if (!clientId) return;
      openOrdersWorkspace();
      await loadClientDetails(clientId);
    });
  });
}

function setMapDetails(html, options = {}) {
  if (!mapDetails) return;
  const actions = `
    <div class="map-details-actions">
      <button class="btn ghost" type="button" data-map-toggle-pin-details>${mapUiState.pinDetails ? 'إلغاء تثبيت البطاقة' : 'تثبيت البطاقة'}</button>
      ${options.orderId ? `<button class="btn ghost" type="button" data-map-focus-order="${escapeHtml(options.orderId)}">إعادة تتبع الطلب</button>` : ''}
      ${options.orderId ? `<button class="btn primary" type="button" data-map-open-order-workspace="${escapeHtml(options.orderId)}">فتح مكتب الطلبات</button>` : ''}
    </div>
  `;
  mapDetails.innerHTML = `<div class="map-details-card">${html}${actions}</div>`;
  bindMapDetailsActions();
  if (options.selection) {
    currentMapSelection = options.selection;
    updateMapSelectionBanner(formatMapSelectionLabel(currentMapSelection));
  }
}

function renderCurrentMapSelection() {
  if (!currentMapSelection) return;
  const selection = currentMapSelection;
  if (selection.type === 'order') {
    const orderData = mapState.orders.get(selection.id)?.data;
    if (orderData) {
      renderOrderDetails(orderData, selection.id);
    }
    return;
  }
  if (selection.type === 'driver') {
    const data = mapState.drivers.get(selection.id)?.data;
    if (data) renderEntityDetails('driver', selection.id, data);
    return;
  }
  if (selection.type === 'client') {
    const data = mapState.clients.get(selection.id)?.data;
    if (data) renderEntityDetails('client', selection.id, data);
    return;
  }
  if (selection.type === 'restaurant') {
    const data = mapState.restaurants.get(selection.id)?.data || selection.fallbackData;
    if (data) {
      renderEntityDetails('restaurant', selection.id, data, selection.context || null);
    }
  }
}

function setMapLegendSummary(text) {
  if (!mapLegendBar) return;
  mapLegendBar.textContent = text;
}

function refreshMapLegendSummary() {
  const hiddenReasonCounts = mapUiState.hiddenRestaurants.reduce((acc, item) => {
    (item.reasons || []).forEach((reason) => {
      acc[reason] = (acc[reason] || 0) + 1;
    });
    return acc;
  }, {});
  const totalDrivers = mapState.drivers.size;
  const availableDrivers = Array.from(mapState.drivers.values())
    .filter(({ data }) => data.isAvailable === true || data.available === true || String(data.availabilityStatus || '').toLowerCase() === 'available')
    .length;
  const activeOrders = Array.from(mapState.orders.values()).filter(({ data }) => matchesMapOrderFilter(data)).length;
  const totalRestaurants = mapState.restaurants.size;
  const visibleRestaurants = markerState.restaurants.size;
  const hiddenRestaurants = Math.max(0, totalRestaurants - visibleRestaurants);
  const totalClients = mapState.clients.size;
  const hiddenSummary = Object.entries(hiddenReasonCounts)
    .slice(0, 2)
    .map(([reason, count]) => `${reason}: ${count}`)
    .join(' | ');

  if (mapMetrics) {
    mapMetrics.innerHTML = `
      <div class="map-metric"><span>الطلبات النشطة</span><strong>${activeOrders}</strong></div>
      <div class="map-metric"><span>المندوبون المتاحون</span><strong>${availableDrivers}/${totalDrivers}</strong></div>
      <div class="map-metric"><span>المطاعم الظاهرة</span><strong>${visibleRestaurants}/${totalRestaurants}</strong></div>
      <div class="map-metric"><span>فلتر الحالة</span><strong>${escapeHtml(MAP_ORDER_STATUS_LABELS[mapUiState.orderStatus] || 'نشط')}</strong></div>
    `;
  }

  setMapLegendSummary(
    `طلبات مطابقة: ${activeOrders} | مندوبون متاحون: ${availableDrivers}/${totalDrivers} | مطاعم ظاهرة: ${visibleRestaurants}/${totalRestaurants} | مطاعم مخفية: ${hiddenRestaurants} | عملاء نشطون: ${totalClients}${hiddenSummary ? ` | أسباب الإخفاء: ${hiddenSummary}` : ''}`
  );
}

function fitMapToLatLngs(latLngs, maxZoom = 15) {
  if (!liveMap || !Array.isArray(latLngs) || !latLngs.length) return;

  if (latLngs.length === 1) {
    liveMap.setView(latLngs[0], maxZoom, { animate: true });
    return;
  }

  const bounds = window.L.latLngBounds(latLngs);
  liveMap.fitBounds(bounds.pad(0.18), { animate: true, maxZoom });
}

function fitMapByScope(scope) {
  activateTab('map');
  const selectedScope = String(scope || 'all');
  const targetGroups = selectedScope === 'drivers'
    ? [markerState.drivers]
    : selectedScope === 'restaurants'
      ? [markerState.restaurants]
      : selectedScope === 'orders'
        ? [markerState.orders]
        : [markerState.drivers, markerState.clients, markerState.restaurants, markerState.orders];

  const latLngs = [];
  targetGroups.forEach((group) => {
    group.forEach((marker) => {
      const latLng = marker.getLatLng();
      if (latLng) latLngs.push(latLng);
    });
  });

  fitMapToLatLngs(latLngs);
}

function focusMapSearchEntity(type, id) {
  const exec = () => {
    if (type === 'order') {
      openOrderOnMap(id);
      return;
    }

    const isDriver = type === 'driver';
    const isClient = type === 'client';
    const markerGroup = isDriver
      ? markerState.drivers
      : isClient
        ? markerState.clients
        : markerState.restaurants;
    const marker = markerGroup.get(id);

    if (marker && liveMap) {
      liveMap.setView(marker.getLatLng(), 16, { animate: true });
      marker.openPopup();
    }

    if (isDriver) {
      const data = mapState.drivers.get(id)?.data;
      if (data) renderEntityDetails('driver', id, data);
      return;
    }

    if (isClient) {
      const data = mapState.clients.get(id)?.data;
      if (data) renderEntityDetails('client', id, data);
      return;
    }

    const data = mapState.restaurants.get(id)?.data;
    if (data) {
      renderEntityDetails('restaurant', id, data);
    }
  };

  activateTab('map');
  setTimeout(exec, 180);
}

function renderMapSearchResults() {
  if (!mapSearchResults) return;
  const query = String(mapSearchInput?.value || '').trim().toLowerCase();

  if (!query) {
    mapSearchResults.innerHTML = '';
    return;
  }

  const matches = [];

  mapState.orders.forEach(({ data }, id) => {
    if (!shouldDisplayMapLayer('orders') || !matchesMapOrderFilter(data)) return;
    const searchText = [
      formatUnifiedOrderCode(data.orderNumber, data.orderId, id),
      data.clientName,
      data.restaurantName,
      data.restaurantId,
      data.clientId,
      data.status,
      data.orderStatus,
    ].join(' ').toLowerCase();
    if (!searchText.includes(query)) return;
    matches.push({
      type: 'order',
      id,
      title: `طلب ${formatUnifiedOrderCode(data.orderNumber, data.orderId, id)}`,
      subtitle: `${String(data.restaurantName || data.restaurantId || 'مطعم غير محدد')} - ${String(data.clientName || data.clientId || 'عميل غير محدد')}`,
    });
  });

  mapState.restaurants.forEach(({ data }, id) => {
    if (!shouldDisplayMapLayer('restaurants')) return;
    const searchText = [data.name, data.phone, data.city, data.address, id].join(' ').toLowerCase();
    if (!searchText.includes(query)) return;
    matches.push({
      type: 'restaurant',
      id,
      title: String(data.name || id),
      subtitle: `مطعم - ${String(data.phone || 'بدون هاتف')}`,
    });
  });

  mapState.drivers.forEach(({ data }, id) => {
    if (!shouldDisplayMapLayer('drivers')) return;
    const searchText = [data.name, data.phone, data.email, id].join(' ').toLowerCase();
    if (!searchText.includes(query)) return;
    matches.push({
      type: 'driver',
      id,
      title: String(data.name || id),
      subtitle: `مندوب - ${String(data.phone || 'بدون هاتف')}`,
    });
  });

  mapState.clients.forEach(({ data }, id) => {
    if (!shouldDisplayMapLayer('clients')) return;
    const searchText = [data.name, data.phone, data.email, id].join(' ').toLowerCase();
    if (!searchText.includes(query)) return;
    matches.push({
      type: 'client',
      id,
      title: String(data.name || id),
      subtitle: `عميل - ${String(data.phone || 'بدون هاتف')}`,
    });
  });

  const limitedMatches = matches.slice(0, 8);
  if (!limitedMatches.length) {
    mapSearchResults.innerHTML = '<div class="muted">لا توجد نتيجة مطابقة داخل الخريطة.</div>';
    return;
  }

  setHtml(
    mapSearchResults,
    limitedMatches.map((match) => `
      <div class="map-search-item ${currentMapSelection?.type === match.type && currentMapSelection?.id === match.id ? 'active' : ''}">
        <div>
          <div class="map-search-item-meta"><span class="map-search-badge" data-kind="${escapeHtml(match.type)}">${escapeHtml(match.type === 'order' ? 'طلب' : match.type === 'restaurant' ? 'مطعم' : match.type === 'driver' ? 'مندوب' : 'عميل')}</span></div>
          <b>${escapeHtml(match.title)}</b>
          <span>${escapeHtml(match.subtitle)}</span>
        </div>
        <button class="btn ghost" type="button" data-map-search-type="${escapeHtml(match.type)}" data-map-search-id="${escapeHtml(match.id)}">تمركز</button>
      </div>
    `).join('')
  );

  mapSearchResults.querySelectorAll('[data-map-search-type]').forEach((button) => {
    button.addEventListener('click', () => {
      const type = button.getAttribute('data-map-search-type');
      const id = button.getAttribute('data-map-search-id');
      if (!type || !id) return;
      focusMapSearchEntity(type, id);
    });
  });
}

async function backfillRestaurantAddressesForMissingRestaurants() {
  if (mapAddressBackfillInProgress) return;

  const missingIds = [];
  mapState.restaurants.forEach(({ data }, id) => {
    const geo = getRestaurantGeo(id, data);
    if (!geo) missingIds.push(id);
  });

  if (!missingIds.length) return;
  mapAddressBackfillInProgress = true;

  try {
    await Promise.all(
      missingIds.map(async (restaurantId) => {
        const snap = await safeGetDocs(collection(db, 'restaurants', restaurantId, 'addresses'));
        if (!snap?.docs?.length) return;

        const byRestaurant = mapState.restaurantAddresses.get(restaurantId) || new Map();
        snap.docs.forEach((addressDoc) => {
          const data = addressDoc.data() || {};
          const geo = normalizeGeo(data.location)
            || normalizeGeoFromPair(data.latitude, data.longitude)
            || normalizeGeoFromPair(data.lat, data.lng);
          if (!geo) return;
          byRestaurant.set(addressDoc.id, { geo, data });
        });

        if (byRestaurant.size) {
          mapState.restaurantAddresses.set(restaurantId, byRestaurant);
        }
      })
    );
  } finally {
    mapAddressBackfillInProgress = false;
  }

  requestRefreshMapLayers();
}

function refreshMapViewport() {
  if (!liveMap || mapAutoFitted) return;

  const latLngs = [];
  [markerState.drivers, markerState.clients, markerState.restaurants, markerState.orders].forEach((group) => {
    group.forEach((marker) => {
      const pos = marker.getLatLng();
      if (pos) latLngs.push(pos);
    });
  });

  if (!latLngs.length) return;

  try {
    const bounds = window.L.latLngBounds(latLngs);
    liveMap.fitBounds(bounds.pad(0.12), { maxZoom: 14, animate: false });
  } catch (_) {
  }
}

function normalizeOrderStatus(status) {
  return String(status || '').toLowerCase();
}

function isActiveOrder(order) {
  const status = normalizeOrderStatus(order.status || order.orderStatus);
  if (!status) return true;
  return ![
    'delivered',
    'completed',
    'cancelled',
    'canceled',
    'rejected',
    'failed'
  ].includes(status);
}

function canDisplayOrderOnMap(orderData, orderId) {
  if (isActiveOrder(orderData)) return true;
  return Boolean(allowCompletedSelectedOrderOnMap && selectedOrderOnMapId && selectedOrderOnMapId === orderId);
}

function clearSelectedOrderOnMap() {
  selectedOrderOnMapId = '';
  allowCompletedSelectedOrderOnMap = false;
  if (currentMapSelection?.type === 'order') {
    currentMapSelection = null;
    updateMapSelectionBanner('لا يوجد عنصر مثبت حاليًا.');
  }
}

function activeOrdersFor(fn) {
  return Array.from(mapState.orders.values()).filter((order) => isActiveOrder(order.data) && fn(order.data));
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

function getOrderTrackingInsight(orderData, restaurantGeo, driverGeo, clientGeo) {
  const status = String(orderData.orderStatus || orderData.status || '').trim();
  if (!driverGeo) {
    return `لا يوجد مندوب مخصص حالياً. الحالة الحالية: ${status || 'غير محددة'}.`;
  }

  if (!restaurantGeo || !clientGeo) {
    return 'موقع المطعم أو العميل غير مكتمل، المتابعة الجزئية فقط متاحة.';
  }

  const driverToRestaurantKm = haversineKm(driverGeo.lat, driverGeo.lng, restaurantGeo.lat, restaurantGeo.lng);
  const driverToClientKm = haversineKm(driverGeo.lat, driverGeo.lng, clientGeo.lat, clientGeo.lng);

  if (status === 'pickup_ready' || status === 'courier_assigned' || status === 'courier_offer_pending') {
    return `المندوب يقترب من المطعم. المسافة التقريبية إلى المطعم: ${driverToRestaurantKm.toFixed(2)} كم.`;
  }

  if (status === 'picked_up' || status === 'arrived_to_client') {
    return `الطلب في طريقه للعميل. المسافة التقريبية بين المندوب والعميل: ${driverToClientKm.toFixed(2)} كم.`;
  }

  if (status === 'delivered' || status === 'تم التوصيل') {
    return 'الطلب مكتمل (تم التسليم).';
  }

  return `المتابعة نشطة. مسافة المندوب للمطعم: ${driverToRestaurantKm.toFixed(2)} كم، وللعميل: ${driverToClientKm.toFixed(2)} كم.`;
}

function describeOrderRouteState(points) {
  const routeKey = buildRouteKey(points);
  if (mapRouteCache.has(routeKey)) {
    return 'مسار فعلي على الطرق';
  }
  if (mapRoutePending.has(routeKey)) {
    return 'جارٍ جلب المسار الفعلي';
  }
  if (mapRouteFailures.has(routeKey)) {
    return 'تعذر جلب المسار الفعلي، تم استخدام خط تقريبي';
  }
  return points.length > 1 ? 'سيتم رسم المسار الفعلي عند التحديث' : 'نقاط المسار غير مكتملة';
}

function renderOrderDetails(orderData, orderId) {
  const clientId = orderData.clientId || '';
  const restaurantId = orderData.restaurantId || '';
  const driverId = orderData.assignedDriverId || '';
  const client = clientId ? mapState.clients.get(clientId)?.data : null;
  const restaurant = restaurantId ? mapState.restaurants.get(restaurantId)?.data : null;
  const driver = driverId ? mapState.drivers.get(driverId)?.data : null;

  const items = Array.isArray(orderData.items)
    ? orderData.items
        .slice(0, 7)
        .map((item) => `<li>${escapeHtml(item?.name || item?.title || 'عنصر')} × ${escapeHtml(item?.quantity ?? 1)}</li>`)
        .join('')
    : '<li>لا توجد عناصر مفصلة</li>';

  const restaurantGeo = getRestaurantGeoByOrder(orderData);
  const driverGeo = getDriverGeoByOrder(orderData);
  const clientGeo = getClientGeoByOrder(orderData);
  const trackingInsight = getOrderTrackingInsight(orderData, restaurantGeo, driverGeo, clientGeo);
  const routeSummary = [
    restaurant?.name || orderData.restaurantName || restaurantId || 'مطعم غير محدد',
    driver?.name || driverId || 'بدون مندوب',
    client?.name || orderData.clientName || clientId || 'عميل غير محدد',
  ];
  const routeAddressSummary = [
    orderData.restaurantAddress || restaurant?.address || restaurant?.city || 'موقع المطعم غير مكتمل',
    orderData.deliveryAddress || orderData.address || client?.address || 'عنوان العميل غير مكتمل',
  ];
  const routeSourcePoints = [];
  if (restaurantGeo) routeSourcePoints.push([restaurantGeo.lat, restaurantGeo.lng]);
  if (driverGeo) routeSourcePoints.push([driverGeo.lat, driverGeo.lng]);
  if (clientGeo) routeSourcePoints.push([clientGeo.lat, clientGeo.lng]);
  const routeStateLabel = describeOrderRouteState(routeSourcePoints);
  const missingPieces = [
    restaurantGeo ? '' : 'المطعم بلا موقع صالح',
    driverId && !driverGeo ? 'المندوب المعين لا يرسل موقعًا حاليًا' : '',
    clientGeo ? '' : 'العميل بلا نقطة توصيل واضحة',
  ].filter(Boolean);

  setMapDetails(`
    <div class="map-order-head">
      <div>
        <h4>تفاصيل الطلب ${escapeHtml(formatUnifiedOrderCode(orderData.orderNumber, orderData.orderId, orderId))}</h4>
        <div class="map-order-route-strip">
          <span class="map-route-node map-route-node--store">${escapeHtml(routeSummary[0])}</span>
          <span class="map-route-arrow">←</span>
          <span class="map-route-node map-route-node--driver">${escapeHtml(routeSummary[1])}</span>
          <span class="map-route-arrow">←</span>
          <span class="map-route-node map-route-node--client">${escapeHtml(routeSummary[2])}</span>
        </div>
      </div>
      <span class="map-status-pill">${escapeHtml(orderData.status || orderData.orderStatus || '-')}</span>
    </div>
    <div class="map-detail-grid">
      <div class="map-detail-metric"><span>المطعم</span><strong>${escapeHtml(restaurant?.name || orderData.restaurantName || restaurantId || '-')}</strong></div>
      <div class="map-detail-metric"><span>المندوب</span><strong>${escapeHtml(driver?.name || driverId || 'غير معين')}</strong></div>
      <div class="map-detail-metric"><span>العميل</span><strong>${escapeHtml(client?.name || orderData.clientName || clientId || '-')}</strong></div>
      <div class="map-detail-metric"><span>الإجمالي</span><strong>${escapeHtml(String(orderData.totalWithDelivery ?? orderData.total ?? orderData.totalPrice ?? '-'))}</strong></div>
      <div class="map-detail-metric"><span>من</span><strong>${escapeHtml(routeAddressSummary[0])}</strong></div>
      <div class="map-detail-metric"><span>إلى</span><strong>${escapeHtml(routeAddressSummary[1])}</strong></div>
      <div class="map-detail-metric"><span>المسار</span><strong>${escapeHtml(routeStateLabel)}</strong></div>
      <div class="map-detail-metric"><span>التغطية</span><strong>${escapeHtml(`مطعم ${restaurantGeo ? 'نعم' : 'لا'} | مندوب ${driverGeo ? 'نعم' : 'لا'} | عميل ${clientGeo ? 'نعم' : 'لا'}`)}</strong></div>
    </div>
    <div class="map-insight-card"><b>متابعة ذكية:</b> ${escapeHtml(trackingInsight)}</div>
    ${missingPieces.length ? `<div class="map-alert-note"><b>تنبيه مكاني:</b> ${escapeHtml(missingPieces.join(' | '))}</div>` : ''}
    <div class="map-inline-actions">
      ${restaurantId ? `<button class="btn ghost" type="button" data-map-open-store="${escapeHtml(restaurantId)}">فتح المتجر</button>` : ''}
      ${driverId ? `<button class="btn ghost" type="button" data-map-open-driver="${escapeHtml(driverId)}">فتح المندوب</button>` : ''}
      ${clientId ? `<button class="btn ghost" type="button" data-map-open-client="${escapeHtml(clientId)}">فتح العميل</button>` : ''}
    </div>
    <div><b>العناصر:</b><ul>${items}</ul></div>
  `, {
    orderId,
    selection: {
      type: 'order',
      id: orderId,
      label: `الطلب ${formatUnifiedOrderCode(orderData.orderNumber, orderData.orderId, orderId)}`
    }
  });
}

function focusMapOnOrder(orderId) {
  const orderEntry = mapState.orders.get(orderId);
  if (!orderEntry || !liveMap) return;

  if (!canDisplayOrderOnMap(orderEntry.data || {}, orderId)) {
    clearSelectedOrderOnMap();
    setMapDetails('<p class="muted">هذا الطلب مكتمل، لذلك لا يظهر داخل تبويب الخريطة إلا إذا تم فتحه من تبويب إدارة الطلبات.</p>');
    return;
  }

  selectedOrderOnMapId = orderId;
  const orderData = orderEntry.data || {};
  renderOrderDetails(orderData, orderId);
  renderMapSearchResults();

  const points = [];
  const restaurantGeo = getRestaurantGeoByOrder(orderData);
  const driverGeo = getDriverGeoByOrder(orderData);
  const clientGeo = getClientGeoByOrder(orderData);

  if (restaurantGeo) points.push([restaurantGeo.lat, restaurantGeo.lng]);
  if (driverGeo) points.push([driverGeo.lat, driverGeo.lng]);
  if (clientGeo) points.push([clientGeo.lat, clientGeo.lng]);

  if (points.length === 1) {
    liveMap.setView(points[0], 15);
  } else if (points.length > 1) {
    const bounds = window.L.latLngBounds(points);
    liveMap.fitBounds(bounds.pad(0.25), { animate: true, maxZoom: 16 });
  }

  const orderMarker = markerState.orders.get(orderId);
  if (orderMarker) {
    orderMarker.openPopup();
  }

  refreshOrderLines();
}

function openOrderOnMap(orderId, options = {}) {
  allowCompletedSelectedOrderOnMap = options.allowCompleted === true;
  selectedOrderOnMapId = orderId;
  activateTab('map');
  setTimeout(() => {
    refreshMapLayers();
    focusMapOnOrder(orderId);
  }, 220);
}

function renderEntityDetails(type, id, data, context = null) {
  const formatGeoInline = (geo) => (geo ? `${geo.lat.toFixed(5)}, ${geo.lng.toFixed(5)}` : 'غير متاح');
  const name = data.name || data.fullName || data.displayName || id;
  if (type === 'driver') {
    const driverGeo = extractGeo(data, ['location', 'currentLocation', 'lastLocation', 'address.location']);
    const available = data.isAvailable === true || data.available === true || String(data.availabilityStatus || '').toLowerCase() === 'available';
    const orders = activeOrdersFor((order) => order.assignedDriverId === id);
    setMapDetails(`
      <h4>المندوب</h4>
      <div><span class="kv"><b>الاسم:</b> ${escapeHtml(name)}</span><span class="kv"><b>الهاتف:</b> ${escapeHtml(data.phone || '-')}</span></div>
      <div><span class="kv"><b>الحالة:</b> ${available ? 'متاح' : 'غير متاح'}</span><span class="kv"><b>الإحداثيات:</b> ${escapeHtml(formatGeoInline(driverGeo))}</span></div>
      <div><b>طلبات نشطة:</b> ${orders.length}</div>
      <ul>${orders.slice(0, 5).map((o) => `<li>${escapeHtml(formatUnifiedOrderCode(o.data.orderNumber, o.data.orderId, o.id))} - ${escapeHtml(o.data.status || o.data.orderStatus || '-')}</li>`).join('') || '<li>لا يوجد</li>'}</ul>
    `, {
      selection: { type: 'driver', id, label: `المندوب ${name}` }
    });
    return;
  }

  if (type === 'client') {
    const clientGeo = extractGeo(data, ['location', 'currentLocation', 'address.location', 'deliveryLocation']);
    const orders = activeOrdersFor((order) => order.clientId === id);
    setMapDetails(`
      <h4>العميل</h4>
      <div><span class="kv"><b>الاسم:</b> ${escapeHtml(name)}</span><span class="kv"><b>الهاتف:</b> ${escapeHtml(data.phone || '-')}</span></div>
      <div><span class="kv"><b>الإحداثيات:</b> ${escapeHtml(formatGeoInline(clientGeo))}</span></div>
      <div><b>طلبات نشطة:</b> ${orders.length}</div>
      <ul>${orders.slice(0, 5).map((o) => `<li>${escapeHtml(formatUnifiedOrderCode(o.data.orderNumber, o.data.orderId, o.id))} - ${escapeHtml(o.data.status || o.data.orderStatus || '-')}</li>`).join('') || '<li>لا يوجد</li>'}</ul>
    `, {
      selection: { type: 'client', id, label: `العميل ${name}` }
    });
    return;
  }

  const restaurantGeo = context?.geo || getRestaurantGeo(id, data);
  const missingReasons = restaurantGeo ? [] : describeRestaurantMapGap(id, data);
  const addressName = String(context?.addressData?.addressName || '').trim();
  const addressCity = String(context?.addressData?.city || '').trim();
  const addressLine = [addressName, addressCity].filter(Boolean).join(' - ');
  const addressMeta = addressLine
    ? `<div><span class="kv"><b>العنوان:</b> ${escapeHtml(addressLine)}</span>${context?.isDefault ? '<span class="kv"><b>افتراضي:</b> نعم</span>' : ''}</div>`
    : '';
  const orders = activeOrdersFor((order) => order.restaurantId === id);
  setMapDetails(`
    <h4>المطعم</h4>
    <div><span class="kv"><b>الاسم:</b> ${escapeHtml(name)}</span><span class="kv"><b>الهاتف:</b> ${escapeHtml(data.phone || '-')}</span></div>
    <div><span class="kv"><b>الحالة:</b> ${escapeHtml(data.temporarilyClosed ? 'مغلق مؤقتًا' : 'مفتوح')}</span><span class="kv"><b>الإحداثيات:</b> ${escapeHtml(formatGeoInline(restaurantGeo))}</span></div>
    ${addressMeta}
    ${missingReasons.length ? `<div class="map-alert-note"><b>سبب غياب الموقع:</b> ${escapeHtml(missingReasons.join(' | '))}</div>` : ''}
    <div><b>طلبات نشطة:</b> ${orders.length}</div>
    <ul>${orders.slice(0, 5).map((o) => `<li>${escapeHtml(formatUnifiedOrderCode(o.data.orderNumber, o.data.orderId, o.id))} - ${escapeHtml(o.data.status || o.data.orderStatus || '-')}</li>`).join('') || '<li>لا يوجد</li>'}</ul>
  `, {
    selection: {
      type: 'restaurant',
      id,
      label: `المطعم ${name}`,
      context,
      fallbackData: data
    }
  });
}

function buildMarkerIcon({ type, variant = 'default' }) {
  const glyphByType = {
    driver: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 4 12h5v9h6v-9h5Z"></path></svg>',
    client: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm0 2c-4.418 0-8 2.239-8 5v1h16v-1c0-2.761-3.582-5-8-5Z"></path></svg>',
    restaurant: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 4h16v4H4Zm1 6h14v10H5Zm3 2v2h2v-2Zm4 0v2h2v-2Z"></path></svg>',
    order: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2a7 7 0 0 0-7 7c0 4.63 7 13 7 13s7-8.37 7-13a7 7 0 0 0-7-7Zm0 9.5A2.5 2.5 0 1 1 12 6a2.5 2.5 0 0 1 0 5.5Z"></path></svg>',
  };

  return window.L.divIcon({
    className: 'map-pin-shell',
    html: `<div class="map-pin map-pin--${type} map-pin--${variant}"><span>${glyphByType[type] || '•'}</span></div>`,
    iconSize: [34, 34],
    iconAnchor: [17, 17],
    popupAnchor: [0, -16],
    tooltipAnchor: [12, -12],
  });
}

function setOrUpdateMarker(stateMap, id, latLng, markerOptions, label, onClick) {
  if (!liveMap) return;
  const existing = stateMap.get(id);
  const icon = buildMarkerIcon(markerOptions || {});
  const layerType = markerOptions?.type || 'orders';

  if (existing) {
    existing.setLatLng(latLng);
    existing.setIcon(icon);
    existing.bindTooltip(label);
    existing.bindPopup(label);
    return;
  }

  const marker = window.L.marker(latLng, { icon });
  marker.bindTooltip(label);
  marker.bindPopup(label);
  marker.on('click', onClick);
  addMarkerToLayer(layerType, marker);
  stateMap.set(id, marker);
}

function removeMissingMarkers(stateMap, validIds) {
  stateMap.forEach((marker, id) => {
    if (!validIds.has(id)) {
      const type = id.startsWith('orphan:') ? 'restaurants' : stateMap === markerState.drivers
        ? 'drivers'
        : stateMap === markerState.clients
          ? 'clients'
          : stateMap === markerState.restaurants
            ? 'restaurants'
            : 'orders';
      removeMarkerFromLayer(type, marker);
      stateMap.delete(id);
    }
  });
}

function refreshDriverMarkers() {
  if (!shouldDisplayMapLayer('drivers')) {
    removeMissingMarkers(markerState.drivers, new Set());
    return;
  }
  const validIds = new Set();
  mapState.drivers.forEach(({ data }, id) => {
    const geo = extractGeo(data, ['location', 'currentLocation', 'lastLocation', 'liveLocation', 'address.location']);
    if (!geo) return;
    validIds.add(id);
    const available = data.isAvailable === true || data.available === true || String(data.availabilityStatus || '').toLowerCase() === 'available';
    setOrUpdateMarker(
      markerState.drivers,
      id,
      [geo.lat, geo.lng],
      { type: 'driver', variant: available ? 'online' : 'offline' },
      `${available ? 'مندوب متاح' : 'مندوب غير متاح'}: ${data.name || id}`,
      () => renderEntityDetails('driver', id, data)
    );
  });
  removeMissingMarkers(markerState.drivers, validIds);
}

function refreshClientMarkers() {
  if (!shouldDisplayMapLayer('clients')) {
    removeMissingMarkers(markerState.clients, new Set());
    return;
  }
  const activeClientIds = new Set(
    activeOrdersFor((order) => !!order.clientId)
      .map((order) => order.data.clientId)
      .filter(Boolean)
  );

  const validIds = new Set();
  mapState.clients.forEach(({ data }, id) => {
    if (!activeClientIds.has(id)) return;
    const geo = extractGeo(data, ['location', 'currentLocation', 'address.location', 'deliveryLocation']);
    if (!geo) return;
    validIds.add(id);
    setOrUpdateMarker(
      markerState.clients,
      id,
      [geo.lat, geo.lng],
      { type: 'client', variant: 'active' },
      `عميل نشط: ${data.name || id}`,
      () => renderEntityDetails('client', id, data)
    );
  });
  removeMissingMarkers(markerState.clients, validIds);
}

function refreshRestaurantMarkers() {
  if (!shouldDisplayMapLayer('restaurants')) {
    mapUiState.hiddenRestaurants = [];
    removeMissingMarkers(markerState.restaurants, new Set());
    return;
  }
  const validIds = new Set();
  const hiddenRestaurants = [];
  mapState.restaurants.forEach(({ data }, id) => {
    const openState = data.temporarilyClosed ? 'closed' : 'open';
    const addresses = mapState.restaurantAddresses.get(id);

    let chosenAddressId = '';
    let chosenAddressEntry = null;
    if (addresses && addresses.size) {
      const defaultAddressId = String(data.defaultAddressId || '').trim();
      if (defaultAddressId && addresses.has(defaultAddressId)) {
        chosenAddressId = defaultAddressId;
        chosenAddressEntry = addresses.get(defaultAddressId);
      } else {
        chosenAddressId = addresses.keys().next().value || '';
        chosenAddressEntry = chosenAddressId ? addresses.get(chosenAddressId) : null;
      }
    }

    const geo = chosenAddressEntry?.geo || getRestaurantGeo(id, data);
    if (!geo) {
      hiddenRestaurants.push({ id, reasons: describeRestaurantMapGap(id, data) });
      return;
    }

    const markerId = id;
    const chosenAddressName = String(chosenAddressEntry?.data?.addressName || '').trim();
    const chosenCity = String(chosenAddressEntry?.data?.city || '').trim();
    const labelParts = [
      `مطعم ${openState === 'open' ? 'مفتوح' : 'مغلق'}: ${data.name || id}`,
      chosenAddressName,
      chosenCity,
    ].filter(Boolean);

    validIds.add(markerId);
    setOrUpdateMarker(
      markerState.restaurants,
      markerId,
      [geo.lat, geo.lng],
      { type: 'restaurant', variant: openState },
      labelParts.join(' | '),
      () => renderEntityDetails('restaurant', id, data, {
        geo,
        addressId: chosenAddressId,
        addressData: chosenAddressEntry?.data || null,
        isDefault: Boolean(chosenAddressId && String(data.defaultAddressId || '').trim() === chosenAddressId),
      })
    );
  });

  // Fallback: addresses that exist under restaurants/{id}/addresses while parent restaurant doc is missing.
  mapState.restaurantAddresses.forEach((addresses, restaurantId) => {
    if (mapState.restaurants.has(restaurantId)) return;
    if (!addresses || !addresses.size) return;

    const firstAddressId = addresses.keys().next().value || '';
    const entry = firstAddressId ? addresses.get(firstAddressId) : null;
    const geo = entry?.geo;
    if (!geo) return;

    const markerId = `orphan:${restaurantId}`;
    const addressName = String(entry?.data?.addressName || '').trim();
    const city = String(entry?.data?.city || '').trim();

    validIds.add(markerId);
    setOrUpdateMarker(
      markerState.restaurants,
      markerId,
      [geo.lat, geo.lng],
      { type: 'restaurant', variant: 'open' },
      [`مطعم غير مكتمل: ${restaurantId}`, addressName, city].filter(Boolean).join(' | '),
      () => renderEntityDetails('restaurant', restaurantId, {
        name: `مطعم غير مكتمل (${restaurantId})`,
        phone: '-',
        temporarilyClosed: false,
      }, {
        geo,
        addressId: firstAddressId,
        addressData: entry?.data || null,
        isDefault: false,
      })
    );
  });

  mapUiState.hiddenRestaurants = hiddenRestaurants;

  removeMissingMarkers(markerState.restaurants, validIds);
}

function refreshOrderMarkers() {
  if (!shouldDisplayMapLayer('orders')) {
    removeMissingMarkers(markerState.orders, new Set());
    return;
  }
  const validIds = new Set();
  mapState.orders.forEach(({ data }, id) => {
    if ((!matchesMapOrderFilter(data) && id !== selectedOrderOnMapId) || !canDisplayOrderOnMap(data, id)) return;
    const geo = extractGeo(data, ['deliveryLocation', 'clientLocation', 'address.location']);
    if (!geo) return;
    validIds.add(id);
    setOrUpdateMarker(
      markerState.orders,
      id,
      [geo.lat, geo.lng],
      { type: 'order', variant: selectedOrderOnMapId === id ? 'selected' : 'active' },
      `طلب: ${formatUnifiedOrderCode(data.orderNumber, data.orderId, id)}`,
      () => {
        selectedOrderOnMapId = id;
        renderOrderDetails(data, id);
        refreshOrderLines();
      }
    );
  });
  removeMissingMarkers(markerState.orders, validIds);
}

function getRestaurantGeoByOrder(orderData) {
  const fromOrder = extractGeo(orderData, ['restaurantLocation']);
  if (fromOrder) return fromOrder;
  const lat = Number(orderData.restaurantLat);
  const lng = Number(orderData.restaurantLng);
  if (Number.isFinite(lat) && Number.isFinite(lng)) return { lat, lng };

  const restaurantId = orderData.restaurantId;
  if (!restaurantId) return null;
  const restaurant = mapState.restaurants.get(restaurantId)?.data;
  return restaurant ? getRestaurantGeo(restaurantId, restaurant) : null;
}

function getDriverGeoByOrder(orderData) {
  const driverId = orderData.assignedDriverId;
  if (!driverId) return null;
  const driver = mapState.drivers.get(driverId)?.data;
  return driver ? extractGeo(driver, ['location', 'currentLocation', 'lastLocation', 'address.location']) : null;
}

function getClientGeoByOrder(orderData) {
  const clientId = orderData.clientId;
  const client = clientId ? mapState.clients.get(clientId)?.data : null;
  return (
    extractGeo(orderData, ['deliveryLocation', 'clientLocation', 'address.location']) ||
    (client ? extractGeo(client, ['location', 'currentLocation', 'deliveryLocation', 'address.location']) : null)
  );
}

function setOrUpdateOrderLine(orderId, points, options) {
  if (!liveMap) return;
  const existing = lineState.orders.get(orderId);
  if (existing) {
    existing.polyline.setLatLngs(points);
    existing.polyline.setStyle(options);
    existing.routeKey = options.routeKey || existing.routeKey || '';
    existing.mode = options.routeMode || existing.mode || 'straight';
    return;
  }
  const polyline = window.L.polyline(points, options).addTo(liveMap);
  lineState.orders.set(orderId, {
    polyline,
    routeKey: options.routeKey || '',
    mode: options.routeMode || 'straight',
  });
}

function removeMissingOrderLines(validIds) {
  lineState.orders.forEach((entry, id) => {
    if (!validIds.has(id)) {
      entry.polyline.remove();
      lineState.orders.delete(id);
    }
  });
}

function refreshOrderLines() {
  if (!shouldDisplayMapLayer('orders')) {
    removeMissingOrderLines(new Set());
    return;
  }
  const validIds = new Set();
  const routedOrderBudget = 8;
  let routedOrderCount = 0;
  mapState.orders.forEach(({ data }, id) => {
    if ((!matchesMapOrderFilter(data) && id !== selectedOrderOnMapId) || !canDisplayOrderOnMap(data, id)) return;

    const restaurantGeo = getRestaurantGeoByOrder(data);
    const driverGeo = getDriverGeoByOrder(data);
    const clientGeo = getClientGeoByOrder(data);

    const points = [];
    if (restaurantGeo) points.push([restaurantGeo.lat, restaurantGeo.lng]);
    if (driverGeo) {
      const lastPoint = points[points.length - 1];
      if (!lastPoint || lastPoint[0] !== driverGeo.lat || lastPoint[1] !== driverGeo.lng) {
        points.push([driverGeo.lat, driverGeo.lng]);
      }
    }
    if (clientGeo) {
      const lastPoint = points[points.length - 1];
      if (!lastPoint || lastPoint[0] !== clientGeo.lat || lastPoint[1] !== clientGeo.lng) {
        points.push([clientGeo.lat, clientGeo.lng]);
      }
    }

    if (points.length < 2) return;

    validIds.add(id);
    const withDriver = Boolean(driverGeo);
    const isSelected = selectedOrderOnMapId && selectedOrderOnMapId === id;
    const shouldUseActualRoute = Boolean(isSelected || routedOrderCount < routedOrderBudget);
    const resolvedRoute = resolveOrderRoutePoints(id, points, shouldUseActualRoute);
    if ((resolvedRoute.mode === 'actual' || resolvedRoute.mode === 'loading') && !isSelected) {
      routedOrderCount += 1;
    }
    setOrUpdateOrderLine(id, resolvedRoute.points, {
      routeKey: resolvedRoute.routeKey,
      routeMode: resolvedRoute.mode,
      color: isSelected ? '#2563eb' : (withDriver ? '#f59e0b' : '#ef4444'),
      weight: isSelected ? 5 : 3,
      opacity: isSelected ? 0.95 : 0.75,
      dashArray: resolvedRoute.mode === 'actual' ? null : (withDriver ? null : '6 6')
    });
  });

  removeMissingOrderLines(validIds);
}

function refreshMapLayers() {
  syncMapUiStateFromInputs();

  if (selectedOrderOnMapId) {
    const selectedOrderData = mapState.orders.get(selectedOrderOnMapId)?.data;
    if (!selectedOrderData || !canDisplayOrderOnMap(selectedOrderData, selectedOrderOnMapId)) {
      clearSelectedOrderOnMap();
    }
  }

  refreshDriverMarkers();
  refreshClientMarkers();
  refreshRestaurantMarkers();
  refreshOrderMarkers();
  refreshOrderLines();

  if (currentMapSelection && mapUiState.pinDetails) {
    renderCurrentMapSelection();
  } else if (selectedOrderOnMapId && mapState.orders.has(selectedOrderOnMapId)) {
    const current = mapState.orders.get(selectedOrderOnMapId);
    renderOrderDetails(current.data || {}, selectedOrderOnMapId);
  }

  if (mapUiState.followSelectedOrder && selectedOrderOnMapId && mapState.orders.has(selectedOrderOnMapId)) {
    const orderMarker = markerState.orders.get(selectedOrderOnMapId);
    if (orderMarker && liveMap) {
      liveMap.setView(orderMarker.getLatLng(), Math.max(liveMap.getZoom(), 15), { animate: true });
    }
  }

  refreshMapLegendSummary();
  renderMapSearchResults();
  renderMapEventFeed();
  refreshMapViewport();
}

async function mountMap() {
  const mapElement = document.getElementById('liveMap');
  if (!mapElement) return;

  try {
    await withTimeout(ensureLeaflet(), 9000, 'تعذر تحميل الخريطة (timeout).');
  } catch (error) {
    setMapDetails(`<p class="muted">${escapeHtml(error.message || 'تعذر تحميل الخريطة.')}</p>`);
    return;
  }

  if (!liveMap) {
    liveMap = window.L.map('liveMap').setView([15.5527, 32.5324], 11); // الخرطوم - السودان
    ensureMarkerLayers();
    syncMapUiStateFromInputs();
    applyMapBaseLayer();
    if (!mapScaleControlAdded) {
      window.L.control.scale({ imperial: false, position: 'bottomright' }).addTo(liveMap);
      mapScaleControlAdded = true;
    }

    liveMap.on('dragstart zoomstart', () => {
      mapAutoFitted = true;
    });

    if (!mapLegendControlAdded) {
      const legend = window.L.control({ position: 'bottomleft' });
      legend.onAdd = function onAdd() {
        const div = window.L.DomUtil.create('div', 'map-details');
        div.style.background = 'rgba(255,255,255,0.95)';
        div.style.padding = '8px 10px';
        div.style.border = '1px solid #e5e7eb';
        div.style.borderRadius = '8px';
        div.style.lineHeight = '1.6';
        div.style.fontSize = '12px';
        div.innerHTML =
          'أخضر: مندوب متاح<br/>رمادي: مندوب غير متاح<br/>أزرق: عميل نشط<br/>برتقالي: مطعم مفتوح<br/>بني: مطعم مغلق<br/>أحمر أو أزرق نابض: طلب محدد أو نشط';
        return div;
      };
      legend.addTo(liveMap);
      mapLegendControlAdded = true;
    }

    void ensureLeafletMarkerCluster()
      .then(() => {
        if (!window.L?.markerClusterGroup || !liveMap) return;
        rebuildMarkerLayers();
        requestRefreshMapLayers();
      })
      .catch(() => {
      });
  }

  if (!mapUiBound) {
    mapUiBound = true;
    mapSearchInput?.addEventListener('input', () => renderMapSearchResults());
    mapOrderStatusFilter?.addEventListener('change', () => requestRefreshMapLayers());
    mapStyleSelect?.addEventListener('change', () => {
      syncMapUiStateFromInputs();
      applyMapBaseLayer();
      requestRefreshMapLayers();
    });
    [mapLayerDriversInput, mapLayerClientsInput, mapLayerRestaurantsInput, mapLayerOrdersInput, mapFollowSelectedOrderInput, mapPinDetailsInput]
      .filter(Boolean)
      .forEach((input) => {
        input.addEventListener('change', () => {
          syncMapUiStateFromInputs();
          requestRefreshMapLayers();
        });
      });
    mapFullscreenBtn?.addEventListener('click', () => {
      void toggleMapFullscreen();
    });
    document.addEventListener('fullscreenchange', () => {
      updateMapFullscreenButton();
      setTimeout(() => {
        if (liveMap) liveMap.invalidateSize();
      }, 180);
    });
  }

  if (mapBootstrapped) {
    refreshMapLayers();
    return;
  }
  mapBootstrapped = true;

  setMapDetails('<p class="muted">اختر علامة على الخريطة لعرض التفاصيل.</p>');
  renderMapEventFeed();
  updateMapSelectionBanner('لا يوجد عنصر مثبت حاليًا.');
  updateMapFullscreenButton();

  unsubscribers.push(
    onSnapshot(collection(db, 'drivers'), (snap) => {
      mapState.drivers.clear();
      snap.docs.forEach((d) => mapState.drivers.set(d.id, { id: d.id, data: d.data() }));
      requestRefreshMapLayers();
    })
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'clients'), (snap) => {
      mapState.clients.clear();
      snap.docs.forEach((d) => mapState.clients.set(d.id, { id: d.id, data: d.data() }));
      requestRefreshMapLayers();
    })
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'restaurants'), (snap) => {
      mapState.restaurants.clear();
      snap.docs.forEach((d) => mapState.restaurants.set(d.id, { id: d.id, data: d.data() }));
      requestRefreshMapLayers();
      void backfillRestaurantAddressesForMissingRestaurants();
    })
  );

  unsubscribers.push(
    onSnapshot(
      collectionGroup(db, 'addresses'),
      (snap) => {
        mapState.restaurantAddresses.clear();

        snap.docs.forEach((d) => {
          const addressesCollection = d.ref.parent;
          const ownerDoc = addressesCollection?.parent;
          const ownerCollection = ownerDoc?.parent;
          if (!ownerDoc || !ownerCollection || ownerCollection.id !== 'restaurants') return;

          const data = d.data() || {};
          const geo = normalizeGeo(data.location)
            || normalizeGeoFromPair(data.latitude, data.longitude)
            || normalizeGeoFromPair(data.lat, data.lng);
          if (!geo) return;

          const restaurantId = ownerDoc.id;
          const byRestaurant = mapState.restaurantAddresses.get(restaurantId) || new Map();
          byRestaurant.set(d.id, { geo, data });
          mapState.restaurantAddresses.set(restaurantId, byRestaurant);
        });

        requestRefreshMapLayers();
        void backfillRestaurantAddressesForMissingRestaurants();
      },
      (error) => {
        console.error('addresses collectionGroup listener failed', error);
        setMapDetails('<p class="muted">تعذر تحميل عناوين المطاعم الفرعية. سيتم عرض المواقع المتاحة من السجل الرئيسي فقط.</p>');
        void backfillRestaurantAddressesForMissingRestaurants();
      }
    )
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'orders'), (snap) => {
      mapState.orders.clear();
      snap.docs.forEach((d) => mapState.orders.set(d.id, { id: d.id, data: d.data() }));
      snap.docChanges().slice(0, 4).forEach((change) => {
        const data = change.doc.data() || {};
        if (!matchesMapOrderFilter(data) && change.type !== 'removed') return;
        const code = formatUnifiedOrderCode(data.orderNumber, data.orderId, change.doc.id);
        const status = String(data.orderStatus || data.status || 'غير محددة');
        pushMapEvent({
          type: 'order',
          id: change.doc.id,
          level: change.type === 'removed' ? 'danger' : change.type === 'added' ? 'info' : 'warning',
          title: `الطلب ${code}`,
          description: change.type === 'removed' ? 'تمت إزالته من القائمة الحية.' : `آخر حالة: ${status}`
        });
      });
      requestRefreshMapLayers();
    })
  );
}

async function safeGetDocs(q) {
  try {
    return await getDocs(q);
  } catch (err) {
    console.warn('query skipped', err);
    return { docs: [] };
  }
}

function isPendingApprovalCandidate(data = {}) {
  const values = [data.approvalStatus, data.status, data.reviewStatus]
    .map((value) => String(value || '').trim().toLowerCase())
    .filter(Boolean);
  return values.some((value) => ['pending', 'pending_review', 'under_review', 'submitted', 'new'].includes(value));
}

function collectPendingApprovalEntries({
  courierApps = [],
  storeApps = [],
  fallbackDrivers = [],
  fallbackStores = [],
} = {}) {
  const entries = [];
  const pendingDriverIds = new Set(courierApps.map((docSnap) => {
    const data = docSnap.data() || {};
    return String(data.driverId || data.ownerUid || data.uid || docSnap.id || '').trim();
  }).filter(Boolean));
  const pendingStoreIds = new Set(storeApps.map((docSnap) => {
    const data = docSnap.data() || {};
    return String(data.restaurantId || data.ownerUid || data.uid || docSnap.id || '').trim();
  }).filter(Boolean));

  courierApps.forEach((docSnap) => {
    const data = docSnap.data() || {};
    entries.push({
      id: `courier-app:${docSnap.id}`,
      title: 'طلب اعتماد مندوب جديد',
      body: `المندوب ${data.name || data.phone || docSnap.id} بانتظار المراجعة.`,
    });
  });

  storeApps.forEach((docSnap) => {
    const data = docSnap.data() || {};
    entries.push({
      id: `store-app:${docSnap.id}`,
      title: 'طلب اعتماد متجر جديد',
      body: `المتجر ${data.name || data.phone || docSnap.id} بانتظار المراجعة.`,
    });
  });

  fallbackDrivers
    .filter((docSnap) => !pendingDriverIds.has(docSnap.id))
    .forEach((docSnap) => {
      const data = docSnap.data() || {};
      entries.push({
        id: `driver-entity:${docSnap.id}`,
        title: 'مندوب بحالة اعتماد معلقة',
        body: `المندوب ${data.name || data.phone || docSnap.id} ما زال بانتظار الاعتماد.`,
      });
    });

  fallbackStores
    .filter((docSnap) => !pendingStoreIds.has(docSnap.id))
    .forEach((docSnap) => {
      const data = docSnap.data() || {};
      entries.push({
        id: `store-entity:${docSnap.id}`,
        title: 'متجر بحالة اعتماد معلقة',
        body: `المتجر ${data.name || data.phone || docSnap.id} ما زال بانتظار الاعتماد.`,
      });
    });

  return entries;
}

function syncPendingApprovalsState(entries = []) {
  opsCenterState.pendingApprovals = entries.length;
  const nextIds = new Set(entries.map((item) => item.id));
  const prevIds = opsCenterState.pendingApprovalIds;

  nextIds.forEach((id) => {
    if (!prevIds.has(id) && opsCenterState.bootstrapped.pendingApprovals) {
      const item = entries.find((entry) => entry.id === id);
      pushOpsAlert(`pending:${id}`, item?.title || 'طلب اعتماد جديد', item?.body || 'يوجد طلب اعتماد جديد بانتظار المراجعة.', 'warning');
    }
  });

  opsCenterState.pendingApprovalIds = nextIds;
  opsCenterState.bootstrapped.pendingApprovals = true;
  renderOpsPriorityCards();
}

function refreshPendingApprovalRealtimeState() {
  syncPendingApprovalsState(collectPendingApprovalEntries({
    courierApps: pendingRealtimeState.courierApps,
    storeApps: pendingRealtimeState.storeApps,
    fallbackDrivers: pendingRealtimeState.fallbackDrivers,
    fallbackStores: pendingRealtimeState.fallbackStores,
  }));
}

function mountPendingApprovalRealtime() {
  if (pendingRealtimeBound) return;
  pendingRealtimeBound = true;

  const attach = (key, queryRef, filterFn = null) => {
    unsubscribers.push(
      onSnapshot(queryRef, (snap) => {
        pendingRealtimeState[key] = typeof filterFn === 'function'
          ? snap.docs.filter((docSnap) => filterFn(docSnap.data() || {}))
          : snap.docs;
        refreshPendingApprovalRealtimeState();
      }, (err) => {
        console.warn(`pending realtime listener failed: ${key}`, err);
      })
    );
  };

  attach('courierApps', collection(db, 'courierApplications'), isPendingApprovalCandidate);
  attach('storeApps', collection(db, 'restaurantApplications'), isPendingApprovalCandidate);
  attach('fallbackDrivers', query(collection(db, 'drivers'), where('approvalStatus', '==', 'pending')));
  attach('fallbackStores', query(collection(db, 'restaurants'), where('approvalStatus', '==', 'pending')));
}

async function mountPending() {
  const [courierApps, storeApps, fallbackDriverSnap, fallbackStoreSnap] = await Promise.all([
    getPendingDocs('courierApplications'),
    getPendingDocs('restaurantApplications'),
    safeGetDocs(query(collection(db, 'drivers'), where('approvalStatus', '==', 'pending'))),
    safeGetDocs(query(collection(db, 'restaurants'), where('approvalStatus', '==', 'pending')))
  ]);

  syncPendingApprovalsState(collectPendingApprovalEntries({
    courierApps,
    storeApps,
    fallbackDrivers: fallbackDriverSnap.docs,
    fallbackStores: fallbackStoreSnap.docs,
  }));

  const pendingDriverIds = new Set(courierApps.map((d) => {
    const data = d.data() || {};
    return data.driverId || data.ownerUid || data.uid || d.id;
  }));

  const pendingStoreIds = new Set(storeApps.map((d) => {
    const data = d.data() || {};
    return data.restaurantId || data.ownerUid || data.uid || d.id;
  }));

  const rows = [];

  courierApps.forEach((d) => {
    const data = d.data() || {};
    const identityNumber = data.nationalIdNumber || '-';
    const identityImageUrl = data.idImageUrl || '';
    rows.push(`<tr>
      <td>مندوب</td>
      <td>${data.name || d.id}</td>
      <td>${data.phone || '-'}</td>
      <td>${data.email || '-'}</td>
      <td>${data.ownerUid || data.driverId || d.id}</td>
      <td>${identityNumber}</td>
      <td>${imageCell(identityImageUrl)}</td>
      <td>
        <button class="btn ghost" data-approve-courier-app="${d.id}">قبول</button>
        <button class="btn danger" data-reject-courier-app="${d.id}">رفض</button>
      </td>
    </tr>`);
  });

  storeApps.forEach((d) => {
    const data = d.data() || {};
    rows.push(`<tr>
      <td>متجر</td>
      <td>${data.name || d.id}</td>
      <td>${data.phone || '-'}</td>
      <td>${data.email || '-'}</td>
      <td>${data.ownerUid || data.restaurantId || d.id}</td>
      <td>${data.commercialRecordNumber || '-'}</td>
      <td>${imageCell(data.commercialRecordImageUrl || '')}</td>
      <td>
        <button class="btn ghost" data-approve-store-app="${d.id}">قبول</button>
        <button class="btn danger" data-reject-store-app="${d.id}">رفض</button>
      </td>
    </tr>`);
  });

  fallbackDriverSnap.docs
    .filter((d) => !pendingDriverIds.has(d.id))
    .forEach((d) => {
      const data = d.data() || {};
      rows.push(`<tr>
        <td>مندوب</td>
        <td>${data.name || d.id}</td>
        <td>${data.phone || '-'}</td>
        <td>${data.email || '-'}</td>
        <td>${data.ownerUid || d.id}</td>
        <td>${data.nationalIdNumber || '-'}</td>
        <td>${imageCell(data.idImageUrl || '')}</td>
        <td>-</td>
      </tr>`);
    });

  fallbackStoreSnap.docs
    .filter((d) => !pendingStoreIds.has(d.id))
    .forEach((d) => {
      const data = d.data() || {};
      rows.push(`<tr>
        <td>متجر</td>
        <td>${data.name || d.id}</td>
        <td>${data.phone || '-'}</td>
        <td>${data.email || '-'}</td>
        <td>${data.ownerUid || d.id}</td>
        <td>${data.commercialRecordNumber || '-'}</td>
        <td>${imageCell(data.commercialRecordImageUrl || '')}</td>
        <td>
          <button class="btn ghost" data-approve-store-entity="${d.id}">قبول</button>
          <button class="btn danger" data-reject-store-entity="${d.id}">رفض</button>
        </td>
      </tr>`);
    });

  setHtml(pendingTable, table(['النوع', 'الاسم', 'الهاتف', 'البريد', 'UID', 'السجل', 'الصورة', 'إجراء'], rows));

  pendingTable.querySelectorAll('[data-approve-courier-app]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const appId = btn.getAttribute('data-approve-courier-app');
      await approveCourierApplication({ applicationId: appId });
      await mountPending();
    });
  });

  pendingTable.querySelectorAll('[data-reject-courier-app]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const appId = btn.getAttribute('data-reject-courier-app');
      const snap = await getDoc(doc(db, 'courierApplications', appId));
      if (!snap.exists()) return mountPending();
      const data = snap.data() || {};
      await setCourierDecision({
        appId,
        driverId: data.driverId || data.ownerUid || data.uid || appId,
        ownerUid: data.ownerUid,
        decision: 'rejected'
      });
      await mountPending();
    });
  });

  pendingTable.querySelectorAll('[data-approve-store-app]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      try {
        const appId = btn.getAttribute('data-approve-store-app');
        const result = await approveRestaurantApplication({ applicationId: appId });
        const payload = result?.data || {};
        if (payload.authCreated) {
          alert(`تمت الموافقة وإنشاء/تفعيل حساب دخول للمتجر بنجاح.\nالبريد: ${payload.email}`);
        } else {
          alert('تمت الموافقة على طلب المتجر بنجاح.');
        }
        await mountPending();
      } catch (err) {
        alert(`تعذر قبول الطلب: ${err.message || err}`);
      }
    });
  });

  pendingTable.querySelectorAll('[data-reject-store-app]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      try {
        const appId = btn.getAttribute('data-reject-store-app');
        const snap = await getDoc(doc(db, 'restaurantApplications', appId));
        if (!snap.exists()) return mountPending();
        const data = snap.data() || {};
        await setStoreDecision({
          appId,
          restaurantId: data.restaurantId || data.ownerUid || data.uid || appId,
          ownerUid: data.ownerUid,
          appData: data,
          decision: 'rejected'
        });
        await mountPending();
      } catch (err) {
        alert(`تعذر رفض الطلب: ${err.message || err}`);
      }
    });
  });

  pendingTable.querySelectorAll('[data-approve-store-entity]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const id = btn.getAttribute('data-approve-store-entity');
      await setStoreDecision({ appId: id, restaurantId: id, ownerUid: id, decision: 'approved' });
      await mountPending();
    });
  });

  pendingTable.querySelectorAll('[data-reject-store-entity]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const id = btn.getAttribute('data-reject-store-entity');
      await setStoreDecision({ appId: id, restaurantId: id, ownerUid: id, decision: 'rejected' });
      await mountPending();
    });
  });

  if (!pendingMenuTable) return;

  const pendingMenuSnap = await safeGetDocs(
    query(collection(db, 'restaurants'), where('pendingApproval', '==', true))
  );

  const menuRows = pendingMenuSnap.docs
    .map((d) => ({ id: d.id, data: d.data() || {} }))
    .sort((a, b) => {
      const at = a.data.approvalRequestedAt && typeof a.data.approvalRequestedAt.toDate === 'function'
        ? a.data.approvalRequestedAt.toDate().getTime()
        : 0;
      const bt = b.data.approvalRequestedAt && typeof b.data.approvalRequestedAt.toDate === 'function'
        ? b.data.approvalRequestedAt.toDate().getTime()
        : 0;
      return bt - at;
    })
    .map(({ id, data }) => {
      let requestedAt = '-';
      try {
        if (data.approvalRequestedAt && typeof data.approvalRequestedAt.toDate === 'function') {
          requestedAt = data.approvalRequestedAt.toDate().toLocaleString('ar-EG');
        }
      } catch (_) {}

      return `<tr>
        <td>${data.name || id}</td>
        <td>${data.phone || '-'}</td>
        <td>${requestedAt}</td>
        <td>${data.menuApproved === true ? 'معتمدة' : 'غير معتمدة'}</td>
        <td>
          <button class="btn ghost" data-approve-menu-request="${id}">قبول القائمة</button>
          <button class="btn danger" data-reject-menu-request="${id}">رفض القائمة</button>
        </td>
      </tr>`;
    });

  setHtml(
    pendingMenuTable,
    table(['المتجر', 'الهاتف', 'تاريخ الطلب', 'الحالة الحالية', 'إجراء'], menuRows)
  );

  pendingMenuTable.querySelectorAll('[data-approve-menu-request]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const restaurantId = btn.getAttribute('data-approve-menu-request');
      if (!restaurantId) return;
      await setMenuApprovalDirect({ restaurantId, approved: true });
      await mountPending();
    });
  });

  pendingMenuTable.querySelectorAll('[data-reject-menu-request]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const restaurantId = btn.getAttribute('data-reject-menu-request');
      if (!restaurantId) return;
      await setMenuApprovalDirect({ restaurantId, approved: false });
      await mountPending();
    });
  });
}

function mountNotifications() {
  if (!notificationForm) return;

  const syncUserFields = () => {
    const isUserMode = String(notificationTargetType?.value || '') === 'user';
    if (notificationUserRole) notificationUserRole.disabled = !isUserMode;
    if (notificationUserId) notificationUserId.disabled = !isUserMode;
    if (!isUserMode && notificationUserId) notificationUserId.value = '';
  };

  if (!notificationFormBound) {
    notificationTargetType?.addEventListener('change', syncUserFields);
    notificationForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const targetType = String(notificationTargetType?.value || 'all');
      const role = String(notificationUserRole?.value || 'client');
      const userId = String(notificationUserId?.value || '').trim();
      const title = String(notificationTitle?.value || '').trim();
      const body = String(notificationBody?.value || '').trim();

      if (!title || !body) {
        if (notificationResult) notificationResult.textContent = 'يرجى إدخال العنوان والرسالة.';
        return;
      }

      if (targetType === 'user' && !userId) {
        if (notificationResult) notificationResult.textContent = 'يرجى إدخال UID عند اختيار مستخدم محدد.';
        return;
      }

      if (notificationSendBtn) notificationSendBtn.disabled = true;
      if (notificationResult) notificationResult.textContent = 'جارٍ إرسال الإشعار...';

      try {
        const payload = { targetType, role, userId, title, body };
        const res = await sendAdminNotification(payload);
        const sent = Number(res?.data?.sentCount || 0);
        if (notificationResult) notificationResult.textContent = `تم الإرسال بنجاح. عدد المستقبلين: ${sent}`;
        if (notificationBody) notificationBody.value = '';
        if (notificationTitle) notificationTitle.value = '';
        if (notificationUserId) notificationUserId.value = '';
      } catch (err) {
        if (notificationResult) notificationResult.textContent = `تعذر إرسال الإشعار: ${err.message || err}`;
      } finally {
        if (notificationSendBtn) notificationSendBtn.disabled = false;
      }
    });
    notificationFormBound = true;
  }

  syncUserFields();
  if (notificationResult && !notificationResult.textContent.trim()) {
    notificationResult.textContent = 'جاهز لإرسال إشعار جديد.';
  }
}

async function mountAll() {
  statsGrid.innerHTML = '';
  financeGrid.innerHTML = '';
  if (hasAdminPermission('dashboard')) mountDashboard();
  if (hasAdminPermission('finance')) mountFinance();
  if (hasAdminPermission('orders')) mountManagement();
  if (hasAdminPermission('admins') || hasAdminPermission('config')) mountAdmins();
  if (hasAdminPermission('notifications')) mountNotifications();
  if (hasAdminPermission('support')) mountSupport();
  if (hasAdminPermission('approvals')) {
    mountPendingApprovalRealtime();
    try {
      await mountPending();
    } catch (err) {
      console.error('mountPending failed', err);
    }
  }
}

onAuthStateChanged(auth, async (user) => {
  clearSubscriptions();
  if (!user) {
    currentAdminProfile = null;
    currentAdminPermissions = new Set();
    authTransitionInProgress = false;
    if (preservedLoginStatus?.message) {
      setLoginStatus(preservedLoginStatus.message, preservedLoginStatus.tone || 'error');
    } else {
      setLoginStatus('');
    }
    authState.textContent = 'غير مسجل';
    loginCard.hidden = false;
    appPanel.hidden = true;
    logoutBtn.hidden = true;
    return;
  }

  await handleAuthenticatedUser(user);
});
