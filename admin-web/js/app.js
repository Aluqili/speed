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
  writeBatch,
  GeoPoint
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-firestore.js';

import {
  configForEnv,
  setAdminEnv,
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
const adminDeleteRestaurantAccount = httpsCallable(fns, 'adminDeleteRestaurantAccount');
const adminGeocodeRestaurantAddress = httpsCallable(fns, 'adminGeocodeRestaurantAddress');
const adminUpdatePromocode = httpsCallable(fns, 'adminUpdatePromocode');

const loginCard = document.getElementById('loginCard');
const appPanel = document.getElementById('appPanel');
const loginForm = document.getElementById('loginForm');
const resetPasswordBtn = document.getElementById('resetPasswordBtn');
const loginStatus = document.getElementById('loginStatus');
const logoutBtn = document.getElementById('logoutBtn');
const authState = document.getElementById('authState');
const envBadge = document.getElementById('envBadge');
const envSelect = document.getElementById('envSelect');
const adminGlobalSearch = document.getElementById('adminGlobalSearch');
const adminSearchMeta = document.getElementById('adminSearchMeta');
const adminSearchResults = document.getElementById('adminSearchResults');
const dashboardQuickActions = document.getElementById('dashboardQuickActions');
const appSidebar = document.getElementById('appSidebar');
const sidebarToggleBtn = document.getElementById('sidebarToggleBtn');

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
const commercialRegistryImageUrlInput = document.getElementById('commercialRegistryImageUrlInput');
const commercialRegistryLinkUrlInput = document.getElementById('commercialRegistryLinkUrlInput');
const savePaymentSettingsBtn = document.getElementById('savePaymentSettingsBtn');
const paymentSettingsResult = document.getElementById('paymentSettingsResult');
const shiftAccountForm = document.getElementById('shiftAccountForm');
const shiftEmployeeDisplayName = document.getElementById('shiftEmployeeDisplayName');
const saveShiftAccountBtn = document.getElementById('saveShiftAccountBtn');
const activateShiftAccountBtn = document.getElementById('activateShiftAccountBtn');
const endShiftAccountBtn = document.getElementById('endShiftAccountBtn');
const activeShiftOwnerLabel = document.getElementById('activeShiftOwnerLabel');
const shiftIncomeSummary = document.getElementById('shiftIncomeSummary');
const shiftAccountResult = document.getElementById('shiftAccountResult');
const restaurantsTable = document.getElementById('restaurantsTable');
const couriersTable = document.getElementById('couriersTable');
const deliveryZoneForm = document.getElementById('deliveryZoneForm');
const deliveryZoneId = document.getElementById('deliveryZoneId');
const deliveryZoneName = document.getElementById('deliveryZoneName');
const deliveryZoneClusterId = document.getElementById('deliveryZoneClusterId');
const deliveryZoneFee = document.getElementById('deliveryZoneFee');
const deliveryZoneDriverPayout = document.getElementById('deliveryZoneDriverPayout');
const deliveryZoneLat = document.getElementById('deliveryZoneLat');
const deliveryZoneLng = document.getElementById('deliveryZoneLng');
const deliveryZoneRadiusKm = document.getElementById('deliveryZoneRadiusKm');
const deliveryZoneActive = document.getElementById('deliveryZoneActive');
const deliveryZonesResult = document.getElementById('deliveryZonesResult');
const deliveryZonesTable = document.getElementById('deliveryZonesTable');
const adminsTable = document.getElementById('adminsTable');
const supportRoot = document.getElementById('supportRoot');
const supportConversationList = document.getElementById('supportConversationList');
const supportConversationHeader = document.getElementById('supportConversationHeader');
const supportMessagesPane = document.getElementById('supportMessagesPane');
const supportMobileBackBtn = document.getElementById('supportMobileBackBtn');
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
const notificationImageInput = document.getElementById('notificationImageInput');
const notificationAttachImageBtn = document.getElementById('notificationAttachImageBtn');
const notificationImagePreview = document.getElementById('notificationImagePreview');
const notificationImagePreviewImg = document.getElementById('notificationImagePreviewImg');
const notificationRemoveImageBtn = document.getElementById('notificationRemoveImageBtn');
const pendingTable = document.getElementById('pendingTable');
const pendingGeoStatsSummary = document.getElementById('pendingGeoStatsSummary');
const pendingGeoStatsTables = document.getElementById('pendingGeoStatsTables');
const pendingMenuTable = document.getElementById('pendingMenuTable');
const storeDetailsPanel = document.getElementById('storeDetailsPanel');
const courierDetailsPanel = document.getElementById('courierDetailsPanel');
const courierActivitySummary = document.getElementById('courierActivitySummary');
const courierActivityTable = document.getElementById('courierActivityTable');
const clientDetailsPanel = document.getElementById('clientDetailsPanel');
const operationsOrderSummary = document.getElementById('operationsOrderSummary');
const operationsOrdersTable = document.getElementById('operationsOrdersTable');
const operationsOrderDetails = document.getElementById('operationsOrderDetails');
const mockOrderForm = document.getElementById('mockOrderForm');
const mockOrderMode = document.getElementById('mockOrderMode');
const mockOrderCourierIds = document.getElementById('mockOrderCourierIds');
const mockOrderClientName = document.getElementById('mockOrderClientName');
const mockOrderClientPhone = document.getElementById('mockOrderClientPhone');
const mockOrderStoreName = document.getElementById('mockOrderStoreName');
const mockOrderAddress = document.getElementById('mockOrderAddress');
const mockOrderPaymentMethod = document.getElementById('mockOrderPaymentMethod');
const mockOrderCreateBtn = document.getElementById('mockOrderCreateBtn');
const mockOrderResult = document.getElementById('mockOrderResult');
const clientsTable = document.getElementById('clientsTable');
const orderStatusFilter = document.getElementById('orderStatusFilter');
const orderSearchInput = document.getElementById('orderSearchInput');
const ordersSegmentButtons = Array.from(document.querySelectorAll('[data-orders-segment]'));
const addAdminForm = document.getElementById('addAdminForm');
const adminEmailInput = document.getElementById('adminEmailInput');
const adminPermissionInputs = Array.from(document.querySelectorAll('input[name="adminPermission"]'));
const adminCanDeleteRestaurantsInput = document.getElementById('adminCanDeleteRestaurantsInput');
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
const clientOptionalUpdateEnabledInput = document.getElementById('clientOptionalUpdateEnabledInput');
const clientRecommendedBuildAndroidInput = document.getElementById('clientRecommendedBuildAndroidInput');
const clientOptionalUpdateMessageInput = document.getElementById('clientOptionalUpdateMessageInput');
const paymentReceiptPrecheckEnabledInput = document.getElementById('paymentReceiptPrecheckEnabledInput');
const paymentReceiptPrecheckModeInput = document.getElementById('paymentReceiptPrecheckModeInput');
const paymentReceiptRequireImageInput = document.getElementById('paymentReceiptRequireImageInput');
const paymentReceiptRequireReferenceInput = document.getElementById('paymentReceiptRequireReferenceInput');
const paymentReceiptMinReferenceDigitsInput = document.getElementById('paymentReceiptMinReferenceDigitsInput');
const paymentReceiptRequirementsMessageInput = document.getElementById('paymentReceiptRequirementsMessageInput');
const paymentReceiptMissingImageMessageInput = document.getElementById('paymentReceiptMissingImageMessageInput');
const paymentReceiptMissingReferenceMessageInput = document.getElementById('paymentReceiptMissingReferenceMessageInput');
const paymentReceiptShortReferenceMessageInput = document.getElementById('paymentReceiptShortReferenceMessageInput');
const paymentReceiptInvalidAmountMessageInput = document.getElementById('paymentReceiptInvalidAmountMessageInput');
const paymentReceiptWarningTitleInput = document.getElementById('paymentReceiptWarningTitleInput');
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
const storeBatchMaxStopsPerTripInput = document.getElementById('storeBatchMaxStopsPerTripInput');
const storeBatchSingleTripMaxStopsInput = document.getElementById('storeBatchSingleTripMaxStopsInput');
const storeBatchSingleTripMaxRouteKmInput = document.getElementById('storeBatchSingleTripMaxRouteKmInput');
const storeBatchMaxRouteKmPerTripInput = document.getElementById('storeBatchMaxRouteKmPerTripInput');
const storeBatchGroupUnclusteredZonesInput = document.getElementById('storeBatchGroupUnclusteredZonesInput');
const reloadPricingConfigBtn = document.getElementById('reloadPricingConfigBtn');
const savePricingConfigBtn = document.getElementById('savePricingConfigBtn');
const pricingConfigResult = document.getElementById('pricingConfigResult');
const storeHomeConfigForm = document.getElementById('storeHomeConfigForm');
const storeHomeConfigTarget = document.getElementById('storeHomeConfigTarget');
const storeHomeFeaturedInput = document.getElementById('storeHomeFeaturedInput');
const storeHomeOffersInput = document.getElementById('storeHomeOffersInput');
const storeHomeConfigResult = document.getElementById('storeHomeConfigResult');
const clientHomeImagesForm = document.getElementById('clientHomeImagesForm');
const clientHomeImagesResult = document.getElementById('clientHomeImagesResult');
const rewardsConfigForm = document.getElementById('rewardsConfigForm');
const rewardsEnabledInput = document.getElementById('rewardsEnabledInput');
const rewardsAmountPerPointInput = document.getElementById('rewardsAmountPerPointInput');
const rewardsMinRedeemPointsInput = document.getElementById('rewardsMinRedeemPointsInput');
const rewardsConfigResult = document.getElementById('rewardsConfigResult');
const discountForm = document.getElementById('discountForm');
const discountCode = document.getElementById('discountCode');
const discountScope = document.getElementById('discountScope');
const discountType = document.getElementById('discountType');
const discountValue = document.getElementById('discountValue');
const discountValueLabel = document.getElementById('discountValueLabel');
const discountEligibility = document.getElementById('discountEligibility');
const discountEligibilityField = document.getElementById('discountEligibilityField');
const discountTargetOrderField = document.getElementById('discountTargetOrderField');
const discountTargetOrderNumber = document.getElementById('discountTargetOrderNumber');
const discountTieredFields = document.getElementById('discountTieredFields');
const discountFirstOrderType = document.getElementById('discountFirstOrderType');
const discountFirstOrderValue = document.getElementById('discountFirstOrderValue');
const discountReturningType = document.getElementById('discountReturningType');
const discountReturningValue = document.getElementById('discountReturningValue');
const discountMinOrder = document.getElementById('discountMinOrder');
const discountMaxUsage = document.getElementById('discountMaxUsage');
const discountMaxUsagePerRestaurant = document.getElementById('discountMaxUsagePerRestaurant');
const discountMaxUsagePerUser = document.getElementById('discountMaxUsagePerUser');
const discountMaxDiscount = document.getElementById('discountMaxDiscount');
const discountRestaurantScope = document.getElementById('discountRestaurantScope');
const discountRestaurantIds = document.getElementById('discountRestaurantIds');
const discountRestaurantsField = document.getElementById('discountRestaurantsField');
const discountItemName = document.getElementById('discountItemName');
const discountExpiryDate = document.getElementById('discountExpiryDate');
const discountIsActive = document.getElementById('discountIsActive');
const discountSaveBtn = document.getElementById('discountSaveBtn');
const discountCancelEditBtn = document.getElementById('discountCancelEditBtn');
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
let notificationPendingImageFile = null;
let notificationPendingImagePreviewUrl = '';
let authTransitionInProgress = false;
let preservedLoginStatus = null;
let selectedOrderOnMapId = '';
let currentMapSelection = null;
let currentAdminProfile = null;
let currentAdminPermissions = new Set();
let financeRangeFilterBound = false;
let paymentSettingsFormBound = false;
let shiftAccountFormBound = false;
let rolloutSelectedCityIds = new Set();
let remoteConfigParametersCache = [];
let operationsOrdersBound = false;
let mockOrderFormBound = false;
let operationsOrderDocsCache = [];
let currentOperationsOrderId = '';
let courierDirectoryCache = [];
let courierDirectoryDocsCache = [];
let courierSearchFilterFrame = 0;
let pendingMountRefreshTimer = null;
let managementRenderTimers = {
  operations: null,
  courierActivity: null,
};
let activeOrderDriverUnsubscribe = null;
let activeOrderDriverCleanupRegistered = false;
let activeOrderDriverId = '';
let longDistanceCouriersUnsubscribe = null;
let longDistanceCouriersOrderId = '';
let restaurantsDirectoryCache = new Map(); // storeId → {name, ...}
let orderInlineMap = null;
let orderInlineMapVisible = false;
let orderInlineMapOrderId = '';

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

const ADMIN_ORDER_STATUS_FLOW = [
  'pending',
  'store_pending',
  'courier_searching',
  'courier_offer_pending',
  'courier_assigned',
  'pickup_ready',
  'picked_up',
  'arrived_to_client',
  'delivered',
];

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

function getAdminOrderedStatusChoices(currentStatusRaw) {
  const currentStatus = String(currentStatusRaw || '').trim().toLowerCase();
  const choices = ADMIN_ORDER_STATUS_FLOW.map((key, index) => {
    const label = ORDER_STATUS_LABELS[key] || key;
    return {
      key,
      title: `${index + 1}. ${label}`,
      selected: key === currentStatus,
    };
  });

  if (currentStatus && !ADMIN_ORDER_STATUS_FLOW.includes(currentStatus)) {
    choices.unshift({
      key: currentStatus,
      title: `الحالة الحالية: ${formatOrderStatusLabel(currentStatus)}`,
      selected: true,
    });
  }

  return choices;
}

function renderStoreApprovalFlowHint(orderData) {
  const data = orderData || {};
  const status = String(data.orderStatus || data.status || '').trim().toLowerCase();
  const courierAcceptedBeforeStore = data.courierAcceptedBeforeStore === true;
  const storeApprovedAtMs = getTimestampMillis(data.storeApprovedAt);
  const hasAssignedDriver = String(data.assignedDriverId || '').trim().length > 0;

  if (courierAcceptedBeforeStore && status === 'store_pending') {
    return '<div style="margin-top:8px; padding:8px 10px; border:1px solid #f59e0b55; background:#fff7ed; border-radius:10px; color:#9a3412;"><b>تنبيه تشغيلي:</b> المندوب وافق أولاً والطلب ما زال بانتظار قبول المتجر.</div>';
  }

  if (storeApprovedAtMs > 0 && hasAssignedDriver) {
    return `<div style="margin-top:8px; padding:8px 10px; border:1px solid #16a34a55; background:#f0fdf4; border-radius:10px; color:#14532d;"><b>تنبيه تشغيلي:</b> المتجر وافق بعد قبول المندوب وتم اعتماد الإسناد.${storeApprovedAtMs ? ` <span class="muted">(${escapeHtml(formatDateTimeLabel(storeApprovedAtMs))})</span>` : ''}</div>`;
  }

  return '';
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

function resolveRestaurantPhone(restaurantId, fallbackPhone = '') {
  const id = String(restaurantId || '').trim();
  const direct = String(fallbackPhone || '').trim();
  if (direct) return direct;
  if (!id) return '';

  const fromMapState = mapState?.restaurants?.get(id)?.data?.phone;
  if (String(fromMapState || '').trim()) return String(fromMapState).trim();

  const fromDirectory = restaurantsDirectoryCache?.get(id)?.phone;
  if (String(fromDirectory || '').trim()) return String(fromDirectory).trim();

  return '';
}

function resolveDriverPhone(driverId, fallbackPhone = '') {
  const id = String(driverId || '').trim();
  const direct = String(fallbackPhone || '').trim();
  if (direct) return direct;
  if (!id) return '';

  const fromMapState = mapState?.drivers?.get(id)?.data?.phone;
  if (String(fromMapState || '').trim()) return String(fromMapState).trim();

  const fromDirectory = (courierDirectoryCache || []).find((entry) => entry.id === id)?.data?.phone;
  if (String(fromDirectory || '').trim()) return String(fromDirectory).trim();

  return '';
}

function normalizeApprovalStatus(value, isApproved) {
  if (value === true) return 'approved';
  if (value === false) return 'rejected';
  const raw = String(value || '').trim().toLowerCase();
  if (raw) return raw;
  if (isApproved === true) return 'approved';
  if (isApproved === false) return 'rejected';
  return 'pending';
}

function formatApprovalStatusLabel(value, isApproved) {
  const normalized = normalizeApprovalStatus(value, isApproved);
  return APPROVAL_STATUS_LABELS[normalized] || String(value || '').trim() || (isApproved === true ? APPROVAL_STATUS_LABELS.approved : isApproved === false ? APPROVAL_STATUS_LABELS.rejected : '-');
}

const mapUiState = {
  style: 'osm',
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
const OPS_LAST_TAB_KEY = 'speedstar-admin-last-tab';
let opsAudioContext = null;
let opsSpeechPrimed = false;
let opsAudioControlsBound = false;

const opsCenterState = {
  activeOrders: 0,
  openCourierIssues: 0,
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
  opsCenterState.openCourierIssues = 0;
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
  client_optional_update_enabled: {
    label: 'تفعيل التحديث الاختياري للعميل',
    description: 'إظهار تذكير تحديث اختياري للعميل مع خيار لاحقا.',
    valueType: 'BOOLEAN',
  },
  client_recommended_build_android: {
    label: 'أقل بناء مقترح للعميل',
    description: 'إذا كان بناء تطبيق العميل أقل من هذا الرقم يظهر تحديث اختياري.',
    valueType: 'NUMBER',
  },
  client_optional_update_message: {
    label: 'رسالة التحديث الاختياري للعميل',
    description: 'الرسالة التي تظهر للعميل في نافذة التحديث الاختياري.',
    valueType: 'STRING',
  },
  client_phone_signin_enabled_sudan: {
    label: 'تسجيل العميل برقم الهاتف',
    description: 'تشغيل أو إيقاف تسجيل ودخول العميل برقم سوداني عبر كود SMS من Firebase.',
    valueType: 'BOOLEAN',
  },
  client_phone_otp_enabled: {
    label: 'تفعيل رمز الهاتف عبر واتساب',
    description: 'تشغيل أو إيقاف تسجيل ودخول العميل برمز واتساب من السيرفر.',
    valueType: 'BOOLEAN',
  },
  client_phone_otp_ttl_minutes: {
    label: 'مدة صلاحية رمز الهاتف',
    description: 'عدد الدقائق التي يبقى فيها رمز واتساب صالحا قبل طلب رمز جديد.',
    valueType: 'NUMBER',
  },
  client_phone_otp_resend_seconds: {
    label: 'مهلة إعادة إرسال الرمز',
    description: 'عدد الثواني قبل السماح للعميل بطلب رمز جديد لنفس الرقم.',
    valueType: 'NUMBER',
  },
  client_phone_otp_max_requests_per_hour: {
    label: 'حد إرسال رموز الهاتف',
    description: 'أقصى عدد رموز يمكن إرسالها لنفس الرقم خلال ساعة.',
    valueType: 'NUMBER',
  },
  client_phone_otp_max_attempts: {
    label: 'حد محاولات رمز الهاتف',
    description: 'أقصى عدد محاولات إدخال خاطئة قبل طلب رمز جديد.',
    valueType: 'NUMBER',
  },
  client_phone_otp_whatsapp_template: {
    label: 'قالب واتساب لرمز الهاتف',
    description: 'اسم قالب Meta المعتمد لإرسال رمز الدخول، مثلا client_phone_otp.',
    valueType: 'STRING',
  },
  client_phone_otp_whatsapp_language: {
    label: 'لغة قالب رمز الهاتف',
    description: 'كود لغة قالب واتساب المعتمد، مثلا ar.',
    valueType: 'STRING',
  },
  client_phone_otp_button_code_enabled: {
    label: 'إرسال كود زر OTP',
    description: 'فعله لقوالب واتساب Authentication التي فيها زر نسخ الرمز أو الملء التلقائي.',
    valueType: 'BOOLEAN',
  },
  client_phone_otp_debug_code_enabled: {
    label: 'إظهار رمز الهاتف للتجربة',
    description: 'للاختبار فقط. عند تفعيله ترجع الدالة الرمز للتطبيق. أوقفه في الإنتاج.',
    valueType: 'BOOLEAN',
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
  payment_receipt_precheck_enabled: {
    label: 'تفعيل فحص إيصال الدفع',
    description: 'تشغيل أو إيقاف فحص الإيصال قبل إرسال طلب الدفع من تطبيق العميل.',
    valueType: 'BOOLEAN',
  },
  payment_receipt_precheck_mode: {
    label: 'وضع فحص إيصال الدفع',
    description: 'block يمنع الطلب عند النقص، warn يحذر ويسمح، off يعطل الفحص.',
    valueType: 'STRING',
  },
  payment_receipt_require_image: {
    label: 'طلب صورة إيصال الدفع',
    description: 'يجعل صورة الإيصال مطلوبة قبل إرسال الدفع.',
    valueType: 'BOOLEAN',
  },
  payment_receipt_require_reference: {
    label: 'طلب رقم العملية',
    description: 'يجعل رقم العملية مطلوبا قبل إرسال الدفع.',
    valueType: 'BOOLEAN',
  },
  payment_receipt_min_reference_digits: {
    label: 'أقل أرقام لرقم العملية',
    description: 'الحد الأدنى لعدد الأرقام داخل رقم العملية قبل قبوله.',
    valueType: 'NUMBER',
  },
  payment_receipt_requirements_message: {
    label: 'رسالة تعليمات الإيصال',
    description: 'النص الذي يظهر للعميل تحت خانة رفع الإيصال.',
    valueType: 'STRING',
  },
  payment_receipt_missing_image_message: {
    label: 'رسالة نقص صورة الإيصال',
    description: 'الرسالة التي تظهر إذا لم يرفع العميل صورة الإيصال.',
    valueType: 'STRING',
  },
  payment_receipt_missing_reference_message: {
    label: 'رسالة نقص رقم العملية',
    description: 'الرسالة التي تظهر إذا ترك العميل رقم العملية فارغا.',
    valueType: 'STRING',
  },
  payment_receipt_short_reference_message: {
    label: 'رسالة رقم العملية الناقص',
    description: 'الرسالة التي تظهر إذا كان رقم العملية أقصر من الحد الأدنى.',
    valueType: 'STRING',
  },
  payment_receipt_invalid_amount_message: {
    label: 'رسالة مبلغ الدفع غير الواضح',
    description: 'الرسالة التي تظهر إذا لم يستطع التطبيق تحديد مبلغ الدفع المطلوب.',
    valueType: 'STRING',
  },
  payment_receipt_warning_title: {
    label: 'عنوان تحذير الإيصال',
    description: 'عنوان نافذة التحذير عند استخدام وضع warn.',
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
  courier_pickup_delay_reminder_minutes: {
    label: 'تذكير تأخر استلام الطلب',
    description: 'عدد الدقائق بعد قبول المندوب للطلب قبل إرسال تذكير الاستلام الأول.',
    valueType: 'NUMBER',
  },
  courier_pickup_delay_critical_minutes: {
    label: 'إنذار تأخر استلام الطلب',
    description: 'عدد الدقائق بعد قبول المندوب للطلب قبل إرسال إنذار التأخر الشديد.',
    valueType: 'NUMBER',
  },
  courier_client_arrival_delay_minutes: {
    label: 'تذكير تأخر الوصول للعميل',
    description: 'عدد الدقائق بعد استلام المندوب للطلب قبل تذكيره بالوصول للعميل.',
    valueType: 'NUMBER',
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
  client_home_show_offers_section: {
    label: 'إظهار قسم العروض في الرئيسية',
    description: 'تشغيل أو إيقاف سلايدر العروض في الصفحة الرئيسية للعميل.',
    valueType: 'BOOLEAN',
  },
  client_home_show_categories_section: {
    label: 'إظهار قسم التصنيفات في الرئيسية',
    description: 'تشغيل أو إيقاف شريط التصنيفات في الصفحة الرئيسية للعميل.',
    valueType: 'BOOLEAN',
  },
  client_home_show_restaurants_section: {
    label: 'إظهار قسم المطاعم في الرئيسية',
    description: 'تشغيل أو إيقاف قائمة المطاعم في الصفحة الرئيسية للعميل.',
    valueType: 'BOOLEAN',
  },
  client_feature_business_filters: {
    label: 'إظهار تبويبات أنواع المنشآت',
    description: 'تشغيل أو إيقاف تبويبات المطاعم والبقالات والصيدليات والبراندات في رئيسية العميل.',
    valueType: 'BOOLEAN',
  },
  client_feature_parcel_delivery: {
    label: 'تفعيل خدمة وصل غرضك',
    description: 'تشغيل أو إيقاف خدمة توصيل غرض العميل بين نقطتي استلام وتسليم.',
    valueType: 'BOOLEAN',
  },
  client_delivery_time_mode: {
    label: 'وضع زمن التوصيل للعميل',
    description: 'القيم: hybrid أو admin_only أو computed للتحكم في طريقة عرض زمن التوصيل.',
    valueType: 'STRING',
  },
  client_delivery_time_show_route_minutes: {
    label: 'إضافة زمن الطريق إلى زمن الأدمن',
    description: 'عند تفعيلها في وضع hybrid يُضاف زمن الطريق إلى الزمن المضبوط من المطعم.',
    valueType: 'BOOLEAN',
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
  store_batch_max_stops_per_trip: {
    label: 'أقصى توقفات رحلة المتجر',
    description: 'أكبر عدد عملاء يمكن وضعهم في رحلة مجمعة واحدة للمتجر.',
    valueType: 'NUMBER',
  },
  store_batch_single_trip_max_stops: {
    label: 'حد الرحلة الواحدة للطلبات القليلة',
    description: 'إذا كان عدد طلبات المتجر أقل من هذا الحد، يحاول النظام إبقاءها مع مندوب واحد.',
    valueType: 'NUMBER',
  },
  store_batch_single_trip_max_route_km: {
    label: 'مسافة الرحلة الواحدة للطلبات القليلة',
    description: 'أقصى طول مسار يسمح بإبقاء الطلبات القليلة في رحلة واحدة.',
    valueType: 'NUMBER',
  },
  store_batch_max_route_km_per_trip: {
    label: 'أقصى مسافة للرحلة المجمعة',
    description: 'عند تجاوز المسار هذه المسافة يقسم النظام التوقفات إلى رحلة أخرى.',
    valueType: 'NUMBER',
  },
  store_batch_group_unclustered_zones: {
    label: 'تجميع المناطق غير المصنفة',
    description: 'يجمع المناطق التي لا تملك clusterId واضحا بدل فصل كل منطقة وحدها.',
    valueType: 'BOOLEAN',
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
  'store_batch_max_stops_per_trip',
  'store_batch_single_trip_max_stops',
  'store_batch_single_trip_max_route_km',
  'store_batch_max_route_km_per_trip',
  'store_batch_group_unclustered_zones',
];

const OPS_RUNTIME_REMOTE_CONFIG_METADATA = {
  ops_chat_enabled: { label: 'تفعيل الدردشة العامة', description: 'تشغيل أو إيقاف الدردشة في كل التطبيقات.', valueType: 'BOOLEAN' },
  ops_chat_disabled_message: { label: 'رسالة إيقاف الدردشة العامة', description: 'الرسالة المعروضة عند إيقاف الدردشة.', valueType: 'STRING' },
  ops_notifications_enabled: { label: 'تفعيل الإشعارات العامة', description: 'تشغيل أو إيقاف الإشعارات في كل التطبيقات.', valueType: 'BOOLEAN' },
  ops_ringtone_enabled: { label: 'تفعيل النغمة العامة', description: 'تشغيل أو إيقاف نغمة التنبيه في التطبيقات.', valueType: 'BOOLEAN' },
  ops_ringtone_volume: { label: 'مستوى النغمة العام', description: 'قيمة من 0 إلى 1 لمستوى نغمة التنبيه.', valueType: 'NUMBER' },
};

for (const [appKey, appLabel] of Object.entries({ client: 'العميل', courier: 'المندوب', store: 'المتجر' })) {
  Object.assign(OPS_RUNTIME_REMOTE_CONFIG_METADATA, {
    [`${appKey}_chat_enabled`]: { label: `تفعيل دردشة ${appLabel}`, description: `تشغيل أو إيقاف الدردشة في تطبيق ${appLabel}.`, valueType: 'BOOLEAN' },
    [`${appKey}_chat_disabled_message`]: { label: `رسالة إيقاف دردشة ${appLabel}`, description: `رسالة إيقاف الدردشة الخاصة بتطبيق ${appLabel}.`, valueType: 'STRING' },
    [`${appKey}_notifications_enabled`]: { label: `تفعيل إشعارات ${appLabel}`, description: `تشغيل أو إيقاف الإشعارات في تطبيق ${appLabel}.`, valueType: 'BOOLEAN' },
    [`${appKey}_ringtone_enabled`]: { label: `تفعيل نغمة ${appLabel}`, description: `تشغيل أو إيقاف نغمة التنبيه في تطبيق ${appLabel}.`, valueType: 'BOOLEAN' },
    [`${appKey}_ringtone_volume`]: { label: `مستوى نغمة ${appLabel}`, description: `قيمة من 0 إلى 1 لمستوى نغمة تطبيق ${appLabel}.`, valueType: 'NUMBER' },
  });
}

Object.assign(REMOTE_CONFIG_METADATA, OPS_RUNTIME_REMOTE_CONFIG_METADATA);

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
  'client_optional_update_enabled',
  'client_recommended_build_android',
  'client_optional_update_message',
  'payment_receipt_precheck_enabled',
  'payment_receipt_precheck_mode',
  'payment_receipt_require_image',
  'payment_receipt_require_reference',
  'payment_receipt_min_reference_digits',
  'payment_receipt_requirements_message',
  'payment_receipt_missing_image_message',
  'payment_receipt_missing_reference_message',
  'payment_receipt_short_reference_message',
  'payment_receipt_invalid_amount_message',
  'payment_receipt_warning_title',
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
    const panel = portalPanels.find((item) => item.dataset.subpanel === nextSubpanelId);
    panel?.scrollIntoView({ behavior: 'smooth', block: 'start' });
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
    envBadge.textContent = `ENV: ${activeEnv.toUpperCase()}`;
  }
  if (envSelect) {
    envSelect.value = activeEnv;
  }
}

syncEnvUi();
if (envSelect) {
  envSelect.addEventListener('change', () => {
    const nextEnv = setAdminEnv(envSelect.value);
    window.location.search = `?env=${encodeURIComponent(nextEnv)}`;
  });
}
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
    <div class="stat accent-danger"><h4>بلاغات مندوب مفتوحة</h4><b>${Number(opsCenterState.openCourierIssues || 0).toLocaleString('ar-EG')}</b></div>
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
    ...(nextAvailable ? {} : { acceptsLongDistance: false, longDistanceEnabledAt: null }),
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

function stopActiveOrderDriverListener() {
  if (typeof activeOrderDriverUnsubscribe === 'function') {
    activeOrderDriverUnsubscribe();
  }
  if (typeof longDistanceCouriersUnsubscribe === 'function') {
    longDistanceCouriersUnsubscribe();
  }
  activeOrderDriverUnsubscribe = null;
  activeOrderDriverId = '';
  longDistanceCouriersUnsubscribe = null;
  longDistanceCouriersOrderId = '';
}

function extractDriverPoint(raw) {
  if (!raw) return null;
  if (typeof GeoPoint !== 'undefined' && raw instanceof GeoPoint) {
    return { lat: raw.latitude, lng: raw.longitude };
  }
  if (typeof raw === 'object') {
    const lat = Number(raw.lat ?? raw.latitude);
    const lng = Number(raw.lng ?? raw.longitude);
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      return { lat, lng };
    }
  }
  return null;
}

function renderLongDistanceCouriersList(orderId, orderData, driverDocs = []) {
  const host = document.getElementById(`longDistanceCouriers-${orderId}`);
  if (!host) return;

  const savedIds = Array.isArray(orderData.longDistanceDriverIds)
    ? orderData.longDistanceDriverIds.map((id) => String(id || '').trim()).filter(Boolean)
    : [];
  const savedDistances = orderData.longDistanceDriverDistancesKm || {};
  const liveRows = driverDocs
    .map((driverSnap) => ({ id: driverSnap.id, data: driverSnap.data() || {} }))
    .filter((item) => item.data.available === true && item.data.acceptsLongDistance === true);

  const merged = new Map();
  savedIds.forEach((id) => {
    const cached = courierDirectoryCache.find((item) => item.id === id);
    merged.set(id, {
      id,
      data: cached?.data || {},
      distanceKm: Number(savedDistances[id]),
      saved: true,
    });
  });
  liveRows.forEach((item) => {
    const previous = merged.get(item.id) || {};
    merged.set(item.id, {
      id: item.id,
      data: { ...(previous.data || {}), ...(item.data || {}) },
      distanceKm: previous.distanceKm,
      saved: previous.saved === true,
    });
  });

  const rows = Array.from(merged.values())
    .filter((item) => item.data.isApproved === true || String(item.data.approvalStatus || '').toLowerCase() === 'approved')
    .sort((a, b) => {
      const aDistance = Number.isFinite(a.distanceKm) ? a.distanceKm : 999999;
      const bDistance = Number.isFinite(b.distanceKm) ? b.distanceKm : 999999;
      return aDistance - bDistance;
    });

  if (!rows.length) {
    host.innerHTML = '<div class="muted">لا يوجد مندوب متاح مفعّل للمسافات البعيدة الآن.</div>';
    return;
  }

  host.innerHTML = rows.map((item) => {
    const distanceText = Number.isFinite(item.distanceKm)
      ? `${item.distanceKm.toFixed(1)} كم من المطعم`
      : 'المسافة غير محسوبة';
    const area = item.data.workAreaLabel || item.data.region || item.data.city || '-';
    return `
      <div class="order-timeline-item">
        <b>${escapeHtml(item.data.name || item.id)}</b>
        <span>${escapeHtml(distanceText)} | ${escapeHtml(area)}</span>
        <button class="btn ghost" data-assign-long-driver="${escapeHtml(item.id)}" data-order-id="${escapeHtml(orderId)}">اختيار</button>
      </div>
    `;
  }).join('');

  host.querySelectorAll('[data-assign-long-driver]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const driverId = btn.getAttribute('data-assign-long-driver');
      const targetOrderId = btn.getAttribute('data-order-id');
      if (!driverId || !targetOrderId) return;
      const payload = {
        orderId: targetOrderId,
        action: 'assign_specific',
        nextDriverId: driverId,
        driverId,
        note: 'long_distance_manual_assignment',
      };
      await withBtnLoading(btn, async () => {
        await adminManageOrder(payload);
        alert('تم تحويل الطلب إلى مندوب المسافات البعيدة.');
        renderOperationsOrderDetails(targetOrderId);
      });
    });
  });
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

function normalizeSupportSourceApp(value) {
  const v = String(value || '').trim().toLowerCase();
  if (v === 'courier' || v === 'driver') return 'courier';
  if (v === 'store' || v === 'restaurant') return 'store';
  return 'client';
}

function splitSupportThreadKey(value) {
  let base = String(value || '').trim();
  let sourceApp = '';
  const prefixPattern = /^(client|courier|store):(.+)$/;
  let match = base.match(prefixPattern);
  while (match) {
    if (!sourceApp) sourceApp = match[1];
    base = match[2];
    match = base.match(prefixPattern);
  }
  return { sourceApp, base };
}

function buildSupportThreadKeyFromData(data = {}) {
  const explicitThreadKey = String(
    data.supportThreadKey || data.supportThreadId || data.threadKey || data.threadId || ''
  ).trim();
  const conversationId = String(data.conversationId || '').trim();
  const parsed = splitSupportThreadKey(explicitThreadKey || conversationId);
  const sourceApp = parsed.sourceApp || normalizeSupportSourceApp(data.sourceApp || 'client');
  const base = parsed.base || conversationId;
  return base ? `${sourceApp}:${base}` : '';
}

function getSupportThreadBaseKey(threadKey) {
  return splitSupportThreadKey(threadKey).base || String(threadKey || '').trim();
}

async function markSupportConversationRead(conversation) {
  const conversationId = typeof conversation === 'object'
    ? String(conversation?.conversationId || conversation?.id || '').trim()
    : String(conversation || '').trim();
  if (!conversationId) return;
  const expectedThreadKey = typeof conversation === 'object'
    ? String(conversation?.id || '').trim()
    : '';
  const q = query(collection(db, 'supportMessages'), where('conversationId', '==', conversationId));
  const result = await getDocs(q);
  if (!result.docs.length) return;
  const batch = writeBatch(db);
  let updates = 0;
  result.docs.forEach((docSnap) => {
    if (expectedThreadKey && buildSupportThreadKeyFromData(docSnap.data() || {}) !== expectedThreadKey) {
      return;
    }
    batch.set(doc(db, 'supportMessages', docSnap.id), {
      adminReadAt: serverTimestamp(),
      adminUnread: false,
      updatedAt: serverTimestamp(),
    }, { merge: true });
    updates += 1;
  });
  if (updates > 0) await batch.commit();
}

async function markAllSupportConversationsRead() {
  const unreadConversations = supportConversations.filter((item) => item.unreadCount > 0);
  for (const convo of unreadConversations) {
    await markSupportConversationRead(convo);
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
const mapRouteLastActualByOrder = new Map();

let leafletReadyPromise = null;
let leafletClusterReadyPromise = null;
let spreadsheetXlsxReadyPromise = null;
let spreadsheetZipReadyPromise = null;

const CLOUDINARY_CLOUD_NAME = 'dvnzloec6';
const CLOUDINARY_UPLOAD_PRESET = 'flutter_unsigned';

async function uploadImageToCloudinary(file, fileName = file?.name || 'upload.jpg') {
  if (!file) return null;
  try {
    const formData = new FormData();
    formData.append('upload_preset', CLOUDINARY_UPLOAD_PRESET);
    formData.append('file', file, fileName || 'upload.jpg');

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

async function downloadImageToDevice(url, suggestedName = 'image') {
  const value = String(url || '').trim();
  if (!value) throw new Error('رابط الصورة غير متاح.');

  const extFromUrl = (() => {
    try {
      const pathname = new URL(value).pathname || '';
      const raw = pathname.split('.').pop() || '';
      const cleaned = String(raw).toLowerCase().replace(/[^a-z0-9]/g, '');
      return cleaned || 'jpg';
    } catch (_) {
      return 'jpg';
    }
  })();

  const baseName = String(suggestedName || 'image').trim().replace(/[^\u0600-\u06FFa-zA-Z0-9._-]/g, '_') || 'image';
  const finalName = baseName.includes('.') ? baseName : `${baseName}.${extFromUrl}`;

  try {
    const response = await fetch(value, { mode: 'cors' });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const blob = await response.blob();
    const blobUrl = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = blobUrl;
    link.download = finalName;
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(blobUrl), 1500);
    return;
  } catch (_) {
    const link = document.createElement('a');
    link.href = value;
    link.target = '_blank';
    link.rel = 'noopener';
    link.download = finalName;
    document.body.appendChild(link);
    link.click();
    link.remove();
  }
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

function normalizeSpreadsheetToken(raw) {
  return String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[\s_-]+/g, '')
    .replace(/[^0-9a-z\u0600-\u06ff]+/g, '');
}

function normalizeSpreadsheetDocId(raw) {
  return String(raw || '')
    .trim()
    .replace(/[\/\\]+/g, '-')
    .replace(/[\s]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function spreadsheetValue(row, aliases) {
  if (!row || typeof row !== 'object') return '';
  const entries = Object.entries(row);
  for (const alias of aliases) {
    const normalizedAlias = normalizeSpreadsheetToken(alias);
    const matched = entries.find(([key]) => normalizeSpreadsheetToken(key) === normalizedAlias);
    if (matched) return matched[1];
  }
  return '';
}

function parseSpreadsheetNumber(raw) {
  const normalized = String(raw || '').trim().replace(',', '.');
  if (!normalized) return null;
  const value = Number(normalized);
  if (!Number.isFinite(value) || value <= 0) return null;
  return value;
}

function parseSpreadsheetBoolean(raw, fallback = true) {
  const normalized = String(raw ?? '').trim().toLowerCase().replace(/\s+/g, '');
  if (!normalized) return fallback;
  if (['1', 'true', 'yes', 'y', 'on', 'active', 'enabled', 'مفعل', 'متاح', 'نعم'].includes(normalized)) {
    return true;
  }
  if (['0', 'false', 'no', 'n', 'off', 'inactive', 'disabled', 'غيرمفعل', 'غيرمتاح', 'لا'].includes(normalized)) {
    return false;
  }
  return fallback;
}

function parseSpreadsheetSizes(row) {
  const basePrice = parseSpreadsheetNumber(spreadsheetValue(row, ['price', 'baseprice', 'السعر', 'سعر']));
  const sizeAliases = [
    ['small', ['smallPrice', 'small', 'سعرصغير', 'صغير']],
    ['medium', ['mediumPrice', 'medium', 'سعروسط', 'وسط']],
    ['large', ['largePrice', 'large', 'سعركبير', 'كبير']],
    ['family', ['familyPrice', 'family', 'سعرعائلي', 'عائلي']],
    ['jumbo', ['jumboPrice', 'jumbo', 'سعرجامبو', 'جامبو']],
  ];

  const sizes = {};
  sizeAliases.forEach(([sizeKey, aliases]) => {
    const parsed = parseSpreadsheetNumber(spreadsheetValue(row, aliases));
    if (parsed != null) {
      sizes[sizeKey] = parsed;
    }
  });

  const hasAnySize = Object.keys(sizes).length > 0;

  if (basePrice == null && !hasAnySize) {
    return {
      ok: false,
      message: 'أدخل السعر الأساسي أو أسعار الأحجام.',
    };
  }

  const fallbackSizePrice =
    sizes.medium ?? sizes.small ?? sizes.large ?? sizes.family ?? sizes.jumbo ?? Object.values(sizes)[0];

  return {
    ok: true,
    price: basePrice ?? fallbackSizePrice,
    sizes: hasAnySize ? sizes : null,
  };
}

async function ensureSpreadsheetXlsx() {
  if (window.XLSX) return;
  if (spreadsheetXlsxReadyPromise) {
    await spreadsheetXlsxReadyPromise;
    return;
  }

  spreadsheetXlsxReadyPromise = (async () => {
    const candidates = [
      'https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js',
      'https://unpkg.com/xlsx@0.18.5/dist/xlsx.full.min.js',
      'https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js'
    ];

    for (const src of candidates) {
      try {
        await loadExternalScript(src);
        if (window.XLSX) return;
      } catch (_) {
      }
    }

    throw new Error('تعذر تحميل مكتبة قراءة CSV/Excel.');
  })();

  await spreadsheetXlsxReadyPromise;
}

async function ensureSpreadsheetZip() {
  if (window.JSZip) return;
  if (spreadsheetZipReadyPromise) {
    await spreadsheetZipReadyPromise;
    return;
  }

  spreadsheetZipReadyPromise = (async () => {
    const candidates = [
      'https://cdn.jsdelivr.net/npm/jszip@3.10.1/dist/jszip.min.js',
      'https://unpkg.com/jszip@3.10.1/dist/jszip.min.js',
      'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js'
    ];

    for (const src of candidates) {
      try {
        await loadExternalScript(src);
        if (window.JSZip) return;
      } catch (_) {
      }
    }

    throw new Error('تعذر تحميل مكتبة ملفات ZIP.');
  })();

  await spreadsheetZipReadyPromise;
}

async function readSpreadsheetRows(file) {
  await ensureSpreadsheetXlsx();

  const isCsv = /\.(csv|txt)$/i.test(file.name) || /csv|text/i.test(file.type || '');
  const workbook = isCsv
    ? window.XLSX.read(await file.text(), { type: 'string' })
    : window.XLSX.read(await file.arrayBuffer(), { type: 'array' });

  const sheetName = workbook?.SheetNames?.[0];
  if (!sheetName) return [];

  const sheet = workbook.Sheets[sheetName];
  if (!sheet) return [];

  return window.XLSX.utils.sheet_to_json(sheet, {
    defval: '',
    raw: false,
    blankrows: false,
  });
}

async function buildSpreadsheetZipState(zipFile) {
  await ensureSpreadsheetZip();
  const zip = await window.JSZip.loadAsync(await zipFile.arrayBuffer());
  const entries = [];

  zip.forEach((relativePath, entry) => {
    if (!entry.dir) {
      entries.push({ path: relativePath, entry });
    }
  });

  return {
    entries,
    cache: new Map(),
  };
}

function findSpreadsheetZipEntry(zipState, imageKey) {
  if (!zipState || !String(imageKey || '').trim()) return null;

  const normalizedKey = normalizeSpreadsheetToken(imageKey);
  const baseKey = normalizedKey.replace(/\.[^.]+$/, '');

  return zipState.entries.find(({ path }) => {
    const normalizedPath = normalizeSpreadsheetToken(path);
    const baseName = normalizeSpreadsheetToken(path.split('/').pop() || '');
    const baseNameNoExt = baseName.replace(/\.[^.]+$/, '');

    return (
      normalizedPath === normalizedKey ||
      normalizedPath.endsWith(`/${normalizedKey}`) ||
      normalizedPath.endsWith(`/${baseKey}`) ||
      baseName === normalizedKey ||
      baseNameNoExt === normalizedKey ||
      baseNameNoExt === baseKey
    );
  }) || null;
}

async function resolveSpreadsheetImageUrl({ imageUrl, imageFileName, zipState, rowLabel }) {
  const directUrl = String(imageUrl || '').trim();
  if (directUrl) return directUrl;

  const fileName = String(imageFileName || '').trim();
  if (!fileName) return null;

  if (!zipState) {
    throw new Error(`الصف ${rowLabel}: توجد قيمة imageFileName لكن لا يوجد ملف ZIP للصور.`);
  }

  const matched = findSpreadsheetZipEntry(zipState, fileName);
  if (!matched) {
    throw new Error(`الصف ${rowLabel}: تعذر العثور على الصورة "${fileName}" داخل ملف ZIP.`);
  }

  if (zipState.cache.has(matched.path)) {
    return zipState.cache.get(matched.path);
  }

  const blob = await matched.entry.async('blob');
  const baseName = matched.path.split('/').pop() || fileName || 'upload.jpg';
  const uploadedUrl = await uploadImageToCloudinary(blob, baseName);
  if (!uploadedUrl) {
    throw new Error(`الصف ${rowLabel}: تعذر رفع الصورة "${fileName}".`);
  }

  zipState.cache.set(matched.path, uploadedUrl);
  return uploadedUrl;
}

function buildSpreadsheetTemplateCsv() {
  return [
    'itemId,name,category,price,smallPrice,mediumPrice,largePrice,familyPrice,jumboPrice,available,imageUrl,imageFileName',
    'pizza-margherita,بيتزا مارجريتا,بيتزا,120,,,,,,true,https://example.com/pizza.jpg,pizza-margherita.jpg',
    'shawarma-chicken,شاورما دجاج,شاورما,,80,,120,150,180,true,,shawarma-chicken.jpg'
  ].join('\n');
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
    const routedPoints = mapRouteCache.get(routeKey);
    mapRouteLastActualByOrder.set(orderId, { routeKey, points: routedPoints });
    return { points: routedPoints, routeKey, mode: 'actual' };
  }

  if (!mapRoutePending.has(routeKey) && !mapRouteFailures.has(routeKey)) {
    const promise = fetchRouteGeometry(points)
      .then((routedPoints) => {
        mapRouteCache.set(routeKey, routedPoints);
        mapRouteLastActualByOrder.set(orderId, { routeKey, points: routedPoints });
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

  const previousActualRoute = mapRouteLastActualByOrder.get(orderId);
  if (previousActualRoute?.points?.length) {
    return {
      points: previousActualRoute.points,
      routeKey,
      mode: 'updating',
    };
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

function focusAdminGlobalSearch() {
  if (!adminGlobalSearch) return;
  adminGlobalSearch.focus();
  adminGlobalSearch.select?.();
}

const MOBILE_SIDEBAR_BREAKPOINT = 1080;
let sidebarBackdrop = null;

function ensureSidebarBackdrop() {
  if (sidebarBackdrop) return sidebarBackdrop;
  const el = document.createElement('button');
  el.type = 'button';
  el.className = 'sidebar-backdrop';
  el.setAttribute('aria-label', 'إغلاق القائمة الجانبية');
  el.addEventListener('click', () => closeSidebar());
  document.body.appendChild(el);
  sidebarBackdrop = el;
  return el;
}

function closeSidebar() {
  appSidebar?.classList.remove('open');
  document.body.classList.remove('sidebar-open');
  ensureSidebarBackdrop().classList.remove('visible');
}

function openSidebar() {
  if (!appSidebar) return;
  appSidebar.classList.add('open');
  document.body.classList.add('sidebar-open');
  ensureSidebarBackdrop().classList.add('visible');
}

function toggleSidebar() {
  if (appSidebar?.classList.contains('open')) {
    closeSidebar();
  } else {
    openSidebar();
  }
}

function syncSidebarForViewport() {
  if (window.innerWidth > MOBILE_SIDEBAR_BREAKPOINT) {
    closeSidebar();
  }
}

function refreshAdminWorkspace() {
  const refreshButton = document.querySelector('[data-ops-action="refresh"]');
  if (refreshButton) {
    refreshButton.classList.add('btn-loading');
    refreshButton.disabled = true;
  }

  Promise.resolve(mountAll())
    .catch((err) => {
      console.error('manual admin refresh failed', err);
      setLoginStatus('تعذر تحديث بيانات اللوحة الآن. حاول مرة أخرى.', 'error');
    })
    .finally(() => {
      if (refreshButton) {
        refreshButton.classList.remove('btn-loading');
        refreshButton.disabled = false;
      }
    });
}

function preserveViewportPosition(run, { enabled = true } = {}) {
  if (!enabled) {
    run();
    return;
  }

  const previousY = window.scrollY || 0;
  run();
  if (previousY < 120) return;

  requestAnimationFrame(() => {
    const nextY = window.scrollY || 0;
    if (Math.abs(nextY - previousY) > 40) {
      window.scrollTo(0, previousY);
    }
  });
}

function getActiveSubpanelId(portalId) {
  return String(document.querySelector(`#${portalId} .portal-subpanel.active`)?.dataset?.subpanel || '');
}

document.addEventListener('keydown', (e) => {
  // Ignore when typing in inputs
  const tag = document.activeElement?.tagName?.toLowerCase();
  if (tag === 'input' || tag === 'textarea' || tag === 'select') return;
  if (document.activeElement?.isContentEditable) return;

  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
    e.preventDefault();
    focusAdminGlobalSearch();
    return;
  }

  if (e.key === '/' && !e.altKey && !e.ctrlKey && !e.metaKey) {
    e.preventDefault();
    focusAdminGlobalSearch();
    return;
  }

  if (e.altKey && e.key.toLowerCase() === 'r') {
    e.preventDefault();
    refreshAdminWorkspace();
    return;
  }

  // Escape → close confirmation overlays / mobile sidebar
  if (e.key === 'Escape') {
    document.querySelectorAll('.confirm-overlay').forEach((el) => el.remove());
    closeSidebar();
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

  if (isDeliveredOrderStatus(lifecycleStatus)) {
    return 'completed';
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
    ['courierIssueReportedAt', 'بلاغ مشكلة من المندوب'],
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

function renderCourierIssueAlert(data = {}) {
  const issue = data.courierIssue;
  if (!issue || typeof issue !== 'object') return '';

  const reasonLabels = {
    client_not_responding: 'العميل لا يرد',
    incorrect_address: 'العنوان غير صحيح',
    store_closed: 'المطعم مغلق',
    cannot_complete_delivery: 'تعذر إتمام التوصيل',
    other: 'مشكلة أخرى',
  };
  const reason = reasonLabels[String(issue.reason || '').trim()] || 'مشكلة غير محددة';
  const note = String(issue.note || '').trim();
  const state = String(issue.status || 'open').trim() === 'open' ? 'مفتوح' : 'تمت معالجته';
  const reportedAt = getTimestampMillis(data.courierIssueReportedAt);

  return `
    <div class="order-context-panel tone-warning">
      <div class="order-context-head">بلاغ مندوب ${escapeHtml(state)}</div>
      <div class="order-context-lines">
        <div><b>السبب:</b> ${escapeHtml(reason)}</div>
        ${note ? `<div><b>الملاحظة:</b> ${escapeHtml(note)}</div>` : ''}
        ${reportedAt ? `<div><b>وقت البلاغ:</b> ${escapeHtml(formatDateTimeLabel(reportedAt))}</div>` : ''}
      </div>
    </div>
  `;
}

function renderUnavailableItemAlert(data = {}) {
  const status = String(data.unavailableItemStatus || '').trim();
  const pending = data.unavailableItemPending === true || status === 'pending_client_choice';
  if (!pending && !['replacement_selected', 'continued_without_item'].includes(status)) {
    return '';
  }
  const item = data.unavailableItem && typeof data.unavailableItem === 'object'
    ? data.unavailableItem
    : {};
  const itemName = String(item.name || item.title || 'صنف من الطلب').trim();
  const replacement = data.unavailableItemReplacement && typeof data.unavailableItemReplacement === 'object'
    ? data.unavailableItemReplacement
    : {};
  const reportedAt = getTimestampMillis(data.unavailableItemReportedAt);
  const resolvedAt = getTimestampMillis(data.unavailableItemResolvedAt);
  const heading = pending
    ? 'صنف غير متوفر - بانتظار العميل'
    : status === 'replacement_selected'
      ? 'اختار العميل بديلاً'
      : 'سيُكمل العميل الطلب بدون الصنف';
  const tone = pending ? 'tone-warning' : 'tone-success';
  return `
    <div class="order-context-panel ${tone}">
      <div class="order-context-head">${escapeHtml(heading)}</div>
      <div class="order-context-lines">
        <div><b>الصنف غير المتوفر:</b> ${escapeHtml(itemName || '-')}</div>
        ${status === 'replacement_selected' ? `<div><b>البديل المختار:</b> ${escapeHtml(String(replacement.name || replacement.title || '-'))}</div>` : ''}
        ${reportedAt ? `<div><b>وقت إشعار العميل:</b> ${escapeHtml(formatDateTimeLabel(reportedAt))}</div>` : ''}
        ${resolvedAt ? `<div><b>وقت قرار العميل:</b> ${escapeHtml(formatDateTimeLabel(resolvedAt))}</div>` : ''}
      </div>
    </div>
  `;
}

function renderCourierIssueHistory(data = {}) {
  const history = Array.isArray(data.courierIssueHistory)
    ? [...data.courierIssueHistory].reverse()
    : [];
  if (!history.length) return '';

  const reasonLabels = {
    client_not_responding: 'العميل لا يرد',
    incorrect_address: 'العنوان غير صحيح',
    store_closed: 'المطعم مغلق',
    cannot_complete_delivery: 'تعذر إتمام التوصيل',
    other: 'مشكلة أخرى',
  };
  const rows = history.map((issue) => {
    const reason = reasonLabels[String(issue?.reason || '').trim()] || 'مشكلة غير محددة';
    const status = String(issue?.status || '').trim() === 'resolved' ? 'تمت المعالجة' : 'مفتوح';
    const reportedAt = Number(issue?.reportedAtMillis || 0);
    const resolutionNote = String(issue?.resolutionNote || '').trim();
    return `<div class="order-timeline-item"><b>${escapeHtml(reason)} - ${escapeHtml(status)}</b><span>${reportedAt ? escapeHtml(formatDateTimeLabel(reportedAt)) : '-'}</span>${resolutionNote ? `<span>${escapeHtml(resolutionNote)}</span>` : ''}</div>`;
  }).join('');
  return `<div class="order-detail-card"><strong>سجل بلاغات المندوب</strong><div class="order-timeline">${rows}</div></div>`;
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

function toAdminMoneyValue(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function formatAdminMoney(value) {
  return `${Math.round(toAdminMoneyValue(value)).toLocaleString('ar-EG')} ج.س`;
}

function computeOrderFinancialBreakdown(orderData = {}) {
  const subtotal = toAdminMoneyValue(orderData.total ?? orderData.subtotal ?? orderData.itemsSubtotal);
  const clientDeliveryFee = toAdminMoneyValue(orderData.deliveryFee ?? orderData.clientDeliveryFee);
  const largeOrderFee = toAdminMoneyValue(orderData.largeOrderFee);
  const discountAmount = toAdminMoneyValue(orderData.discountAmount);
  const totalBeforeDiscount = toAdminMoneyValue(
    orderData.totalBeforeDiscount ?? (subtotal + clientDeliveryFee + largeOrderFee)
  );
  const fallbackTotal = Math.max(0, totalBeforeDiscount - discountAmount);
  const totalWithDelivery = toAdminMoneyValue(orderData.totalWithDelivery || orderData.orderTotal || fallbackTotal);

  const restaurantShare = toAdminMoneyValue(
    orderData.restaurantShare ?? orderData.storeShare ?? orderData.restaurantNet ?? subtotal
  );
  const driverShare = toAdminMoneyValue(
    orderData.driverShare
      ?? orderData.deliveryFeeForDriver
      ?? orderData.courierFee
      ?? orderData.driverFee
      ?? orderData.courierDeliveryFee
      ?? 0
  );
  let platformShare = Math.max(0, totalWithDelivery - restaurantShare - driverShare);

  return {
    subtotal,
    clientDeliveryFee,
    deliveryFee: clientDeliveryFee,
    largeOrderFee,
    discountAmount,
    totalBeforeDiscount,
    totalWithDelivery,
    restaurantShare,
    driverShare,
    platformShare,
    platformGrossDelivery: clientDeliveryFee,
    walletUsed: toAdminMoneyValue(orderData.walletUsedAmount ?? orderData.walletRequestedAmount),
    paymentMethod: String(orderData.paymentMethod || '-'),
  };
}

function renderOrderFinancialBreakdown(financial) {
  const cells = [
    ['قيمة الأصناف', financial.subtotal],
    ['سعر التوصيل على العميل', financial.clientDeliveryFee],
    ['رسوم الطلب الكبير', financial.largeOrderFee],
    ['الخصم', financial.discountAmount],
    ['الإجمالي قبل الخصم', financial.totalBeforeDiscount],
    ['الإجمالي النهائي', financial.totalWithDelivery],
    ['مستحق المطعم', financial.restaurantShare],
    ['مستحق المندوب', financial.driverShare],
    ['إجمالي التوصيل', financial.platformGrossDelivery],
    ['صافي المنصة', financial.platformShare],
    ['المحفظة المستخدمة', financial.walletUsed],
  ];

  return `
    <div class="order-detail-card">
      <strong>التفاصيل المالية</strong>
      <div class="order-detail-grid" style="margin-top:10px;">
        ${cells.map(([label, value]) => `
          <div class="order-detail-card">
            <span class="muted">${escapeHtml(label)}</span><br />
            <b>${formatAdminMoney(value)}</b>
          </div>
        `).join('')}
      </div>
      <div class="muted" style="margin-top:8px;">طريقة الدفع: ${escapeHtml(financial.paymentMethod)}</div>
    </div>
  `;
}

function buildWalletSummarySection(title, walletData = {}) {
  return buildEntitySection(title, buildEntityFactsGrid([
    {
      label: 'الرصيد المستحق الآن',
      value: formatAdminMoney(walletData.walletPendingBalance),
      className: 'entity-fact-highlight',
    },
    { label: 'إجمالي المستحقات', value: formatAdminMoney(walletData.walletLifetimeEarnings) },
    { label: 'المحول سابقًا', value: formatAdminMoney(walletData.walletTransferredTotal) },
    { label: 'طلبات مسلمة محسوبة', value: Number(walletData.walletDeliveredOrdersCount || 0).toLocaleString('ar-EG') },
  ]), { eyebrow: 'المحفظة' });
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
  try { localStorage.setItem(OPS_LAST_TAB_KEY, id); } catch (_) {}

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
  closeSidebar();
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

let adminGlobalFilterFrame = 0;
function scheduleAdminGlobalFilter() {
  if (adminGlobalFilterFrame) cancelAnimationFrame(adminGlobalFilterFrame);
  adminGlobalFilterFrame = requestAnimationFrame(() => {
    adminGlobalFilterFrame = 0;
    applyAdminGlobalFilter();
  });
}

if (adminGlobalSearch) {
  adminGlobalSearch.addEventListener('input', () => {
    scheduleAdminGlobalFilter();
  });
}

function initAdminExperienceEnhancements() {
  if (!document.body || document.body.dataset.adminExperienceReady === '1') return;
  document.body.dataset.adminExperienceReady = '1';

  ensureSidebarBackdrop();
  syncSidebarForViewport();
  window.addEventListener('resize', syncSidebarForViewport);

  sidebarToggleBtn?.addEventListener('click', (event) => {
    event.preventDefault();
    toggleSidebar();
  });

  document.addEventListener('click', (event) => {
    if (window.innerWidth > MOBILE_SIDEBAR_BREAKPOINT) return;
    const target = event.target;
    if (!(target instanceof Node)) return;
    if (!appSidebar?.classList.contains('open')) return;
    if (appSidebar.contains(target) || sidebarToggleBtn?.contains(target)) return;
    closeSidebar();
  });

  const dock = document.createElement('div');
  dock.className = 'ops-control-dock';
  dock.setAttribute('aria-label', 'أدوات التحكم السريعة');
  dock.innerHTML = `
    <button type="button" class="ops-control-btn" data-ops-action="search" title="بحث سريع">
      <span aria-hidden="true">⌕</span><span>بحث</span>
    </button>
    <button type="button" class="ops-control-btn" data-ops-action="refresh" title="تحديث البيانات">
      <span aria-hidden="true">↻</span><span>تحديث</span>
    </button>
    <button type="button" class="ops-control-btn" data-ops-action="top" title="أعلى الصفحة">
      <span aria-hidden="true">↑</span><span>أعلى</span>
    </button>
    <button type="button" class="ops-control-btn" data-ops-action="print" title="طباعة التقرير الحالي">
      <span aria-hidden="true">⎙</span><span>طباعة</span>
    </button>
  `;
  const portalStrip = document.querySelector('.portal-strip');
  if (portalStrip) {
    dock.classList.add('ops-control-dock--inline');
    portalStrip.prepend(dock);
  } else {
    document.body.appendChild(dock);
  }

  dock.querySelector('[data-ops-action="search"]')?.addEventListener('click', focusAdminGlobalSearch);
  dock.querySelector('[data-ops-action="refresh"]')?.addEventListener('click', refreshAdminWorkspace);
  dock.querySelector('[data-ops-action="top"]')?.addEventListener('click', () => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });
  dock.querySelector('[data-ops-action="print"]')?.addEventListener('click', () => window.print());

  const authActions = document.querySelector('.auth-actions');
  if (authActions && !document.getElementById('opsNetworkStatus')) {
    const status = document.createElement('span');
    status.id = 'opsNetworkStatus';
    status.className = 'ops-network-status';
    authActions.prepend(status);

    const syncNetworkStatus = () => {
      const online = navigator.onLine !== false;
      status.textContent = online ? 'متصل' : 'غير متصل';
      status.classList.toggle('is-online', online);
      status.classList.toggle('is-offline', !online);
    };
    window.addEventListener('online', syncNetworkStatus);
    window.addEventListener('offline', syncNetworkStatus);
    syncNetworkStatus();
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initAdminExperienceEnhancements, { once: true });
} else {
  initAdminExperienceEnhancements();
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
        activateTab('management');
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

    const hashTab = (location.hash || '').replace('#', '').trim();
    let storedTab = '';
    try { storedTab = localStorage.getItem(OPS_LAST_TAB_KEY) || ''; } catch (_) {}
    const initialTab =
      hashTab && canAccessPortal(hashTab)
        ? hashTab
        : storedTab && canAccessPortal(storedTab)
          ? storedTab
          : getFirstAccessibleTabId();
    activateTab(initialTab);
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

  const computeFinancial = (orderData) => computeOrderFinancialBreakdown(orderData);

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
      ${renderStoreApprovalFlowHint(data)}
      <div><span class="kv"><b>العميل:</b> ${resolveClientDisplay(data.clientId, data.clientName)}</span><span class="kv"><b>المطعم:</b> ${resolveRestaurantDisplay(data.restaurantId, data.restaurantName)}</span></div>
      <div><span class="kv"><b>المندوب:</b> ${data.assignedDriverId ? resolveDriverDisplay(data.assignedDriverId, data.assignedDriverName || '') : '<span class="muted">غير معين</span>'}</span><span class="kv"><b>الهاتف:</b> ${escapeHtml(data.clientPhone || '-')}</span></div>
      <div><span class="kv"><b>الإجمالي:</b> ${formatMoney(financial.totalWithDelivery)}</span><span class="kv"><b>حصة المطعم:</b> ${formatMoney(financial.restaurantShare)}</span><span class="kv"><b>حصة المندوب:</b> ${formatMoney(financial.driverShare)}</span><span class="kv"><b>حصة المنصة:</b> ${formatMoney(financial.platformShare)}</span></div>
      ${renderOrderFinancialBreakdown(financial)}
      ${renderPaymentReceiptMarkup(data)}
      ${renderDeliveryProofMarkup(data)}
      ${renderUnavailableItemAlert(data)}
      ${renderCourierIssueAlert(data)}
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
      opsCenterState.openCourierIssues = snap.docs.filter((docSnap) =>
        String(docSnap.data()?.courierIssue?.status || '').trim().toLowerCase() === 'open'
      ).length;
      renderOpsPriorityCards();

      const buildRows = (docs, { allowMap = true } = {}) => docs.map((d) => {
        const data = d.data();
        const financial = computeFinancial(data);
        return `<tr>
          <td>${formatUnifiedOrderCode(data.orderNumber, data.orderId, d.id)}</td>
          <td>${data.clientName || '-'}</td>
          <td>${resolveRestaurantDisplay(data.restaurantId, data.restaurantName)}</td>
          <td>${data.assignedDriverId ? resolveDriverDisplay(data.assignedDriverId, data.assignedDriverName || '') : '<span class="muted">غير معين</span>'}</td>
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

  const computeFinancial = (orderData) => computeOrderFinancialBreakdown(orderData);

  const needsFinancialUpdate = (orderData, computed) => {
    const sameRestaurant = Math.round(toMoney(orderData.restaurantShare)) === Math.round(computed.restaurantShare);
    const sameDriver = Math.round(toMoney(orderData.driverShare ?? orderData.deliveryFeeForDriver ?? orderData.courierFee ?? orderData.driverFee ?? orderData.courierDeliveryFee)) === Math.round(computed.driverShare);
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

  const currentAdminUid = String(auth.currentUser?.uid || '').trim();
  const shiftAccountDocRef = currentAdminUid
    ? doc(db, 'paymentSettings', `shift_account_${currentAdminUid}`)
    : null;
  const resolveShiftOwnerName = (data = {}) => {
    const fromShift = String(data?.activeShift?.ownerDisplayName || '').trim();
    const fromRoot = String(data?.activeShiftOwnerName || '').trim();
    const fromProfile = String(currentAdminProfile?.name || currentAdminProfile?.displayName || auth.currentUser?.displayName || '').trim();
    return fromShift || fromRoot || fromProfile || currentAdminUid || '-';
  };

  const collectShiftMethods = () => {
    const methods = [];
    if (enableBankk?.checked) methods.push('bankk');
    if (enableOcash?.checked) methods.push('ocash');
    if (enableFawry?.checked) methods.push('fawry');
    return methods;
  };

  const buildShiftAccountPayload = () => ({
    displayName: String(shiftEmployeeDisplayName?.value || '').trim(),
    enabledMethods: collectShiftMethods(),
    bankkAccount: String(bankkAccountInput?.value || '').trim(),
    ocashAccount: String(ocashAccountInput?.value || '').trim(),
    fawryAccount: String(fawryAccountInput?.value || '').trim(),
    bankkAccountHolder: String(bankkAccountHolderInput?.value || '').trim(),
    ocashAccountHolder: String(ocashAccountHolderInput?.value || '').trim(),
    fawryAccountHolder: String(fawryAccountHolderInput?.value || '').trim(),
    bankkQrUrl: String(bankkQrUrlInput?.value || '').trim(),
    ocashQrUrl: String(ocashQrUrlInput?.value || '').trim(),
    fawryQrUrl: String(fawryQrUrlInput?.value || '').trim(),
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
    commercialRegistryImageUrl: String(commercialRegistryImageUrlInput?.value || '').trim(),
    commercialRegistryLinkUrl: String(commercialRegistryLinkUrlInput?.value || '').trim(),
  });

  const applyPaymentSettingsToForm = (data = {}) => {
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
    if (commercialRegistryImageUrlInput) commercialRegistryImageUrlInput.value = String(data.commercialRegistryImageUrl || '');
    if (commercialRegistryLinkUrlInput) commercialRegistryLinkUrlInput.value = String(data.commercialRegistryLinkUrl || '');
  };

  const renderShiftSummary = async (paymentDocData = null) => {
    if (!activeShiftOwnerLabel || !shiftIncomeSummary) return;

    const data = paymentDocData || (await safeGetDoc(doc(db, 'paymentSettings', 'default')))?.data?.() || {};
    const activeShift = data?.activeShift || {};
    const ownerName = resolveShiftOwnerName(data);
    const ownerUid = String(activeShift.ownerUid || data.activeShiftOwnerUid || '').trim();
    const shiftActive = Boolean(activeShift.isActive);

    activeShiftOwnerLabel.textContent = shiftActive
      ? `الحسابات المفعلة الآن تخص: ${ownerName}`
      : 'لا يوجد دوام مفعل الآن.';

    if (!shiftActive || !ownerUid) {
      shiftIncomeSummary.textContent = 'دخل الدوام الحالي: 0 ج.س | دخل الشهر: 0 ج.س';
      return;
    }

    const shiftStartedAtMs = getTimestampMillis(activeShift.startedAt || activeShift.startedAtMs || data.activeShiftStartedAt);
    const now = new Date();
    const monthStartMs = new Date(now.getFullYear(), now.getMonth(), 1).getTime();

    let shiftIncome = 0;
    let monthIncome = 0;

    const addByTime = (amount, ts) => {
      const safeAmount = Number(amount) || 0;
      const ms = getTimestampMillis(ts);
      if (!safeAmount || !ms) return;
      if (shiftStartedAtMs > 0 && ms >= shiftStartedAtMs) shiftIncome += safeAmount;
      if (ms >= monthStartMs) monthIncome += safeAmount;
    };

    try {
      const [ordersSnap, rechargesSnap, withdrawalsSnap] = await Promise.all([
        safeGetDocs(query(collection(db, 'orders'), where('paymentStatus', '==', 'paid'), orderBy('updatedAt', 'desc'), limit(600))),
        safeGetDocs(query(collection(db, 'wallet_recharges'), orderBy('createdAt', 'desc'), limit(600))),
        safeGetDocs(query(collection(db, 'wallet_withdrawals'), orderBy('createdAt', 'desc'), limit(600))),
      ]);

      (ordersSnap?.docs || []).forEach((docSnap) => {
        const row = docSnap.data() || {};
        const byUid = String(row.paymentReviewedByAdminUid || row.reviewedByAdminUid || row.updatedByAdminUid || '').trim();
        if (byUid !== ownerUid) return;
        const financial = computeFinancial(row);
        addByTime(financial.totalWithDelivery, row.paidAt || row.updatedAt || row.createdAt);
      });

      (rechargesSnap?.docs || []).forEach((docSnap) => {
        const row = docSnap.data() || {};
        const status = String(row.status || '').trim().toLowerCase();
        const reviewStatus = String(row.reviewStatus || '').trim().toLowerCase();
        if (!(status === 'approved' || reviewStatus === 'approved')) return;
        const byUid = String(row.reviewedByAdminUid || row.updatedByAdminUid || '').trim();
        if (byUid !== ownerUid) return;
        addByTime(Number(row.amount || 0), row.reviewedAt || row.updatedAt || row.createdAt);
      });

      (withdrawalsSnap?.docs || []).forEach((docSnap) => {
        const row = docSnap.data() || {};
        const status = String(row.status || '').trim().toLowerCase();
        const reviewStatus = String(row.reviewStatus || '').trim().toLowerCase();
        if (!(status === 'approved' || reviewStatus === 'approved')) return;
        const byUid = String(row.reviewedByAdminUid || row.updatedByAdminUid || '').trim();
        if (byUid !== ownerUid) return;
        addByTime(Number(row.amount || 0), row.reviewedAt || row.updatedAt || row.createdAt);
      });
    } catch (err) {
      console.warn('shift summary failed', err);
    }

    shiftIncomeSummary.textContent = `دخل الدوام الحالي: ${formatMoney(shiftIncome)} | دخل الشهر: ${formatMoney(monthIncome)}`;
  };

  if (shiftAccountForm && !shiftAccountFormBound) {
    shiftAccountForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      if (!currentAdminUid) {
        if (shiftAccountResult) shiftAccountResult.textContent = 'تعذر تحديد حساب الأدمن الحالي.';
        return;
      }

      const payload = buildShiftAccountPayload();
      if (!payload.displayName) {
        payload.displayName = String(currentAdminProfile?.name || currentAdminProfile?.displayName || auth.currentUser?.displayName || currentAdminUid);
      }

      if (saveShiftAccountBtn) saveShiftAccountBtn.disabled = true;
      if (shiftAccountResult) shiftAccountResult.textContent = 'جارٍ حفظ حساب الموظف...';

      try {
        if (!shiftAccountDocRef) throw new Error('تعذر تحديد مسار حفظ حساب الدوام.');
        await setDoc(shiftAccountDocRef, {
          ...payload,
          adminUid: currentAdminUid,
          updatedAt: serverTimestamp(),
        }, { merge: true });
        if (shiftAccountResult) shiftAccountResult.textContent = '✅ تم حفظ حساب الموظف.';
      } catch (err) {
        if (shiftAccountResult) shiftAccountResult.textContent = `تعذر حفظ حساب الموظف: ${err.message || err}`;
      } finally {
        if (saveShiftAccountBtn) saveShiftAccountBtn.disabled = false;
      }
    });

    activateShiftAccountBtn?.addEventListener('click', async () => {
      if (!currentAdminUid) {
        if (shiftAccountResult) shiftAccountResult.textContent = 'تعذر تحديد حساب الأدمن الحالي.';
        return;
      }

      const shiftData = buildShiftAccountPayload();
      const enabledMethods = shiftData.enabledMethods;
      if (!enabledMethods.length) {
        if (shiftAccountResult) shiftAccountResult.textContent = 'يجب تفعيل طريقة دفع واحدة على الأقل في حساب الموظف.';
        return;
      }

      const ownerName = String(shiftData.displayName || currentAdminProfile?.name || currentAdminProfile?.displayName || auth.currentUser?.displayName || currentAdminUid).trim();

      if (activateShiftAccountBtn) activateShiftAccountBtn.disabled = true;
      if (shiftAccountResult) shiftAccountResult.textContent = 'جارٍ تفعيل الدوام ونشر الحسابات للعملاء...';

      try {
        if (!shiftAccountDocRef) throw new Error('تعذر تحديد مسار حفظ حساب الدوام.');
        await setDoc(shiftAccountDocRef, {
          ...shiftData,
          adminUid: currentAdminUid,
          updatedAt: serverTimestamp(),
        }, { merge: true });

        await setDoc(doc(db, 'paymentSettings', 'default'), {
          enabledMethods,
          bankkAccount: shiftData.bankkAccount,
          ocashAccount: shiftData.ocashAccount,
          fawryAccount: shiftData.fawryAccount,
          bankkAccountHolder: shiftData.bankkAccountHolder,
          ocashAccountHolder: shiftData.ocashAccountHolder,
          fawryAccountHolder: shiftData.fawryAccountHolder,
          bankkQrUrl: shiftData.bankkQrUrl,
          ocashQrUrl: shiftData.ocashQrUrl,
          fawryQrUrl: shiftData.fawryQrUrl,
          bankkInstructions: shiftData.bankkInstructions,
          ocashInstructions: shiftData.ocashInstructions,
          fawryInstructions: shiftData.fawryInstructions,
          bankkOpenUrlAndroid: shiftData.bankkOpenUrlAndroid,
          ocashOpenUrlAndroid: shiftData.ocashOpenUrlAndroid,
          fawryOpenUrlAndroid: shiftData.fawryOpenUrlAndroid,
          bankkOpenUrlIos: shiftData.bankkOpenUrlIos,
          ocashOpenUrlIos: shiftData.ocashOpenUrlIos,
          fawryOpenUrlIos: shiftData.fawryOpenUrlIos,
          bankkOpenUrl: shiftData.bankkOpenUrl,
          ocashOpenUrl: shiftData.ocashOpenUrl,
          fawryOpenUrl: shiftData.fawryOpenUrl,
          commercialRegistryImageUrl: shiftData.commercialRegistryImageUrl,
          commercialRegistryLinkUrl: shiftData.commercialRegistryLinkUrl,
          activeShiftOwnerUid: currentAdminUid,
          activeShiftOwnerName: ownerName,
          activeShiftStartedAt: serverTimestamp(),
          activeShift: {
            isActive: true,
            ownerUid: currentAdminUid,
            ownerDisplayName: ownerName,
            startedAt: serverTimestamp(),
            enabledMethods,
          },
          updatedAt: serverTimestamp(),
          updatedByAdminUid: currentAdminUid,
        }, { merge: true });

        if (shiftAccountResult) shiftAccountResult.textContent = '✅ تم بدء الدوام. العملاء الآن يرون حساباتك فقط.';
      } catch (err) {
        if (shiftAccountResult) shiftAccountResult.textContent = `تعذر تفعيل الدوام: ${err.message || err}`;
      } finally {
        if (activateShiftAccountBtn) activateShiftAccountBtn.disabled = false;
      }
    });

    endShiftAccountBtn?.addEventListener('click', async () => {
      if (!currentAdminUid) {
        if (shiftAccountResult) shiftAccountResult.textContent = 'تعذر تحديد حساب الأدمن الحالي.';
        return;
      }

      if (endShiftAccountBtn) endShiftAccountBtn.disabled = true;
      if (shiftAccountResult) shiftAccountResult.textContent = 'جارٍ إنهاء الدوام...';

      try {
        await setDoc(doc(db, 'paymentSettings', 'default'), {
          activeShiftOwnerUid: '',
          activeShiftOwnerName: '',
          activeShiftEndedAt: serverTimestamp(),
          activeShift: {
            isActive: false,
            ownerUid: '',
            ownerDisplayName: '',
            endedAt: serverTimestamp(),
            endedByUid: currentAdminUid,
          },
          updatedAt: serverTimestamp(),
          updatedByAdminUid: currentAdminUid,
        }, { merge: true });

        if (shiftAccountResult) shiftAccountResult.textContent = '✅ تم إنهاء الدوام بنجاح.';
      } catch (err) {
        if (shiftAccountResult) shiftAccountResult.textContent = `تعذر إنهاء الدوام: ${err.message || err}`;
      } finally {
        if (endShiftAccountBtn) endShiftAccountBtn.disabled = false;
      }
    });

    shiftAccountFormBound = true;
  }

  if (paymentSettingsForm && !paymentSettingsFormBound) {
    paymentSettingsForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      if (!currentAdminUid || !shiftAccountDocRef) {
        if (paymentSettingsResult) {
          paymentSettingsResult.textContent = 'تعذر تحديد حساب الأدمن الحالي.';
        }
        return;
      }

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
          commercialRegistryImageUrl: String(commercialRegistryImageUrlInput?.value || '').trim(),
          commercialRegistryLinkUrl: String(commercialRegistryLinkUrlInput?.value || '').trim(),
          updatedAt: serverTimestamp(),
          updatedByAdminUid: currentAdminUid,
          adminUid: currentAdminUid,
        };

        if (paymentSettingsResult) paymentSettingsResult.textContent = 'جارٍ حفظ الإعدادات...';
        await setDoc(shiftAccountDocRef, payload, { merge: true });

        const defaultSnap = await safeGetDoc(doc(db, 'paymentSettings', 'default'));
        const defaultData = defaultSnap?.data?.() || {};
        const activeShift = defaultData.activeShift || {};
        const activeOwnerUid = String(activeShift.ownerUid || defaultData.activeShiftOwnerUid || '').trim();
        const activeShiftOn = Boolean(activeShift.isActive);

        if (activeShiftOn && activeOwnerUid && activeOwnerUid === currentAdminUid) {
          await setDoc(doc(db, 'paymentSettings', 'default'), {
            ...payload,
            updatedAt: serverTimestamp(),
            updatedByAdminUid: currentAdminUid,
          }, { merge: true });
        }

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
          paymentSettingsResult.textContent = activeShiftOn && activeOwnerUid === currentAdminUid
            ? '✅ تم حفظ إعداداتك وتحديث حسابات الدفع المعروضة للعملاء.'
            : '✅ تم حفظ إعداداتك الخاصة. ستظهر للعملاء عند الضغط على بدء الدوام.';
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
    onSnapshot(shiftAccountDocRef || doc(db, 'paymentSettings', '__missing_shift_account__'), (snap) => {
      const data = snap.data() || {};
      if (shiftEmployeeDisplayName) {
        const fallbackName = String(currentAdminProfile?.name || currentAdminProfile?.displayName || auth.currentUser?.displayName || currentAdminUid || '');
        shiftEmployeeDisplayName.value = String(data.displayName || fallbackName);
      }

      applyPaymentSettingsToForm(data);

      if (paymentSettingsResult && !paymentSettingsResult.textContent.includes('✅')) {
        paymentSettingsResult.textContent = 'تم تحميل إعداداتك الخاصة.';
      }
    }, () => {})
  );

  unsubscribers.push(
    onSnapshot(doc(db, 'paymentSettings', 'default'), (snap) => {
      const data = snap.data() || {};
      void renderShiftSummary(data);
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

    const renderRemainingBadge = (payableRaw) => {
      const payable = Math.max(0, Math.round(toMoney(payableRaw)));
      if (payable <= 0) {
        return `<span class="payout-remaining-badge payout-remaining-badge--done">${formatMoney(0)} • مكتمل</span>`;
      }
      return `<span class="payout-remaining-badge payout-remaining-badge--pending">${formatMoney(payable)} • متبقي</span>`;
    };

    const resolveTransferAmount = (payableRaw, label) => {
      const payable = Math.max(0, Math.round(toMoney(payableRaw)));
      const amountRaw = prompt(`قيمة التحويل ${label} (المتبقي الحالي: ${payable.toLocaleString('ar-EG')} ج.س):`, String(payable));
      if (amountRaw === null) return { cancelled: true, amount: 0, remainingAfter: payable };

      const amount = Math.round(toMoney(amountRaw));
      if (!Number.isFinite(amount) || amount <= 0) {
        if (window.showToast) window.showToast('قيمة التحويل غير صحيحة.', 'error');
        else alert('قيمة التحويل غير صحيحة.');
        return { cancelled: true, amount: 0, remainingAfter: payable };
      }

      const extraAmount = Math.max(0, amount - payable);
      return {
        cancelled: false,
        amount,
        remainingAfter: Math.max(0, payable - amount),
        extraAmount,
        isExtra: extraAmount > 0,
      };
    };

    const storeRows = Array.from(storeAgg.entries()).map(([storeId, agg]) => {
      const data = restaurantMap.get(storeId) || {};
      const account = parseAccount(data);
      const payableRounded = Math.max(0, Math.round(toMoney(agg.payable)));
      return `<tr>
        <td>${escapeHtml(String(data.name || storeId))}</td>
        <td>${agg.ordersCount}</td>
        <td>${formatMoney(agg.totalEarned)}</td>
        <td>${formatMoney(agg.transferred)}</td>
        <td>${renderRemainingBadge(agg.payable)}</td>
        <td>${escapeHtml(account.method || '-')}</td>
        <td>${escapeHtml(account.accountName || '-')}</td>
        <td>${escapeHtml(account.accountNumber || '-')}</td>
        <td>
          <button class="btn ${payableRounded > 0 ? 'primary' : 'ghost'}" data-pay-store="${escapeHtml(storeId)}" data-payable="${payableRounded}">${payableRounded > 0 ? 'تم التحويل' : 'إضافة وتحويل'}</button>
        </td>
      </tr>`;
    });

    const courierRows = Array.from(courierAgg.entries()).map(([driverId, agg]) => {
      const data = driverMap.get(driverId) || {};
      const account = parseAccount(data);
      const payableRounded = Math.max(0, Math.round(toMoney(agg.payable)));
      return `<tr>
        <td>${escapeHtml(String(data.name || driverId))}</td>
        <td>${agg.ordersCount}</td>
        <td>${formatMoney(agg.totalEarned)}</td>
        <td>${formatMoney(agg.transferred)}</td>
        <td>${renderRemainingBadge(agg.payable)}</td>
        <td>${escapeHtml(account.method || '-')}</td>
        <td>${escapeHtml(account.accountName || '-')}</td>
        <td>${escapeHtml(account.accountNumber || '-')}</td>
        <td>
          <button class="btn ${payableRounded > 0 ? 'primary' : 'ghost'}" data-pay-courier="${escapeHtml(driverId)}" data-payable="${payableRounded}">${payableRounded > 0 ? 'تم التحويل' : 'إضافة وتحويل'}</button>
        </td>
      </tr>`;
    });

    const openPayoutComposer = ({ label, name, payable }) => new Promise((resolve) => {
      const safePayable = Math.max(0, Math.round(toMoney(payable)));
      const suggestedAmount = safePayable > 0 ? safePayable : 10;

      const overlay = document.createElement('div');
      overlay.className = 'confirm-overlay';
      overlay.innerHTML = `
        <div class="confirm-dialog payout-composer-dialog" role="dialog" aria-modal="true">
          <h4>تسجيل تحويل ${escapeHtml(label)}</h4>
          <p>الجهة: <b>${escapeHtml(name)}</b></p>
          <div class="payout-composer-meta">
            <span class="payout-remaining-badge payout-remaining-badge--pending">المتبقي الحالي: ${formatMoney(safePayable)}</span>
          </div>
          <div class="payout-composer-form">
            <label>قيمة التحويل
              <input id="_payoutAmount" type="number" min="1" step="1" value="${suggestedAmount}" />
            </label>
            <label>صورة إشعار التحويل (اختياري)
              <input id="_payoutImage" type="file" accept="image/*" />
              <span id="_payoutImageHint" class="field-hint">يمكنك رفع صورة أو إدخال رابط يدويًا.</span>
            </label>
            <label>رابط إشعار التحويل (اختياري)
              <input id="_payoutUrl" type="url" placeholder="https://..." />
            </label>
            <div id="_payoutPreview" class="payout-composer-preview"></div>
          </div>
          <div class="confirm-dialog-actions">
            <button class="btn ghost" id="_payoutCancel">إلغاء</button>
            <button class="btn primary" id="_payoutConfirm">تسجيل التحويل</button>
          </div>
        </div>
      `;

      let settled = false;
      const settle = (payload) => {
        if (settled) return;
        settled = true;
        document.removeEventListener('keydown', onKeyDown, true);
        overlay.remove();
        resolve(payload);
      };

      const onKeyDown = (event) => {
        if (event.key === 'Escape') {
          event.preventDefault();
          settle({ cancelled: true });
        }
      };

      const amountInput = overlay.querySelector('#_payoutAmount');
      const imageInput = overlay.querySelector('#_payoutImage');
      const urlInput = overlay.querySelector('#_payoutUrl');
      const imageHint = overlay.querySelector('#_payoutImageHint');
      const preview = overlay.querySelector('#_payoutPreview');
      const confirmBtn = overlay.querySelector('#_payoutConfirm');
      const cancelBtn = overlay.querySelector('#_payoutCancel');

      const renderPreview = () => {
        const amount = Math.max(0, Math.round(toMoney(amountInput?.value)));
        const remaining = Math.max(0, safePayable - amount);
        const extra = Math.max(0, amount - safePayable);
        const remainingClass = remaining > 0 ? 'payout-remaining-badge--pending' : 'payout-remaining-badge--done';
        preview.innerHTML = `
          <span class="payout-remaining-badge ${remainingClass}">المتبقي بعد التحويل: ${formatMoney(remaining)}</span>
          ${extra > 0 ? `<span class="payout-remaining-badge payout-remaining-badge--pending">إضافة يدوية: ${formatMoney(extra)}</span>` : ''}
        `;
      };

      amountInput?.addEventListener('input', renderPreview);
      imageInput?.addEventListener('change', () => {
        const selectedName = imageInput.files?.[0]?.name || '';
        imageHint.textContent = selectedName ? `تم اختيار: ${selectedName}` : 'يمكنك رفع صورة أو إدخال رابط يدويًا.';
      });

      cancelBtn?.addEventListener('click', () => settle({ cancelled: true }));
      overlay.addEventListener('click', (event) => {
        if (event.target === overlay) settle({ cancelled: true });
      });

      confirmBtn?.addEventListener('click', async () => {
        const amount = Math.max(0, Math.round(toMoney(amountInput?.value)));
        if (!Number.isFinite(amount) || amount <= 0) {
          if (window.showToast) window.showToast('قيمة التحويل غير صحيحة.', 'error');
          else alert('قيمة التحويل غير صحيحة.');
          return;
        }

        if (confirmBtn) confirmBtn.disabled = true;

        try {
          let receiptUrl = String(urlInput?.value || '').trim();
          const file = imageInput?.files?.[0] || null;
          if (file) {
            if (window.showToast) window.showToast('جارٍ رفع الصورة...', 'info');
            const uploadedUrl = await uploadImageToCloudinary(file, file.name || 'payout-receipt.jpg');
            if (!uploadedUrl) {
              if (window.showToast) window.showToast('تعذر رفع الصورة. جرّب صورة أخرى أو استخدم رابط يدوي.', 'error');
              if (confirmBtn) confirmBtn.disabled = false;
              return;
            }
            receiptUrl = String(uploadedUrl).trim();
            if (urlInput) urlInput.value = receiptUrl;
            if (window.showToast) window.showToast('تم رفع الصورة وتحويلها لرابط.', 'success');
          }

          const remainingAfter = Math.max(0, safePayable - amount);
          const extraAmount = Math.max(0, amount - safePayable);
          settle({
            cancelled: false,
            amount,
            receiptUrl,
            remainingAfter,
            extraAmount,
            isExtra: extraAmount > 0,
          });
        } catch (err) {
          if (window.showToast) window.showToast(`تعذر تجهيز التحويل: ${err.message || err}`, 'error');
          if (confirmBtn) confirmBtn.disabled = false;
        }
      });

      document.body.appendChild(overlay);
      document.addEventListener('keydown', onKeyDown, true);
      renderPreview();
      amountInput?.focus();
      amountInput?.select?.();
    });

    if (financeStoresPayoutTable) {
      setHtml(financeStoresPayoutTable, table(['المطعم', 'عدد الطلبات', 'المستحق الكلي', 'المحول سابقاً', 'المتبقي للتحويل', 'طريقة الدفع', 'اسم صاحب الحساب', 'رقم الحساب', 'إجراء'], storeRows));
      financeStoresPayoutTable.querySelectorAll('[data-pay-store]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const targetId = btn.getAttribute('data-pay-store');
          const payable = toMoney(btn.getAttribute('data-payable'));
          if (!targetId) {
            if (window.showToast) window.showToast('تعذر تحديد المطعم.', 'error');
            else alert('تعذر تحديد المطعم.');
            return;
          }

          const storeName = escapeHtml(btn.closest('tr')?.querySelector('td')?.textContent?.trim() || targetId);
          const transferChoice = await openPayoutComposer({
            label: 'للمطعم',
            name: storeName,
            payable,
          });
          if (transferChoice.cancelled) return;

          try {
            await recordWalletPayout({
              role: 'store',
              targetId,
              amount: transferChoice.amount,
              allowExtra: transferChoice.isExtra,
              receiptUrl: transferChoice.receiptUrl || '',
              note: `${transferChoice.receiptUrl ? `رابط إشعار التحويل: ${transferChoice.receiptUrl}` : ''}${transferChoice.isExtra ? `${transferChoice.receiptUrl ? ' | ' : ''}إضافة يدوية: ${transferChoice.extraAmount} ج.س` : ''}`,
            });
            if (window.showToast) window.showToast('تم تسجيل التحويل للمطعم وإرسال إشعار.', 'success');
          } catch (err) {
            if (window.showToast) window.showToast(`تعذر تسجيل التحويل: ${err.message || err}`, 'error');
          }
        });
      });
    }

    if (financeCouriersPayoutTable) {
      setHtml(financeCouriersPayoutTable, table(['المندوب', 'عدد الطلبات', 'المستحق الكلي', 'المحول سابقاً', 'المتبقي للتحويل', 'طريقة الدفع', 'اسم صاحب الحساب', 'رقم الحساب', 'إجراء'], courierRows));
      financeCouriersPayoutTable.querySelectorAll('[data-pay-courier]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const targetId = btn.getAttribute('data-pay-courier');
          const payable = toMoney(btn.getAttribute('data-payable'));
          if (!targetId) {
            if (window.showToast) window.showToast('تعذر تحديد المندوب.', 'error');
            else alert('تعذر تحديد المندوب.');
            return;
          }

          const courierName = escapeHtml(btn.closest('tr')?.querySelector('td')?.textContent?.trim() || targetId);
          const transferChoice = await openPayoutComposer({
            label: 'للمندوب',
            name: courierName,
            payable,
          });
          if (transferChoice.cancelled) return;

          try {
            await recordWalletPayout({
              role: 'courier',
              targetId,
              amount: transferChoice.amount,
              allowExtra: transferChoice.isExtra,
              receiptUrl: transferChoice.receiptUrl || '',
              note: `${transferChoice.receiptUrl ? `رابط إشعار التحويل: ${transferChoice.receiptUrl}` : ''}${transferChoice.isExtra ? `${transferChoice.receiptUrl ? ' | ' : ''}إضافة يدوية: ${transferChoice.extraAmount} ج.س` : ''}`,
            });
            if (window.showToast) window.showToast('تم تسجيل التحويل للمندوب وإرسال إشعار.', 'success');
          } catch (err) {
            if (window.showToast) window.showToast(`تعذر تسجيل التحويل: ${err.message || err}`, 'error');
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
        const receiptUrl = resolvePaymentReceiptUrl(data);
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
          <td>${receiptUrl ? `<a class="btn ghost" href="${escapeHtml(receiptUrl)}" target="_blank" rel="noopener">عرض</a>` : '-'}</td>
          <td>${formatDateTimeCell(data.paymentReviewAutoFlaggedAt || data.updatedAt || data.paidAt)}</td>
          <td>
            <details class="review-details-toggle">
              <summary>تفاصيل</summary>
              <div class="review-expand-card">
                <div class="review-expand-grid">
                  <div><strong>المندوب</strong>${data.assignedDriverId ? resolveDriverDisplay(data.assignedDriverId, data.assignedDriverName || '') : '<span class="muted">غير معين</span>'}</div>
                  <div><strong>هاتف العميل</strong>${escapeHtml(String(data.clientPhone || '-'))}</div>
                  <div><strong>الحالة الحالية</strong>${escapeHtml(formatOrderStatusLabel(data.orderStatus || data.status || '-'))}</div>
                  <div><strong>سير القبول</strong>${renderStoreApprovalFlowHint(data) || '<span class="muted">طبيعي</span>'}</div>
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
        openOrderOnMap(orderId);
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
                const refundToWallet = window.confirm(
                  'هل تريد إعادة مبلغ هذا الطلب مباشرة إلى محفظة العميل؟\n\nموافق: إعادة المبلغ\nإلغاء: رفض الإيصال دون رد للمحفظة'
                );
                await reviewOrderPaymentEvidence({ orderId, decision: 'reject', note: '', refundToWallet });
                if (window.showToast) window.showToast('تم رفض الإيصال بنجاح.', 'success');
              } catch (err) {
                if (window.showToast) window.showToast(`تعذر رفض الإيصال: ${err.message || err}`, 'error');
              }
            },
          });
        } else {
          const note = prompt('سبب الرفض (اختياري):', '') || '';
          const refundToWallet = window.confirm(
            'هل تريد إعادة مبلغ هذا الطلب مباشرة إلى محفظة العميل؟\n\nموافق: إعادة المبلغ\nإلغاء: رفض الإيصال دون رد للمحفظة'
          );
          reviewOrderPaymentEvidence({ orderId, decision: 'reject', note: note.trim(), refundToWallet })
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
      const receiptUrl = resolvePaymentReceiptUrl(data);
      return `<tr>
        <td>${escapeHtml(String(data.clientName || data.clientId || '-'))}</td>
        <td>${escapeHtml(String(data.clientPhone || '-'))}</td>
        <td>${formatMoney(data.amount || 0)}</td>
        <td>${escapeHtml(String(data.paymentMethod || '-'))}</td>
        <td>${escapeHtml(String(data.transactionReference || '-'))}</td>
        <td>${receiptUrl ? `<a class="btn ghost" href="${escapeHtml(receiptUrl)}" target="_blank" rel="noopener">عرض</a>` : '-'}</td>
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

    const selectedKindForValidation = String(document.getElementById('adminOfferKind')?.value || 'discount').trim().toLowerCase();
    const targetItems = parseAdminOfferTargetItems(adminOfferTargetItems?.value);
    const kindNeedsItems = selectedKindForValidation === 'buy_x_get_y'
      || selectedKindForValidation === 'bundle_price'
      || selectedKindForValidation === 'nth_item_percent';
    if ((adminOfferDiscountScope?.value === 'specific_items' || kindNeedsItems) && targetItems.length === 0) {
      if (adminCreateOfferResult) adminCreateOfferResult.textContent = 'اكتب أسماء الأصناف المشمولة بالعرض.';
      return;
    }

    if (adminCreateOfferBtn) adminCreateOfferBtn.disabled = true;
    if (adminCreateOfferResult) adminCreateOfferResult.textContent = 'جاري إنشاء العرض...';
    try {
      const titleText = String(adminOfferTitle?.value || '').trim();
      const descriptionText = String(adminOfferDescription?.value || '').trim();
      const ruleSource = `${titleText} ${descriptionText}`;
      const plusMatch = ruleSource.match(/(\d+)\s*\+\s*(\d+)/);
      const selectedKind = String(document.getElementById('adminOfferKind')?.value || '').trim().toLowerCase();
      let offerKind = selectedKind || 'discount';
      let offerRule = { type: offerKind };

      if (!selectedKind && plusMatch && (adminOfferDiscountScope?.value === 'specific_items')) {
        offerKind = 'buy_x_get_y';
        offerRule = {
          type: 'buy_x_get_y',
          buyQty: Number(plusMatch[1] || 3),
          freeQty: Number(plusMatch[2] || 1),
          applyOn: 'same_item',
        };
      }

      if (offerKind === 'buy_x_get_y') {
        offerRule = {
          type: 'buy_x_get_y',
          buyQty: Number(document.getElementById('adminOfferBuyQty')?.value || plusMatch?.[1] || 3),
          freeQty: Number(document.getElementById('adminOfferFreeQty')?.value || plusMatch?.[2] || 1),
          applyOn: String(document.getElementById('adminOfferApplyOn')?.value || 'same_item').trim().toLowerCase(),
        };
      } else if (offerKind === 'bundle_price') {
        offerRule = {
          type: 'bundle_price',
          bundleQty: Number(document.getElementById('adminOfferBundleQty')?.value || 2),
          bundlePrice: Number(document.getElementById('adminOfferBundlePrice')?.value || 0),
        };
      } else if (offerKind === 'nth_item_percent') {
        offerRule = {
          type: 'nth_item_percent',
          nthQty: Number(document.getElementById('adminOfferNthQty')?.value || 2),
          percentOff: Number(document.getElementById('adminOfferNthPercent')?.value || 50),
        };
      } else if (offerKind === 'spend_x_get_percent') {
        offerRule = {
          type: 'spend_x_get_percent',
          minSpend: Number(document.getElementById('adminOfferMinSpend')?.value || adminOfferMinOrder?.value || 0),
          percentOff: Number(document.getElementById('adminOfferSpendPercent')?.value || 10),
        };
      }

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
          offerKind,
          offerRule,
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

  const formatDateTimeInput = (value) => {
    if (!value || typeof value.toDate !== 'function') return '';
    const date = value.toDate();
    const pad = (part) => String(part).padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
  };

  const renderEmptyState = (message, columns) => [
    `<tr><td colspan="${columns}" class="muted">${escapeHtml(message)}</td></tr>`
  ];

  const callReview = async (offerId, action) => {
    try {
      let reviewNote = '';
      if (action === 'reject') {
        const input = prompt('اكتب سبب رفض العرض ليظهر للمطعم:', '');
        if (input == null) return;
        reviewNote = input.trim();
      }
      await reviewStoreOfferRequest({ offerId, action, reviewNote });
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

function setMockOrderResult(message = '', tone = 'muted') {
  if (!mockOrderResult) return;
  const safeTone = tone === 'error' || tone === 'success' ? tone : 'muted';
  mockOrderResult.className = safeTone;
  mockOrderResult.textContent = message;
}

function getApprovedCouriersForMockOrder() {
  return courierDirectoryCache
    .filter((item) => {
      const data = item.data || {};
      return data.isApproved === true || String(data.approvalStatus || '').trim().toLowerCase() === 'approved';
    })
    .map((item) => ({
      id: item.id,
      data: item.data || {},
    }));
}

function renderMockOrderCouriersSelect() {
  if (!mockOrderCourierIds) return;
  const approvedCouriers = getApprovedCouriersForMockOrder();
  const previousSelection = new Set(Array.from(mockOrderCourierIds.selectedOptions || []).map((opt) => String(opt.value || '').trim()));
  const rows = approvedCouriers
    .sort((a, b) => String(a.data.name || a.id).localeCompare(String(b.data.name || b.id), 'ar'))
    .map((item) => {
      const name = String(item.data.name || item.id).trim();
      const available = item.data.available === true;
      const statusLabel = available ? 'متاح' : 'غير متاح';
      return `<option value="${escapeHtml(item.id)}">${escapeHtml(name)} - ${escapeHtml(statusLabel)} - ${escapeHtml(item.id)}</option>`;
    });

  mockOrderCourierIds.innerHTML = rows.length
    ? rows.join('')
    : '<option value="" disabled>لا يوجد مندوبون معتمدون حالياً</option>';

  Array.from(mockOrderCourierIds.options || []).forEach((opt) => {
    if (previousSelection.has(String(opt.value || '').trim())) {
      opt.selected = true;
    }
  });
}

function syncMockOrderModeUi() {
  if (!mockOrderMode || !mockOrderCourierIds) return;
  const mode = String(mockOrderMode.value || 'all').trim().toLowerCase();
  const isSpecific = mode === 'specific';
  mockOrderCourierIds.disabled = !isSpecific;
}

function getMockOrderTargetDriverIds() {
  const approvedCouriers = getApprovedCouriersForMockOrder();
  const approvedById = new Map(approvedCouriers.map((item) => [item.id, item]));
  const mode = String(mockOrderMode?.value || 'all').trim().toLowerCase();

  if (mode === 'specific') {
    const selectedIds = Array.from(mockOrderCourierIds?.selectedOptions || [])
      .map((opt) => String(opt.value || '').trim())
      .filter(Boolean);
    const selectedApproved = selectedIds.filter((id) => approvedById.has(id));
    const selectedAvailable = selectedApproved.filter((id) => approvedById.get(id)?.data?.available === true);
    return {
      ids: Array.from(new Set(selectedAvailable)),
      selectedCount: selectedIds.length,
      unavailableCount: Math.max(0, selectedApproved.length - selectedAvailable.length),
      mode,
    };
  }

  const allAvailable = approvedCouriers
    .filter((item) => item.data.available === true)
    .map((item) => item.id);

  return {
    ids: Array.from(new Set(allAvailable)),
    selectedCount: allAvailable.length,
    unavailableCount: 0,
    mode,
  };
}

async function createMockOrderFromAdmin(event) {
  event.preventDefault();

  if (!hasAdminPermission('orders')) {
    setMockOrderResult('لا تملك صلاحية إنشاء طلب تجريبي.', 'error');
    return;
  }

  const target = getMockOrderTargetDriverIds();
  if (!target.ids.length) {
    if (target.mode === 'specific') {
      setMockOrderResult('اختر مندوبًا متاحًا واحدًا على الأقل. المندوب غير المتاح لا يستقبل عروضًا.', 'error');
      return;
    }
    setMockOrderResult('لا يوجد مندوبون متاحون حاليًا لاستقبال الطلب التجريبي.', 'error');
    return;
  }

  const now = Date.now();
  const orderSeed = String(now).slice(-8);
  const clientName = String(mockOrderClientName?.value || '').trim() || 'عميل تجريبي';
  const clientPhone = String(mockOrderClientPhone?.value || '').trim() || '0900000000';
  const restaurantName = String(mockOrderStoreName?.value || '').trim() || 'متجر تجريبي';
  const deliveryAddress = String(mockOrderAddress?.value || '').trim() || 'الخرطوم - طلب تجريبي';
  const paymentMethod = String(mockOrderPaymentMethod?.value || 'cash').trim().toLowerCase();
  const offeredDriverId = target.ids[0];

  const payload = {
    orderId: `mock-${now}`,
    orderNumber: orderSeed,
    source: 'admin_mock_order',
    isMockOrder: true,
    status: 'courier_offer_pending',
    orderStatus: 'courier_offer_pending',
    paymentMethod,
    paymentStatus: 'pending',
    storeApprovalPending: false,
    clientId: `mock-client-${orderSeed}`,
    clientName,
    clientPhone,
    restaurantId: `mock-store-${orderSeed}`,
    restaurantName,
    deliveryAddress,
    address: deliveryAddress,
    restaurantLat: 15.5007,
    restaurantLng: 32.5599,
    clientLat: 15.5406,
    clientLng: 32.5599,
    restaurantLocation: new GeoPoint(15.5007, 32.5599),
    clientLocation: new GeoPoint(15.5406, 32.5599),
    items: [
      {
        name: 'طلب تجريبي من لوحة الأدمن',
        quantity: 1,
        price: 2500,
        total: 2500,
      },
    ],
    subtotal: 2500,
    deliveryFee: 400,
    total: 2900,
    totalAmount: 2900,
    currency: 'SDG',
    offeredDriverId,
    offerDriverIds: target.ids,
    offerEligibleDriversCount: target.ids.length,
    assignmentAvailableDriversCount: target.ids.length,
    courierOfferRadiusKm: 20,
    maxDriverDistanceKm: 20,
    createdByAdminUid: String(currentAdminProfile?.uid || auth.currentUser?.uid || '').trim(),
    createdByAdminEmail: String(currentAdminProfile?.email || auth.currentUser?.email || '').trim(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    storeApprovedAt: serverTimestamp(),
    offerStartedAt: serverTimestamp(),
  };

  if (mockOrderCreateBtn) mockOrderCreateBtn.disabled = true;
  setMockOrderResult('جاري إنشاء الطلب التجريبي...', 'muted');

  try {
    const ref = await addDoc(collection(db, 'orders'), payload);
    const extra = target.unavailableCount > 0
      ? ` (تم استبعاد ${target.unavailableCount} غير متاح)`
      : '';
    setMockOrderResult(`تم إنشاء الطلب التجريبي بنجاح: ${formatUnifiedOrderCode(payload.orderNumber, payload.orderId, ref.id)} | المستهدفون: ${target.ids.length}${extra}`, 'success');
    if (orderSearchInput) {
      orderSearchInput.value = ref.id;
    }
    if (orderStatusFilter) {
      orderStatusFilter.value = 'active';
    }
    renderOperationsOrders();
  } catch (err) {
    setMockOrderResult(`تعذر إنشاء الطلب التجريبي: ${err.message || err}`, 'error');
  } finally {
    if (mockOrderCreateBtn) mockOrderCreateBtn.disabled = false;
  }
}

function bindMockOrderForm() {
  if (!mockOrderForm || mockOrderFormBound) return;
  mockOrderFormBound = true;

  if (mockOrderClientName && !mockOrderClientName.value) mockOrderClientName.value = 'عميل تجريبي';
  if (mockOrderStoreName && !mockOrderStoreName.value) mockOrderStoreName.value = 'متجر تجريبي';
  if (mockOrderAddress && !mockOrderAddress.value) mockOrderAddress.value = 'الخرطوم - طلب تجريبي';

  renderMockOrderCouriersSelect();
  syncMockOrderModeUi();

  mockOrderMode?.addEventListener('change', () => {
    syncMockOrderModeUi();
    const isSpecific = String(mockOrderMode.value || 'all').trim().toLowerCase() === 'specific';
    setMockOrderResult(isSpecific
      ? 'اختر مندوبًا متاحًا أو أكثر من القائمة.'
      : 'سيتم الاستهداف تلقائيًا لكل المندوبين المتاحين.', 'muted');
  });

  mockOrderForm.addEventListener('submit', createMockOrderFromAdmin);
}

function getFilteredOperationsOrders() {
  const filter = String(orderStatusFilter?.value || 'active').trim().toLowerCase();
  const queryText = String(orderSearchInput?.value || '').trim().toLowerCase();

  return operationsOrderDocsCache
    .filter((item) => {
      const data = item.data || {};
      const status = getOrderLifecycleStatus(data);
      const bucket = getOperationsOrderBucket(data);
      const offerDriverIds = Array.isArray(data.offerDriverIds) ? data.offerDriverIds : [];

      if (filter === 'active' && !isActiveOrderStatus(status)) return false;
      if (filter === 'completed' && bucket !== 'completed') return false;
      if (filter === 'review' && bucket !== 'review') return false;
      if (filter === 'cancelled' && bucket !== 'cancelled') return false;
      if (filter === 'courier' && !data.assignedDriverId) return false;

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
        ...offerDriverIds,
      ].join(' ').toLowerCase();
      return haystack.includes(queryText);
    })
    .sort((a, b) => (b.createdAtMillis || 0) - (a.createdAtMillis || 0));
}

async function executeAdminOrderAction(orderId, action) {
  const orderEntry = operationsOrderDocsCache.find((item) => item.id === orderId);
  const order = orderEntry?.data || {};
  if (!orderId || !orderEntry) return;

  const notePrompt = action === 'resolve_courier_issue'
    ? 'اكتب نتيجة المعالجة لإرسالها إلى المندوب (اختياري):'
    : 'ملاحظة إدارية داخلية (اختياري):';
  const note = String(prompt(notePrompt, '') || '').trim();
  const payload = { orderId, action, note };

  if (action === 'assign_specific') {
    const driverId = String(document.getElementById(`orderAssignDriver-${orderId}`)?.value || '').trim();
    if (!driverId) {
      alert('اختر مندوبًا أولاً.');
      return;
    }
    payload.nextDriverId = driverId;
    payload.driverId = driverId;
  }

  if (action === 'set_status') {
    const nextStatus = String(document.getElementById(`orderSetStatus-${orderId}`)?.value || '').trim().toLowerCase();
    if (!nextStatus) {
      alert('اختر الحالة أولاً.');
      return;
    }
    payload.nextStatus = nextStatus;
  }

  if (action === 'expand_courier_radius') {
    const currentRadius = Number(order.courierOfferRadiusKm || order.maxDriverDistanceKm || 20);
    const radiusInput = prompt('اكتب نطاق عرض الطلب للمناديب بالكيلومتر:', String(currentRadius || 20));
    if (radiusInput == null) return;
    const radiusKm = Number(radiusInput);
    if (!Number.isFinite(radiusKm) || radiusKm <= 0) {
      alert('أدخل نطاقًا صحيحًا أكبر من صفر.');
      return;
    }
    payload.radiusKm = radiusKm;
  }

  if (action === 'cancel' && !confirm(`تأكيد إلغاء الطلب ${formatUnifiedOrderCode(order.orderNumber, order.orderId, orderId)}؟`)) {
    return;
  }

  if (action === 'cancel') {
    payload.refundToWallet = window.confirm(
      'هل تريد إعادة المبلغ المدفوع إلى محفظة العميل؟\n\nموافق: إعادة المبلغ\nإلغاء: إلغاء الطلب دون رد للمحفظة'
    );
  }

  if (action === 'restore_cancelled' && !confirm(`تأكيد استرجاع الطلب ${formatUnifiedOrderCode(order.orderNumber, order.orderId, orderId)} لنفس مرحلته السابقة؟`)) {
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

function getOfferAudienceCount(orderData = {}) {
  const countFromEligible = Number(orderData.offerEligibleDriversCount);
  if (Number.isFinite(countFromEligible) && countFromEligible > 0) {
    return Math.floor(countFromEligible);
  }

  const idsFromOfferList = Array.isArray(orderData.offerDriverIds)
    ? orderData.offerDriverIds.map((id) => String(id || '').trim()).filter(Boolean)
    : [];
  if (idsFromOfferList.length) {
    return idsFromOfferList.length;
  }

  const idsFromLegacyList = Array.isArray(orderData.offeredDriverIds)
    ? orderData.offeredDriverIds.map((id) => String(id || '').trim()).filter(Boolean)
    : [];
  if (idsFromLegacyList.length) {
    return idsFromLegacyList.length;
  }

  const distanceMapCount = orderData.offerDriverDistancesKm && typeof orderData.offerDriverDistancesKm === 'object'
    ? Object.keys(orderData.offerDriverDistancesKm).filter(Boolean).length
    : 0;
  if (distanceMapCount > 0) {
    return distanceMapCount;
  }

  if (String(orderData.offeredDriverId || '').trim()) {
    return 1;
  }

  const countFromAvailable = Number(orderData.assignmentAvailableDriversCount);
  if (Number.isFinite(countFromAvailable) && countFromAvailable > 0) {
    return Math.floor(countFromAvailable);
  }

  const countFromCandidates = Array.isArray(orderData.candidateDrivers)
    ? orderData.candidateDrivers.map((id) => String(id || '').trim()).filter(Boolean).length
    : 0;
  if (countFromCandidates > 0) {
    return countFromCandidates;
  }

  return 0;
}

function getOrderProgressState(orderData = {}) {
  const status = String(getOrderLifecycleStatus(orderData) || '').trim().toLowerCase();
  const steps = [
    { key: 'created', label: 'الإنشاء' },
    { key: 'searching', label: 'بحث مندوب' },
    { key: 'assigned', label: 'إسناد' },
    { key: 'pickup', label: 'استلام' },
    { key: 'arrived', label: 'وصول' },
    { key: 'delivered', label: 'تسليم' },
  ];

  const cancelled = status.includes('cancel') || status.includes('رفض') || status.includes('rejected') || status.includes('ملغي');
  if (cancelled) {
    return {
      steps,
      currentStep: 2,
      cancelled: true,
      label: 'ملغي',
    };
  }

  if (isDeliveredOrderStatus(status)) {
    return { steps, currentStep: 6, cancelled: false, label: 'مكتمل' };
  }

  const stepMap = {
    pending: 1,
    store_pending: 1,
    courier_searching: 2,
    courier_offer_pending: 2,
    courier_assigned: 3,
    pickup_ready: 4,
    picked_up: 4,
    arrived_to_client: 5,
  };

  return {
    steps,
    currentStep: stepMap[status] || 1,
    cancelled: false,
    label: formatOrderStatusLabel(status || '-'),
  };
}

function buildOrderProgressMarkup(orderData = {}) {
  const state = getOrderProgressState(orderData);
  const pct = Math.round((Math.max(1, state.currentStep) / state.steps.length) * 100);
  const items = state.steps.map((step, index) => {
    const n = index + 1;
    const cls = n < state.currentStep ? 'done' : n === state.currentStep ? 'active' : 'todo';
    return `
      <li class="order-progress-step ${cls}">
        <span class="order-progress-dot">${n}</span>
        <span class="order-progress-label">${escapeHtml(step.label)}</span>
      </li>
    `;
  }).join('');

  return `
    <div class="order-progress ${state.cancelled ? 'is-cancelled' : ''}">
      <div class="order-progress-head">
        <strong>مسار الطلب التشغيلي</strong>
        <span class="order-progress-status">${escapeHtml(state.label)}</span>
      </div>
      <div class="order-progress-bar" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${state.cancelled ? 0 : pct}">
        <span style="width:${state.cancelled ? 100 : pct}%"></span>
      </div>
      <ol class="order-progress-steps">${items}</ol>
    </div>
  `;
}

function markSelectedOperationsRow(orderId) {
  const rows = operationsOrdersTable?.querySelectorAll('tbody tr') || [];
  rows.forEach((row) => {
    const btn = row.querySelector('[data-operations-order]');
    const rowOrderId = String(btn?.getAttribute('data-operations-order') || '');
    row.classList.toggle('is-selected-row', !!orderId && rowOrderId === orderId);
  });
}

function destroyOrderInlineMap() {
  if (orderInlineMap) {
    try {
      orderInlineMap.remove();
    } catch (_) {
    }
  }
  orderInlineMap = null;
}

function getBatchDeliveryStops(orderData = {}) {
  if (!['store_batch_delivery', 'store_direct_delivery'].includes(String(orderData.orderSource || ''))) return [];
  return Array.isArray(orderData.batchStops)
    ? orderData.batchStops
        .map((stop, index) => ({ index, data: stop || {} }))
        .sort((a, b) => Number(a.data.sequence ?? a.index) - Number(b.data.sequence ?? b.index))
    : [];
}

function getBatchStopGeo(stop = {}) {
  return (
    extractGeo(stop, ['clientLocation', 'location', 'address.location']) ||
    extractGeoByPairs(stop, [
      ['clientLat', 'clientLng'],
      ['lat', 'lng'],
      ['latitude', 'longitude'],
    ])
  );
}

function formatBatchStopStatus(status = '') {
  const value = String(status || 'pending').trim();
  const labels = {
    pending: 'بانتظار التنفيذ',
    next: 'التالي',
    on_the_way: 'في الطريق',
    delivered: 'تم التسليم',
    failed: 'تعذر التسليم',
    deferred: 'مؤجل/لم يستلم',
    returned: 'مرتجع',
    removal_requested: 'طلب إزالة بانتظار المتجر',
    removal_rejected: 'رفض المتجر الإزالة',
    removed_by_store: 'أزيلت بموافقة المتجر',
  };
  return labels[value] || value || '-';
}

function getBatchTripCode(orderData = {}, fallback = '') {
  return String(
    orderData.publicBatchCode ||
    orderData.batchCode ||
    orderData.tripCode ||
    orderData.batchCodeSeed ||
    fallback ||
    ''
  ).trim();
}

function getBatchStopCode(stop = {}, fallback = '') {
  return String(stop.publicStopCode || stop.stopCode || fallback || '').trim();
}

function getRemovedBatchDeliveryStops(orderData = {}) {
  if (!['store_batch_delivery', 'store_direct_delivery'].includes(String(orderData.orderSource || ''))) return [];
  return Array.isArray(orderData.removedBatchStops)
    ? orderData.removedBatchStops
        .map((stop, index) => ({ index, data: stop || {} }))
        .sort((a, b) => Number(a.data.removedAt || a.index) - Number(b.data.removedAt || b.index))
    : [];
}

function summarizeBatchStops(stops = [], removedStops = []) {
  return stops.reduce((summary, item) => {
    const status = String(item?.data?.status || 'pending').trim();
    if (status === 'delivered') summary.delivered += 1;
    else if (['failed', 'deferred', 'returned'].includes(status)) summary.exceptions += 1;
    else if (status === 'removal_requested') summary.removalPending += 1;
    else summary.active += 1;
    return summary;
  }, {
    total: stops.length,
    active: 0,
    delivered: 0,
    exceptions: 0,
    removalPending: 0,
    removed: removedStops.length,
  });
}

function getBatchStopRowClass(status = '') {
  const value = String(status || '').trim();
  if (value === 'delivered') return 'batch-stop-row--delivered';
  if (['failed', 'deferred', 'returned'].includes(value)) return 'batch-stop-row--issue';
  if (['removal_requested', 'removal_rejected', 'removed_by_store'].includes(value)) return 'batch-stop-row--removal';
  return '';
}

function formatOrderSourceLabel(orderData = {}) {
  const source = String(orderData.orderSource || '').trim();
  const fulfillment = String(orderData.fulfillmentMode || orderData.deliveryMode || '').trim();
  if (source === 'store_batch_delivery') return 'رحلة متجر مجمعة';
  if (source === 'store_direct_delivery') return 'وصّلها من متجر';
  if (source === 'client_parcel_delivery') return 'وصّلها من عميل';
  if (fulfillment === 'merchant_delivery') return 'توصيل متجر';
  return 'طلب متجر/مطعم';
}

function isClientParcelOrder(orderData = {}) {
  return String(orderData.orderSource || '').trim() === 'client_parcel_delivery';
}

function getPickupGeoByOrder(orderData = {}) {
  if (isClientParcelOrder(orderData)) {
    const fromPickup = extractGeo(orderData, ['pickupLocation']);
    if (fromPickup) return fromPickup;
    const lat = Number(orderData.pickupLat);
    const lng = Number(orderData.pickupLng);
    return Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : null;
  }
  return getRestaurantGeoByOrder(orderData);
}

function getDropoffGeoByOrder(orderData = {}) {
  return getClientGeoByOrder(orderData);
}

function getPickupLabelByOrder(orderData = {}) {
  if (isClientParcelOrder(orderData)) return 'نقطة الاستلام';
  if (String(orderData.orderSource || '').trim() === 'store_direct_delivery') return 'المتجر';
  return 'المتجر/المطعم';
}

function getPickupNameByOrder(orderData = {}, fallback = '') {
  if (isClientParcelOrder(orderData)) {
    return String(orderData.pickupAddress || orderData.pickupMapUrl || 'نقطة الاستلام من العميل').trim();
  }
  return String(orderData.restaurantName || fallback || 'نقطة الاستلام').trim();
}

function renderBatchStopsMarkup(orderData = {}) {
  const stops = getBatchDeliveryStops(orderData);
  const removedStops = getRemovedBatchDeliveryStops(orderData);
  if (!stops.length && !removedStops.length) return '';
  const batchCode = getBatchTripCode(orderData, orderData.orderNumber || orderData.orderId || '');
  const sourceLabel = formatOrderSourceLabel(orderData);
  const summary = summarizeBatchStops(stops, removedStops);
  const rows = stops.map(({ index, data }, displayIndex) => {
    const geo = getBatchStopGeo(data);
    const status = String(data.status || 'pending').trim();
    const reason = String(data.failureReason || data.removalReason || data.removalRejectNote || data.returnReason || '').trim();
    const stopCode = getBatchStopCode(data, String(displayIndex + 1));
    const trackingUrl = String(data.trackingUrl || data.publicTrackingUrl || '').trim();
    const rowClass = getBatchStopRowClass(status);
    return `
      <tr class="${rowClass}">
        <td><span class="batch-stop-code">${escapeHtml(stopCode)}</span><br /><span class="muted">#${escapeHtml(String(index + 1))}</span></td>
        <td><b>${escapeHtml(data.clientName || 'عميل')}</b><br /><span class="muted">${escapeHtml(data.clientPhone || '-')}</span></td>
        <td>${escapeHtml(data.zoneName || '-')}<br /><span class="muted">${escapeHtml(data.addressText || '')}</span></td>
        <td>${escapeHtml(formatBatchStopStatus(status))}</td>
        <td>${reason ? escapeHtml(reason) : '<span class="muted">لا توجد</span>'}</td>
        <td>${trackingUrl ? `<a href="${escapeHtml(trackingUrl)}" target="_blank" rel="noopener">فتح الرابط</a>` : '<span class="muted">لا يوجد</span>'}</td>
        <td>${geo ? escapeHtml(`${geo.lat.toFixed(5)}, ${geo.lng.toFixed(5)}`) : '<span class="muted">لا يوجد</span>'}</td>
      </tr>
    `;
  }).join('');
  const removedRows = removedStops.map(({ data }, displayIndex) => {
    const stopCode = getBatchStopCode(data, String(displayIndex + 1));
    const reason = String(data.removalReason || data.removalApproveNote || '').trim();
    return `
      <tr class="batch-stop-row--removal">
        <td><span class="batch-stop-code">${escapeHtml(stopCode)}</span></td>
        <td>${escapeHtml(data.clientName || 'عميل')}<br /><span class="muted">${escapeHtml(data.clientPhone || '-')}</span></td>
        <td>${escapeHtml(data.zoneName || '-')}</td>
        <td>${escapeHtml(reason || 'أزيل قبل الاستلام بموافقة المتجر')}</td>
      </tr>
    `;
  }).join('');
  return `
    <div class="order-detail-card" style="grid-column:1/-1">
      <strong>تفاصيل ${escapeHtml(sourceLabel)} ${batchCode ? `- ${escapeHtml(batchCode)}` : ''}</strong>
      <div class="batch-summary-grid">
        <span class="batch-summary-pill">الحالية <b>${summary.total}</b></span>
        <span class="batch-summary-pill">قيد التنفيذ <b>${summary.active}</b></span>
        <span class="batch-summary-pill">تم التسليم <b>${summary.delivered}</b></span>
        <span class="batch-summary-pill">متعذر/مرتجع <b>${summary.exceptions}</b></span>
        <span class="batch-summary-pill">طلبات إزالة <b>${summary.removalPending}</b></span>
        <span class="batch-summary-pill">أزيلت <b>${summary.removed}</b></span>
      </div>
      <div class="table-scroll" style="margin-top:10px">
        <table class="data-table compact">
          <thead><tr><th>رقم الطلب</th><th>العميل</th><th>المنطقة والعنوان</th><th>الحالة</th><th>الملاحظة</th><th>التتبع</th><th>الإحداثيات</th></tr></thead>
          <tbody>${rows}</tbody>
        </table>
      </div>
      ${removedRows ? `
        <div class="batch-removed-box">
          <b>طلبات أزيلت قبل استلام المندوب</b>
          <div class="table-scroll" style="margin-top:8px">
            <table class="data-table compact">
              <thead><tr><th>رقم الطلب</th><th>العميل</th><th>المنطقة</th><th>السبب</th></tr></thead>
              <tbody>${removedRows}</tbody>
            </table>
          </div>
        </div>
      ` : ''}
    </div>
  `;
}

function resolvePaymentReceiptUrl(orderData = {}) {
  const status = String(orderData.orderStatus || orderData.status || '').trim().toLowerCase();
  const courierStage = String(orderData.courierLastStage || '').trim().toLowerCase();
  const proofImageUrl = String(orderData.proofImageUrl || '').trim();
  const proofLooksLikeDelivery = Boolean(
    proofImageUrl
    && (status === 'delivered' || status === 'completed' || courierStage === 'delivered')
  );
  const candidates = [
    orderData.paymentReceiptUrl,
    orderData.paymentReceiptImageUrl,
    orderData.paymentProofUrl,
    orderData.paymentProofImageUrl,
    orderData.paymentEvidenceUrl,
    orderData.paymentEvidenceImageUrl,
    orderData.receiptUrl,
    orderData.receiptImageUrl,
    orderData.transferReceiptUrl,
    orderData.transferReceiptImageUrl,
    orderData.evidenceImageUrl,
    orderData.bankReceiptUrl,
    orderData.bankReceiptImageUrl,
    orderData.imageUrl,
    orderData.paymentEvidence?.proofImageUrl,
    orderData.paymentEvidence?.imageUrl,
    orderData.paymentEvidence?.receiptUrl,
    orderData.payment?.proofImageUrl,
    orderData.payment?.imageUrl,
    orderData.payment?.receiptUrl,
  ];
  const explicitReceiptUrl = String(candidates.find((value) => String(value || '').trim()) || '').trim();
  if (explicitReceiptUrl) return explicitReceiptUrl;

  const hasPaymentReviewContext = Boolean(
    String(orderData.transactionReference || '').trim()
    && (
      orderData.paymentReviewRequired === true
      || String(orderData.paymentReviewDecision || '').trim()
      || ['payment_review', 'under_review'].includes(status)
      || ['under_review', 'pending'].includes(String(orderData.paymentStatus || '').trim().toLowerCase())
    )
  );
  return hasPaymentReviewContext && !proofLooksLikeDelivery ? proofImageUrl : '';
}

function resolveDeliveryProofUrl(orderData = {}) {
  const status = String(orderData.orderStatus || orderData.status || '').trim().toLowerCase();
  const courierStage = String(orderData.courierLastStage || '').trim().toLowerCase();
  const explicitProofUrl = String(
    orderData.deliveryProofImageUrl
    || orderData.deliveryEvidenceImageUrl
    || orderData.deliveredProofImageUrl
    || orderData.deliveryProofUrl
    || orderData.deliveryEvidenceUrl
    || orderData.delivery?.proofImageUrl
    || orderData.delivery?.imageUrl
    || ''
  ).trim();
  if (explicitProofUrl) return explicitProofUrl;
  const proofImageUrl = String(orderData.proofImageUrl || '').trim();
  return proofImageUrl && (status === 'delivered' || status === 'completed' || courierStage === 'delivered')
    ? proofImageUrl
    : '';
}

function renderPaymentReceiptMarkup(orderData = {}) {
  const proofImageUrl = resolvePaymentReceiptUrl(orderData);
  const transactionReference = String(orderData.transactionReference || '').trim();
  const paymentMethod = String(orderData.paymentMethod || orderData.method || '').trim();
  const reviewedAt = orderData.paymentReviewedAt || orderData.paymentReviewAutoApprovedAt || orderData.paidAt;
  const reviewedBy = String(orderData.paymentReviewedByAdminEmail || orderData.paymentReviewedByAdminUid || '').trim();
  const decision = String(orderData.paymentReviewDecision || '').trim();
  const precheck = orderData.paymentReceiptPrecheck || orderData.receiptPrecheck || {};
  const precheckIssues = Array.isArray(precheck.issues) ? precheck.issues : [];
  const precheckStatus = String(orderData.paymentReceiptValidationStatus || '').trim();

  if (!proofImageUrl && !transactionReference && !paymentMethod) return '';

  const reviewLabel = decision
    ? formatOrderStatusLabel(decision)
    : String(orderData.paymentStatus || '-');

  return `
    <div class="order-detail-card" style="grid-column:1/-1">
      <strong>إيصال الدفع</strong>
      <div class="order-detail-grid" style="margin-top:10px">
        <div><b>طريقة الدفع:</b> ${escapeHtml(paymentMethod || '-')}</div>
        <div><b>رقم العملية:</b> ${escapeHtml(transactionReference || '-')}</div>
        <div><b>حالة المراجعة:</b> ${escapeHtml(reviewLabel || '-')}</div>
        <div><b>وقت الاعتماد:</b> ${escapeHtml(formatDateTimeLabel(reviewedAt))}</div>
        <div><b>اعتمد بواسطة:</b> ${escapeHtml(reviewedBy || '-')}</div>
        <div><b>فحص الإيصال:</b> ${escapeHtml(precheckStatus || (precheck.passed === true ? 'passed_local' : precheck.mode ? 'checked' : '-'))}</div>
      </div>
      ${precheckIssues.length ? `<div class="muted" style="margin-top:10px">ملاحظات الفحص: ${precheckIssues.map((item) => escapeHtml(String(item || '').trim())).filter(Boolean).join(' | ')}</div>` : ''}
      ${proofImageUrl ? `
        <div style="margin-top:12px; display:flex; gap:10px; align-items:flex-start; flex-wrap:wrap">
          <a class="btn primary" href="${escapeHtml(proofImageUrl)}" target="_blank" rel="noopener">فتح الإيصال</a>
          <a href="${escapeHtml(proofImageUrl)}" target="_blank" rel="noopener" style="display:block; max-width:220px">
            <img src="${escapeHtml(proofImageUrl)}" alt="إيصال الدفع" loading="lazy" style="width:100%; max-height:180px; object-fit:contain; border:1px solid #e5e7eb; border-radius:8px; background:#fff" />
          </a>
        </div>
      ` : '<div class="muted" style="margin-top:10px">لا توجد صورة إيصال محفوظة لهذا الطلب.</div>'}
    </div>
  `;
}

function renderDeliveryProofMarkup(orderData = {}) {
  const deliveryProofUrl = resolveDeliveryProofUrl(orderData);
  if (!deliveryProofUrl) return '';
  const deliveredAt = orderData.deliveredAt || orderData.courierLastStageAt || orderData.completedAt;
  const driverLabel = orderData.assignedDriverId
    ? resolveDriverDisplay(orderData.assignedDriverId, orderData.assignedDriverName || '')
    : '<span class="muted">غير معين</span>';
  return `
    <div class="order-detail-card" style="grid-column:1/-1">
      <strong>إثبات التسليم</strong>
      <div class="order-detail-grid" style="margin-top:10px">
        <div><b>المندوب:</b> ${driverLabel}</div>
        <div><b>وقت التسليم:</b> ${escapeHtml(formatDateTimeLabel(deliveredAt))}</div>
      </div>
      <div style="margin-top:12px; display:flex; gap:10px; align-items:flex-start; flex-wrap:wrap">
        <a class="btn primary" href="${escapeHtml(deliveryProofUrl)}" target="_blank" rel="noopener">فتح إثبات التسليم</a>
        <a href="${escapeHtml(deliveryProofUrl)}" target="_blank" rel="noopener" style="display:block; max-width:220px">
          <img src="${escapeHtml(deliveryProofUrl)}" alt="إثبات التسليم" loading="lazy" style="width:100%; max-height:180px; object-fit:contain; border:1px solid #e5e7eb; border-radius:8px; background:#fff" />
        </a>
      </div>
    </div>
  `;
}

async function renderInlineOrderMap(orderId, orderData = {}) {
  const mapShell = document.getElementById(`orderInlineMapShell-${orderId}`);
  const mapCanvas = document.getElementById(`orderInlineMap-${orderId}`);
  const mapMeta = document.getElementById(`orderInlineMapMeta-${orderId}`);
  if (!mapShell || !mapCanvas) return;

  mapShell.classList.remove('is-hidden');
  orderInlineMapVisible = true;
  orderInlineMapOrderId = String(orderId || '').trim();

  try {
    await withTimeout(ensureLeaflet(), 9000, 'تعذر تحميل الخريطة داخل الطلب (timeout).');
  } catch (error) {
    if (mapMeta) {
      mapMeta.textContent = error?.message || 'تعذر تحميل الخريطة داخل الطلب.';
      mapMeta.classList.remove('muted');
    }
    return;
  }

  destroyOrderInlineMap();
  orderInlineMap = window.L.map(mapCanvas, {
    zoomControl: true,
    attributionControl: true,
  });

  const inlineBase = MAP_STYLE_PRESETS[mapUiState.style] || MAP_STYLE_PRESETS.voyager || MAP_STYLE_PRESETS.osm;
  window.L.tileLayer(inlineBase.url, {
    attribution: inlineBase.attribution || '&copy; OpenStreetMap contributors',
    subdomains: inlineBase.subdomains,
    maxZoom: 19,
  }).addTo(orderInlineMap);

  const restaurantGeo = getRestaurantGeoByOrder(orderData);
  const driverGeo = getDriverGeoByOrder(orderData);
  const clientGeo = getClientGeoByOrder(orderData);

  const points = [];
  const routePoints = [];

  const pushPoint = (geo, title, markerType, markerVariant = 'default') => {
    if (!geo) return;
    const latLng = [geo.lat, geo.lng];
    points.push(latLng);
    const last = routePoints[routePoints.length - 1];
    if (!last || last[0] !== latLng[0] || last[1] !== latLng[1]) {
      routePoints.push(latLng);
    }
    const marker = window.L.marker(latLng, {
      icon: buildMarkerIcon({ type: markerType, variant: markerVariant })
    }).addTo(orderInlineMap);
    marker.bindTooltip(title);
    marker.bindPopup(title);
  };

  const batchStops = getBatchDeliveryStops(orderData);
  if (batchStops.length) {
    pushPoint(restaurantGeo, `${pickupLabel}: ${pickupName}`, 'restaurant', 'online');
    pushPoint(driverGeo, `المندوب: ${resolveDriverDisplay(orderData.assignedDriverId, orderData.assignedDriverName || '')}`, 'driver', 'current');

    batchStops.forEach(({ data }, displayIndex) => {
      const geo = getBatchStopGeo(data);
      if (!geo) return;
      const latLng = [geo.lat, geo.lng];
      points.push(latLng);
      const last = routePoints[routePoints.length - 1];
      if (!last || last[0] !== latLng[0] || last[1] !== latLng[1]) {
        routePoints.push(latLng);
      }
      const status = String(data.status || 'pending').trim();
      const markerVariant = status === 'delivered'
        ? 'active'
        : (['failed', 'deferred', 'returned'].includes(status) ? 'offline' : 'selected');
      const stopCode = getBatchStopCode(data, String(displayIndex + 1));
      const reason = String(data.failureReason || data.removalReason || data.removalRejectNote || data.returnReason || '').trim();
      const trackingUrl = String(data.trackingUrl || data.publicTrackingUrl || '').trim();
      const title = `${stopCode}. ${data.clientName || 'عميل'} | ${formatBatchStopStatus(status)} | ${data.clientPhone || '-'}`;
      const marker = window.L.marker(latLng, {
        icon: buildMarkerIcon({ type: 'client', variant: markerVariant })
      }).addTo(orderInlineMap);
      marker.bindTooltip(title);
      marker.bindPopup(`
        <b>${escapeHtml(stopCode)}</b><br />
        <b>${escapeHtml(data.clientName || 'عميل')}</b><br />
        ${escapeHtml(data.clientPhone || '-')}<br />
        ${escapeHtml(data.zoneName || '-')}<br />
        ${escapeHtml(formatBatchStopStatus(status))}
        ${reason ? `<br /><span>${escapeHtml(reason)}</span>` : ''}
        ${trackingUrl ? `<br /><a href="${escapeHtml(trackingUrl)}" target="_blank" rel="noopener">فتح تتبع العميل</a>` : ''}
      `);
    });

    if (routePoints.length >= 2) {
      window.L.polyline(routePoints, {
        color: '#2563eb',
        weight: 5,
        opacity: 0.95,
        lineCap: 'round',
      }).addTo(orderInlineMap);
    }

    if (!points.length) {
      orderInlineMap.setView([15.5007, 32.5599], 11);
      if (mapMeta) {
        mapMeta.textContent = `لا تتوفر نقاط جغرافية كافية لهذه الخدمة حالياً: ${formatOrderSourceLabel(orderData)}.`;
        mapMeta.classList.remove('muted');
      }
      return;
    }

    if (points.length === 1) {
      orderInlineMap.setView(points[0], 15);
    } else {
      const bounds = window.L.latLngBounds(points);
      orderInlineMap.fitBounds(bounds.pad(0.24), { animate: true, maxZoom: 16 });
    }

    if (mapMeta) {
      const withGeo = batchStops.filter(({ data }) => getBatchStopGeo(data)).length;
      mapMeta.textContent = `${formatOrderSourceLabel(orderData)}: ${withGeo} نقطة مرسومة من ${batchStops.length} عميل.`;
      mapMeta.classList.remove('muted');
    }
    mapShell.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    requestAnimationFrame(() => orderInlineMap?.invalidateSize());
    setTimeout(() => orderInlineMap?.invalidateSize(), 160);
    return;
  }

  pushPoint(restaurantGeo, `${pickupLabel}: ${pickupName}`, 'restaurant', 'online');
  pushPoint(driverGeo, `المندوب: ${resolveDriverDisplay(orderData.assignedDriverId, orderData.assignedDriverName || '')}`, 'driver', 'current');
  pushPoint(clientGeo, `العميل: ${resolveClientDisplay(orderData.clientId, orderData.clientName)}`, 'client', 'default');

  if (restaurantGeo && driverGeo) {
    window.L.polyline([
      [restaurantGeo.lat, restaurantGeo.lng],
      [driverGeo.lat, driverGeo.lng],
    ], {
      color: '#0ea5e9',
      weight: 4,
      opacity: 0.85,
      lineCap: 'round',
      dashArray: '2, 6',
    }).addTo(orderInlineMap);
  }

  if (driverGeo && clientGeo) {
    window.L.polyline([
      [driverGeo.lat, driverGeo.lng],
      [clientGeo.lat, clientGeo.lng],
    ], {
      color: '#2563eb',
      weight: 5,
      opacity: 0.95,
      lineCap: 'round',
    }).addTo(orderInlineMap);
  } else if (routePoints.length >= 2) {
    window.L.polyline(routePoints, {
      color: '#2563eb',
      weight: 4,
      opacity: 0.9,
      lineCap: 'round',
    }).addTo(orderInlineMap);
  }

  if (!points.length) {
    orderInlineMap.setView([15.5007, 32.5599], 11);
    if (mapMeta) {
      mapMeta.textContent = 'لا تتوفر نقاط جغرافية كافية لهذا الطلب حالياً.';
      mapMeta.classList.remove('muted');
    }
    return;
  }

  if (points.length === 1) {
    orderInlineMap.setView(points[0], 15);
  } else {
    const bounds = window.L.latLngBounds(points);
    orderInlineMap.fitBounds(bounds.pad(0.24), { animate: true, maxZoom: 16 });
  }

  const routeStateLabel = describeOrderRouteState(orderId, points);
  const missingPieces = [
    restaurantGeo ? '' : 'المتجر بلا موقع صالح',
    String(orderData.assignedDriverId || '').trim() && !driverGeo ? 'المندوب المعين لا يرسل موقعًا حاليًا' : '',
    clientGeo ? '' : 'العميل بلا موقع صالح',
  ].filter(Boolean);

  if (mapMeta) {
    mapMeta.textContent = missingPieces.length
      ? `${routeStateLabel} | ${missingPieces.join(' | ')}`
      : routeStateLabel;
    mapMeta.classList.remove('muted');
  }

  mapShell.scrollIntoView({ block: 'nearest', behavior: 'smooth' });

  const settleResize = () => {
    try {
      orderInlineMap?.invalidateSize();
    } catch (_) {
    }
  };
  requestAnimationFrame(settleResize);
  setTimeout(() => {
    settleResize();
  }, 120);
  setTimeout(() => {
    settleResize();
  }, 420);
}

function renderOperationsOrderDetails(orderId) {
  if (!operationsOrderDetails) return;
  const shouldRestoreInlineMap = orderInlineMapVisible && orderInlineMapOrderId === String(orderId || '').trim();
  destroyOrderInlineMap();
  if (!shouldRestoreInlineMap) {
    orderInlineMapVisible = false;
    orderInlineMapOrderId = '';
  }
  currentOperationsOrderId = String(orderId || '').trim();
  stopActiveOrderDriverListener();
  const entry = operationsOrderDocsCache.find((item) => item.id === orderId);
  if (!entry) {
    operationsOrderDetails.innerHTML = '<span class="muted">لم يتم العثور على الطلب المحدد.</span>';
    orderInlineMapVisible = false;
    orderInlineMapOrderId = '';
    return;
  }

  const data = entry.data || {};
  const lifecycleStatus = String(getOrderLifecycleStatus(data) || '').trim().toLowerCase();
  const isCancelledOrder = lifecycleStatus.includes('cancel') || lifecycleStatus.includes('store_rejected') || lifecycleStatus.includes('reject');
  const statusChoices = getAdminOrderedStatusChoices(lifecycleStatus);
  const timeline = getOrderTimelineEntries(data);
  const financial = computeOrderFinancialBreakdown(data);
  const availableCouriers = courierDirectoryCache.filter((item) => {
    const courier = item.data || {};
    return courier.isApproved === true || String(courier.approvalStatus || '').trim().toLowerCase() === 'approved';
  });
  const offerDriverIds = Array.isArray(data.offerDriverIds) ? data.offerDriverIds : [];
  const storeId = String(data.restaurantId || '').trim();
  const assignedDriverId = String(data.assignedDriverId || '').trim();
  const hasOpenCourierIssue = String(data.courierIssue?.status || '').trim().toLowerCase() === 'open';
  const offeredDriverId = String(data.offeredDriverId || '').trim();
  const driverIdFromOrder = assignedDriverId;
  const storePhone = resolveRestaurantPhone(
    storeId,
    data.restaurantPhone || data.storePhone || data.restaurantMobile || data.storeMobile || ''
  );
  const driverPhone = resolveDriverPhone(
    driverIdFromOrder,
    data.assignedDriverPhone || data.driverPhone || data.offeredDriverPhone || ''
  );
  const liveDriverId = isActiveOrderStatus(lifecycleStatus) ? assignedDriverId : '';
  const liveDriverName = String(data.assignedDriverName || '').trim();
  const isAwaitingOfferDecision = String(data.orderStatus || data.status || '').trim() === 'courier_offer_pending';
  const offerAudienceCount = getOfferAudienceCount(data);
  const courierRadiusKm = Number(data.courierOfferRadiusKm || data.maxDriverDistanceKm || 20);
  const offerAudienceSummary = offerAudienceCount > 0
    ? `<div><b>تم عرض الطلب على:</b> ${offerAudienceCount} مندوب</div>`
    : '<div><b>تم عرض الطلب على:</b> غير متاح</div>';
  const offerSummaryMarkup = isAwaitingOfferDecision
    ? `<div><b>المعروض عليهم الآن:</b> ${offerAudienceCount || '-'}</div>${offerAudienceSummary}<div class="muted">العرض ما زال بانتظار قبول أحد المناديب.</div>`
    : assignedDriverId
      ? `<div><b>المندوب الذي قبل الطلب:</b> ${resolveDriverDisplay(assignedDriverId, liveDriverName || data.assignedDriverName || '')}</div>${offerAudienceSummary}<div class="muted">النطاق السابق: ${escapeHtml(`${courierRadiusKm || 20} كم`)}</div>`
      : `${offerAudienceSummary}<div><b>النطاق السابق:</b> ${escapeHtml(`${courierRadiusKm || 20} كم`)}</div>${offeredDriverId ? '<div class="muted">يوجد مندوب مرشح للعرض، لكن لم يتم إسناد الطلب بعد.</div>' : '<div class="muted">لا يوجد مندوب معين حاليًا.</div>'}`;

  operationsOrderDetails.classList.remove('muted');
  operationsOrderDetails.innerHTML = `
    <div class="order-detail-shell">
      ${buildOrderProgressMarkup(data)}
      <div class="order-detail-head">
        <div>
          <h4 style="margin:0 0 8px">${escapeHtml(formatUnifiedOrderCode(data.orderNumber, data.orderId, orderId))}</h4>
          <div><span class="kv"><b>الحالة:</b> ${escapeHtml(formatOrderStatusLabel(data.orderStatus || data.status || '-'))}</span><span class="kv"><b>الدفع:</b> ${escapeHtml(data.paymentStatus || '-')}</span></div>
          ${renderStoreApprovalFlowHint(data)}
        </div>
        <div class="order-actions-row">
          ${isCancelledOrder
            ? `<button class="btn primary" data-admin-order-action="restore_cancelled" data-order-id="${escapeHtml(orderId)}">استرجاع الطلب كما كان</button>`
            : `
              <button class="btn danger" data-admin-order-action="cancel" data-order-id="${escapeHtml(orderId)}">إلغاء الطلب</button>
              <button class="btn ghost" data-admin-order-action="unassign_courier" data-order-id="${escapeHtml(orderId)}">سحب المندوب</button>
              <button class="btn ghost" data-admin-order-action="reassign_auto" data-order-id="${escapeHtml(orderId)}">إعادة إسناد تلقائي</button>
              <button class="btn ghost" data-admin-order-action="expand_courier_radius" data-order-id="${escapeHtml(orderId)}">توسيع نطاق المناديب</button>
            `}
          ${hasOpenCourierIssue ? `<button class="btn primary" data-admin-order-action="resolve_courier_issue" data-order-id="${escapeHtml(orderId)}">معالجة بلاغ المندوب</button>` : ''}
          <button class="btn primary" data-open-order-map="${escapeHtml(orderId)}">الخريطة داخل الطلب</button>
        </div>
      </div>
      <div class="order-detail-grid">
        <div class="order-detail-card"><strong>العميل</strong>${resolveClientDisplay(data.clientId, data.clientName)}<br />${escapeHtml(data.clientPhone || '-')}</div>
        <div class="order-detail-card"><strong>المتجر</strong>${resolveRestaurantDisplay(data.restaurantId, data.restaurantName)}<br />${escapeHtml(storePhone || '-')}</div>
        <div class="order-detail-card order-detail-card--driver${assignedDriverId ? ' order-detail-card--driver-current' : ''}" id="orderDriverCard-${escapeHtml(orderId)}">
          <strong>المندوب الحالي</strong>
          <div id="orderDriverName-${escapeHtml(orderId)}">${assignedDriverId ? resolveDriverDisplay(assignedDriverId, data.assignedDriverName || '') : 'لا يوجد مندوب معين'}</div>
          <div id="orderDriverPhone-${escapeHtml(orderId)}" class="muted">${escapeHtml(driverPhone || '-')}</div>
          <div id="orderDriverLocation-${escapeHtml(orderId)}" class="muted">${assignedDriverId ? 'جاري تحميل الموقع المباشر...' : 'الطلب معروض للمناديب ضمن النطاق، وليس مسنداً لمندوب بعد.'}</div>
          <div id="orderDriverUpdated-${escapeHtml(orderId)}" class="muted"></div>
        </div>
        <div class="order-detail-card"><strong>نطاق العرض</strong>${offerSummaryMarkup}</div>
        <div class="order-detail-card"><strong>العنوان</strong>${escapeHtml(data.deliveryAddress || data.address || '-')}</div>
        ${renderPaymentReceiptMarkup(data)}
        ${renderDeliveryProofMarkup(data)}
        ${renderBatchStopsMarkup(data)}
      </div>
      ${renderOrderFinancialBreakdown(financial)}
      ${renderUnavailableItemAlert(data)}
      ${renderCourierIssueAlert(data)}
      ${isCancelledOrder ? '' : `
      <div class="order-actions-row">
        <select id="orderSetStatus-${escapeHtml(orderId)}">
          ${statusChoices.map((item) => `<option value="${escapeHtml(item.key)}" ${item.selected ? 'selected' : ''}>${escapeHtml(item.title)}</option>`).join('')}
        </select>
        <button class="btn primary" data-admin-order-action="set_status" data-order-id="${escapeHtml(orderId)}">تغيير الحالة</button>
        <select id="orderAssignDriver-${escapeHtml(orderId)}">
          <option value="">اختر مندوبًا للتحويل اليدوي</option>
          ${availableCouriers.map((item) => `<option value="${escapeHtml(item.id)}">${escapeHtml(String(item.data?.name || item.id))}</option>`).join('')}
        </select>
        <button class="btn primary" data-admin-order-action="assign_specific" data-order-id="${escapeHtml(orderId)}">تحويل إلى المندوب المحدد</button>
        <button class="btn ghost" data-open-store-from-order="${escapeHtml(String(data.restaurantId || ''))}">معلومات المتجر</button>
        ${assignedDriverId ? `<button class="btn ghost" data-open-courier-from-order="${escapeHtml(assignedDriverId)}">معلومات المندوب</button>` : ''}
        <button class="btn ghost" data-open-client-from-order="${escapeHtml(String(data.clientId || ''))}">معلومات العميل</button>
      </div>
      `}
      <div id="orderContextPanel-${escapeHtml(orderId)}" class="order-context-panel muted">اختر "معلومات المتجر" أو "معلومات المندوب" أو "معلومات العميل" لعرض بطاقة سريعة هنا.</div>
      <section class="order-inline-map-shell is-hidden" id="orderInlineMapShell-${escapeHtml(orderId)}">
        <div class="order-inline-map-head">
          <strong>خريطة الطلب المباشرة</strong>
          <button class="btn ghost" type="button" data-close-order-map="${escapeHtml(orderId)}">إغلاق الخريطة</button>
        </div>
        <div id="orderInlineMap-${escapeHtml(orderId)}" class="order-inline-map-canvas"></div>
        <div id="orderInlineMapMeta-${escapeHtml(orderId)}" class="order-inline-map-meta muted">جاري تجهيز الخريطة...</div>
      </section>
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
        ${renderCourierIssueHistory(data)}
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

  operationsOrderDetails.querySelector('[data-open-order-map]')?.addEventListener('click', async () => {
    await renderInlineOrderMap(orderId, data);
  });

  operationsOrderDetails.querySelector('[data-close-order-map]')?.addEventListener('click', () => {
    const shell = document.getElementById(`orderInlineMapShell-${orderId}`);
    shell?.classList.add('is-hidden');
    orderInlineMapVisible = false;
    orderInlineMapOrderId = '';
    destroyOrderInlineMap();
  });

  if (liveDriverId) {
    activeOrderDriverId = liveDriverId;
    if (!activeOrderDriverCleanupRegistered) {
      unsubscribers.push(() => stopActiveOrderDriverListener());
      activeOrderDriverCleanupRegistered = true;
    }

    activeOrderDriverUnsubscribe = onSnapshot(doc(db, 'drivers', liveDriverId), (driverSnap) => {
      if (activeOrderDriverId !== liveDriverId) return;

      const nameEl = document.getElementById(`orderDriverName-${orderId}`);
      const phoneEl = document.getElementById(`orderDriverPhone-${orderId}`);
      const locationEl = document.getElementById(`orderDriverLocation-${orderId}`);
      const updatedEl = document.getElementById(`orderDriverUpdated-${orderId}`);
      if (!nameEl || !phoneEl || !locationEl || !updatedEl) return;

      if (!driverSnap.exists()) {
        nameEl.textContent = 'تم حذف حساب المندوب';
        phoneEl.textContent = '-';
        locationEl.textContent = 'لا توجد بيانات موقع حالياً';
        updatedEl.textContent = '';
        return;
      }

      const driver = driverSnap.data() || {};
      const point = extractDriverPoint(driver.location)
        || extractDriverPoint(driver.currentLocation)
        || extractDriverPoint(driver.lastLocation)
        || extractDriverPoint({ lat: driver.latitude, lng: driver.longitude });
      const lastUpdate = driver.lastLocationUpdate || driver.lastUpdated || driver.updatedAt || driver.createdAt;

      nameEl.innerHTML = resolveDriverDisplay(liveDriverId, driver.name || driver.displayName || data.assignedDriverName || '');
      phoneEl.textContent = String(driver.phone || data.assignedDriverPhone || data.driverPhone || '-');
      locationEl.textContent = point
        ? `الموقع المباشر: ${point.lat.toFixed(5)}, ${point.lng.toFixed(5)}`
        : 'جاري تحميل الموقع المباشر...';
      updatedEl.textContent = lastUpdate ? `آخر تحديث: ${formatDateTimeLabel(lastUpdate)}` : '';
    });
  }

  longDistanceCouriersOrderId = '';

  const setOrderContextPanel = (title, lines = [], tone = 'info') => {
    const panel = document.getElementById(`orderContextPanel-${orderId}`);
    if (!panel) return;
    panel.classList.remove('muted', 'tone-info', 'tone-success', 'tone-warning');
    panel.classList.add(`tone-${tone}`);
    panel.innerHTML = `
      <div class="order-context-head">${escapeHtml(title)}</div>
      <div class="order-context-lines">
        ${lines.map((line) => `<div>${escapeHtml(String(line || '-'))}</div>`).join('')}
      </div>
    `;
  };

  operationsOrderDetails.querySelector('[data-open-store-from-order]')?.addEventListener('click', async () => {
    const storeId = String(data.restaurantId || '').trim();
    if (!storeId) return;
    const storeData = restaurantsDirectoryCache.get(storeId) || {};
    const storeName = String(data.restaurantName || storeData.name || storeId);
    const storePhone = String(
      data.restaurantPhone
      || data.storePhone
      || storeData.phone
      || storeData.mobile
      || '-'
    );
    const storeAddress = String(data.deliveryAddress || data.address || storeData.address || '-');
    setOrderContextPanel('ملخص المتجر', [
      `الاسم: ${storeName}`,
      `الهاتف: ${storePhone}`,
      `العنوان: ${storeAddress}`,
      `المعرف: ${storeId}`,
    ], 'info');
  });

  operationsOrderDetails.querySelector('[data-open-courier-from-order]')?.addEventListener('click', async () => {
    const driverId = String(data.assignedDriverId || '').trim();
    if (!driverId) return;
    const driverEntry = courierDirectoryCache.find((item) => item.id === driverId);
    const driverData = driverEntry?.data || {};
    const driverName = String(data.assignedDriverName || driverData.name || driverId);
    const driverPhone = String(data.assignedDriverPhone || data.driverPhone || driverData.phone || '-');
    const driverAvailability = driverData.available === true ? 'متاح الآن' : 'غير متاح';
    setOrderContextPanel('ملخص المندوب', [
      `الاسم: ${driverName}`,
      `الهاتف: ${driverPhone}`,
      `الحالة: ${driverAvailability}`,
      `المعرف: ${driverId}`,
    ], driverData.available === true ? 'success' : 'warning');
  });

  operationsOrderDetails.querySelector('[data-open-client-from-order]')?.addEventListener('click', async () => {
    const clientId = String(data.clientId || '').trim();
    if (!clientId) return;
    setOrderContextPanel('ملخص العميل', [
      `الاسم: ${String(data.clientName || 'غير متوفر')}`,
      `الهاتف: ${String(data.clientPhone || 'غير متوفر')}`,
      `المعرف: ${clientId}`,
    ], 'info');
  });

  if (shouldRestoreInlineMap) {
    renderInlineOrderMap(orderId, data).catch(() => {});
  }
}

function renderOperationsOrders() {
  if (!operationsOrdersTable) return;
  const filtered = getFilteredOperationsOrders();
  const activeCount = operationsOrderDocsCache.filter((item) => isActiveOrderStatus(getOrderLifecycleStatus(item.data || {}))).length;
  const completedCount = operationsOrderDocsCache.filter((item) => isDeliveredOrderStatus(getOrderLifecycleStatus(item.data || {}))).length;
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
        <div class="orders-summary-stat"><strong>مكتملة</strong><b>${completedCount}</b></div>
        <div class="orders-summary-stat"><strong>قيد المراجعة</strong><b>${reviewCount}</b></div>
        <div class="orders-summary-stat"><strong>ملغاة</strong><b>${cancelledCount}</b></div>
        <div class="orders-summary-stat"><strong>المعروضة الآن</strong><b>${filtered.length}</b></div>
      </div>
    `;
  }

  const rows = filtered.slice(0, 150).map((item) => {
    const data = item.data || {};
    const bucket = getOperationsOrderBucket(data);
    const isSelected = currentOperationsOrderId && currentOperationsOrderId === item.id;
    const batchStops = getBatchDeliveryStops(data);
    const removedBatchStops = getRemovedBatchDeliveryStops(data);
    const batchSummary = summarizeBatchStops(batchStops, removedBatchStops);
    const sourceLabel = formatOrderSourceLabel(data);
    const orderCode = batchStops.length || removedBatchStops.length
      ? getBatchTripCode(data, formatUnifiedOrderCode(data.orderNumber, data.orderId, item.id))
      : formatUnifiedOrderCode(data.orderNumber, data.orderId, item.id);
    const orderMeta = batchStops.length || removedBatchStops.length
      ? `<br /><span class="muted">${escapeHtml(sourceLabel)}: ${batchSummary.total} حالية، ${batchSummary.delivered} تم، ${batchSummary.exceptions} متعذر، ${batchSummary.removalPending} إزالة</span>`
      : `<br /><span class="muted">${escapeHtml(sourceLabel)}</span>`;
    const bucketLabel = bucket === 'review'
      ? 'مراجعة'
      : bucket === 'cancelled'
        ? 'ملغى'
        : bucket === 'completed'
          ? 'مكتمل'
          : bucket === 'active'
            ? 'نشط'
            : 'أخرى';
    return `<tr class="${isSelected ? 'is-selected-row' : ''}">
      <td><span class="batch-stop-code">${escapeHtml(orderCode)}</span>${orderMeta}</td>
      <td>${resolveClientDisplay(data.clientId, data.clientName)}</td>
      <td>${resolveRestaurantDisplay(data.restaurantId, data.restaurantName)}</td>
      <td>${data.assignedDriverId ? resolveDriverDisplay(data.assignedDriverId, data.assignedDriverName || '') : '<span class="muted">غير معين</span>'}</td>
      <td>${escapeHtml(formatOrderStatusLabel(data.orderStatus || data.status || '-'))}</td>
      <td>${escapeHtml(String(data.paymentStatus || '-'))}</td>
      <td>${escapeHtml(bucketLabel)}<br /><span class="muted">${escapeHtml(formatDateTimeLabel(data.updatedAt || data.createdAt))}</span></td>
      <td><button class="btn ghost" data-operations-order="${escapeHtml(item.id)}">تفاصيل وتحكم</button></td>
    </tr>`;
  });

  preserveViewportPosition(() => {
    setHtml(operationsOrdersTable, table(['الطلب', 'العميل', 'المتجر', 'المندوب', 'الحالة', 'الدفع', 'التصنيف', 'إجراء'], rows));
    operationsOrdersTable.querySelectorAll('[data-operations-order]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const orderId = btn.getAttribute('data-operations-order');
        if (!orderId) return;
        currentOperationsOrderId = orderId;
        renderOperationsOrderDetails(orderId);
        markSelectedOperationsRow(orderId);
      });
    });
    markSelectedOperationsRow(currentOperationsOrderId);
  }, { enabled: String(document.querySelector('.tab-panel.active')?.id || '') === 'orders' });

  const selectedStillVisible = filtered.some((item) => item.id === currentOperationsOrderId);
  if (!selectedStillVisible) {
    currentOperationsOrderId = filtered[0]?.id || '';
  }

  if (currentOperationsOrderId && operationsOrderDetails?.classList.contains('muted')) {
    renderOperationsOrderDetails(currentOperationsOrderId);
    return;
  }

  if (!currentOperationsOrderId && filtered.length && operationsOrderDetails?.classList.contains('muted')) {
    currentOperationsOrderId = filtered[0].id;
    renderOperationsOrderDetails(currentOperationsOrderId);
  }
}

function getCourierActivityTier(item = {}) {
  const monthOrders = Number(item.monthOrders || 0);
  const monthHours = Number(item.monthMs || 0) / (60 * 60 * 1000);
  const todayOrders = Number(item.todayOrders || 0);
  const todayHours = Number(item.todayMs || 0) / (60 * 60 * 1000);
  const activeOrders = Number(item.activeOrders || 0);

  if (monthOrders >= 4 || monthHours >= 20 || todayHours >= 8 || (monthOrders >= 2 && (todayOrders > 0 || activeOrders > 0))) {
    return { key: 'consistent', label: 'ثابت النشاط', className: 'live' };
  }

  if (monthOrders >= 1 || monthHours >= 6 || todayOrders > 0 || todayHours > 0 || activeOrders > 0) {
    return { key: 'average', label: 'متوسط', className: 'soon' };
  }

  return { key: 'inactive', label: 'غير نشط', className: 'idle' };
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
      approvalStatus: normalizeApprovalStatus(entry.data?.approvalStatus, entry.data?.isApproved),
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
    .map((item) => {
      const tier = getCourierActivityTier(item);
      return {
        ...item,
        activityTier: tier.key,
        activityTierLabel: tier.label,
        activityTierClass: tier.className,
      };
    })
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
  const consistentCount = rowsData.filter((item) => item.activityTier === 'consistent').length;
  const averageCount = rowsData.filter((item) => item.activityTier === 'average').length;
  const inactiveCount = rowsData.filter((item) => item.activityTier === 'inactive').length;

  preserveViewportPosition(() => {
    courierActivitySummary.classList.remove('muted');
    courierActivitySummary.innerHTML = `
      <div class="stats">
        <div class="stat"><h4>إجمالي المندوبين</h4><b>${rowsData.length.toLocaleString('ar-EG')}</b></div>
        <div class="stat"><h4>نشطون اليوم</h4><b>${activeTodayCount.toLocaleString('ar-EG')}</b></div>
        <div class="stat"><h4>وقت التوفر اليوم</h4><b>${formatDurationHours(totalTodayMs)}</b></div>
        <div class="stat"><h4>نشاط الشهر</h4><b>${formatDurationHours(totalMonthMs)}</b></div>
      </div>
      <div class="stats" style="margin-top:8px;">
        <div class="stat"><h4>ثابتون</h4><b>${consistentCount.toLocaleString('ar-EG')}</b></div>
        <div class="stat"><h4>متوسطون</h4><b>${averageCount.toLocaleString('ar-EG')}</b></div>
        <div class="stat"><h4>غير نشطين</h4><b>${inactiveCount.toLocaleString('ar-EG')}</b></div>
      </div>
      <div style="margin-top:10px;">يُحسب نشاط الشهر من عدد الطلبات المتوقعة وساعات التقدير المجمعة، مع تصنيف واضح لكل مندوب إلى ثابت النشاط أو متوسط أو غير نشط.</div>
    `;
  }, { enabled: String(document.querySelector('.tab-panel.active')?.id || '') === 'management' && getActiveSubpanelId('management') === 'management-courier-activity' });

  if (!rowsData.length) {
    setHtml(courierActivityTable, '<p class="muted">لا توجد بيانات نشاط كافية لعرض التقرير حاليًا.</p>');
    return;
  }

  const rows = rowsData.slice(0, 150).map((item) => `
    <tr>
      <td>${escapeHtml(item.name)}</td>
      <td>${escapeHtml(item.phone)}</td>
      <td>${item.available ? 'متاح الآن' : 'غير متاح'}</td>
      <td><span class="badge ${escapeHtml(item.activityTierClass)}">${escapeHtml(item.activityTierLabel)}</span></td>
      <td>${formatDurationHours(item.todayMs)}</td>
      <td>${item.todayOrders.toLocaleString('ar-EG')}</td>
      <td>${escapeHtml(`${item.monthOrders.toLocaleString('ar-EG')} طلب • ${formatDurationHours(item.monthMs)}`)}</td>
      <td>${item.activeOrders.toLocaleString('ar-EG')}</td>
      <td>${escapeHtml(formatDateTimeLabel(item.lastSeenMs))}</td>
      <td><button class="btn ghost" data-open-activity-driver="${escapeHtml(item.id)}">فتح المندوب</button></td>
    </tr>
  `);

  preserveViewportPosition(() => {
    setHtml(courierActivityTable, table(['المندوب', 'الهاتف', 'الحالة الحالية', 'التصنيف', 'وقت التوفر اليوم', 'طلبات اليوم', 'نشاط الشهر', 'طلبات نشطة', 'آخر ظهور', 'إجراء'], rows));
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
  }, { enabled: String(document.querySelector('.tab-panel.active')?.id || '') === 'management' && getActiveSubpanelId('management') === 'management-courier-activity' });
}

let deliveryZonesBound = false;

function parseAdminOptionalNumber(value) {
  const raw = String(value || '').trim();
  if (!raw) return null;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : null;
}

function fillDeliveryZoneForm(id, data = {}) {
  if (deliveryZoneId) deliveryZoneId.value = id || '';
  if (deliveryZoneName) deliveryZoneName.value = String(data.name || '');
  if (deliveryZoneClusterId) deliveryZoneClusterId.value = String(data.clusterId || '');
  if (deliveryZoneFee) deliveryZoneFee.value = String(data.fixedDeliveryFee ?? data.deliveryFee ?? '');
  if (deliveryZoneDriverPayout) deliveryZoneDriverPayout.value = String(data.driverPayout ?? data.driverFee ?? '');
  if (deliveryZoneLat) deliveryZoneLat.value = String(data.centerLat ?? data.lat ?? '');
  if (deliveryZoneLng) deliveryZoneLng.value = String(data.centerLng ?? data.lng ?? '');
  if (deliveryZoneRadiusKm) deliveryZoneRadiusKm.value = String(data.radiusKm ?? '');
  if (deliveryZoneActive) deliveryZoneActive.checked = data.active !== false;
}

function bindDeliveryZonesManagement() {
  if (!deliveryZoneForm || deliveryZonesBound) return;
  deliveryZoneForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    const id = String(deliveryZoneId?.value || '').trim();
    const name = String(deliveryZoneName?.value || '').trim();
    const clusterId = String(deliveryZoneClusterId?.value || '').trim();
    const fixedDeliveryFee = Number(deliveryZoneFee?.value || 0);
    const driverPayout = Number(deliveryZoneDriverPayout?.value || 0);
    if (!id || !name || !clusterId || !Number.isFinite(fixedDeliveryFee)) {
      if (deliveryZonesResult) deliveryZonesResult.textContent = 'أدخل معرفًا واسمًا ومجموعة وسعرًا صحيحًا.';
      return;
    }
    try {
      if (deliveryZonesResult) deliveryZonesResult.textContent = 'جارٍ حفظ المنطقة...';
      const centerLat = parseAdminOptionalNumber(deliveryZoneLat?.value);
      const centerLng = parseAdminOptionalNumber(deliveryZoneLng?.value);
      const radiusKm = parseAdminOptionalNumber(deliveryZoneRadiusKm?.value);
      await setDoc(doc(db, 'deliveryZones', id), {
        name,
        clusterId,
        fixedDeliveryFee,
        driverPayout: Number.isFinite(driverPayout) ? driverPayout : 0,
        ...(centerLat != null ? { centerLat } : {}),
        ...(centerLng != null ? { centerLng } : {}),
        ...(radiusKm != null ? { radiusKm } : {}),
        active: deliveryZoneActive?.checked !== false,
        updatedAt: serverTimestamp(),
      }, { merge: true });
      if (deliveryZonesResult) deliveryZonesResult.textContent = 'تم حفظ المنطقة.';
      fillDeliveryZoneForm('', { active: true });
    } catch (err) {
      if (deliveryZonesResult) deliveryZonesResult.textContent = `تعذر حفظ المنطقة: ${err.message || err}`;
    }
  });
  deliveryZonesBound = true;
  renderDeliveryZones();
}

function renderDeliveryZones() {
  if (!deliveryZonesTable) return;
  onSnapshot(query(collection(db, 'deliveryZones'), orderBy('name')), (snap) => {
    const rows = snap.docs.map((d) => {
      const data = d.data() || {};
      const active = data.active !== false;
      return `<tr>
        <td>${escapeHtml(data.name || d.id)}</td>
        <td>${escapeHtml(d.id)}</td>
        <td>${escapeHtml(data.clusterId || '-')}</td>
        <td>${formatAdminMoney(data.fixedDeliveryFee || data.deliveryFee || 0)}</td>
        <td>${formatAdminMoney(data.driverPayout || data.driverFee || 0)}</td>
        <td><span class="badge ${active ? 'closed' : 'open'}">${active ? 'مفعلة' : 'متوقفة'}</span></td>
        <td>
          <button class="btn ghost" data-edit-delivery-zone="${escapeHtml(d.id)}">تعديل</button>
          <button class="btn ghost" data-toggle-delivery-zone="${escapeHtml(d.id)}" data-active="${active ? 'true' : 'false'}">${active ? 'إيقاف' : 'تفعيل'}</button>
        </td>
      </tr>`;
    });
    setHtml(deliveryZonesTable, table(['المنطقة', 'المعرف', 'المجموعة', 'سعر المتجر', 'أجر المندوب', 'الحالة', 'إجراء'], rows));
    deliveryZonesTable.querySelectorAll('[data-edit-delivery-zone]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-edit-delivery-zone');
        const snapDoc = await getDoc(doc(db, 'deliveryZones', id));
        fillDeliveryZoneForm(id, snapDoc.data() || {});
      });
    });
    deliveryZonesTable.querySelectorAll('[data-toggle-delivery-zone]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-toggle-delivery-zone');
        const active = btn.getAttribute('data-active') === 'true';
        await setDoc(doc(db, 'deliveryZones', id), {
          active: !active,
          updatedAt: serverTimestamp(),
        }, { merge: true });
      });
    });
  });
}

function mountManagement() {
  bindDeliveryZonesManagement();
  if (!operationsOrdersBound) {
    orderStatusFilter?.addEventListener('change', () => renderOperationsOrders());
    orderSearchInput?.addEventListener('input', () => renderOperationsOrders());
    operationsOrdersBound = true;
  }
  bindMockOrderForm();
  renderMockOrderCouriersSelect();
  syncMockOrderModeUi();

  // Skeletons while waiting for Firestore data
  if (restaurantsTable) setHtml(restaurantsTable, skeletonTable(['المتجر', 'الرصيد', 'الحالة', 'حالة القائمة', 'إجراء']));
  if (couriersTable) setHtml(couriersTable, skeletonTable(['المندوب', 'الرصيد', 'الحالة', 'المركبة', 'إجراء']));

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
          <td>${formatAdminMoney(data.walletPendingBalance)}</td>
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
      setHtml(restaurantsTable, table(['المتجر', 'الرصيد', 'الحالة', 'حالة القائمة', 'إجراء'], rows));
      restaurantsTable.querySelectorAll('[data-view-store]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const id = btn.getAttribute('data-view-store');
          await loadStoreDetails(id);
        });
      });
      restaurantsTable.querySelectorAll('[data-toggle-store]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          await withBtnLoading(btn, async () => {
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
      });
      restaurantsTable.querySelectorAll('[data-direct-menu-approve]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          await withBtnLoading(btn, async () => {
            const id = btn.getAttribute('data-direct-menu-approve');
            if (!id) return;
            await setMenuApprovalDirect({ restaurantId: id, approved: true });
          });
        });
      });
      restaurantsTable.querySelectorAll('[data-direct-menu-reject]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          await withBtnLoading(btn, async () => {
            const id = btn.getAttribute('data-direct-menu-reject');
            if (!id) return;
            await setMenuApprovalDirect({ restaurantId: id, approved: false });
          });
        });
      });
    })
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'drivers'), (snap) => {
      courierDirectoryDocsCache = snap.docs
        .map((d) => ({
          id: d.id,
          data: d.data() || {},
          updatedAtMs: d.data()?.updatedAt?.toMillis?.() || d.data()?.createdAt?.toMillis?.() || 0,
        }))
        .sort((a, b) => b.updatedAtMs - a.updatedAtMs);
      courierDirectoryCache = courierDirectoryDocsCache.map((entry) => ({ id: entry.id, data: entry.data }));
      renderMockOrderCouriersSelect();

      const prevWrap = couriersTable?.querySelector('.table-wrap');
      const prevScrollTop = Number(prevWrap?.scrollTop || 0);
      const prevScrollable = Math.max(1, Number((prevWrap?.scrollHeight || 0) - (prevWrap?.clientHeight || 0)));
      const prevScrollRatio = prevScrollTop / prevScrollable;

      const rows = courierDirectoryDocsCache.map(({ id, data }) => {
        const status = formatApprovalStatusLabel(data.approvalStatus, data.isApproved);
        const available = data.available === true;
        const longDistance = available && data.acceptsLongDistance === true;
        const displayName = String(data.name || '').trim() || id;
        const phone = String(data.phone || '').trim();
        const email = String(data.email || '').trim();
        const searchText = [displayName, phone, email, id, status, available ? 'متاح' : 'غير متاح']
          .join(' ')
          .toLowerCase();
        return `<tr>
          <td>
            <span class="entity-cell">
              <span class="entity-cell-name">${escapeHtml(displayName)}</span>
              <span class="entity-cell-id">${escapeHtml(phone || '-')} • ${escapeHtml(id)}</span>
            </span>
          </td>
          <td>${formatAdminMoney(data.walletPendingBalance)}</td>
          <td>${status}</td>
          <td>${available ? 'متاح' : 'غير متاح'}</td>
          <td>${longDistance ? 'نعم' : '-'}</td>
          <td>
            <button class="btn ghost" data-view-driver="${id}" data-courier-search="${escapeHtml(searchText)}">تفاصيل</button>
          </td>
        </tr>`;
      });
      preserveViewportPosition(() => {
        setHtml(couriersTable, table(['المندوب', 'الرصيد', 'حالة الموافقة', 'التوفر', 'مسافات بعيدة', 'إجراء'], rows));
      }, { enabled: String(document.querySelector('.tab-panel.active')?.id || '') === 'management' && getActiveSubpanelId('management') === 'management-couriers' });

      const nextWrap = couriersTable?.querySelector('.table-wrap');
      if (nextWrap) {
        requestAnimationFrame(() => {
          const nextScrollable = Math.max(1, Number(nextWrap.scrollHeight - nextWrap.clientHeight));
          nextWrap.scrollTop = Math.round(nextScrollable * prevScrollRatio);
        });
      }

      couriersTable.querySelectorAll('[data-view-driver]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const id = btn.getAttribute('data-view-driver');
          await loadCourierDetails(id);
        });
      });

      bindCourierSearchInput();
      scheduleCourierSearchFilter();

      scheduleCourierActivityReportRender();
      scheduleOperationsOrdersRender();
    })
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'orders'), (snap) => {
      operationsOrderDocsCache = snap.docs.map((d) => ({
        id: d.id,
        data: d.data() || {},
        createdAtMillis: d.data()?.createdAt?.toMillis?.() || d.data()?.updatedAt?.toMillis?.() || 0,
      }));
      scheduleCourierActivityReportRender();
      scheduleOperationsOrdersRender();
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
      scheduleOperationsOrdersRender();

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
function applyCourierSearchFilter() {
  const courierSearchInput = document.getElementById('courierSearchInput');
  const q = String(courierSearchInput?.value || '').trim().toLowerCase();
  const countEl = document.getElementById('courierSearchCount');
  const rows = couriersTable?.querySelectorAll('tbody tr') || [];
  let visible = 0;

  rows.forEach((row) => {
    const searchMeta = String(row.querySelector('[data-courier-search]')?.getAttribute('data-courier-search') || '');
    const text = `${searchMeta} ${(row.textContent || '').toLowerCase()}`;
    const match = !q || text.includes(q);
    row.style.display = match ? '' : 'none';
    if (match) visible += 1;
  });

  if (countEl) {
    countEl.textContent = q ? `${visible} من ${rows.length}` : `${rows.length} مندوب`;
  }
}

function scheduleCourierSearchFilter() {
  if (courierSearchFilterFrame) cancelAnimationFrame(courierSearchFilterFrame);
  courierSearchFilterFrame = requestAnimationFrame(() => {
    courierSearchFilterFrame = 0;
    applyCourierSearchFilter();
  });
}

function scheduleOperationsOrdersRender() {
  if (managementRenderTimers.operations) return;
  managementRenderTimers.operations = setTimeout(() => {
    managementRenderTimers.operations = null;
    renderOperationsOrders();
  }, 80);
}

function scheduleCourierActivityReportRender() {
  if (managementRenderTimers.courierActivity) return;
  managementRenderTimers.courierActivity = setTimeout(() => {
    managementRenderTimers.courierActivity = null;
    renderCourierActivityReport();
  }, 120);
}

function bindCourierSearchInput() {
  const courierSearchInput = document.getElementById('courierSearchInput');
  if (!courierSearchInput || courierSearchInput.dataset.bound) return;
  courierSearchInput.dataset.bound = '1';
  courierSearchInput.addEventListener('input', () => {
    scheduleCourierSearchFilter();
  });
}

async function loadCourierDetails(driverId) {
  if (!courierDetailsPanel) return;
  stopActiveOrderDriverListener();
  courierDetailsPanel.innerHTML = '<span class="muted">جاري تحميل تفاصيل المندوب...</span>';

  try {
    const normalizedDriverId = String(driverId || '').trim();
    if (!normalizedDriverId) {
      courierDetailsPanel.innerHTML = '<span class="muted">معرف المندوب غير متاح.</span>';
      return;
    }

    let driverRef = doc(db, 'drivers', normalizedDriverId);
    let driverSnap = await getDoc(driverRef);
    if (!driverSnap.exists()) {
      const fallbackSnap = await safeGetDocs(query(collection(db, 'drivers'), where('ownerUid', '==', normalizedDriverId)));
      if (fallbackSnap.docs.length) {
        driverSnap = fallbackSnap.docs[0];
        driverRef = driverSnap.ref;
      } else {
        const uidFallbackSnap = await safeGetDocs(query(collection(db, 'drivers'), where('uid', '==', normalizedDriverId)));
        if (uidFallbackSnap.docs.length) {
          driverSnap = uidFallbackSnap.docs[0];
          driverRef = driverSnap.ref;
        }
      }
    }

    const driverDomId = driverSnap.exists() ? driverSnap.id : normalizedDriverId;
    const ordersSnap = await safeGetDocs(query(collection(db, 'orders'), where('assignedDriverId', '==', driverDomId)));
    const orders = ordersSnap.docs.map((d) => d.data() || {});
    const activeOrderStatuses = new Set(['courier_offer_pending', 'courier_assigned', 'pickup_ready', 'picked_up', 'arrived_to_client']);
    const activeOrdersCount = orders.filter((o) => activeOrderStatuses.has(String(o.orderStatus || o.status || ''))).length;
    const renderCourierPanel = (driver) => {
      const todayAvailabilityMs = getCourierAvailableTodayMs(driver);
      const livePoint = extractDriverPoint(driver.location)
        || extractDriverPoint(driver.currentLocation)
        || extractDriverPoint(driver.lastLocation)
        || extractDriverPoint({ lat: driver.latitude, lng: driver.longitude });
      const liveLocationText = livePoint
        ? `${livePoint.lat.toFixed(5)}, ${livePoint.lng.toFixed(5)}`
        : 'الموقع غير متاح';
      const liveUpdatedText = driver.lastLocationUpdate || driver.lastUpdated || driver.updatedAt || driver.createdAt
        ? formatDateTimeLabel(driver.lastLocationUpdate || driver.lastUpdated || driver.updatedAt || driver.createdAt)
        : '-';
      const idImage = driver.idImageUrl
        ? `<div class="entity-media-card"><a class="btn ghost" href="${escapeHtml(driver.idImageUrl)}" target="_blank" rel="noopener">فتح صورة إثبات الشخصية</a></div>`
        : '<div class="entity-media-card muted">لا توجد صورة هوية/رخصة</div>';
      const courierProfileImage = driver.profileImage
        ? `<div class="entity-media-card"><a class="btn ghost" href="${escapeHtml(driver.profileImage)}" target="_blank" rel="noopener">فتح شعار/صورة المندوب</a></div>`
        : '<div class="entity-media-card muted">لا يوجد شعار للمندوب</div>';
      const workLocalityName = driver.workLocalityName || driver.serviceArea?.localityName || '';
      const workAreaName = driver.workAreaName || driver.serviceArea?.areaName || '';
      const workAreaLabel = driver.workAreaLabel || driver.serviceArea?.label || driver.region || '';

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
            { label: 'المعرف', value: driverDomId },
            { label: 'الاسم', value: driver.name || '-' },
            { label: 'البريد', value: driver.email || '-' },
            { label: 'الهاتف', value: driver.phone || '-' },
            { label: 'نوع المركبة', value: driver.vehicleType || '-' },
            { label: 'رقم اللوحة', value: driver.vehiclePlate || '-' },
            { label: 'رقم إثبات الشخصية', value: driver.nationalIdNumber || '-' },
            { label: 'محلية العمل', value: workLocalityName || '-' },
            { label: 'منطقة العمل', value: workAreaName || '-' },
            { label: 'نطاق العمل', value: workAreaLabel || '-' },
            { label: 'الموافقة', value: formatApprovalStatusLabel(driver.approvalStatus, driver.isApproved) },
            { label: 'التوفر', value: driver.available === true ? 'متاح' : 'غير متاح', className: driver.available === true ? 'entity-fact-highlight' : '' },
            { label: 'المسافات البعيدة', value: driver.acceptsLongDistance === true ? 'مفعلة' : 'غير مفعلة', className: driver.acceptsLongDistance === true ? 'entity-fact-highlight' : '' },
          ]), { eyebrow: 'الملف' })}
          ${buildEntitySection('الموقع الحي', `
            <div class="entity-facts-grid">
              <div class="entity-fact">
                <span>الموقع الحالي</span>
                <strong id="driverLiveLocation-${driverDomId}">${liveLocationText}</strong>
              </div>
              <div class="entity-fact">
                <span>آخر تحديث</span>
                <strong id="driverLiveUpdated-${driverDomId}">${liveUpdatedText}</strong>
              </div>
            </div>
          `, { eyebrow: 'التتبع' })}
          ${buildWalletSummarySection('محفظة المندوب', driver)}
          ${buildBankAccountsDetailsMarkup(driver)}
          ${buildEntitySection('الأداء الحالي', buildEntityFactsGrid([
            { label: 'إجمالي الطلبات', value: orders.length },
            { label: 'الطلبات النشطة', value: activeOrdersCount },
            { label: 'وقت التوفر اليوم', value: formatDurationHours(todayAvailabilityMs), className: 'entity-fact-highlight' },
          ]), { eyebrow: 'النشاط' })}
          ${buildEntitySection('إثبات الشخصية والمرفقات', `${idImage}${courierProfileImage}<div class="entity-actions"><button class="btn ghost" id="driverImageChange-${driverDomId}">تعديل صورة إثبات الشخصية</button><button class="btn ghost" id="driverProfileImageChange-${driverDomId}">رفع شعار/صورة المندوب</button><button class="btn ghost" id="driverProfileImageDownload-${driverDomId}">تنزيل شعار/صورة المندوب</button><button class="btn ghost" id="driverToggleAvailability-${driverDomId}">${driver.available === true ? 'إيقاف التوفر' : 'تفعيل التوفر'}</button><button class="btn ghost" id="driverApprove-${driverDomId}">قبول</button><button class="btn danger" id="driverReject-${driverDomId}">رفض</button><button class="btn danger" id="driverDelete-${driverDomId}">حذف الحساب</button></div>`, { eyebrow: 'الإجراءات' })}
          ${buildEntitySection('تعديل بيانات المندوب', `
            <div class="entity-form-grid">
              <label>الاسم<input id="driverName-${driverDomId}" type="text" value="${escapeHtml(driver.name || '')}" /></label>
              <label>الهاتف<input id="driverPhone-${driverDomId}" type="text" value="${escapeHtml(driver.phone || '')}" /></label>
              <label>البريد الإلكتروني<input id="driverEmail-${driverDomId}" type="email" value="${escapeHtml(driver.email || '')}" /></label>
              <label>نوع المركبة<input id="driverVehicleType-${driverDomId}" type="text" value="${escapeHtml(driver.vehicleType || '')}" /></label>
              <label>رقم اللوحة<input id="driverVehiclePlate-${driverDomId}" type="text" value="${escapeHtml(driver.vehiclePlate || '')}" /></label>
              <label>رقم إثبات الشخصية<input id="driverNationalId-${driverDomId}" type="text" value="${escapeHtml(driver.nationalIdNumber || '')}" /></label>
              <label>محلية العمل<input id="driverWorkLocalityName-${driverDomId}" type="text" value="${escapeHtml(workLocalityName)}" /></label>
              <label>منطقة العمل<input id="driverWorkAreaName-${driverDomId}" type="text" value="${escapeHtml(workAreaName)}" /></label>
              <label>نطاق العمل<input id="driverRegion-${driverDomId}" type="text" value="${escapeHtml(workAreaLabel)}" /></label>
              <label>رابط صورة إثبات الشخصية<input id="driverIdImageUrl-${driverDomId}" type="text" value="${escapeHtml(driver.idImageUrl || '')}" /></label>
              <label>رابط شعار/صورة المندوب<input id="driverProfileImage-${driverDomId}" type="text" value="${escapeHtml(driver.profileImage || '')}" /></label>
            </div>
            <div class="entity-actions">
              <button class="btn primary" id="driverSave-${driverDomId}">حفظ التعديلات</button>
            </div>
          `, { eyebrow: 'التحرير' })}
        </div>
      `;

      if (activeOrderDriverId !== driverDomId) return;
      const locationEl = document.getElementById(`driverLiveLocation-${driverDomId}`);
      const updatedEl = document.getElementById(`driverLiveUpdated-${driverDomId}`);
      if (locationEl) locationEl.textContent = liveLocationText;
      if (updatedEl) updatedEl.textContent = liveUpdatedText;
    };

    let driver = driverSnap.data() || {};
    renderCourierPanel(driver);

    activeOrderDriverId = driverDomId;
    if (!activeOrderDriverCleanupRegistered) {
      unsubscribers.push(() => stopActiveOrderDriverListener());
      activeOrderDriverCleanupRegistered = true;
    }
    activeOrderDriverUnsubscribe = onSnapshot(driverRef, (liveSnap) => {
      if (activeOrderDriverId !== driverDomId) return;
      if (!liveSnap.exists()) {
        courierDetailsPanel.innerHTML = '<span class="muted">تم حذف حساب المندوب.</span>';
        return;
      }
      const liveDriver = liveSnap.data() || {};
      const livePoint = extractDriverPoint(liveDriver.location)
        || extractDriverPoint(liveDriver.currentLocation)
        || extractDriverPoint(liveDriver.lastLocation)
        || extractDriverPoint({ lat: liveDriver.latitude, lng: liveDriver.longitude });
      const locationEl = document.getElementById(`driverLiveLocation-${driverDomId}`);
      const updatedEl = document.getElementById(`driverLiveUpdated-${driverDomId}`);
      const availabilityPill = courierDetailsPanel.querySelector('.entity-state-pill');
      if (availabilityPill) {
        availabilityPill.textContent = liveDriver.available === true ? 'متاح الآن' : 'غير متاح';
        availabilityPill.classList.toggle('live', liveDriver.available === true);
        availabilityPill.classList.toggle('idle', liveDriver.available !== true);
      }
      if (locationEl) {
        locationEl.textContent = livePoint
          ? `${livePoint.lat.toFixed(5)}, ${livePoint.lng.toFixed(5)}`
          : 'الموقع غير متاح';
      }
      if (updatedEl) {
        const liveUpdated = liveDriver.lastLocationUpdate || liveDriver.lastUpdated || liveDriver.updatedAt || liveDriver.createdAt;
        updatedEl.textContent = liveUpdated ? formatDateTimeLabel(liveUpdated) : '-';
      }
    });

    document.getElementById(`driverSave-${driverDomId}`)?.addEventListener('click', async () => {
      try {
        await updateManagedUserProfile({
          role: 'courier',
          uid: driverDomId,
          fields: {
            name: (document.getElementById(`driverName-${driverDomId}`)?.value || '').trim(),
            phone: (document.getElementById(`driverPhone-${driverDomId}`)?.value || '').trim(),
            email: (document.getElementById(`driverEmail-${driverDomId}`)?.value || '').trim(),
            vehicleType: (document.getElementById(`driverVehicleType-${driverDomId}`)?.value || '').trim(),
            vehiclePlate: (document.getElementById(`driverVehiclePlate-${driverDomId}`)?.value || '').trim(),
            nationalIdNumber: (document.getElementById(`driverNationalId-${driverDomId}`)?.value || '').trim(),
            stateId: 'khartoum',
            stateName: 'ولاية الخرطوم',
            workStateId: 'khartoum',
            workStateName: 'ولاية الخرطوم',
            city: (document.getElementById(`driverWorkLocalityName-${driverDomId}`)?.value || '').trim(),
            workLocalityName: (document.getElementById(`driverWorkLocalityName-${driverDomId}`)?.value || '').trim(),
            workAreaName: (document.getElementById(`driverWorkAreaName-${driverDomId}`)?.value || '').trim(),
            workAreaLabel: (document.getElementById(`driverRegion-${driverDomId}`)?.value || '').trim(),
            region: (document.getElementById(`driverRegion-${driverDomId}`)?.value || '').trim(),
            idImageUrl: (document.getElementById(`driverIdImageUrl-${driverDomId}`)?.value || '').trim(),
            profileImage: (document.getElementById(`driverProfileImage-${driverDomId}`)?.value || '').trim(),
          },
        });
        alert('تم حفظ بيانات المندوب بنجاح');
        await loadCourierDetails(driverDomId);
      } catch (err) {
        alert(`تعذر حفظ البيانات: ${err.message || err}`);
      }
    });

    document.getElementById(`driverToggleAvailability-${driverDomId}`)?.addEventListener('click', async () => {
      try {
        await updateDoc(doc(db, 'drivers', driverDomId), await buildDriverAvailabilityPatch(driverDomId, driver.available !== true));
        await loadCourierDetails(driverDomId);
      } catch (err) {
        alert(`تعذر تحديث التوفر: ${err.message || err}`);
      }
    });

    document.getElementById(`driverApprove-${driverDomId}`)?.addEventListener('click', async () => {
      try {
        await updateDoc(doc(db, 'drivers', driverDomId), {
          approvalStatus: 'approved',
          isApproved: true,
          updatedAt: serverTimestamp(),
        });
        await loadCourierDetails(driverDomId);
      } catch (err) {
        alert(`تعذر قبول المندوب: ${err.message || err}`);
      }
    });

    document.getElementById(`driverReject-${driverDomId}`)?.addEventListener('click', async () => {
      try {
        await updateDoc(doc(db, 'drivers', driverDomId), {
          ...(await buildDriverAvailabilityPatch(driverDomId, false)),
          approvalStatus: 'rejected',
          isApproved: false,
          updatedAt: serverTimestamp(),
        });
        await loadCourierDetails(driverDomId);
      } catch (err) {
        alert(`تعذر رفض المندوب: ${err.message || err}`);
      }
    });

    document.getElementById(`driverDelete-${driverDomId}`)?.addEventListener('click', async () => {
      await handleManagedUserDeletion({
        role: 'courier',
        uid: driverDomId,
        displayName: driver.name || driverDomId,
      });
    });

    document.getElementById(`driverImageChange-${driverDomId}`)?.addEventListener('click', async () => {
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
        await updateDoc(doc(db, 'drivers', driverDomId), {
          idImageUrl: uploaded,
          updatedAt: serverTimestamp(),
        });
        await loadCourierDetails(driverDomId);
      } catch (err) {
        alert(`تعذر تحديث الصورة: ${err.message || err}`);
      }
    });

    document.getElementById(`driverProfileImageChange-${driverDomId}`)?.addEventListener('click', async () => {
      const pickedFile = await pickSingleImageFile();
      if (!pickedFile) {
        alert('لم يتم اختيار صورة');
        return;
      }
      const uploaded = await uploadImageToCloudinary(pickedFile, pickedFile.name || `courier-profile-${driverDomId}.jpg`);
      if (!uploaded) {
        alert('تعذر رفع شعار/صورة المندوب');
        return;
      }

      try {
        await updateManagedUserProfile({
          role: 'courier',
          uid: driverDomId,
          fields: {
            profileImage: uploaded,
          },
        });
        await loadCourierDetails(driverDomId);
      } catch (err) {
        alert(`تعذر تحديث شعار المندوب: ${err.message || err}`);
      }
    });

    document.getElementById(`driverProfileImageDownload-${driverDomId}`)?.addEventListener('click', async () => {
      const value = (document.getElementById(`driverProfileImage-${driverDomId}`)?.value || '').trim();
      if (!value) {
        alert('لا يوجد شعار/صورة للمندوب لتنزيلها.');
        return;
      }
      try {
        await downloadImageToDevice(value, `courier-profile-${driverDomId}`);
      } catch (err) {
        alert(`تعذر تنزيل الصورة: ${err.message || err}`);
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
    const storeLat = Number(
      store.latitude ?? store.lat ?? store.restaurantLat ?? store.location?.latitude ?? store.location?._latitude
    );
    const storeLng = Number(
      store.longitude ?? store.lng ?? store.restaurantLng ?? store.location?.longitude ?? store.location?._longitude
    );
    const currentEmail = String(auth.currentUser?.email || '').toLowerCase().trim();
    const canHardDeleteStore = hasAdminPermission('admins') && (
      guaranteedAdminEmails.has(currentEmail)
      || currentAdminProfile?.canDeleteRestaurants === true
    );
    const [ordersSnap, addressesSnap, menuDocsSnap, fullMenuDocsSnap] = await Promise.all([
      safeGetDocs(query(collection(db, 'orders'), where('restaurantId', '==', storeId))),
      safeGetDocs(collection(db, 'restaurants', storeId, 'addresses')),
      safeGetDocs(collection(db, 'restaurants', storeId, 'menu')),
      safeGetDocs(collection(db, 'restaurants', storeId, 'full_menu')),
    ]);

    const orders = ordersSnap.docs.map((d) => d.data() || {});
    const activeOrderStatuses = new Set(['store_pending', 'courier_searching', 'courier_offer_pending', 'courier_assigned', 'pickup_ready', 'picked_up', 'arrived_to_client']);
    const activeOrdersCount = orders.filter((o) => activeOrderStatuses.has(String(o.orderStatus || o.status || ''))).length;

    const managerName = String(
      store.contactPersonName
      || store.responsibleName
      || store.managerName
      || ''
    ).trim();
    const managerPhone = String(
      store.contactPersonPhone
      || store.responsiblePhone
      || store.managerPhone
      || ''
    ).trim();

    const image = store.commercialRecordImageUrl
      ? `<div style="margin-top:8px"><a class="btn ghost" href="${escapeHtml(store.commercialRecordImageUrl)}" target="_blank" rel="noopener">فتح صورة السجل</a></div>`
      : '';
    const storeLogoMedia = store.logoImageUrl
      ? `<div style="margin-top:8px"><a class="btn ghost" href="${escapeHtml(store.logoImageUrl)}" target="_blank" rel="noopener">فتح شعار المتجر الأصلي</a></div>`
      : '<div class="entity-media-card muted">لا يوجد شعار مرفوع للمتجر</div>';

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
          { label: 'اسم المسؤول عن المطعم', value: managerName || '-' },
          { label: 'هاتف المسؤول عن المطعم', value: managerPhone || '-' },
          { label: 'صاحب الحساب', value: store.ownerUid || '-' },
          { label: 'الحالة', value: formatApprovalStatusLabel(store.approvalStatus, store.isApproved) },
          { label: 'السجل التجاري', value: store.commercialRecordNumber || '-' },
          { label: 'القبول التلقائي', value: store.autoAcceptOrders === true ? 'مفعل' : 'غير مفعل' },
          { label: 'حالة الظهور', value: storeOpenState, className: store.temporarilyClosed === true ? '' : 'entity-fact-highlight' },
          { label: 'العنوان', value: store.address || '-' },
          { label: 'خصم التوصيل/المتجر', value: String(store.deliveryDiscountPercentage ?? '-') },
        ]), { eyebrow: 'الملف' })}
        ${buildWalletSummarySection('محفظة المطعم', store)}
        ${buildBankAccountsDetailsMarkup(store)}
        ${buildEntitySection('مؤشرات المتجر', buildEntityFactsGrid([
          { label: 'إجمالي الطلبات', value: orders.length },
          { label: 'الطلبات النشطة', value: activeOrdersCount },
          { label: 'عدد العناوين', value: addressesSnap.docs.length },
          { label: 'أقسام المنيو', value: menuDocsSnap.docs.length },
          { label: 'عناصر full_menu', value: fullMenuDocsSnap.docs.length, className: 'entity-fact-highlight' },
        ]), { eyebrow: 'النشاط' })}
        ${buildEntitySection('الوثائق والميديا', `${image || '<div class="entity-media-card muted">لا توجد صورة سجل تجاري</div>'}${storeLogoMedia}`, { eyebrow: 'المرفقات' })}
        ${buildEntitySection('تعديل بيانات المتجر', `
          <div class="entity-form-grid">
            <label>الاسم<input id="storeName-${storeId}" type="text" value="${escapeHtml(store.name || '')}" /></label>
            <label>الهاتف<input id="storePhone-${storeId}" type="text" value="${escapeHtml(store.phone || '')}" /></label>
            <label>اسم المسؤول عن المطعم<input id="storeManagerName-${storeId}" type="text" value="${escapeHtml(managerName)}" /></label>
            <label>هاتف المسؤول عن المطعم<input id="storeManagerPhone-${storeId}" type="text" value="${escapeHtml(managerPhone)}" /></label>
            <label>البريد الإلكتروني<input id="storeEmail-${storeId}" type="email" value="${escapeHtml(store.email || '')}" /></label>
            <label>السجل التجاري<input id="storeCommercialRecord-${storeId}" type="text" value="${escapeHtml(store.commercialRecordNumber || '')}" /></label>
            <label>العنوان<input id="storeAddress-${storeId}" type="text" value="${escapeHtml(store.address || '')}" /></label>
            <label>خط العرض (Latitude)<input id="storeLatitude-${storeId}" type="number" step="0.000001" value="${Number.isFinite(storeLat) ? escapeHtml(String(storeLat)) : ''}" /></label>
            <label>خط الطول (Longitude)<input id="storeLongitude-${storeId}" type="number" step="0.000001" value="${Number.isFinite(storeLng) ? escapeHtml(String(storeLng)) : ''}" /></label>
            <label>نسبة الخصم<input id="storeDiscountPct-${storeId}" type="number" step="0.01" value="${escapeHtml(String(store.deliveryDiscountPercentage ?? ''))}" /></label>
            <label>رابط صورة الغلاف<input id="storeCoverImageUrl-${storeId}" type="text" value="${escapeHtml(store.coverImageUrl || '')}" /></label>
            <label>رابط الشعار<input id="storeLogoImageUrl-${storeId}" type="text" value="${escapeHtml(store.logoImageUrl || '')}" /></label>
            <label>وقت تجهيز المطعم المعتاد<input id="storeDeliveryTime-${storeId}" type="text" placeholder="مثال: 20-30 دقيقة" value="${escapeHtml(store.deliveryTime || '')}" /></label>
          </div>
          <div class="entity-actions">
            <button class="btn ghost" id="storeGeocodeAddress-${storeId}">جلب الموقع من Google حسب العنوان</button>
            <button class="btn ghost" id="storePickLocationMap-${storeId}">تحديد الموقع من الخريطة</button>
            <button class="btn ghost" id="storeUploadCover-${storeId}">رفع صورة غلاف</button>
            <button class="btn ghost" id="storeUploadLogo-${storeId}">رفع شعار</button>
            <button class="btn ghost" id="storeDownloadLogo-${storeId}">تنزيل شعار المتجر</button>
            <button class="btn primary" id="storeSaveProfile-${storeId}">حفظ بيانات المتجر</button>
          </div>
          <div id="storeMapPickerWrap-${storeId}" class="entity-media-card" style="display:none; margin-top:10px;">
            <p class="muted" style="margin-bottom:8px;">انقر على الخريطة لتحديد موقع المطعم، وسيتم تعبئة الإحداثيات تلقائيًا.</p>
            <div id="storeMapPicker-${storeId}" style="height:300px; border-radius:12px; overflow:hidden;"></div>
            <div class="entity-actions" style="margin-top:10px;">
              <button class="btn ghost" id="storeMapPickerClose-${storeId}">إغلاق الخريطة</button>
            </div>
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
        ${canHardDeleteStore ? buildEntitySection('إجراء شديد الحساسية', `
          <p class="entity-inline-note" style="color:#b91c1c; font-weight:700;">
            الحذف النهائي يمسح المطعم وبياناته المرتبطة من قاعدة البيانات ولا يمكن التراجع عنه.
          </p>
          <p class="entity-inline-note">لن يتم الحذف إذا كانت هناك طلبات نشطة للمطعم.</p>
          <div class="entity-actions">
            <button class="btn danger" id="storeHardDelete-${storeId}">حذف المطعم نهائيًا</button>
          </div>
        `, { eyebrow: 'خطر' }) : ''}
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

    document.getElementById(`storeDownloadLogo-${storeId}`)?.addEventListener('click', async () => {
      const value = (document.getElementById(`storeLogoImageUrl-${storeId}`)?.value || '').trim();
      if (!value) {
        alert('لا يوجد شعار لتنزيله حالياً.');
        return;
      }
      try {
        await downloadImageToDevice(value, `store-logo-${storeId}`);
      } catch (err) {
        alert(`تعذر تنزيل الشعار: ${err.message || err}`);
      }
    });

    document.getElementById(`storeGeocodeAddress-${storeId}`)?.addEventListener('click', async () => {
      const btn = document.getElementById(`storeGeocodeAddress-${storeId}`);
      const addressInput = document.getElementById(`storeAddress-${storeId}`);
      const latitudeInput = document.getElementById(`storeLatitude-${storeId}`);
      const longitudeInput = document.getElementById(`storeLongitude-${storeId}`);
      const address = String(addressInput?.value || '').trim();

      if (!address) {
        alert('أدخل عنوان المتجر أولًا ثم جرّب الجلب من Google.');
        return;
      }

      try {
        await withBtnLoading(btn, async () => {
          const response = await adminGeocodeRestaurantAddress({
            restaurantId: storeId,
            address,
          });
          const data = response?.data || {};
          if (addressInput && data.address) {
            addressInput.value = String(data.address || '');
          }
          if (latitudeInput && Number.isFinite(Number(data.latitude))) {
            latitudeInput.value = String(data.latitude);
          }
          if (longitudeInput && Number.isFinite(Number(data.longitude))) {
            longitudeInput.value = String(data.longitude);
          }
        });
        alert('تم جلب الموقع من Google وتحديث بيانات المتجر.');
      } catch (err) {
        alert(`تعذر جلب الموقع من Google: ${err.message || err}`);
      }
    });

    let storePickerMap = null;
    let storePickerMarker = null;
    const mapPickerWrap = document.getElementById(`storeMapPickerWrap-${storeId}`);
    const latitudeInput = document.getElementById(`storeLatitude-${storeId}`);
    const longitudeInput = document.getElementById(`storeLongitude-${storeId}`);

    const setPickedStorePoint = (lat, lng) => {
      if (latitudeInput) latitudeInput.value = String(lat);
      if (longitudeInput) longitudeInput.value = String(lng);

      if (storePickerMap && window.L) {
        if (!storePickerMarker) {
          storePickerMarker = window.L.marker([lat, lng]).addTo(storePickerMap);
        } else {
          storePickerMarker.setLatLng([lat, lng]);
        }
      }
    };

    const initStoreMapPicker = async () => {
      try {
        await ensureLeaflet();
      } catch (_) {
        alert('تعذر تحميل الخريطة حالياً. حاول مرة أخرى.');
        return;
      }

      if (!window.L) {
        alert('تعذر تحميل الخريطة حالياً. حاول مرة أخرى.');
        return;
      }

      const startLat = Number.parseFloat(latitudeInput?.value || '') || (Number.isFinite(storeLat) ? storeLat : 15.5007);
      const startLng = Number.parseFloat(longitudeInput?.value || '') || (Number.isFinite(storeLng) ? storeLng : 32.5599);

      if (!storePickerMap) {
        storePickerMap = window.L.map(`storeMapPicker-${storeId}`, {
          zoomControl: true,
          attributionControl: true,
        }).setView([startLat, startLng], 13);

        window.L.tileLayer(MAP_STYLE_PRESETS.voyager.url, {
          attribution: MAP_STYLE_PRESETS.voyager.attribution,
          subdomains: MAP_STYLE_PRESETS.voyager.subdomains,
          maxZoom: 20,
        }).addTo(storePickerMap);

        storePickerMap.on('click', (event) => {
          const lat = Number(event.latlng?.lat);
          const lng = Number(event.latlng?.lng);
          if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
          setPickedStorePoint(lat, lng);
        });
      } else {
        storePickerMap.setView([startLat, startLng], Math.max(storePickerMap.getZoom(), 13));
      }

      setPickedStorePoint(startLat, startLng);
      setTimeout(() => storePickerMap?.invalidateSize(), 120);
    };

    document.getElementById(`storePickLocationMap-${storeId}`)?.addEventListener('click', async () => {
      if (mapPickerWrap) {
        mapPickerWrap.style.display = 'block';
      }
      await initStoreMapPicker();
      mapPickerWrap?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    });

    document.getElementById(`storeMapPickerClose-${storeId}`)?.addEventListener('click', () => {
      if (mapPickerWrap) {
        mapPickerWrap.style.display = 'none';
      }
    });

    document.getElementById(`storeSaveProfile-${storeId}`)?.addEventListener('click', async () => {
      try {
        const latitudeRaw = String(latitudeInput?.value || '').trim().replace(',', '.');
        const longitudeRaw = String(longitudeInput?.value || '').trim().replace(',', '.');
        const hasLat = latitudeRaw !== '';
        const hasLng = longitudeRaw !== '';
        const latitude = hasLat ? Number(latitudeRaw) : null;
        const longitude = hasLng ? Number(longitudeRaw) : null;

        if ((hasLat && !hasLng) || (!hasLat && hasLng)) {
          alert('أدخل خط العرض والطول معًا أو اتركهما فارغين.');
          return;
        }
        if (hasLat && hasLng) {
          if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
            alert('إحداثيات الموقع غير صالحة.');
            return;
          }
          if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
            alert('الإحداثيات خارج النطاق المسموح.');
            return;
          }
        }

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
        const deliveryTimeVal = (document.getElementById(`storeDeliveryTime-${storeId}`)?.value || '')
          .replace(/\s+/g, ' ')
          .trim();
        const managerNameVal = (document.getElementById(`storeManagerName-${storeId}`)?.value || '').trim();
        const managerPhoneVal = (document.getElementById(`storeManagerPhone-${storeId}`)?.value || '').trim();
        const profilePatch = {
          contactPersonName: managerNameVal,
          contactPersonPhone: managerPhoneVal,
          deliveryTime: deliveryTimeVal,
          estimatedDeliveryTime: deliveryTimeVal,
          updatedAt: serverTimestamp(),
        };

        if (hasLat && hasLng) {
          profilePatch.location = new GeoPoint(latitude, longitude);
          profilePatch.latitude = latitude;
          profilePatch.longitude = longitude;
          profilePatch.lat = latitude;
          profilePatch.lng = longitude;
          profilePatch.restaurantLat = latitude;
          profilePatch.restaurantLng = longitude;
        }

        await updateDoc(doc(db, 'restaurants', storeId), profilePatch);
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

    document.getElementById(`storeHardDelete-${storeId}`)?.addEventListener('click', async () => {
      const button = document.getElementById(`storeHardDelete-${storeId}`);
      if (!button) return;

      const storeName = String(store.name || storeId).trim();
      const firstConfirm = window.confirm(
        `تحذير شديد: سيتم حذف المطعم (${storeName}) نهائيًا مع البيانات المرتبطة. هل تريد المتابعة؟`
      );
      if (!firstConfirm) return;

      const expectedToken = 'DELETE';
      const typedToken = window.prompt(
        `للتأكيد النهائي اكتب العبارة التالية حرفيًا:\n${expectedToken}`,
        ''
      );
      if (typedToken == null) return;
      if (String(typedToken).trim() !== expectedToken) {
        alert('عبارة التأكيد غير صحيحة. تم إلغاء العملية.');
        return;
      }

      await withBtnLoading(button, async () => {
        await adminDeleteRestaurantAccount({
          restaurantId: storeId,
          confirmation: expectedToken,
        });

        alert('تم حذف المطعم نهائيًا بنجاح.');
        storeDetailsPanel.innerHTML = '<span class="muted">تم حذف المتجر نهائيًا.</span>';
      });
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
    const normalized = {};
    Object.entries(sizesRaw).forEach(([rawKey, rawValue]) => {
      const key = String(rawKey || '').trim().toLowerCase();
      if (!key) return;
      const parsed = parsePositiveOrNull(rawValue);
      if (parsed != null) {
        normalized[key] = parsed;
      }
    });
    return Object.keys(normalized).length ? normalized : null;
  };

  const parseExtraSizesText = (rawText) => {
    const text = String(rawText || '').trim();
    if (!text) return { ok: true, sizes: {} };

    const result = {};
    const parts = text
      .split(/[\n,،;]+/)
      .map((part) => part.trim())
      .filter(Boolean);

    for (const part of parts) {
      const [rawKey, rawValue] = part.split(/[:=]/).map((value) => String(value || '').trim());
      const key = String(rawKey || '').toLowerCase().replace(/\s+/g, '_');
      const value = parsePositiveOrNull(rawValue);

      if (!key || value == null) {
        return {
          ok: false,
          message: 'صيغة الأحجام الإضافية غير صحيحة. استخدم مثال: family:150, jumbo:180',
        };
      }

      result[key] = value;
    }

    return { ok: true, sizes: result };
  };

  const pickDefaultMenuPrice = (sizes) => {
    if (!sizes || typeof sizes !== 'object') return null;
    if (sizes.medium != null) return sizes.medium;
    if (sizes.small != null) return sizes.small;
    if (sizes.large != null) return sizes.large;
    const first = Object.values(sizes)[0];
    return Number.isFinite(first) ? first : null;
  };

  const buildPricePayload = ({ baseRaw, smallRaw, mediumRaw, largeRaw, familyRaw, jumboRaw, extraRaw }) => {
    const basePrice = parsePositiveOrNull(baseRaw);
    const manualSizes = normalizeSizes({
      small: smallRaw,
      medium: mediumRaw,
      large: largeRaw,
      family: familyRaw,
      jumbo: jumboRaw,
    }) || {};

    const parsedExtra = parseExtraSizesText(extraRaw);
    if (!parsedExtra.ok) {
      return parsedExtra;
    }

    const sizesCandidate = {
      ...manualSizes,
      ...parsedExtra.sizes,
    };
    const hasAnySize = Object.keys(sizesCandidate).length > 0;
    const sizes = hasAnySize ? sizesCandidate : null;

    if (basePrice == null && !sizes) {
      return {
        ok: false,
        message: 'أدخل السعر الأساسي أو أسعار الأحجام',
      };
    }

    const fallbackSizePrice = pickDefaultMenuPrice(sizes);
    const price = basePrice ?? fallbackSizePrice;
    if (!price || price <= 0) {
      return {
        ok: false,
        message: 'أدخل سعرًا أساسيًا أو حجمًا بسعر صالح أكبر من صفر',
      };
    }
    return { ok: true, price, sizes };
  };

  const legacyMenuCategoryId = (value) => {
    const raw = String(value || '').trim();
    if (!raw) return '';
    return raw.replace(/[\\/#?\[\]]/g, '-');
  };

  const getLegacyMenuItemRef = (legacyStoreId, category, itemId) => {
    const categoryId = legacyMenuCategoryId(category);
    if (!legacyStoreId || !categoryId || !itemId) return null;
    return doc(db, 'restaurants', legacyStoreId, 'menu', categoryId, 'items', itemId);
  };

  const queueLegacyMenuMirror = (batch, legacyStoreId, itemId, itemData = {}, updates = {}) => {
    const legacyRef = getLegacyMenuItemRef(legacyStoreId, updates.category || itemData.category, itemId);
    if (!legacyRef) return;

    const payload = {
      name: updates.name ?? itemData.name ?? '',
      price: updates.price ?? itemData.price ?? 0,
      imageUrl: updates.imageUrl ?? itemData.imageUrl ?? '',
      category: updates.category ?? itemData.category ?? '',
      available: updates.available ?? itemData.available ?? true,
      updatedAt: serverTimestamp(),
    };

    if (updates.sizes) {
      payload.sizes = updates.sizes;
    } else if (itemData.sizes) {
      payload.sizes = itemData.sizes;
    }

    batch.set(legacyRef, payload, { merge: true });
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
    const orderedSizeKeys = ['small', 'medium', 'large', 'family', 'jumbo'];
    const customSizeKeys = sizes
      ? Object.keys(sizes).filter((key) => !orderedSizeKeys.includes(key)).sort()
      : [];
    const displaySizeKeys = sizes
      ? [...orderedSizeKeys.filter((key) => sizes[key] != null), ...customSizeKeys]
      : [];
    const sizeLabelMap = {
      small: 'صغير',
      medium: 'وسط',
      large: 'كبير',
      family: 'عائلي',
      jumbo: 'جامبو',
    };
    const sizesCell = sizes
      ? displaySizeKeys
          .map((key) => `${sizeLabelMap[key] || key}:${sizes[key]}`)
          .join(' | ')
      : '-';

    return `<tr>
      <td>${name}</td>
      <td>${category}</td>
      <td>${Number.isFinite(price) ? price : 0}</td>
      <td>${sizesCell}</td>
      <td>${image}</td>
      <td>${available ? 'متاح' : 'غير متاح'}</td>
      <td>
        <button class="btn primary" data-menu-edit="${d.id}">تعديل</button>
        <button class="btn ghost" data-menu-image="${d.id}">تعديل الصورة</button>
        <button class="btn ghost" data-menu-toggle="${d.id}" data-available="${available ? 'true' : 'false'}">${available ? 'إيقاف' : 'تفعيل'}</button>
        <button class="btn danger" data-menu-delete="${d.id}">حذف</button>
      </td>
    </tr>`;
  });

  container.innerHTML = `
    <div class="admin-menu-manager">
      <div class="admin-menu-import-card">
        <div class="entity-section-head compact">
          <span class="entity-section-eyebrow">استيراد جماعي</span>
          <h5>استيراد الأصناف من CSV أو Excel</h5>
          <p>الأعمدة المقترحة: itemId, name, category, price, smallPrice, mediumPrice, largePrice, familyPrice, jumboPrice, available, imageUrl, imageFileName.</p>
          <p class="field-hint">إذا كانت الصور داخل ملف ZIP، ضع اسم الملف في imageFileName. وإذا كانت الروابط جاهزة، استخدم imageUrl مباشرة.</p>
          <p class="field-hint">إذا تركت itemId فارغًا، سيُنشئ النظام معرفًا ثابتًا من الاسم والفئة حتى لا تتكرر الأصناف عند إعادة الاستيراد.</p>
        </div>
        <div class="admin-menu-import-grid">
          <label class="admin-menu-import-file-field">ملف الأصناف<input id="menuImportFile-${storeId}" type="file" accept=".csv,.xlsx,.xls,.csv,.txt,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/csv" /></label>
          <label class="admin-menu-import-file-field">ملف الصور ZIP (اختياري)<input id="menuImportZip-${storeId}" type="file" accept=".zip,application/zip" /></label>
        </div>
        <div class="admin-menu-import-actions">
          <button class="btn ghost" id="pickMenuImportFile-${storeId}" type="button">اختيار ملف CSV / Excel</button>
          <button class="btn ghost" id="pickMenuImportZip-${storeId}" type="button">اختيار ملف ZIP للصور</button>
          <button class="btn ghost" id="downloadMenuTemplate-${storeId}" type="button">تحميل قالب مثال</button>
          <button class="btn primary" id="importMenuItems-${storeId}" type="button">استيراد الأصناف</button>
        </div>
        <div class="admin-menu-import-files muted" id="menuImportFiles-${storeId}">لم يتم اختيار أي ملف بعد.</div>
        <div id="menuImportStatus-${storeId}" class="muted normalize-result">اختر ملف CSV أو Excel لبدء الاستيراد.</div>
      </div>
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
          <label>سعر عائلي<input id="newItemFamilyPrice-${storeId}" type="number" step="0.01" placeholder="عائلي" /></label>
          <label>سعر جامبو<input id="newItemJumboPrice-${storeId}" type="number" step="0.01" placeholder="جامبو" /></label>
          <label>أحجام إضافية (اختياري)<input id="newItemExtraSizes-${storeId}" type="text" placeholder="مثال: mega:220, party:260" /></label>
          <label class="admin-menu-file-field">صورة الصنف<input id="newItemImageFile-${storeId}" type="file" accept="image/*" /></label>
        </div>
        <div class="admin-menu-toolbar">
          <button class="btn primary" id="addMenuItem-${storeId}">إضافة الصنف</button>
        </div>
      </div>
      <div class="admin-menu-edit-card" id="menuEditCard-${storeId}" hidden>
        <div class="entity-section-head compact">
          <span class="entity-section-eyebrow">تحرير الصنف</span>
          <h5 id="menuEditTitle-${storeId}">تعديل صنف</h5>
          <p>عدّل الاسم والأسعار والفئة فقط. تعديل الصورة له زر مستقل في الجدول.</p>
        </div>
        <div class="admin-menu-edit-grid">
          <label>اسم الصنف<input id="menuEditName-${storeId}" type="text" /></label>
          <label>الفئة<input id="menuEditCategory-${storeId}" type="text" /></label>
          <label>السعر الأساسي<input id="menuEditPrice-${storeId}" type="number" step="0.01" placeholder="اختياري مع الأحجام" /></label>
          <label>سعر صغير<input id="menuEditSmallPrice-${storeId}" type="number" step="0.01" placeholder="صغير" /></label>
          <label>سعر وسط<input id="menuEditMediumPrice-${storeId}" type="number" step="0.01" placeholder="وسط" /></label>
          <label>سعر كبير<input id="menuEditLargePrice-${storeId}" type="number" step="0.01" placeholder="كبير" /></label>
          <label>سعر عائلي<input id="menuEditFamilyPrice-${storeId}" type="number" step="0.01" placeholder="عائلي" /></label>
          <label>سعر جامبو<input id="menuEditJumboPrice-${storeId}" type="number" step="0.01" placeholder="جامبو" /></label>
          <label>أحجام إضافية (اختياري)<input id="menuEditExtraSizes-${storeId}" type="text" placeholder="مثال: mega:220, party:260" /></label>
        </div>
        <div class="admin-menu-edit-actions">
          <button class="btn primary" id="menuEditSave-${storeId}" type="button">حفظ التعديل</button>
          <button class="btn ghost" id="menuEditCancel-${storeId}" type="button">إلغاء</button>
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

  const menuImportFileInput = document.getElementById(`menuImportFile-${storeId}`);
  const menuImportZipInput = document.getElementById(`menuImportZip-${storeId}`);
  const menuImportFiles = document.getElementById(`menuImportFiles-${storeId}`);
  const menuImportStatus = document.getElementById(`menuImportStatus-${storeId}`);
  const menuEditCard = document.getElementById(`menuEditCard-${storeId}`);
  const menuEditTitle = document.getElementById(`menuEditTitle-${storeId}`);
  const menuEditName = document.getElementById(`menuEditName-${storeId}`);
  const menuEditCategory = document.getElementById(`menuEditCategory-${storeId}`);
  const menuEditPrice = document.getElementById(`menuEditPrice-${storeId}`);
  const menuEditSmallPrice = document.getElementById(`menuEditSmallPrice-${storeId}`);
  const menuEditMediumPrice = document.getElementById(`menuEditMediumPrice-${storeId}`);
  const menuEditLargePrice = document.getElementById(`menuEditLargePrice-${storeId}`);
  const menuEditFamilyPrice = document.getElementById(`menuEditFamilyPrice-${storeId}`);
  const menuEditJumboPrice = document.getElementById(`menuEditJumboPrice-${storeId}`);
  const menuEditExtraSizes = document.getElementById(`menuEditExtraSizes-${storeId}`);
  const menuEditSaveBtn = document.getElementById(`menuEditSave-${storeId}`);
  const menuEditCancelBtn = document.getElementById(`menuEditCancel-${storeId}`);
  const pickMenuImportFileBtn = document.getElementById(`pickMenuImportFile-${storeId}`);
  const pickMenuImportZipBtn = document.getElementById(`pickMenuImportZip-${storeId}`);
  const downloadMenuTemplateBtn = document.getElementById(`downloadMenuTemplate-${storeId}`);
  const importMenuItemsBtn = document.getElementById(`importMenuItems-${storeId}`);

  let menuEditActiveItemId = '';
  let menuEditActiveLegacyCategory = '';

  const hideMenuEditor = () => {
    menuEditActiveItemId = '';
    menuEditActiveLegacyCategory = '';
    if (menuEditCard) menuEditCard.hidden = true;
  };

  const openMenuEditor = async (itemId) => {
    if (!itemId) return;
    const docSnap = await getDoc(doc(db, 'restaurants', storeId, 'full_menu', itemId));
    if (!docSnap.exists()) {
      alert('الصنف غير موجود');
      return;
    }

    const item = docSnap.data() || {};
    const sizes = normalizeSizes(item.sizes);
    menuEditActiveItemId = itemId;
    menuEditActiveLegacyCategory = String(item.category || '').trim();

    if (menuEditTitle) {
      menuEditTitle.textContent = `تعديل: ${item.name || itemId}`;
    }
    if (menuEditName) menuEditName.value = String(item.name || '');
    if (menuEditCategory) menuEditCategory.value = String(item.category || '');
    if (menuEditPrice) menuEditPrice.value = item.price ?? '';
    if (menuEditSmallPrice) menuEditSmallPrice.value = sizes?.small ?? '';
    if (menuEditMediumPrice) menuEditMediumPrice.value = sizes?.medium ?? '';
    if (menuEditLargePrice) menuEditLargePrice.value = sizes?.large ?? '';
    if (menuEditFamilyPrice) menuEditFamilyPrice.value = sizes?.family ?? '';
    if (menuEditJumboPrice) menuEditJumboPrice.value = sizes?.jumbo ?? '';
    if (menuEditExtraSizes) {
      const extraEntries = Object.entries(sizes || {})
        .filter(([key]) => !['small', 'medium', 'large', 'family', 'jumbo'].includes(key))
        .map(([key, value]) => `${key}:${value}`);
      menuEditExtraSizes.value = extraEntries.join(', ');
    }
    if (menuEditCard) menuEditCard.hidden = false;
    menuEditCard?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    menuEditName?.focus({ preventScroll: true });
  };

  const syncMenuImportFilesLabel = () => {
    if (!menuImportFiles) return;
    const spreadsheetName = menuImportFileInput?.files && menuImportFileInput.files.length ? menuImportFileInput.files[0].name : 'لم يتم اختيار ملف أصناف';
    const zipName = menuImportZipInput?.files && menuImportZipInput.files.length ? menuImportZipInput.files[0].name : 'بدون ملف ZIP';
    menuImportFiles.textContent = `ملف الأصناف: ${spreadsheetName} | ملف الصور: ${zipName}`;
  };

  menuImportFileInput?.addEventListener('change', syncMenuImportFilesLabel);
  menuImportZipInput?.addEventListener('change', syncMenuImportFilesLabel);

  pickMenuImportFileBtn?.addEventListener('click', () => menuImportFileInput?.click());
  pickMenuImportZipBtn?.addEventListener('click', () => menuImportZipInput?.click());
  syncMenuImportFilesLabel();

  downloadMenuTemplateBtn?.addEventListener('click', () => {
    const csv = buildSpreadsheetTemplateCsv();
    const blob = new Blob([`\ufeff${csv}`], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = 'speedstar-menu-template.csv';
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  });

  importMenuItemsBtn?.addEventListener('click', async () => {
    const spreadsheetFile = menuImportFileInput?.files && menuImportFileInput.files.length ? menuImportFileInput.files[0] : null;
    const zipFile = menuImportZipInput?.files && menuImportZipInput.files.length ? menuImportZipInput.files[0] : null;

    if (!spreadsheetFile) {
      alert('اختر ملف CSV أو Excel أولًا.');
      return;
    }

    if (menuImportStatus) {
      menuImportStatus.textContent = 'جارٍ قراءة الملف...';
    }

    importMenuItemsBtn.disabled = true;

    try {
      const rows = await readSpreadsheetRows(spreadsheetFile);
      if (!rows.length) {
        throw new Error('الملف لا يحتوي على صفوف بيانات صالحة.');
      }

      const zipState = zipFile ? await buildSpreadsheetZipState(zipFile) : null;
      const importErrors = [];
      let importedCount = 0;
      let skippedCount = 0;
      let batch = writeBatch(db);
      let batchCount = 0;

      const commitBatch = async () => {
        if (!batchCount) return;
        await batch.commit();
        batch = writeBatch(db);
        batchCount = 0;
      };

      for (let index = 0; index < rows.length; index += 1) {
        const row = rows[index] || {};
        const rowNumber = index + 2;

        if (menuImportStatus && index % 5 === 0) {
          menuImportStatus.textContent = `جارٍ تجهيز الصف ${rowNumber} من ${rows.length}...`;
        }

        const category = String(spreadsheetValue(row, ['category', 'section', 'الفئة', 'القسم', 'التصنيف'])).trim();
        const itemIdRaw = String(spreadsheetValue(row, ['itemId', 'id', 'docId', 'معرف', 'معرفالصنف'])).trim();
        const name = String(spreadsheetValue(row, ['name', 'itemName', 'اسم', 'اسمالصنف', 'الصنف'])).trim();
        const available = parseSpreadsheetBoolean(spreadsheetValue(row, ['available', 'active', 'isActive', 'متاح', 'الحالة']), true);
        const priceResult = parseSpreadsheetSizes(row);

        if (!name) {
          skippedCount += 1;
          importErrors.push(`الصف ${rowNumber}: اسم الصنف مفقود.`);
          continue;
        }

        if (!category) {
          skippedCount += 1;
          importErrors.push(`الصف ${rowNumber}: الفئة مفقودة للصنف "${name}".`);
          continue;
        }

        if (!priceResult.ok) {
          skippedCount += 1;
          importErrors.push(`الصف ${rowNumber} (${name}): ${priceResult.message}`);
          continue;
        }

        const imageUrlRaw = spreadsheetValue(row, ['imageUrl', 'image', 'photo', 'photoUrl', 'url', 'رابطالصورة', 'الصورة']);
        const imageFileName = spreadsheetValue(row, ['imageFileName', 'imageKey', 'imageName', 'fileName', 'اسمالصورة', 'ملفالصورة']);

        let imageUrl = String(imageUrlRaw || '').trim();
        if (!imageUrl) {
          try {
            imageUrl = await resolveSpreadsheetImageUrl({
              imageUrl: '',
              imageFileName,
              zipState,
              rowLabel: rowNumber,
            }) || '';
          } catch (err) {
            skippedCount += 1;
            importErrors.push(err.message || `الصف ${rowNumber}: تعذر تجهيز الصورة.`);
            continue;
          }
        }

        if (!imageUrl) {
          skippedCount += 1;
          importErrors.push(`الصف ${rowNumber} (${name}): أضف imageUrl أو imageFileName مع ملف ZIP للصور.`);
          continue;
        }

        const itemId = normalizeSpreadsheetDocId(itemIdRaw || `${name}-${category}`);
        const targetRef = itemId ? doc(fullMenuRef, itemId) : doc(fullMenuRef);

        batch.set(targetRef, {
          name,
          category,
          price: priceResult.price,
          ...(priceResult.sizes ? { sizes: priceResult.sizes } : {}),
          imageUrl,
          available,
          updatedAt: serverTimestamp(),
          updatedByAdminUid: auth.currentUser?.uid || null,
          importedFromSpreadsheet: true,
          importSourceFile: spreadsheetFile.name,
          importRowNumber: rowNumber,
        }, { merge: true });

        batchCount += 1;
        importedCount += 1;

        if (batchCount >= 300) {
          await commitBatch();
        }
      }

      await commitBatch();

      const summary = [
        `تم استيراد ${importedCount} صنفًا من ${rows.length} صفًا.`,
      ];
      if (skippedCount) {
        summary.push(`تم تخطي ${skippedCount} صفًا.`);
      }
      if (importErrors.length) {
        summary.push(`أول الأخطاء:\n${importErrors.slice(0, 5).join('\n')}`);
      }

      const summaryText = summary.join('\n\n');

      if (menuImportStatus) {
        menuImportStatus.textContent = summaryText;
      }

      await renderAdminMenuManager(storeId);
      const refreshedStatus = document.getElementById(`menuImportStatus-${storeId}`);
      if (refreshedStatus) {
        refreshedStatus.textContent = summaryText;
      }
    } catch (err) {
      if (menuImportStatus) {
        menuImportStatus.textContent = `تعذر استيراد الملف: ${err.message || err}`;
      }
      alert(`تعذر استيراد الملف: ${err.message || err}`);
    } finally {
      importMenuItemsBtn.disabled = false;
    }
  });

  const addBtn = document.getElementById(`addMenuItem-${storeId}`);
  addBtn?.addEventListener('click', async () => {
    const name = (document.getElementById(`newItemName-${storeId}`)?.value || '').trim();
    const basePriceRaw = (document.getElementById(`newItemPrice-${storeId}`)?.value || '').trim();
    const smallPriceRaw = (document.getElementById(`newItemSmallPrice-${storeId}`)?.value || '').trim();
    const mediumPriceRaw = (document.getElementById(`newItemMediumPrice-${storeId}`)?.value || '').trim();
    const largePriceRaw = (document.getElementById(`newItemLargePrice-${storeId}`)?.value || '').trim();
    const familyPriceRaw = (document.getElementById(`newItemFamilyPrice-${storeId}`)?.value || '').trim();
    const jumboPriceRaw = (document.getElementById(`newItemJumboPrice-${storeId}`)?.value || '').trim();
    const extraSizesRaw = (document.getElementById(`newItemExtraSizes-${storeId}`)?.value || '').trim();
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
      familyRaw: familyPriceRaw,
      jumboRaw: jumboPriceRaw,
      extraRaw: extraSizesRaw,
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
      const chunkSize = 200;
      for (let start = 0; start < docs.length; start += chunkSize) {
        const batch = writeBatch(db);
        const chunk = docs.slice(start, start + chunkSize);

        chunk.forEach((d) => {
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
            updates.sizes = {};
            Object.entries(sizes).forEach(([sizeKey, sizePrice]) => {
              updates.sizes[sizeKey] = Math.round(sizePrice * factor * 100) / 100;
            });
            if (!updates.price) {
              updates.price = pickDefaultMenuPrice(updates.sizes);
            }
          }

          if (!updates.price) return;
          batch.update(doc(db, 'restaurants', storeId, 'full_menu', d.id), updates);
          queueLegacyMenuMirror(batch, storeId, d.id, item, updates);
        });

        await batch.commit();
      }
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
        const docRef = doc(db, 'restaurants', storeId, 'full_menu', itemId);
        const docSnap = await getDoc(docRef);
        const itemData = docSnap.exists() ? (docSnap.data() || {}) : {};
        const batch = writeBatch(db);
        batch.delete(docRef);
        const legacyRef = getLegacyMenuItemRef(storeId, itemData.category, itemId);
        if (legacyRef) batch.delete(legacyRef);
        await batch.commit();
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
        const docRef = doc(db, 'restaurants', storeId, 'full_menu', itemId);
        const docSnap = await getDoc(docRef);
        const itemData = docSnap.exists() ? (docSnap.data() || {}) : {};
        await updateDoc(docRef, {
          available: !available,
          updatedAt: serverTimestamp(),
          updatedByAdminUid: auth.currentUser?.uid || null,
        });
        const legacyRef = getLegacyMenuItemRef(storeId, itemData.category, itemId);
        if (legacyRef) {
          await setDoc(legacyRef, {
            available: !available,
            updatedAt: serverTimestamp(),
          }, { merge: true });
        }
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
      await openMenuEditor(itemId);
    });
  });

  menuEditCancelBtn?.addEventListener('click', () => hideMenuEditor());

  menuEditSaveBtn?.addEventListener('click', async () => {
    if (!menuEditActiveItemId) return;

    const nextName = String(menuEditName?.value || '').trim();
    const nextCategory = String(menuEditCategory?.value || '').trim();
    const priceResult = buildPricePayload({
      baseRaw: menuEditPrice?.value || '',
      smallRaw: menuEditSmallPrice?.value || '',
      mediumRaw: menuEditMediumPrice?.value || '',
      largeRaw: menuEditLargePrice?.value || '',
      familyRaw: menuEditFamilyPrice?.value || '',
      jumboRaw: menuEditJumboPrice?.value || '',
      extraRaw: menuEditExtraSizes?.value || '',
    });

    if (!nextName) {
      alert('أدخل اسم الصنف');
      return;
    }
    if (!nextCategory) {
      alert('أدخل الفئة');
      return;
    }
    if (!priceResult.ok) {
      alert(priceResult.message);
      return;
    }

    try {
      const docRef = doc(db, 'restaurants', storeId, 'full_menu', menuEditActiveItemId);
      const docSnap = await getDoc(docRef);
      const itemData = docSnap.exists() ? (docSnap.data() || {}) : {};
      const previousCategory = String(menuEditActiveLegacyCategory || itemData.category || '').trim();
      const nextCategoryTrimmed = nextCategory.trim();

      const updates = {
        name: nextName,
        price: priceResult.price,
        ...(priceResult.sizes ? { sizes: priceResult.sizes } : { sizes: deleteField() }),
        category: nextCategoryTrimmed,
        updatedAt: serverTimestamp(),
        updatedByAdminUid: auth.currentUser?.uid || null,
      };

      await updateDoc(docRef, updates);

      const legacyBatch = writeBatch(db);
      const nextLegacyRef = getLegacyMenuItemRef(storeId, nextCategoryTrimmed, menuEditActiveItemId);
      const previousLegacyRef = getLegacyMenuItemRef(storeId, previousCategory, menuEditActiveItemId);

      if (previousLegacyRef && previousLegacyRef.path !== nextLegacyRef?.path) {
        legacyBatch.delete(previousLegacyRef);
      }

      if (nextLegacyRef) {
        legacyBatch.set(nextLegacyRef, {
          name: nextName,
          price: priceResult.price,
          ...(priceResult.sizes ? { sizes: priceResult.sizes } : {}),
          category: nextCategoryTrimmed,
          imageUrl: String(itemData.imageUrl || '').trim(),
          available: itemData.available !== false,
          updatedAt: serverTimestamp(),
        }, { merge: true });
      }

      await legacyBatch.commit();
      hideMenuEditor();
      await renderAdminMenuManager(storeId);
    } catch (err) {
      alert(`تعذر تعديل الصنف: ${err.message || err}`);
    }
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
        const docRef = doc(db, 'restaurants', storeId, 'full_menu', itemId);
        const docSnap = await getDoc(docRef);
        const itemData = docSnap.exists() ? (docSnap.data() || {}) : {};
        await updateDoc(docRef, {
          imageUrl: uploaded,
          updatedAt: serverTimestamp(),
          updatedByAdminUid: auth.currentUser?.uid || null,
        });
        const legacyRef = getLegacyMenuItemRef(storeId, itemData.category, itemId);
        if (legacyRef) {
          await setDoc(legacyRef, {
            imageUrl: uploaded,
            updatedAt: serverTimestamp(),
          }, { merge: true });
        }
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

function getFirstNonEmptyText(values = [], fallback = 'غير محددة') {
  for (const value of values) {
    const text = String(value ?? '').trim();
    if (text) return text;
  }
  return fallback;
}

function formatPendingDateTime(value) {
  if (!value || typeof value.toDate !== 'function') return '-';
  try {
    return value.toDate().toLocaleString('ar-EG');
  } catch (_) {
    return '-';
  }
}

function getApplicantGeoMeta(data = {}) {
  const state = getFirstNonEmptyText([
    data.workStateName,
    data.stateName,
    data.state,
    data.serviceArea?.stateName,
  ]);
  const locality = getFirstNonEmptyText([
    data.workLocalityName,
    data.serviceArea?.localityName,
    data.city,
    data.locality,
    data.region,
  ]);
  const area = getFirstNonEmptyText([
    data.workAreaName,
    data.serviceArea?.areaName,
    data.workAreaLabel,
    data.area,
  ]);
  return { state, locality, area };
}

function buildPendingFactsMarkup(data = {}, kind = 'store') {
  const geo = getApplicantGeoMeta(data);
  const facts = kind === 'courier'
    ? [
        { label: 'UID', value: data.ownerUid || data.driverId || data.uid || '-' },
        { label: 'رقم إثبات الشخصية', value: data.nationalIdNumber || '-' },
        { label: 'نوع المركبة', value: data.vehicleType || '-' },
        { label: 'رقم اللوحة', value: data.vehiclePlate || '-' },
        { label: 'الولاية', value: geo.state },
        { label: 'المحلية', value: geo.locality },
        { label: 'المنطقة', value: geo.area },
        { label: 'التوفر', value: data.available === true ? 'متاح' : 'غير متاح' },
        { label: 'المسافات البعيدة', value: data.acceptsLongDistance === true ? 'مفعلة' : 'غير مفعلة' },
        { label: 'حالة الاعتماد', value: formatApprovalStatusLabel(data.approvalStatus, data.isApproved) },
        { label: 'تم الإنشاء', value: formatPendingDateTime(data.createdAt) },
        { label: 'آخر تحديث', value: formatPendingDateTime(data.updatedAt) },
      ]
    : [
        { label: 'UID', value: data.ownerUid || data.restaurantId || data.uid || '-' },
        { label: 'رقم السجل', value: data.commercialRecordNumber || '-' },
        { label: 'الولاية', value: geo.state },
        { label: 'المحلية', value: geo.locality },
        { label: 'المنطقة', value: geo.area },
        { label: 'حالة القائمة', value: data.menuApproved === true ? 'معتمدة' : 'غير معتمدة' },
        { label: 'اعتماد المتجر', value: formatApprovalStatusLabel(data.approvalStatus, data.isApproved) },
        { label: 'قيد المراجعة', value: data.pendingApproval === true ? 'نعم' : 'لا' },
        { label: 'إغلاق مؤقت', value: data.temporarilyClosed === true ? 'نعم' : 'لا' },
        { label: 'تم الإنشاء', value: formatPendingDateTime(data.createdAt) },
        { label: 'آخر تحديث', value: formatPendingDateTime(data.updatedAt) },
        { label: 'طلب القائمة', value: formatPendingDateTime(data.approvalRequestedAt) },
      ];

  return buildEntityFactsGrid(facts);
}

function buildPendingApplicantCard({ kind, id, data = {}, actions = '', imageUrl = '', title = '' }) {
  const geo = getApplicantGeoMeta(data);
  const roleLabel = kind === 'courier' ? 'مندوب' : 'مطعم';
  const requestTypeLabel = kind === 'courier' ? 'طلب اعتماد مندوب' : 'طلب اعتماد مطعم';
  const statusLabel = formatApprovalStatusLabel(data.approvalStatus, data.isApproved);
  const uidValue = String(data.ownerUid || data.driverId || data.restaurantId || data.uid || id || '-');
  const phoneValue = String(data.phone || data.mobile || '-');
  const displayName = title
    || data.name
    || data.storeName
    || data.restaurantName
    || data.fullName
    || id;
  const identityValue = kind === 'courier'
    ? String(data.nationalIdNumber || '-')
    : String(data.commercialRecordNumber || '-');
  const identityLabel = kind === 'courier' ? 'هوية' : 'سجل';
  const createdAtValue = formatPendingDateTime(data.createdAt);
  const imageBlock = imageUrl
    ? `<div class="pending-application-avatar">${imageCell(imageUrl)}</div>`
    : '';

  return `
    <article class="pending-application-card pending-application-card--compact">
      ${imageBlock}
      <div class="pending-application-main">
        <span class="pending-application-badge">${escapeHtml(roleLabel)}</span>
        <strong class="pending-application-title">${escapeHtml(displayName)}</strong>
      </div>
      <div class="pending-application-meta pending-application-meta--compact">
        <span><b>UID:</b> ${escapeHtml(uidValue)}</span>
        <span><b>${escapeHtml(identityLabel)}:</b> ${escapeHtml(identityValue)}</span>
        <span><b>الهاتف:</b> ${escapeHtml(phoneValue)}</span>
        <span><b>الولاية:</b> ${escapeHtml(geo.state)}</span>
        <span><b>المحلية:</b> ${escapeHtml(geo.locality)}</span>
        <span><b>المنطقة:</b> ${escapeHtml(geo.area)}</span>
        <span><b>وقت الطلب:</b> ${escapeHtml(createdAtValue)}</span>
      </div>
      <div class="pending-application-status-row">
        <span class="approval-geo-count">${escapeHtml(statusLabel)}</span>
        <span class="pending-application-status-hint">${escapeHtml(requestTypeLabel)}</span>
      </div>
      <div class="pending-application-actions">${actions}</div>
    </article>
  `;
}

function aggregateApprovedGeoStats(entries = []) {
  const localityMap = new Map();
  let totalCouriers = 0;
  let totalStores = 0;

  const addArea = (localityKey, localityLabel, areaKey, areaLabel, role) => {
    if (!localityMap.has(localityKey)) {
      localityMap.set(localityKey, {
        key: localityKey,
        label: localityLabel,
        couriers: 0,
        stores: 0,
        total: 0,
        areas: new Map(),
      });
    }

    const locality = localityMap.get(localityKey);
    locality.total += 1;
    if (role === 'courier') locality.couriers += 1;
    else locality.stores += 1;

    if (!locality.areas.has(areaKey)) {
      locality.areas.set(areaKey, {
        key: areaKey,
        label: areaLabel,
        couriers: 0,
        stores: 0,
        total: 0,
      });
    }

    const area = locality.areas.get(areaKey);
    area.total += 1;
    if (role === 'courier') area.couriers += 1;
    else area.stores += 1;
  };

  entries.forEach((entry) => {
    const role = entry.role === 'courier' ? 'courier' : 'store';
    if (role === 'courier') totalCouriers += 1;
    else totalStores += 1;

    const geo = getApplicantGeoMeta(entry.data || {});
    const localityLabel = geo.locality || 'غير محددة';
    const areaLabel = geo.area || 'غير محددة';
    const localityKey = normalizeSpreadsheetToken(localityLabel) || 'غيرمحددة';
    const areaKey = normalizeSpreadsheetToken(`${localityLabel}:${areaLabel}`) || `${localityKey}:area`;
    addArea(localityKey, localityLabel, areaKey, areaLabel, role);
  });

  const localities = Array.from(localityMap.values())
    .map((locality) => ({
      ...locality,
      areas: Array.from(locality.areas.values()).sort((a, b) => b.total - a.total || String(a.label).localeCompare(String(b.label), 'ar')),
    }))
    .sort((a, b) => b.total - a.total || String(a.label).localeCompare(String(b.label), 'ar'));

  const totalAreas = localities.reduce((sum, locality) => sum + locality.areas.length, 0);

  return {
    totals: {
      couriers: totalCouriers,
      stores: totalStores,
      localities: localities.length,
      areas: totalAreas,
    },
    localities,
  };
}

function renderPendingGeoStats(approvedEntries = []) {
  if (!pendingGeoStatsSummary || !pendingGeoStatsTables) return;

  const stats = aggregateApprovedGeoStats(approvedEntries);
  pendingGeoStatsSummary.innerHTML = `
    <div class="stat"><h4>مندوبون معتمدون</h4><b>${stats.totals.couriers.toLocaleString('ar-EG')}</b></div>
    <div class="stat"><h4>متاجر معتمدة</h4><b>${stats.totals.stores.toLocaleString('ar-EG')}</b></div>
    <div class="stat"><h4>المحليات</h4><b>${stats.totals.localities.toLocaleString('ar-EG')}</b></div>
    <div class="stat"><h4>المناطق</h4><b>${stats.totals.areas.toLocaleString('ar-EG')}</b></div>
  `;

  if (!stats.localities.length) {
    pendingGeoStatsTables.innerHTML = '<div class="muted">لا توجد بيانات معتمدة كافية للإحصاءات حاليًا.</div>';
    return;
  }

  pendingGeoStatsTables.innerHTML = `
    <div class="approval-geo-tree">
      ${stats.localities.map((locality) => `
        <div class="approval-geo-locality">
          <div class="approval-geo-locality-head">
            <div>
              <h4>${escapeHtml(locality.label)}</h4>
              <div class="approval-geo-locality-meta">
                <span>الإجمالي: ${locality.total.toLocaleString('ar-EG')}</span>
                <span>مندوبون: ${locality.couriers.toLocaleString('ar-EG')}</span>
                <span>متاجر: ${locality.stores.toLocaleString('ar-EG')}</span>
              </div>
            </div>
            <div class="approval-geo-count">${locality.total.toLocaleString('ar-EG')}</div>
          </div>
          <div class="approval-geo-areas">
            ${locality.areas.map((area) => `
              <div class="approval-geo-area">
                <div class="approval-geo-area-head">
                  <strong>${escapeHtml(area.label)}</strong>
                  <span class="approval-geo-count">${area.total.toLocaleString('ar-EG')}</span>
                </div>
                <div class="approval-geo-locality-meta">
                  <span>مندوبون: ${area.couriers.toLocaleString('ar-EG')}</span>
                  <span>متاجر: ${area.stores.toLocaleString('ar-EG')}</span>
                </div>
              </div>
            `).join('')}
          </div>
        </div>
      `).join('')}
    </div>
  `;
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
      businessType: ['restaurant', 'brand', 'ecommerce', 'grocery', 'pharmacy'].includes(String(appData.businessType || '').trim())
        ? String(appData.businessType).trim()
        : 'restaurant',
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
    .replace(/[^-\p{L}\p{N}\s]+/gu, ' ')
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
    approvalRequestedAt: deleteField(),
  };

  if (approved) {
    updates.approvalStatus = 'approved';
    updates.isApproved = true;
    updates.status = 'approved';
    updates.reviewStatus = 'approved';
    Object.assign(updates, buildRestaurantVisibilityBackfill(restaurantData, addressData));
  } else {
    updates.status = 'rejected';
    updates.reviewStatus = 'rejected';
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

  const showSupportMobileThread = (showThread) => {
    supportRoot.classList.toggle('support-mobile-thread', showThread);
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

  const getConversationDisplayName = (messages = [], latestMsg = {}) => {
    const externalMsg = messages.slice().reverse().find((m) => {
      const senderType = String(m.senderType || '').toLowerCase();
      return senderType !== 'admin' && senderType !== 'support'
        && String(m.senderId || '').toLowerCase() !== 'support';
    });
    if (externalMsg) {
      return String(externalMsg.senderName || externalMsg.senderId || externalMsg.senderType || '').trim() || '';
    }
    const explicitUser = String(latestMsg.userId || latestMsg.senderId || latestMsg.receiverId || '').trim();
    if (explicitUser) return explicitUser;
    return String(latestMsg.senderName || latestMsg.senderType || 'مستخدم').trim() || 'مستخدم';
  };

  const isSupportAdminMessage = (msg = {}) => {
    const senderType = String(msg.senderType || '').toLowerCase();
    const senderId = String(msg.senderId || '').toLowerCase();
    return senderType === 'admin' || senderType === 'support' || senderId === 'support'
      || senderId && senderId === String(auth.currentUser?.uid || '').toLowerCase();
  };

  const getReadableSenderName = (msg = {}) => {
    const senderType = String(msg.senderType || '').toLowerCase();
    const senderId = String(msg.senderId || '').trim();
    const senderName = String(msg.senderName || '').trim();
    if (senderType === 'admin' || senderType === 'support' || senderId.toLowerCase() === 'support') return 'الدعم الفني';
    if (senderType === 'client' || senderType === 'customer' || senderType === 'عميل') return senderName || senderId || 'عميل';
    if (senderType === 'courier' || senderType === 'driver' || senderType === 'مندوب') return senderName || senderId || 'مندوب';
    if (senderType === 'store' || senderType === 'restaurant' || senderType === 'مطعم') return senderName || senderId || 'متجر';
    if (senderName) return senderName;
    if (senderId) return senderId;
    return String(msg.receiverName || msg.receiverId || msg.senderType || 'مستخدم');
  };

  const getAppLabel = (sourceApp) => {
    if (sourceApp === 'client') return 'العملاء';
    if (sourceApp === 'courier') return 'المندوبون';
    return 'المتاجر';
  };

  const getReceiverLabel = (msg = {}) => {
    const receiverType = String(msg.receiverType || '').toLowerCase();
    const receiverId = String(msg.receiverId || '').trim();
    const receiverName = String(msg.receiverName || '').trim();
    if (receiverType === 'admin' || receiverType === 'support' || receiverId.toLowerCase() === 'support') return 'الدعم الفني';
    if (receiverType === 'client' || receiverType === 'customer' || receiverType === 'عميل') return receiverName || receiverId || 'عميل';
    if (receiverType === 'courier' || receiverType === 'driver' || receiverType === 'مندوب') return receiverName || receiverId || 'مندوب';
    if (receiverType === 'store' || receiverType === 'restaurant' || receiverType === 'مطعم') return receiverName || receiverId || 'مطعم';
    return receiverName || receiverId || 'غير محدد';
  };

  const getSupportReference = (msg = {}, convo = {}) => {
    return String(
      msg.orderId
      || msg.requestId
      || msg.ticketId
      || msg.caseId
      || msg.referenceId
      || msg.conversationId
      || convo.conversationId
      || convo.id
      || '-'
    ).trim() || '-';
  };

  const markConversationReadIfNeeded = async (convo) => {
    if (!convo || !(convo.unreadCount > 0)) return;
    try {
      await markSupportConversationRead(convo);
    } catch (err) {
      console.error('Failed to auto-mark support conversation as read', err);
    }
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
    const conversationId = String(conversation.conversationId || conversation.id || '');
    if (conversationId.endsWith('-support')) {
      return conversationId.slice(0, -'-support'.length);
    }

    const messages = supportMessagesByConversation.get(String(conversation.id || conversationId)) || [];
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
        const appLabel = getAppLabel(item.sourceApp);
        return `
          <button class="support-item ${item.id === supportSelectedConversationId ? 'active' : ''}" data-support-conversation="${escapeHtml(item.id)}" type="button">
            <div class="support-item-top">
              <span class="badge ${item.status === 'closed' ? 'closed' : 'open'}">${item.status === 'closed' ? 'مغلقة' : 'مفتوحة'}</span>
              <span class="support-item-time muted">${escapeHtml(item.latestTimeText)}</span>
            </div>
            <div class="support-item-title-row">
              <div class="support-item-title">${escapeHtml(item.senderName || item.userId || item.id)}</div>
              ${item.unreadCount > 0 ? `<span class="support-unread">${item.unreadCount}</span>` : ''}
            </div>
            <div class="support-item-meta">
              <span class="support-item-pill">${escapeHtml(appLabel)}</span>
              <span class="support-item-pill">${escapeHtml(item.actor)}</span>
              <span class="support-item-pill">${item.status === 'closed' ? 'مغلقة' : 'مفتوحة'}</span>
              <span class="support-item-pill support-item-pill-direction">${escapeHtml(item.latestDirectionLabel || '-')}</span>
            </div>
            <div class="support-item-sub support-item-route">
              <span><b>من:</b> ${escapeHtml(item.latestSenderLabel || item.senderName || '-')}</span>
              <span><b>إلى:</b> ${escapeHtml(item.latestReceiverLabel || 'الدعم الفني')}</span>
            </div>
            <div class="support-item-sub">المعرف: ${escapeHtml(item.userId || '-')}
            </div>
            <div class="support-item-sub support-item-conversation">الخيط: ${escapeHtml(item.conversationId || item.id)}</div>
            <div class="support-item-preview">${escapeHtml(item.preview || '-')}</div>
          </button>
        `;
      })
      .join('');

    supportConversationList.querySelectorAll('[data-support-conversation]').forEach((btn) => {
      btn.addEventListener('click', () => {
        supportSelectedConversationId = btn.getAttribute('data-support-conversation') || '';
        showSupportMobileThread(true);
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
      <div class="support-header-title">${escapeHtml(convo.senderName || convo.userId || convo.id)}</div>
      <div class="support-header-meta">
        <span class="support-item-pill">${escapeHtml(appLabel)}</span>
        <span class="support-item-pill">${escapeHtml(convo.actor)}</span>
        <span class="support-item-pill ${convo.status === 'closed' ? 'closed' : 'open'}">${convo.status === 'closed' ? 'مغلقة' : 'مفتوحة'}</span>
      </div>
      <div class="support-header-meta support-header-meta--dim">
        <span class="kv"><b>معرف المستخدم:</b> ${escapeHtml(convo.userId || '-')}</span>
        <span class="kv"><b>معرف الخيط:</b> ${escapeHtml(convo.conversationId || convo.id)}</span>
      </div>
    `;

    const messagesMarkup = messages.length
      ? messages.map((msg, index) => {
          const mine = isSupportAdminMessage(msg);
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
          const senderLabel = getReadableSenderName(msg);
          const receiverLabel = getReceiverLabel(msg);
          const directionLabel = mine ? 'صادر من الدعم' : 'وارد إلى الدعم';
          const messageTypeLabel = msg.imageUrl
            ? (String(msg.message || '').trim() ? 'نص + صورة' : 'صورة')
            : 'نص';
          const refValue = getSupportReference(msg, convo);
          const appScopeLabel = getAppLabel(convo.sourceApp || normalizeApp(msg.sourceApp || 'client'));
          const statusText = String(msg.status || convo.status || 'open') === 'closed' ? 'مغلقة' : 'مفتوحة';
          return `
            <div class="support-message-row ${mine ? 'support-message-row--mine' : 'support-message-row--other'}" data-support-message-index="${index}" ${isUnreadForAdmin ? 'data-support-unread="true"' : ''}>
              <div class="support-bubble ${mine ? 'mine' : 'other'}">
                <div class="support-bubble-head">${escapeHtml(senderLabel)}</div>
                <div class="support-bubble-meta">
                  <span class="support-meta-chip">${escapeHtml(directionLabel)}</span>
                  <span class="support-meta-chip">${escapeHtml(messageTypeLabel)}</span>
                  <span class="support-meta-chip">${escapeHtml(appScopeLabel)}</span>
                  <span class="support-meta-chip ${statusText === 'مغلقة' ? 'closed' : 'open'}">${escapeHtml(statusText)}</span>
                </div>
                <div class="support-bubble-identifiers">
                  <span><b>من:</b> ${escapeHtml(senderLabel)}</span>
                  <span><b>إلى:</b> ${escapeHtml(receiverLabel)}</span>
                  <span><b>المرجع:</b> ${escapeHtml(refValue)}</span>
                </div>
                <div>${body}</div>
                <div class="support-bubble-time">${escapeHtml(msg.timeText)}</div>
              </div>
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
    if (supportMarkReadBtn) supportMarkReadBtn.disabled = !(convo.unreadCount > 0);
    supportReplyInput.disabled = convo.status === 'closed';
    supportToggleStatusBtn.textContent = convo.status === 'closed' ? 'إعادة فتح المحادثة' : 'إغلاق المحادثة';
    syncComposerState();

    if (convo.unreadCount > 0) {
      convo.unreadCount = 0;
      renderConversationList();
      markConversationReadIfNeeded(convo);
    }

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
        conversationId: convo.conversationId || convo.id,
        supportThreadKey: getSupportThreadBaseKey(convo.id),
        chatKind: 'support',
        sourceApp: convo.sourceApp,
        senderId: auth.currentUser?.uid || '',
        senderType: 'admin',
        senderName: 'الدعم الفني',
        receiverId: userId,
        receiverType: convo.sourceApp === 'courier'
          ? 'courier'
          : (convo.sourceApp === 'store' ? 'store' : 'client'),
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
      const q = query(collection(db, 'supportMessages'), where('conversationId', '==', convo.conversationId || supportSelectedConversationId));
      const result = await getDocs(q);
      const batch = writeBatch(db);
      let updates = 0;
      result.docs.forEach((docSnap) => {
        if (buildSupportThreadKeyFromData(docSnap.data() || {}) !== convo.id) {
          return;
        }
        batch.update(doc(db, 'supportMessages', docSnap.id), {
          status: nextStatus,
          updatedAt: serverTimestamp(),
          ...(nextStatus === 'closed' ? { closedAt: serverTimestamp() } : { reopenedAt: serverTimestamp() }),
        });
        updates += 1;
      });
      if (updates > 0) await batch.commit();
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
        const convo = supportConversations.find((item) => item.id === supportSelectedConversationId);
        if (!convo) return;
        await markSupportConversationRead(convo);
        convo.unreadCount = 0;
        renderConversationList();
        renderSelectedConversation();
      } catch (err) {
        alert(`تعذر تعليم المحادثة كمقروءة: ${err.message || err}`);
      }
    });
    supportMobileBackBtn?.addEventListener('click', () => {
      showSupportMobileThread(false);
      renderConversationList();
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

        const supportThreadKey = buildSupportThreadKeyFromData(data);
        if (!supportThreadKey) return;

        const message = {
          id: d.id,
          ...data,
          timestampMillis: getMillis(data.timestamp),
          timeText: fmtTime(data.timestamp),
          supportThreadKey,
        };

        if (!messagesMap.has(supportThreadKey)) {
          messagesMap.set(supportThreadKey, []);
        }
        messagesMap.get(supportThreadKey).push(message);

        if (!conversationMap.has(supportThreadKey)) {
          conversationMap.set(supportThreadKey, message);
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
          const latestMine = isSupportAdminMessage(latestMsg);
          const latestSenderLabel = getReadableSenderName(latestMsg);
          const latestReceiverLabel = getReceiverLabel(latestMsg);
          const userId = String(latestMsg.userId || latestMsg.senderId || latestMsg.receiverId || '').trim()
            || (String(latestMsg.conversationId || '').endsWith('-support')
              ? String(latestMsg.conversationId || '').slice(0, -'-support'.length)
              : '');
          return {
            id,
            conversationId: String(latestMsg.conversationId || latest.conversationId || id),
            actor,
            sourceApp,
            status: String(latestMsg.status || 'open') === 'closed' ? 'closed' : 'open',
            senderName: getConversationDisplayName(all, latestMsg),
            preview: latestMsg.message || (latestMsg.imageUrl ? '📷 صورة مرفقة' : '-'),
            latestMillis: latestMsg.timestampMillis || 0,
            latestTimeText: latestMsg.timeText || '-',
            latestDirectionLabel: latestMine ? 'آخر رسالة: من الدعم' : 'آخر رسالة: من المستخدم',
            latestSenderLabel,
            latestReceiverLabel,
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
  let editingDiscountCode = '';

  const syncDiscountRestaurantField = () => {
    const isSelectedScope = discountRestaurantScope?.value === 'selected';
    if (discountRestaurantsField) discountRestaurantsField.hidden = !isSelectedScope;
    if (discountRestaurantIds) discountRestaurantIds.required = isSelectedScope;
  };

  const syncDiscountPolicyFields = () => {
    const isFixedDeliveryPrice = discountType?.value === 'delivery_fixed_price';
    const isTieredDiscount = discountType?.value === 'tiered_order_discount';
    const tierUsesFixedDeliveryPrice = discountFirstOrderType?.value === 'delivery_fixed_price'
      || discountReturningType?.value === 'delivery_fixed_price';
    if ((isFixedDeliveryPrice || (isTieredDiscount && tierUsesFixedDeliveryPrice)) && discountScope) {
      discountScope.value = 'delivery_fee';
    }
    if (discountTieredFields) discountTieredFields.hidden = !isTieredDiscount;
    if (discountValueLabel) discountValueLabel.hidden = isTieredDiscount;
    if (discountValue) discountValue.required = !isTieredDiscount;
    if (discountEligibilityField) discountEligibilityField.hidden = isTieredDiscount;
    if (isTieredDiscount && discountEligibility) discountEligibility.value = 'all_customers';
    if (discountValueLabel) {
      discountValueLabel.firstChild.textContent = isFixedDeliveryPrice
        ? 'سعر التوصيل بعد الخصم '
        : 'قيمة الخصم ';
    }
    if (discountValue && !isTieredDiscount) {
      discountValue.placeholder = isFixedDeliveryPrice ? '1000' : '20';
    }
    const needsOrderNumber = !isTieredDiscount && discountEligibility?.value === 'exact_order_number';
    if (discountTargetOrderField) discountTargetOrderField.hidden = !needsOrderNumber;
    if (discountTargetOrderNumber) discountTargetOrderNumber.required = needsOrderNumber;
  };

  const selectedDiscountRestaurantIds = () => Array.from(discountRestaurantIds?.selectedOptions || [])
    .map((option) => String(option.value || '').trim())
    .filter(Boolean);

  const formatDateTimeInput = (value) => {
    if (!value || typeof value.toDate !== 'function') return '';
    const date = value.toDate();
    const pad = (part) => String(part).padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
  };

  const resetDiscountEditor = () => {
    editingDiscountCode = '';
    discountForm.reset();
    if (discountIsActive) discountIsActive.checked = true;
    if (discountScope) discountScope.value = 'order_total';
    if (discountType) discountType.value = 'percent';
    if (discountEligibility) discountEligibility.value = 'all_customers';
    if (discountTargetOrderNumber) discountTargetOrderNumber.value = '2';
    if (discountFirstOrderType) discountFirstOrderType.value = 'fixed';
    if (discountFirstOrderValue) discountFirstOrderValue.value = '';
    if (discountReturningType) discountReturningType.value = 'percent';
    if (discountReturningValue) discountReturningValue.value = '';
    if (discountRestaurantScope) discountRestaurantScope.value = 'all';
    if (discountRestaurantIds) Array.from(discountRestaurantIds.options).forEach((option) => { option.selected = false; });
    syncDiscountRestaurantField();
    syncDiscountPolicyFields();
    if (discountSaveBtn) discountSaveBtn.textContent = 'حفظ الكود';
    if (discountCancelEditBtn) discountCancelEditBtn.hidden = true;
  };

  const beginDiscountEdit = (sourceCode, data) => {
    editingDiscountCode = sourceCode;
    if (discountCode) discountCode.value = sourceCode;
    if (discountScope) discountScope.value = String(data.discountScope || 'order_total');
    if (discountType) discountType.value = String(data.discountType || 'percent');
    if (discountValue) discountValue.value = String(data.discountValue ?? '');
    if (discountEligibility) {
      discountEligibility.value = String(
        data.eligibility || (data.onlyForNewOrders === true ? 'first_order' : 'all_customers')
      );
    }
    if (discountTargetOrderNumber) discountTargetOrderNumber.value = String(data.targetOrderNumber || 2);
    const tieredDiscount = data.tieredDiscount || {};
    if (discountFirstOrderType) discountFirstOrderType.value = String(tieredDiscount.firstOrder?.type || 'fixed');
    if (discountFirstOrderValue) discountFirstOrderValue.value = String(tieredDiscount.firstOrder?.value ?? '');
    if (discountReturningType) discountReturningType.value = String(tieredDiscount.returning?.type || 'percent');
    if (discountReturningValue) discountReturningValue.value = String(tieredDiscount.returning?.value ?? '');
    if (discountMinOrder) discountMinOrder.value = String(data.minOrder ?? '');
    if (discountMaxUsage) discountMaxUsage.value = String(data.maxUsage ?? '');
    if (discountMaxUsagePerRestaurant) discountMaxUsagePerRestaurant.value = String(data.maxUsagePerRestaurant ?? '');
    if (discountMaxUsagePerUser) discountMaxUsagePerUser.value = String(data.maxUsagePerUser ?? '');
    if (discountMaxDiscount) discountMaxDiscount.value = String(data.maxDiscount ?? '');
    const restaurantIds = Array.isArray(data.restaurantIds)
      ? data.restaurantIds.map((id) => String(id || '').trim()).filter(Boolean)
      : (data.restaurantId ? [String(data.restaurantId).trim()] : []);
    if (discountRestaurantScope) discountRestaurantScope.value = restaurantIds.length ? 'selected' : 'all';
    if (discountRestaurantIds) {
      Array.from(discountRestaurantIds.options).forEach((option) => {
        option.selected = restaurantIds.includes(option.value);
      });
    }
    syncDiscountRestaurantField();
    syncDiscountPolicyFields();
    if (discountItemName) discountItemName.value = String(data.itemName || '');
    if (discountExpiryDate) discountExpiryDate.value = formatDateTimeInput(data.expiryDate);
    if (discountIsActive) discountIsActive.checked = data.isActive === true;
    if (discountSaveBtn) discountSaveBtn.textContent = 'حفظ التعديلات';
    if (discountCancelEditBtn) discountCancelEditBtn.hidden = false;
    if (discountResult) discountResult.textContent = `تعديل الكود ${sourceCode}: يمكنك تغيير الكود أو الشروط ثم الحفظ.`;
    discountCode?.focus();
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
    discountRestaurantScope?.addEventListener('change', syncDiscountRestaurantField);
    discountType?.addEventListener('change', syncDiscountPolicyFields);
    discountEligibility?.addEventListener('change', syncDiscountPolicyFields);
    discountFirstOrderType?.addEventListener('change', syncDiscountPolicyFields);
    discountReturningType?.addEventListener('change', syncDiscountPolicyFields);
    discountCancelEditBtn?.addEventListener('click', () => {
      resetDiscountEditor();
      if (discountResult) discountResult.textContent = 'تم إلغاء التعديل.';
    });
    discountForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const code = String(discountCode?.value || '').trim().toUpperCase();
      const scope = String(discountScope?.value || 'order_total').trim().toLowerCase();
      const type = String(discountType?.value || 'percent').trim().toLowerCase();
      const eligibility = String(discountEligibility?.value || 'all_customers').trim().toLowerCase();
      const targetOrderNumber = Math.max(1, Math.floor(Number(discountTargetOrderNumber?.value || 2)));
      const value = parseNumberOrNull(discountValue?.value);
      const expiryRaw = String(discountExpiryDate?.value || '').trim();
      const expiryMillis = Date.parse(expiryRaw);
      const restaurantScope = String(discountRestaurantScope?.value || 'all');
      const restaurantIds = restaurantScope === 'selected' ? selectedDiscountRestaurantIds() : [];
      const tieredDiscount = type === 'tiered_order_discount'
        ? {
          firstOrder: {
            type: String(discountFirstOrderType?.value || '').trim().toLowerCase(),
            value: parseNumberOrNull(discountFirstOrderValue?.value),
          },
          returning: {
            type: String(discountReturningType?.value || '').trim().toLowerCase(),
            value: parseNumberOrNull(discountReturningValue?.value),
          },
        }
        : null;

      if (!code) {
        if (discountResult) discountResult.textContent = 'يرجى إدخال كود الخصم.';
        return;
      }
      if (!['percent', 'fixed', 'delivery_fixed_price', 'tiered_order_discount'].includes(type)) {
        if (discountResult) discountResult.textContent = 'نوع الخصم غير صالح.';
        return;
      }
      if (!['order_total', 'delivery_fee'].includes(scope)) {
        if (discountResult) discountResult.textContent = 'نطاق الخصم غير صالح.';
        return;
      }
      if (type === 'delivery_fixed_price' && scope !== 'delivery_fee') {
        if (discountResult) discountResult.textContent = 'السعر النهائي ثابت متاح لرسوم التوصيل فقط.';
        return;
      }
      if (type === 'tiered_order_discount') {
        const tiers = [tieredDiscount?.firstOrder, tieredDiscount?.returning];
        const tierIsValid = tiers.every((tier) => tier
          && ['percent', 'fixed', 'delivery_fixed_price'].includes(tier.type)
          && Number.isFinite(tier.value)
          && tier.value > 0
          && (tier.type !== 'delivery_fixed_price' || scope === 'delivery_fee'));
        if (!tierIsValid) {
          if (discountResult) discountResult.textContent = 'أدخل نوعًا وقيمة صحيحة للأول وللطلب الثاني فما بعد. سعر التوصيل الثابت يتطلب نطاق التوصيل.';
          return;
        }
      }
      if (eligibility === 'exact_order_number' && !Number.isFinite(targetOrderNumber)) {
        if (discountResult) discountResult.textContent = 'أدخل رقم طلب صحيحًا.';
        return;
      }
      if (type !== 'tiered_order_discount' && (value == null || value <= 0)) {
        if (discountResult) discountResult.textContent = 'قيمة الخصم يجب أن تكون أكبر من صفر.';
        return;
      }
      if (!Number.isFinite(expiryMillis)) {
        if (discountResult) discountResult.textContent = 'يرجى إدخال تاريخ انتهاء صحيح.';
        return;
      }
      if (restaurantScope === 'selected' && restaurantIds.length === 0) {
        if (discountResult) discountResult.textContent = 'اختر مطعمًا واحدًا على الأقل أو غيّر النطاق إلى كل المطاعم.';
        return;
      }

      const payload = {
        code,
        discountScope: scope,
        discountType: type,
        discountValue: type === 'tiered_order_discount' ? 0 : value,
        isActive: discountIsActive?.checked === true,
        eligibility: type === 'tiered_order_discount' ? 'all_customers' : eligibility,
        targetOrderNumber,
        tieredDiscount,
        restaurantIds,
        itemName: scope === 'delivery_fee' ? '' : String(discountItemName?.value || '').trim(),
        minOrder: parseNumberOrNull(discountMinOrder?.value),
        maxUsage: parseNumberOrNull(discountMaxUsage?.value),
        maxUsagePerRestaurant: parseNumberOrNull(discountMaxUsagePerRestaurant?.value),
        maxUsagePerUser: parseNumberOrNull(discountMaxUsagePerUser?.value),
        maxDiscount: parseNumberOrNull(discountMaxDiscount?.value),
        expiryDate: new Date(expiryMillis),
      };

      if (discountSaveBtn) discountSaveBtn.disabled = true;
      if (discountResult) discountResult.textContent = 'جارٍ حفظ كود الخصم...';

      try {
        if (editingDiscountCode) {
          const result = await adminUpdatePromocode({
            sourceCode: editingDiscountCode,
            promo: {
              ...payload,
              expiryMillis,
            },
          });
          const renamed = result.data?.renamed === true;
          if (discountResult) {
            discountResult.textContent = renamed
              ? `تم تغيير الكود من ${editingDiscountCode} إلى ${code} مع الاحتفاظ بعدادات الاستخدام.`
              : `تم تحديث الكود ${code} بنجاح.`;
          }
        } else {
          await adminUpdatePromocode({
            sourceCode: '',
            promo: {
              ...payload,
              expiryMillis,
            },
          });
          if (discountResult) discountResult.textContent = `تم حفظ الكود ${code} بنجاح.`;
        }
        resetDiscountEditor();
      } catch (err) {
        if (discountResult) discountResult.textContent = `تعذر حفظ الكود: ${err.message || err}`;
      } finally {
        if (discountSaveBtn) discountSaveBtn.disabled = false;
      }
    });
    discountFormBound = true;
  }

  syncDiscountRestaurantField();
  syncDiscountPolicyFields();
  unsubscribers.push(
    onSnapshot(query(collection(db, 'restaurants'), limit(500)), (snap) => {
      if (!discountRestaurantIds) return;
      const selected = new Set(selectedDiscountRestaurantIds());
      const restaurants = snap.docs
        .map((docSnap) => ({ id: docSnap.id, data: docSnap.data() || {} }))
        .filter((item) => {
          const status = String(item.data.approvalStatus || '').trim().toLowerCase();
          return !status || status === 'approved' || item.data.active === true;
        })
        .sort((a, b) => String(a.data.name || a.id).localeCompare(String(b.data.name || b.id), 'ar'));
      discountRestaurantIds.innerHTML = restaurants.map((item) => {
        const name = String(item.data.name || item.data.restaurantName || item.id).trim();
        const isSelected = selected.has(item.id) ? ' selected' : '';
        return `<option value="${escapeHtml(item.id)}"${isSelected}>${escapeHtml(name)}</option>`;
      }).join('');
    })
  );

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
        const maxUsagePerRestaurant = Number(data.maxUsagePerRestaurant || 0);
        const capText = Number(data.maxDiscount || 0) > 0 ? ` (سقف ${Number(data.maxDiscount)})` : '';
        const scopeLabel = DISCOUNT_SCOPE_LABELS[String(data.discountScope || 'order_total').trim().toLowerCase()] || 'إجمالي الطلب';
        const eligibilityLabels = {
          all_customers: 'كل العملاء',
          first_order: 'أول طلب فقط',
          returning_customer: 'الطلب الثاني فما بعد',
          exact_order_number: `الطلب رقم ${Number(data.targetOrderNumber || 2)}`,
        };
        const eligibility = String(data.eligibility || (data.onlyForNewOrders ? 'first_order' : 'all_customers'));
        const typeLabel = data.discountType === 'delivery_fixed_price'
          ? 'توصيل بسعر ثابت'
          : data.discountType === 'tiered_order_discount'
            ? 'خصم متدرج حسب الطلب'
            : String(data.discountType || '-');
        const tieredDiscount = data.tieredDiscount || {};
        const formatTier = (tier) => `${tier?.type === 'percent' ? '%' : tier?.type === 'delivery_fixed_price' ? 'سعر توصيل' : 'ثابت'} ${Number(tier?.value || 0)}`;
        const valueLabel = data.discountType === 'tiered_order_discount'
          ? `الأول: ${formatTier(tieredDiscount.firstOrder)} | الثاني+: ${formatTier(tieredDiscount.returning)}`
          : data.discountType === 'delivery_fixed_price'
          ? `${Number(data.discountValue || 0)} ج.س نهائيًا`
          : `${Number(data.discountValue || 0)}${capText}`;

        return `<tr>
          <td>${escapeHtml(code)}</td>
          <td>${escapeHtml(scopeLabel)}</td>
          <td>${escapeHtml(typeLabel)}</td>
          <td>${escapeHtml(valueLabel)}</td>
          <td>${escapeHtml(eligibilityLabels[eligibility] || 'كل العملاء')}</td>
          <td>${usedCount}${maxUsage > 0 ? ` / ${maxUsage}` : ''}</td>
          <td>${Array.isArray(data.restaurantIds) && data.restaurantIds.length ? `${data.restaurantIds.length} مطاعم` : 'كل المطاعم'}${maxUsagePerRestaurant > 0 ? ` · ${maxUsagePerRestaurant} لكل مطعم` : ''}</td>
          <td>${formatDateTimeLocal(data.expiryDate)}</td>
          <td><span class="badge ${active ? 'closed' : 'open'}">${active ? 'مفعل' : 'موقوف'}</span></td>
          <td>
            <button class="btn ghost" data-edit-discount="${escapeHtml(code)}">تعديل</button>
            <button class="btn ghost" data-toggle-discount="${escapeHtml(code)}" data-active="${active ? 'true' : 'false'}">${active ? 'إيقاف' : 'تفعيل'}</button>
            <button class="btn danger" data-delete-discount="${escapeHtml(code)}">حذف</button>
          </td>
        </tr>`;
      });

      setHtml(discountsTable, table(['الكود', 'النطاق', 'النوع', 'القيمة', 'الأهلية', 'الاستخدام', 'المطاعم', 'ينتهي في', 'الحالة', 'إجراء'], rows));

      discountsTable.querySelectorAll('[data-edit-discount]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const code = btn.getAttribute('data-edit-discount');
          const promoDoc = docs.find((item) => String(item.id) === String(code));
          if (code && promoDoc) beginDiscountEdit(code, promoDoc.data() || {});
        });
      });

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
  if (storeBatchMaxStopsPerTripInput) storeBatchMaxStopsPerTripInput.value = String(getRemoteConfigEntry('store_batch_max_stops_per_trip')?.value || '8');
  if (storeBatchSingleTripMaxStopsInput) storeBatchSingleTripMaxStopsInput.value = String(getRemoteConfigEntry('store_batch_single_trip_max_stops')?.value || '5');
  if (storeBatchSingleTripMaxRouteKmInput) storeBatchSingleTripMaxRouteKmInput.value = String(getRemoteConfigEntry('store_batch_single_trip_max_route_km')?.value || '45');
  if (storeBatchMaxRouteKmPerTripInput) storeBatchMaxRouteKmPerTripInput.value = String(getRemoteConfigEntry('store_batch_max_route_km_per_trip')?.value || '55');
  if (storeBatchGroupUnclusteredZonesInput) storeBatchGroupUnclusteredZonesInput.value = String(getRemoteConfigEntry('store_batch_group_unclustered_zones')?.value || 'true');
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
  clientUpdateUrlAndroidInput.value = String(getRemoteConfigEntry('client_update_url_android')?.value || 'https://speedstarapp.web.app/downloads/client-android.zip');
  clientRootUrlInput.value = String(getRemoteConfigEntry('client_root_url')?.value || 'https://speedstar-prod-4c7c5.web.app/sdui/client/index.json');
  if (clientOptionalUpdateEnabledInput) clientOptionalUpdateEnabledInput.value = String(getRemoteConfigEntry('client_optional_update_enabled')?.value || 'false');
  if (clientRecommendedBuildAndroidInput) clientRecommendedBuildAndroidInput.value = String(getRemoteConfigEntry('client_recommended_build_android')?.value || '0');
  if (clientOptionalUpdateMessageInput) clientOptionalUpdateMessageInput.value = String(getRemoteConfigEntry('client_optional_update_message')?.value || 'يتوفر إصدار جديد من تطبيق SpeedStar. ننصحك بالتحديث للحصول على أفضل تجربة.');
  if (paymentReceiptPrecheckEnabledInput) paymentReceiptPrecheckEnabledInput.value = String(getRemoteConfigEntry('payment_receipt_precheck_enabled')?.value || 'true');
  if (paymentReceiptPrecheckModeInput) paymentReceiptPrecheckModeInput.value = String(getRemoteConfigEntry('payment_receipt_precheck_mode')?.value || 'block');
  if (paymentReceiptRequireImageInput) paymentReceiptRequireImageInput.value = String(getRemoteConfigEntry('payment_receipt_require_image')?.value || 'true');
  if (paymentReceiptRequireReferenceInput) paymentReceiptRequireReferenceInput.value = String(getRemoteConfigEntry('payment_receipt_require_reference')?.value || 'true');
  if (paymentReceiptMinReferenceDigitsInput) paymentReceiptMinReferenceDigitsInput.value = String(getRemoteConfigEntry('payment_receipt_min_reference_digits')?.value || '8');
  if (paymentReceiptRequirementsMessageInput) paymentReceiptRequirementsMessageInput.value = String(getRemoteConfigEntry('payment_receipt_requirements_message')?.value || 'ارفع إيصالاً واضحاً يظهر فيه رقم العملية والمبلغ والحساب المحوّل إليه، ثم أدخل رقم العملية كاملاً.');
  if (paymentReceiptMissingImageMessageInput) paymentReceiptMissingImageMessageInput.value = String(getRemoteConfigEntry('payment_receipt_missing_image_message')?.value || 'ارفع صورة إيصال واضحة قبل إرسال الطلب.');
  if (paymentReceiptMissingReferenceMessageInput) paymentReceiptMissingReferenceMessageInput.value = String(getRemoteConfigEntry('payment_receipt_missing_reference_message')?.value || 'أدخل رقم العملية كاملاً كما يظهر في الإيصال.');
  if (paymentReceiptShortReferenceMessageInput) paymentReceiptShortReferenceMessageInput.value = String(getRemoteConfigEntry('payment_receipt_short_reference_message')?.value || 'رقم العملية يبدو ناقصاً. تأكد من إدخاله كاملاً من الإيصال.');
  if (paymentReceiptInvalidAmountMessageInput) paymentReceiptInvalidAmountMessageInput.value = String(getRemoteConfigEntry('payment_receipt_invalid_amount_message')?.value || 'مبلغ الدفع غير واضح. أعد المحاولة أو تواصل مع الدعم.');
  if (paymentReceiptWarningTitleInput) paymentReceiptWarningTitleInput.value = String(getRemoteConfigEntry('payment_receipt_warning_title')?.value || 'راجع بيانات الإيصال قبل المتابعة');
  storeForceUpdateEnabledInput.value = String(getRemoteConfigEntry('store_force_update_enabled')?.value || 'true');
  storeMinBuildAndroidInput.value = String(getRemoteConfigEntry('store_min_build_android')?.value || '5');
  storeUpdateMessageInput.value = String(getRemoteConfigEntry('store_update_message')?.value || 'يرجى تحديث تطبيق المتجر للاستمرار.');
  storeUpdateUrlAndroidInput.value = String(getRemoteConfigEntry('store_update_url_android')?.value || 'https://speedstarapp.web.app/downloads/store-android.zip');
  storeRootUrlInput.value = String(getRemoteConfigEntry('store_root_url')?.value || 'https://speedstar-prod-4c7c5.web.app/sdui/store/index.json');
  courierForceUpdateEnabledInput.value = String(getRemoteConfigEntry('courier_force_update_enabled')?.value || 'false');
  courierMinBuildAndroidInput.value = String(getRemoteConfigEntry('courier_min_build_android')?.value || '1');
  courierUpdateMessageInput.value = String(getRemoteConfigEntry('courier_update_message')?.value || 'يرجى تحديث تطبيق المندوب للاستمرار.');
  courierUpdateUrlAndroidInput.value = String(getRemoteConfigEntry('courier_update_url_android')?.value || 'https://speedstarapp.web.app/downloads/courier-android.zip');
  courierRootUrlInput.value = String(getRemoteConfigEntry('courier_root_url')?.value || 'https://speedstar-prod-4c7c5.web.app/sdui/courier/index.json');
}

const REMOTE_CONFIG_GROUPS = [
  { id: 'operations', title: 'التحكم التشغيلي العام', description: 'إعدادات مشتركة تؤثر على التطبيقات الثلاثة.' },
  { id: 'client', title: 'تطبيق العميل', description: 'الواجهة والطلب والتحديثات الخاصة بالعميل.' },
  { id: 'store', title: 'تطبيق المتجر', description: 'تنبيهات وتشغيل وإصدارات تطبيق المتجر.' },
  { id: 'courier', title: 'تطبيق المندوب', description: 'العروض والتنبيهات وإصدارات تطبيق المندوب.' },
  { id: 'pricing', title: 'التسعير والرسوم', description: 'رسوم التوصيل والطلبات الكبيرة.' },
  { id: 'other', title: 'إعدادات إضافية', description: 'مفاتيح Remote Config الأخرى المتاحة.' },
];

function remoteConfigGroupId(key) {
  if (key.startsWith('pricing_')) return 'pricing';
  if (key.startsWith('store_batch_')) return 'pricing';
  if (key.startsWith('client_')) return 'client';
  if (key.startsWith('store_')) return 'store';
  if (key.startsWith('courier_')) return 'courier';
  if (key.startsWith('ops_')) return 'operations';
  return 'other';
}

function remoteConfigLabel(key, meta) {
  if (meta?.label) return String(meta.label);
  return `إعداد: ${String(key).replaceAll('_', ' ')}`;
}

function remoteConfigControl(item, valueType) {
  const key = String(item.key || '');
  const value = String(item.value ?? '');
  const escapedKey = escapeHtml(key);
  const escapedValue = escapeHtml(value);
  const attributes = `class="remote-control-input" data-remote-key="${escapedKey}" data-remote-type="${escapeHtml(valueType)}"`;

  if (valueType === 'BOOLEAN') {
    const checked = value.toLowerCase() === 'true' ? 'checked' : '';
    return `<label class="remote-switch" title="انقر للتشغيل أو الإيقاف">
      <input ${attributes} type="checkbox" ${checked} />
      <span class="remote-switch-track" aria-hidden="true"></span>
      <span class="remote-switch-state">${checked ? 'مفعّل' : 'متوقف'}</span>
    </label>`;
  }

  if (key === 'client_delivery_time_mode') {
    const options = [
      ['hybrid', 'هجين: إعداد المطعم مع زمن الطريق'],
      ['admin_only', 'إعداد المطعم فقط'],
      ['computed', 'محسوب من الطريق فقط'],
    ];
    return `<select ${attributes}>${options.map(([optionValue, label]) => `<option value="${optionValue}" ${value === optionValue ? 'selected' : ''}>${label}</option>`).join('')}</select>`;
  }

  if (key.endsWith('_ringtone_volume')) {
    const normalized = Math.max(0, Math.min(1, Number(value) || 0));
    return `<div class="remote-range-control">
      <input ${attributes} type="range" min="0" max="1" step="0.05" value="${normalized}" />
      <output data-remote-output="${escapedKey}">${Math.round(normalized * 100)}%</output>
    </div>`;
  }

  if (valueType === 'NUMBER') {
    const min = key.includes('volume') ? ' min="0" max="1" step="0.05"' : ' min="0" step="1"';
    return `<input ${attributes} type="number"${min} value="${escapedValue}" />`;
  }

  if (key.includes('message') || key.includes('disabled_message') || key.includes('block_message')) {
    return `<textarea ${attributes} rows="2">${escapedValue}</textarea>`;
  }

  const inputType = key.includes('url') ? 'url' : 'text';
  return `<input ${attributes} type="${inputType}" value="${escapedValue}" />`;
}

function bindRemoteConfigControls() {
  remoteConfigTable?.querySelectorAll('.remote-control-input').forEach((input) => {
    input.addEventListener('input', () => {
      const item = input.closest('.remote-config-item');
      item?.classList.add('is-dirty');
      if (input.type === 'range') {
        const output = remoteConfigTable.querySelector(`[data-remote-output="${input.dataset.remoteKey}"]`);
        if (output) output.textContent = `${Math.round(Number(input.value || 0) * 100)}%`;
      }
      if (input.type === 'checkbox') {
        const state = input.closest('.remote-switch')?.querySelector('.remote-switch-state');
        if (state) state.textContent = input.checked ? 'مفعّل' : 'متوقف';
      }
    });
  });
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

  const grouped = new Map(REMOTE_CONFIG_GROUPS.map((group) => [group.id, []]));
  for (const item of filtered) grouped.get(remoteConfigGroupId(String(item.key || ''))).push(item);

  const groupsMarkup = REMOTE_CONFIG_GROUPS.map((group) => {
    const items = grouped.get(group.id) || [];
    if (!items.length) return '';
    const itemMarkup = items
      .sort((left, right) => remoteConfigLabel(String(left.key || ''), REMOTE_CONFIG_METADATA[String(left.key || '')]).localeCompare(remoteConfigLabel(String(right.key || ''), REMOTE_CONFIG_METADATA[String(right.key || '')]), 'ar'))
      .map((item) => {
        const key = String(item.key || '');
        const meta = REMOTE_CONFIG_METADATA[key] || null;
        const valueType = String(meta?.valueType || item.valueType || 'STRING').toUpperCase();
        const description = String(meta?.description || item.description || 'إعداد متقدم من Remote Config.').trim();
        const tags = [valueType, item.isManagedDefault ? 'يحتاج تهيئة' : '', item.hasConditionalValues ? 'له قيم شرطية' : ''].filter(Boolean);
        return `<article class="remote-config-item" data-remote-item="${escapeHtml(key)}">
          <div class="remote-config-item-copy">
            <h4>${escapeHtml(remoteConfigLabel(key, meta))}</h4>
            <p>${escapeHtml(description)}</p>
            <div class="remote-config-item-meta">
              <code>${escapeHtml(key)}</code>
              ${tags.map((tag) => `<span>${escapeHtml(tag)}</span>`).join('')}
            </div>
          </div>
          <div class="remote-config-item-control">${remoteConfigControl(item, valueType)}</div>
        </article>`;
      }).join('');
    return `<section class="remote-config-group" data-remote-group="${group.id}">
      <header><div><h3>${group.title}</h3><p>${group.description}</p></div><b>${items.length}</b></header>
      <div class="remote-config-items">${itemMarkup}</div>
    </section>`;
  }).join('');

  setHtml(remoteConfigTable, `<div class="remote-config-toolbar"><span>المفاتيح الظاهرة: <strong>${filtered.length}</strong></span><span>التغييرات تُحفظ دفعة واحدة</span></div><div class="remote-config-groups">${groupsMarkup}</div>`);
  bindRemoteConfigControls();
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

async function loadStoreHomeConfigTargetOptions() {
  if (!storeHomeConfigTarget) return;
  const selected = storeHomeConfigTarget.value;
  const snapshot = await getDocs(collection(db, 'restaurants'));
  const stores = snapshot.docs
    .map((entry) => ({ id: entry.id, ...entry.data() }))
    .filter((entry) => String(entry.approvalStatus || '') === 'approved')
    .sort((left, right) => String(left.name || '').localeCompare(String(right.name || ''), 'ar'));
  storeHomeConfigTarget.innerHTML = [
    '<option value="">اختر منشأة</option>',
    ...stores.map((store) => `<option value="${escapeHtml(store.id)}">${escapeHtml(String(store.name || store.id))}</option>`),
  ].join('');
  if (selected) storeHomeConfigTarget.value = selected;
}

async function loadSelectedStoreHomeConfig() {
  const storeId = String(storeHomeConfigTarget?.value || '').trim();
  if (!storeId) return;
  const snapshot = await getDoc(doc(db, 'restaurants', storeId));
  const data = snapshot.data() || {};
  if (storeHomeFeaturedInput) storeHomeFeaturedInput.checked = data.featuredOnHome === true;
  if (storeHomeOffersInput) storeHomeOffersInput.checked = data.showInHomeOffers === true;
}

async function saveClientHomeImages() {
  const inputs = Array.from(clientHomeImagesForm?.querySelectorAll('[data-business-image]') || []);
  const currentSnapshot = await getDoc(doc(db, 'clientHomeSettings', 'default'));
  const images = { ...(currentSnapshot.data()?.businessFilterImages || {}) };
  for (const input of inputs) {
    const file = input.files?.[0];
    const key = String(input.dataset.businessImage || '').trim();
    if (!file || !key) continue;
    const imageUrl = await uploadImageToCloudinary(file, `client-home-${key}-${Date.now()}.jpg`);
    if (!imageUrl) throw new Error(`تعذر رفع صورة قسم ${key}`);
    images[key] = imageUrl;
  }
  await setDoc(doc(db, 'clientHomeSettings', 'default'), {
    businessFilterImages: images,
    updatedAt: serverTimestamp(),
    updatedByUid: auth.currentUser?.uid || '',
  }, { merge: true });
}

async function loadRewardsConfig() {
  if (!rewardsConfigForm) return;
  const snapshot = await getDoc(doc(db, 'clientHomeSettings', 'default'));
  const config = snapshot.data()?.rewards || {};
  if (rewardsEnabledInput) rewardsEnabledInput.checked = config.enabled === true;
  if (rewardsAmountPerPointInput) rewardsAmountPerPointInput.value = Math.max(1, Number(config.amountPerPoint || 100));
  if (rewardsMinRedeemPointsInput) rewardsMinRedeemPointsInput.value = Math.max(1, Number(config.minRedeemPoints || 100));
}

function mountAdmins() {
  const currentEmail = String(auth.currentUser?.email || '').toLowerCase().trim();
  const canGrantHardDeletePermission = guaranteedAdminEmails.has(currentEmail);

  if (adminCanDeleteRestaurantsInput) {
    adminCanDeleteRestaurantsInput.disabled = !canGrantHardDeletePermission;
    adminCanDeleteRestaurantsInput.checked = false;
    adminCanDeleteRestaurantsInput.title = canGrantHardDeletePermission
      ? ''
      : 'هذه الصلاحية يمكن منحها فقط من أدمن أعلى مخوّل.';
  }

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
        const payload = { email, active: true, permissions };
        if (canGrantHardDeletePermission && adminCanDeleteRestaurantsInput) {
          payload.canDeleteRestaurants = adminCanDeleteRestaurantsInput.checked;
        }
        await setUserAdminRole(payload);
        adminEmailInput.value = '';
        adminPermissionInputs.forEach((input) => {
          input.checked = true;
        });
        if (adminCanDeleteRestaurantsInput) {
          adminCanDeleteRestaurantsInput.checked = false;
        }
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
        const rawValue = input.type === 'checkbox' ? input.checked : input.value;
        const nextValue = normalizeRemoteValueByType(rawValue, valueType);
        const prevValue = normalizeRemoteValueByType(current?.value || '', valueType);
        if (nextValue === prevValue && !current?.isManagedDefault) return;

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

  if (hasAdminPermission('config') && storeHomeConfigForm?.dataset.bound !== 'true') {
    loadStoreHomeConfigTargetOptions().catch((error) => {
      if (storeHomeConfigResult) storeHomeConfigResult.textContent = `تعذر تحميل المنشآت: ${error.message || error}`;
    });
    storeHomeConfigTarget?.addEventListener('change', () => {
      loadSelectedStoreHomeConfig().catch((error) => {
        if (storeHomeConfigResult) storeHomeConfigResult.textContent = `تعذر تحميل إعدادات المنشأة: ${error.message || error}`;
      });
    });
    storeHomeConfigForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const storeId = String(storeHomeConfigTarget?.value || '').trim();
      if (!storeId) return;
      if (storeHomeConfigResult) storeHomeConfigResult.textContent = 'جارٍ حفظ إعدادات المنشأة المختارة...';
      try {
        await updateDoc(doc(db, 'restaurants', storeId), {
          featuredOnHome: storeHomeFeaturedInput?.checked === true,
          showInHomeOffers: storeHomeOffersInput?.checked === true,
          updatedAt: serverTimestamp(),
        });
        if (storeHomeConfigResult) storeHomeConfigResult.textContent = 'تم حفظ إعدادات المنشأة المختارة فقط.';
      } catch (error) {
        if (storeHomeConfigResult) storeHomeConfigResult.textContent = `تعذر الحفظ: ${error.message || error}`;
      }
    });
    storeHomeConfigForm.dataset.bound = 'true';
  }

  if (hasAdminPermission('config') && clientHomeImagesForm?.dataset.bound !== 'true') {
    clientHomeImagesForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      if (clientHomeImagesResult) clientHomeImagesResult.textContent = 'جارٍ رفع صور الأقسام...';
      try {
        await saveClientHomeImages();
        if (clientHomeImagesResult) clientHomeImagesResult.textContent = 'تم حفظ صور الأقسام. ستظهر في الصفحة الرئيسية للعميل.';
      } catch (error) {
        if (clientHomeImagesResult) clientHomeImagesResult.textContent = `تعذر حفظ الصور: ${error.message || error}`;
      }
    });
    clientHomeImagesForm.dataset.bound = 'true';
  }

  if (hasAdminPermission('config') && rewardsConfigForm?.dataset.bound !== 'true') {
    loadRewardsConfig().catch((error) => {
      if (rewardsConfigResult) rewardsConfigResult.textContent = `تعذر تحميل إعدادات المكافآت: ${error.message || error}`;
    });
    rewardsConfigForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const amountPerPoint = Math.max(1, Math.floor(Number(rewardsAmountPerPointInput?.value || 100)));
      const minRedeemPoints = Math.max(1, Math.floor(Number(rewardsMinRedeemPointsInput?.value || 100)));
      if (rewardsConfigResult) rewardsConfigResult.textContent = 'جارٍ حفظ إعدادات المكافآت...';
      try {
        await setDoc(doc(db, 'clientHomeSettings', 'default'), {
          rewards: {
            enabled: rewardsEnabledInput?.checked === true,
            amountPerPoint,
            minRedeemPoints,
          },
          updatedAt: serverTimestamp(),
          updatedByUid: auth.currentUser?.uid || '',
        }, { merge: true });
        if (rewardsConfigResult) rewardsConfigResult.textContent = 'تم حفظ برنامج المكافآت. ستُحتسب النقاط للطلبات التي تُسلّم لاحقاً.';
      } catch (error) {
        if (rewardsConfigResult) rewardsConfigResult.textContent = `تعذر حفظ المكافآت: ${error.message || error}`;
      }
    });
    rewardsConfigForm.dataset.bound = 'true';
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
        client_optional_update_enabled: normalizeRemoteValueByType(clientOptionalUpdateEnabledInput?.value || 'false', 'BOOLEAN'),
        client_recommended_build_android: normalizeRemoteValueByType(clientRecommendedBuildAndroidInput?.value || '0', 'NUMBER'),
        client_optional_update_message: normalizeRemoteValueByType(clientOptionalUpdateMessageInput?.value || '', 'STRING'),
        payment_receipt_precheck_enabled: normalizeRemoteValueByType(paymentReceiptPrecheckEnabledInput?.value || 'true', 'BOOLEAN'),
        payment_receipt_precheck_mode: normalizeRemoteValueByType(paymentReceiptPrecheckModeInput?.value || 'block', 'STRING'),
        payment_receipt_require_image: normalizeRemoteValueByType(paymentReceiptRequireImageInput?.value || 'true', 'BOOLEAN'),
        payment_receipt_require_reference: normalizeRemoteValueByType(paymentReceiptRequireReferenceInput?.value || 'true', 'BOOLEAN'),
        payment_receipt_min_reference_digits: normalizeRemoteValueByType(paymentReceiptMinReferenceDigitsInput?.value || '8', 'NUMBER'),
        payment_receipt_requirements_message: normalizeRemoteValueByType(paymentReceiptRequirementsMessageInput?.value || '', 'STRING'),
        payment_receipt_missing_image_message: normalizeRemoteValueByType(paymentReceiptMissingImageMessageInput?.value || '', 'STRING'),
        payment_receipt_missing_reference_message: normalizeRemoteValueByType(paymentReceiptMissingReferenceMessageInput?.value || '', 'STRING'),
        payment_receipt_short_reference_message: normalizeRemoteValueByType(paymentReceiptShortReferenceMessageInput?.value || '', 'STRING'),
        payment_receipt_invalid_amount_message: normalizeRemoteValueByType(paymentReceiptInvalidAmountMessageInput?.value || '', 'STRING'),
        payment_receipt_warning_title: normalizeRemoteValueByType(paymentReceiptWarningTitleInput?.value || '', 'STRING'),
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
        store_batch_max_stops_per_trip: normalizeRemoteValueByType(storeBatchMaxStopsPerTripInput?.value || '8', 'NUMBER'),
        store_batch_single_trip_max_stops: normalizeRemoteValueByType(storeBatchSingleTripMaxStopsInput?.value || '5', 'NUMBER'),
        store_batch_single_trip_max_route_km: normalizeRemoteValueByType(storeBatchSingleTripMaxRouteKmInput?.value || '45', 'NUMBER'),
        store_batch_max_route_km_per_trip: normalizeRemoteValueByType(storeBatchMaxRouteKmPerTripInput?.value || '55', 'NUMBER'),
        store_batch_group_unclustered_zones: normalizeRemoteValueByType(storeBatchGroupUnclusteredZonesInput?.value || 'true', 'BOOLEAN'),
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
        const adminsByUid = new Map();
        snap.docs.forEach((docSnap) => {
          const data = docSnap.data() || {};
          const uid = String(data.uid || docSnap.id || '').trim();
          if (!uid) return;
          adminsByUid.set(uid, data);
        });

        const rows = snap.docs
          .map((d) => {
            const data = d.data() || {};
            const isActive = data.active === true || data.role === 'admin';
            const permissionsSummary = formatAdminPermissionsSummary(data.permissions);
            const uid = String(data.uid || d.id || '').trim();
            const canDeleteRestaurants = data.canDeleteRestaurants === true;
            const hardDeleteBadge = `<span class="badge ${canDeleteRestaurants ? 'closed' : 'open'}">${canDeleteRestaurants ? 'مفعل' : 'غير مفعل'}</span>`;
            const toggleButton = canGrantHardDeletePermission
              ? `<button class="btn ${canDeleteRestaurants ? 'ghost' : 'danger'}" data-admin-toggle-hard-delete="${escapeHtml(uid)}">${canDeleteRestaurants ? 'إلغاء صلاحية الحذف النهائي' : 'تفعيل صلاحية الحذف النهائي'}</button>`
              : '-';
            return `<tr>
              <td>${data.email || '-'}</td>
              <td>${data.uid || d.id}</td>
              <td>${data.role || '-'}</td>
              <td>${escapeHtml(permissionsSummary || 'كامل')}</td>
              <td><span class="badge ${isActive ? 'closed' : 'open'}">${isActive ? 'نشط' : 'غير نشط'}</span></td>
              <td>${hardDeleteBadge}</td>
              <td>${toggleButton}</td>
            </tr>`;
          });
        setHtml(adminsTable, table(['البريد', 'UID', 'الدور', 'الصلاحيات', 'الحالة', 'حذف المطاعم نهائيًا', 'إجراء'], rows));

        if (canGrantHardDeletePermission && adminsTable) {
          adminsTable.querySelectorAll('[data-admin-toggle-hard-delete]').forEach((btn) => {
            btn.addEventListener('click', async () => {
              const uid = String(btn.getAttribute('data-admin-toggle-hard-delete') || '').trim();
              if (!uid) return;

              const data = adminsByUid.get(uid);
              if (!data) return;

              const nextValue = data.canDeleteRestaurants !== true;
              const adminLabel = String(data.email || uid).trim();
              const confirmText = nextValue
                ? `هل تريد منح صلاحية الحذف النهائي للمطاعم إلى ${adminLabel}؟`
                : `هل تريد سحب صلاحية الحذف النهائي للمطاعم من ${adminLabel}؟`;

              if (!window.confirm(confirmText)) return;

              try {
                await withBtnLoading(btn, async () => {
                  const permissions = normalizeAdminPermissions(data.permissions, { fallbackToAll: true });
                  await setUserAdminRole({
                    uid,
                    active: data.active !== false,
                    permissions,
                    canDeleteRestaurants: nextValue,
                  });
                });
                if (window.showToast) {
                  window.showToast(
                    nextValue
                      ? 'تم تفعيل صلاحية الحذف النهائي بنجاح.'
                      : 'تم سحب صلاحية الحذف النهائي بنجاح.',
                    'success'
                  );
                }
              } catch (err) {
                if (window.showToast) {
                  window.showToast(`تعذر تعديل الصلاحية: ${err.message || err}`, 'error');
                } else {
                  alert(`تعذر تعديل الصلاحية: ${err.message || err}`);
                }
              }
            });
          });
        }
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
  mapUiState.style = String(mapStyleSelect?.value || 'osm');
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
  const preset = MAP_STYLE_PRESETS[mapUiState.style] || MAP_STYLE_PRESETS.osm;
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
  const typeLabelMap = {
    order: 'طلب',
    driver: 'مندوب',
    client: 'عميل',
    restaurant: 'مطعم',
  };
  const typeLabel = typeLabelMap[selection.type] || 'عنصر';
  const subtitle = String(selection.subtitle || '').trim();
  const pinnedLabel = mapUiState.pinDetails ? ' | البطاقة مثبتة' : '';
  return `${typeLabel} محدد: ${selection.label || 'عنصر محدد'}${subtitle ? ` | ${subtitle}` : ''}${pinnedLabel}`;
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
  mapDetails.querySelectorAll('[data-map-clear-selection]').forEach((button) => {
    button.addEventListener('click', () => {
      clearMapSelection();
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
      <button class="btn ghost" type="button" data-map-clear-selection>إظهار الكل</button>
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
  const trackedDrivers = Array.from(mapState.drivers.values()).filter(({ data }) => {
    return Boolean(
      extractGeo(data, ['location', 'currentLocation', 'lastLocation', 'liveLocation', 'address.location'])
      || extractGeoByPairs(data, [
        ['latitude', 'longitude'],
        ['lat', 'lng'],
      ])
    );
  }).length;
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
      <div class="map-metric"><span>المندوبون المرسومون</span><strong>${trackedDrivers}/${totalDrivers}</strong></div>
      <div class="map-metric"><span>المطاعم الظاهرة</span><strong>${visibleRestaurants}/${totalRestaurants}</strong></div>
      <div class="map-metric"><span>فلتر الحالة</span><strong>${escapeHtml(MAP_ORDER_STATUS_LABELS[mapUiState.orderStatus] || 'نشط')}</strong></div>
    `;
  }

  setMapLegendSummary(
    `نشط: ${activeOrders} | مندوبون متاحون: ${availableDrivers} | مطاعم ظاهرة: ${visibleRestaurants} | عملاء نشطون: ${totalClients}${hiddenSummary ? ` | مخفي: ${hiddenRestaurants}` : ''}`
  );
}

function clearMapSelection() {
  currentMapSelection = null;
  clearSelectedOrderOnMap();
  updateMapSelectionBanner('لا يوجد عنصر محدد.');
  setMapDetails('<p class="muted">اختر عنصرًا من الخريطة أو البحث.</p>');
  renderMapSearchResults();
  requestRefreshMapLayers();
}

function shouldShowEntityUnderSelection() {
  // Selection changes details and highlighting only; it must not trap map navigation.
  return true;
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
      if (data) {
        renderEntityDetails('driver', id, data);
        requestRefreshMapLayers();
      }
      return;
    }

    if (isClient) {
      const data = mapState.clients.get(id)?.data;
      if (data) {
        renderEntityDetails('client', id, data);
        requestRefreshMapLayers();
      }
      return;
    }

    const data = mapState.restaurants.get(id)?.data;
    if (data) {
      renderEntityDetails('restaurant', id, data);
      requestRefreshMapLayers();
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
    `
      <div class="map-search-focusbar">
        <button class="btn primary map-focus-primary" type="button" data-map-search-type="${escapeHtml(limitedMatches[0].type)}" data-map-search-id="${escapeHtml(limitedMatches[0].id)}">تمركز سريع: ${escapeHtml(limitedMatches[0].title)}</button>
      </div>
      ${limitedMatches.map((match) => `
      <div class="map-search-item ${currentMapSelection?.type === match.type && currentMapSelection?.id === match.id ? 'active' : ''}">
        <div>
          <div class="map-search-item-meta"><span class="map-search-badge" data-kind="${escapeHtml(match.type)}">${escapeHtml(match.type === 'order' ? 'طلب' : match.type === 'restaurant' ? 'مطعم' : match.type === 'driver' ? 'مندوب' : 'عميل')}</span></div>
          <b>${escapeHtml(match.title)}</b>
          <span>${escapeHtml(match.subtitle)}</span>
        </div>
        <button class="btn ghost" type="button" data-map-search-type="${escapeHtml(match.type)}" data-map-search-id="${escapeHtml(match.id)}">تمركز</button>
      </div>
      `).join('')}
    `
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
  return isActiveOrderStatus(order?.orderStatus || order?.status);
}

function canDisplayOrderOnMap(orderData, orderId) {
  return isActiveOrder(orderData);
}

function clearSelectedOrderOnMap() {
  selectedOrderOnMapId = '';
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

function describeOrderRouteState(orderId, points) {
  const routeKey = buildRouteKey(points);
  if (mapRouteCache.has(routeKey)) {
    return 'مسار فعلي على الطرق';
  }
  if (mapRouteLastActualByOrder.get(orderId)?.points?.length) {
    return 'مسار فعلي على الطرق، يجري تحديثه';
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
  const batchStops = getBatchDeliveryStops(orderData);
  const removedBatchStops = getRemovedBatchDeliveryStops(orderData);
  const batchSummary = summarizeBatchStops(batchStops, removedBatchStops);
  const batchCode = getBatchTripCode(orderData, formatUnifiedOrderCode(orderData.orderNumber, orderData.orderId, orderId));
  const sourceLabel = formatOrderSourceLabel(orderData);
  const batchStopsList = batchStops.length
    ? `<div class="map-batch-summary">
        <b>${escapeHtml(sourceLabel)} ${escapeHtml(batchCode)}</b>
        <div class="batch-summary-grid batch-summary-grid--compact">
          <span class="batch-summary-pill">الحالية <b>${batchSummary.total}</b></span>
          <span class="batch-summary-pill">قيد التنفيذ <b>${batchSummary.active}</b></span>
          <span class="batch-summary-pill">تم التسليم <b>${batchSummary.delivered}</b></span>
          <span class="batch-summary-pill">متعذر <b>${batchSummary.exceptions}</b></span>
          <span class="batch-summary-pill">إزالة <b>${batchSummary.removalPending}</b></span>
        </div>
        <ul>${batchStops.slice(0, 12).map(({ data }, index) => {
          const stopCode = getBatchStopCode(data, String(index + 1));
          const status = String(data.status || 'pending').trim();
          return `<li><span class="batch-stop-code">${escapeHtml(stopCode)}</span> - ${escapeHtml(data.clientName || 'عميل')} - ${escapeHtml(data.zoneName || '-')} - ${escapeHtml(formatBatchStopStatus(status))}</li>`;
        }).join('')}</ul>
        ${batchStops.length > 12 ? `<div class="muted">+ ${batchStops.length - 12} طلبات أخرى داخل الرحلة</div>` : ''}
        ${removedBatchStops.length ? `<div class="muted">أزيلت قبل الاستلام: ${removedBatchStops.length}</div>` : ''}
      </div>`
    : '';

  const restaurantGeo = getPickupGeoByOrder(orderData);
  const driverGeo = getDriverGeoByOrder(orderData);
  const clientGeo = getDropoffGeoByOrder(orderData);
  const trackingInsight = getOrderTrackingInsight(orderData, restaurantGeo, driverGeo, clientGeo);
  const pickupLabel = getPickupLabelByOrder(orderData);
  const pickupName = getPickupNameByOrder(orderData, restaurant?.name || orderData.restaurantName || restaurantId);
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
  const routeStateLabel = describeOrderRouteState(orderId, routeSourcePoints);
  const missingPieces = [
    restaurantGeo ? '' : 'المطعم بلا موقع صالح',
    driverId && !driverGeo ? 'المندوب المعين لا يرسل موقعًا حاليًا' : '',
    clientGeo ? '' : 'العميل بلا نقطة توصيل واضحة',
  ].filter(Boolean);

  setMapDetails(`
    <div class="map-order-head">
      <div>
        <h4>${escapeHtml(formatUnifiedOrderCode(orderData.orderNumber, orderData.orderId, orderId))}</h4>
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
      <div class="map-detail-metric"><span>المسار</span><strong>${escapeHtml(routeStateLabel)}</strong></div>
      <div class="map-detail-metric"><span>القيمة</span><strong>${escapeHtml(String(orderData.totalWithDelivery ?? orderData.total ?? orderData.totalPrice ?? '-'))}</strong></div>
      <div class="map-detail-metric"><span>من</span><strong>${escapeHtml(routeAddressSummary[0])}</strong></div>
      <div class="map-detail-metric"><span>إلى</span><strong>${escapeHtml(routeAddressSummary[1])}</strong></div>
    </div>
    <div class="map-insight-card">${escapeHtml(trackingInsight)}</div>
    ${missingPieces.length ? `<div class="map-alert-note">${escapeHtml(missingPieces.join(' | '))}</div>` : ''}
    <div class="map-inline-actions">
      ${restaurantId ? `<button class="btn ghost" type="button" data-map-open-store="${escapeHtml(restaurantId)}">المتجر</button>` : ''}
      ${driverId ? `<button class="btn ghost" type="button" data-map-open-driver="${escapeHtml(driverId)}">المندوب</button>` : ''}
      ${clientId ? `<button class="btn ghost" type="button" data-map-open-client="${escapeHtml(clientId)}">العميل</button>` : ''}
    </div>
    ${batchStopsList}
    <div><b>العناصر</b><ul>${items}</ul></div>
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
    setMapDetails('<p class="muted">هذا الطلب غير نشط، لذلك لا يظهر داخل الخريطة الحية.</p>');
    return;
  }

  selectedOrderOnMapId = orderId;
  const orderData = orderEntry.data || {};
  renderOrderDetails(orderData, orderId);
  renderMapSearchResults();

  const points = [];
  const restaurantGeo = getPickupGeoByOrder(orderData);
  const driverGeo = getDriverGeoByOrder(orderData);
  const clientGeo = getDropoffGeoByOrder(orderData);
  const pickupLabel = getPickupLabelByOrder(orderData);
  const pickupName = getPickupNameByOrder(orderData, resolveRestaurantDisplay(orderData.restaurantId, orderData.restaurantName));
  const batchStops = getBatchDeliveryStops(orderData);
  const batchPoints = batchStops.map((item) => getBatchStopGeo(item.data)).filter(Boolean);

  if (restaurantGeo) points.push([restaurantGeo.lat, restaurantGeo.lng]);
  if (driverGeo) points.push([driverGeo.lat, driverGeo.lng]);
  if (batchPoints.length) {
    batchPoints.forEach((geo) => points.push([geo.lat, geo.lng]));
  } else if (clientGeo) {
    points.push([clientGeo.lat, clientGeo.lng]);
  }

  if (points.length === 1) {
    liveMap.setView(points[0], 15, { animate: true });
  } else if (points.length > 1) {
    const bounds = window.L.latLngBounds(points);
    liveMap.fitBounds(bounds.pad(0.25), {
      animate: true,
      maxZoom: 16,
      padding: [72, 72],
    });
  }

  const orderMarker = markerState.orders.get(orderId);
  if (orderMarker) {
    orderMarker.openPopup();
  }

  refreshOrderLines();
  requestRefreshMapLayers();
}
function openOrderOnMap(orderId) {
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
      selection: {
        type: 'driver',
        id,
        label: `المندوب ${name}`,
        subtitle: `${available ? 'متاح' : 'غير متاح'} · ${orders.length} طلب نشط`,
      }
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
        selection: {
          type: 'client',
          id,
          label: `العميل ${name}`,
          subtitle: `${orders.length} طلب نشط`,
        }
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
      subtitle: `${restaurantGeo ? 'موقع مباشر متاح' : 'موقع غير متاح'} · ${data.temporarilyClosed ? 'مغلق مؤقتًا' : 'مفتوح'}`,
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

function getSelectedOrderDriverId() {
  if (!selectedOrderOnMapId) return '';
  const orderData = mapState.orders.get(selectedOrderOnMapId)?.data;
  if (!orderData) return '';
  return String(orderData.assignedDriverId || '').trim();
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
  const highlightedDriverId = getSelectedOrderDriverId();
  mapState.drivers.forEach(({ data }, id) => {
    if (!shouldShowEntityUnderSelection('driver', id)) return;
    const geo = extractGeo(data, ['location', 'currentLocation', 'lastLocation', 'liveLocation', 'address.location']);
    if (!geo) return;
    validIds.add(id);
    const available = data.isAvailable === true || data.available === true || String(data.availabilityStatus || '').toLowerCase() === 'available';
    const lastUpdate = data.lastLocationUpdate || data.lastUpdated || data.updatedAt || data.createdAt;
    const lastUpdateLabel = lastUpdate ? formatDateTimeLabel(lastUpdate) : 'غير متاح';
    const isCurrentDriver = highlightedDriverId && highlightedDriverId === id;
    setOrUpdateMarker(
      markerState.drivers,
      id,
      [geo.lat, geo.lng],
      { type: 'driver', variant: isCurrentDriver ? 'current' : (available ? 'online' : 'offline') },
      `${available ? 'مندوب متاح' : 'مندوب غير متاح'}: ${data.name || id} | ${geo.lat.toFixed(5)}, ${geo.lng.toFixed(5)} | آخر تحديث: ${lastUpdateLabel}`,
      () => {
        renderEntityDetails('driver', id, data);
        requestRefreshMapLayers();
      }
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
    if (!shouldShowEntityUnderSelection('client', id)) return;
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
      () => {
        renderEntityDetails('client', id, data);
        requestRefreshMapLayers();
      }
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
    if (!shouldShowEntityUnderSelection('restaurant', id)) return;
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
      () => {
        renderEntityDetails('restaurant', id, data, {
          geo,
          addressId: chosenAddressId,
          addressData: chosenAddressEntry?.data || null,
          isDefault: Boolean(chosenAddressId && String(data.defaultAddressId || '').trim() === chosenAddressId),
        });
        requestRefreshMapLayers();
      }
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
    if (!shouldShowEntityUnderSelection('order', id)) return;
    if (!matchesMapOrderFilter(data) || !canDisplayOrderOnMap(data, id)) return;
    const batchStops = getBatchDeliveryStops(data);
    const firstBatchGeo = batchStops.map((item) => getBatchStopGeo(item.data)).find(Boolean);
    const geo = firstBatchGeo || extractGeo(data, ['deliveryLocation', 'clientLocation', 'address.location']);
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
        requestRefreshMapLayers();
      }
    );
  });
  removeMissingMarkers(markerState.orders, validIds);
}

function getRestaurantGeoByOrder(orderData) {
  if (isClientParcelOrder(orderData)) {
    const fromPickup = extractGeo(orderData, ['pickupLocation']);
    if (fromPickup) return fromPickup;
    const pickupLat = Number(orderData.pickupLat);
    const pickupLng = Number(orderData.pickupLng);
    if (Number.isFinite(pickupLat) && Number.isFinite(pickupLng)) {
      return { lat: pickupLat, lng: pickupLng };
    }
  }
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
  if (!isActiveOrderStatus(getOrderLifecycleStatus(orderData))) return null;
  const driverId = orderData.assignedDriverId;
  if (!driverId) return null;
  const driver = mapState.drivers.get(driverId)?.data;
  return driver ? extractGeo(driver, ['location', 'currentLocation', 'lastLocation', 'address.location']) : null;
}

function getClientGeoByOrder(orderData) {
  const batchStops = getBatchDeliveryStops(orderData);
  const firstBatchGeo = batchStops.map((item) => getBatchStopGeo(item.data)).find(Boolean);
  if (firstBatchGeo) return firstBatchGeo;
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
  if (!selectedOrderOnMapId) {
    removeMissingOrderLines(new Set());
    return;
  }
  const validIds = new Set();
  mapState.orders.forEach(({ data }, id) => {
    if (id !== selectedOrderOnMapId) return;
    if (!matchesMapOrderFilter(data) || !canDisplayOrderOnMap(data, id)) return;

    const restaurantGeo = getRestaurantGeoByOrder(data);
    const driverGeo = getDriverGeoByOrder(data);
    const clientGeo = getClientGeoByOrder(data);
    const batchStops = getBatchDeliveryStops(data);
    const batchPoints = batchStops.map((item) => getBatchStopGeo(item.data)).filter(Boolean);

    const points = [];
    if (restaurantGeo) points.push([restaurantGeo.lat, restaurantGeo.lng]);
    if (driverGeo) {
      const lastPoint = points[points.length - 1];
      if (!lastPoint || lastPoint[0] !== driverGeo.lat || lastPoint[1] !== driverGeo.lng) {
        points.push([driverGeo.lat, driverGeo.lng]);
      }
    }
    if (batchPoints.length) {
      batchPoints.forEach((geo) => {
        const lastPoint = points[points.length - 1];
        if (!lastPoint || lastPoint[0] !== geo.lat || lastPoint[1] !== geo.lng) {
          points.push([geo.lat, geo.lng]);
        }
      });
    } else if (clientGeo) {
      const lastPoint = points[points.length - 1];
      if (!lastPoint || lastPoint[0] !== clientGeo.lat || lastPoint[1] !== clientGeo.lng) {
        points.push([clientGeo.lat, clientGeo.lng]);
      }
    }

    if (points.length < 2) return;

    validIds.add(id);
    const withDriver = Boolean(driverGeo);
    const isSelected = true;
    const shouldUseActualRoute = true;
    const resolvedRoute = resolveOrderRoutePoints(id, points, shouldUseActualRoute);
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
          'مندوب: أخضر/رمادي<br/>عميل: أزرق<br/>مطعم: برتقالي/بني<br/>طلب محدد: أزرق';
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

  setMapDetails('<p class="muted">اختر عنصرًا من الخريطة أو نتائج البحث.</p>');
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

function schedulePendingMountRefresh(delayMs = 240) {
  if (pendingMountRefreshTimer) clearTimeout(pendingMountRefreshTimer);
  pendingMountRefreshTimer = setTimeout(() => {
    pendingMountRefreshTimer = null;
    mountPending().catch((err) => {
      console.warn('pending refresh failed after action', err);
    });
  }, delayMs);
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

  const [approvedDriverSnap, approvedStoreSnap] = await Promise.all([
    safeGetDocs(query(collection(db, 'drivers'), where('approvalStatus', '==', 'approved'))),
    safeGetDocs(query(collection(db, 'restaurants'), where('approvalStatus', '==', 'approved'))),
  ]);

  syncPendingApprovalsState(collectPendingApprovalEntries({
    courierApps,
    storeApps,
    fallbackDrivers: fallbackDriverSnap.docs,
    fallbackStores: fallbackStoreSnap.docs,
  }));

  renderPendingGeoStats([
    ...approvedDriverSnap.docs.map((docSnap) => ({ role: 'courier', data: docSnap.data() || {} })),
    ...approvedStoreSnap.docs.map((docSnap) => ({ role: 'store', data: docSnap.data() || {} })),
  ]);

  const pendingDriverIds = new Set(courierApps.map((d) => {
    const data = d.data() || {};
    return data.driverId || data.ownerUid || data.uid || d.id;
  }));

  const pendingStoreIds = new Set(storeApps.map((d) => {
    const data = d.data() || {};
    return data.restaurantId || data.ownerUid || data.uid || d.id;
  }));

  const courierCards = [];
  const storeCards = [];

  courierApps.forEach((d) => {
    const data = d.data() || {};
    const identityNumber = data.nationalIdNumber || '-';
    const identityImageUrl = data.idImageUrl || '';
    courierCards.push(buildPendingApplicantCard({
      kind: 'courier',
      id: d.id,
      data,
      title: data.name || d.id,
      imageUrl: identityImageUrl,
      actions: `
        <button class="btn ghost" data-approve-courier-app="${d.id}">قبول</button>
        <button class="btn danger" data-reject-courier-app="${d.id}">رفض</button>
      `,
    }));
  });

  storeApps.forEach((d) => {
    const data = d.data() || {};
    const businessTypeLabels = {
      restaurant: 'مطعم',
      brand: 'براند',
      ecommerce: 'متجر إلكتروني',
      grocery: 'بقالة',
      pharmacy: 'صيدلية',
    };
    const businessTypeLabel = businessTypeLabels[data.businessType] || 'مطعم';
    storeCards.push(buildPendingApplicantCard({
      kind: 'store',
      id: d.id,
      data,
      title: `${data.name || d.id} - ${businessTypeLabel}`,
      imageUrl: data.commercialRecordImageUrl || '',
      actions: `
        <button class="btn ghost" data-approve-store-app="${d.id}">قبول</button>
        <button class="btn danger" data-reject-store-app="${d.id}">رفض</button>
      `,
    }));
  });

  fallbackDriverSnap.docs
    .filter((d) => !pendingDriverIds.has(d.id))
    .forEach((d) => {
      const data = d.data() || {};
      courierCards.push(buildPendingApplicantCard({
        kind: 'courier',
        id: d.id,
        data,
        title: data.name || d.id,
        imageUrl: data.idImageUrl || '',
        actions: '<span class="muted">هذا السجل غير موجود ضمن طلبات معلقة، ويمكن مراجعته فقط.</span>',
      }));
    });

  fallbackStoreSnap.docs
    .filter((d) => !pendingStoreIds.has(d.id))
    .forEach((d) => {
      const data = d.data() || {};
      storeCards.push(buildPendingApplicantCard({
        kind: 'store',
        id: d.id,
        data,
        title: data.name || d.id,
        imageUrl: data.commercialRecordImageUrl || '',
        actions: `
          <button class="btn ghost" data-approve-store-entity="${d.id}">قبول</button>
          <button class="btn danger" data-reject-store-entity="${d.id}">رفض</button>
        `,
      }));
    });

  setHtml(pendingTable, `<div class="pending-application-grid">${[...courierCards, ...storeCards].join('')}</div>`);

  pendingTable.querySelectorAll('[data-approve-courier-app]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const appId = btn.getAttribute('data-approve-courier-app');
      await withBtnLoading(btn, async () => {
        await approveCourierApplication({ applicationId: appId });
      });
      btn.closest('.pending-application-card')?.remove();
      schedulePendingMountRefresh();
    });
  });

  pendingTable.querySelectorAll('[data-reject-courier-app]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      await withBtnLoading(btn, async () => {
        const appId = btn.getAttribute('data-reject-courier-app');
        const snap = await getDoc(doc(db, 'courierApplications', appId));
        if (!snap.exists()) return;
        const data = snap.data() || {};
        await setCourierDecision({
          appId,
          driverId: data.driverId || data.ownerUid || data.uid || appId,
          ownerUid: data.ownerUid,
          decision: 'rejected'
        });
      });
      btn.closest('.pending-application-card')?.remove();
      schedulePendingMountRefresh();
    });
  });

  pendingTable.querySelectorAll('[data-approve-store-app]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      try {
        let result = null;
        await withBtnLoading(btn, async () => {
          const appId = btn.getAttribute('data-approve-store-app');
          result = await approveRestaurantApplication({ applicationId: appId });
        });
        const payload = result?.data || {};
        if (payload.authCreated) {
          alert(`تمت الموافقة وإنشاء/تفعيل حساب دخول للمتجر بنجاح.\nالبريد: ${payload.email}`);
        } else {
          alert('تمت الموافقة على طلب المتجر بنجاح.');
        }
        btn.closest('.pending-application-card')?.remove();
        schedulePendingMountRefresh();
      } catch (err) {
        alert(`تعذر قبول الطلب: ${err.message || err}`);
      }
    });
  });

  pendingTable.querySelectorAll('[data-reject-store-app]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      try {
        await withBtnLoading(btn, async () => {
          const appId = btn.getAttribute('data-reject-store-app');
          const snap = await getDoc(doc(db, 'restaurantApplications', appId));
          if (!snap.exists()) return;
          const data = snap.data() || {};
          await setStoreDecision({
            appId,
            restaurantId: data.restaurantId || data.ownerUid || data.uid || appId,
            ownerUid: data.ownerUid,
            appData: data,
            decision: 'rejected'
          });
        });
        btn.closest('.pending-application-card')?.remove();
        schedulePendingMountRefresh();
      } catch (err) {
        alert(`تعذر رفض الطلب: ${err.message || err}`);
      }
    });
  });

  pendingTable.querySelectorAll('[data-approve-store-entity]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      await withBtnLoading(btn, async () => {
        const id = btn.getAttribute('data-approve-store-entity');
        await setStoreDecision({ appId: id, restaurantId: id, ownerUid: id, decision: 'approved' });
      });
      btn.closest('.pending-application-card')?.remove();
      schedulePendingMountRefresh();
    });
  });

  pendingTable.querySelectorAll('[data-reject-store-entity]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      await withBtnLoading(btn, async () => {
        const id = btn.getAttribute('data-reject-store-entity');
        await setStoreDecision({ appId: id, restaurantId: id, ownerUid: id, decision: 'rejected' });
      });
      btn.closest('.pending-application-card')?.remove();
      schedulePendingMountRefresh();
    });
  });

  if (!pendingMenuTable) return;

  const approvedMenuSnap = await safeGetDocs(query(collection(db, 'restaurants'), where('approvalStatus', '==', 'approved')));

  const pendingMenuSnap = await safeGetDocs(
    query(collection(db, 'restaurants'), where('pendingApproval', '==', true))
  );

  renderPendingGeoStats([
    ...approvedDriverSnap.docs.map((docSnap) => ({ role: 'courier', data: docSnap.data() || {} })),
    ...approvedMenuSnap.docs.map((docSnap) => ({ role: 'store', data: docSnap.data() || {} })),
  ]);

  const menuCards = pendingMenuSnap.docs
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

      return buildPendingApplicantCard({
        kind: 'store',
        id,
        data: { ...data, approvalRequestedAt: data.approvalRequestedAt, requestedAt },
        title: data.name || id,
        imageUrl: data.commercialRecordImageUrl || '',
        actions: `
          <button class="btn ghost" data-approve-menu-request="${id}">قبول القائمة</button>
          <button class="btn danger" data-reject-menu-request="${id}">رفض القائمة</button>
        `,
      });
    });

  setHtml(pendingMenuTable, `<div class="pending-application-grid">${menuCards.join('')}</div>`);

  pendingMenuTable.querySelectorAll('[data-approve-menu-request]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      await withBtnLoading(btn, async () => {
        const restaurantId = btn.getAttribute('data-approve-menu-request');
        if (!restaurantId) return;
        await setMenuApprovalDirect({ restaurantId, approved: true });
      });
      btn.closest('.pending-application-card')?.remove();
      schedulePendingMountRefresh();
    });
  });

  pendingMenuTable.querySelectorAll('[data-reject-menu-request]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      await withBtnLoading(btn, async () => {
        const restaurantId = btn.getAttribute('data-reject-menu-request');
        if (!restaurantId) return;
        await setMenuApprovalDirect({ restaurantId, approved: false });
      });
      btn.closest('.pending-application-card')?.remove();
      schedulePendingMountRefresh();
    });
  });
}

function mountNotifications() {
  if (!notificationForm) return;

  const clearNotificationPendingImage = () => {
    notificationPendingImageFile = null;
    if (notificationPendingImagePreviewUrl) {
      URL.revokeObjectURL(notificationPendingImagePreviewUrl);
      notificationPendingImagePreviewUrl = '';
    }
    if (notificationImageInput) notificationImageInput.value = '';
    if (notificationImagePreview) notificationImagePreview.hidden = true;
    notificationImagePreviewImg?.removeAttribute('src');
  };

  const renderNotificationPendingImage = () => {
    if (!notificationImagePreview || !notificationImagePreviewImg) return;
    if (!notificationPendingImageFile || !notificationPendingImagePreviewUrl) {
      notificationImagePreview.hidden = true;
      notificationImagePreviewImg.removeAttribute('src');
      return;
    }
    notificationImagePreviewImg.src = notificationPendingImagePreviewUrl;
    notificationImagePreview.hidden = false;
  };

  const syncUserFields = () => {
    const isUserMode = String(notificationTargetType?.value || '') === 'user';
    if (notificationUserRole) notificationUserRole.disabled = !isUserMode;
    if (notificationUserId) notificationUserId.disabled = !isUserMode;
    if (!isUserMode && notificationUserId) notificationUserId.value = '';
  };

  if (!notificationFormBound) {
    notificationTargetType?.addEventListener('change', syncUserFields);
    notificationAttachImageBtn?.addEventListener('click', () => notificationImageInput?.click());
    notificationImageInput?.addEventListener('change', () => {
      const file = notificationImageInput.files?.[0] || null;
      if (!file) {
        clearNotificationPendingImage();
        return;
      }
      if (!String(file.type || '').startsWith('image/')) {
        alert('اختر ملف صورة صالحاً.');
        clearNotificationPendingImage();
        return;
      }
      if (file.size > 10 * 1024 * 1024) {
        alert('حجم الصورة يجب ألا يتجاوز 10MB.');
        clearNotificationPendingImage();
        return;
      }
      if (notificationPendingImagePreviewUrl) URL.revokeObjectURL(notificationPendingImagePreviewUrl);
      notificationPendingImageFile = file;
      notificationPendingImagePreviewUrl = URL.createObjectURL(file);
      renderNotificationPendingImage();
    });
    notificationRemoveImageBtn?.addEventListener('click', clearNotificationPendingImage);
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
        let imageUrl = '';
        if (notificationPendingImageFile) {
          if (notificationResult) notificationResult.textContent = 'جارٍ رفع الصورة...';
          imageUrl = await uploadImageToCloudinary(notificationPendingImageFile) || '';
          if (!imageUrl) throw new Error('تعذر رفع الصورة المرفقة.');
        }
        const payload = { targetType, role, userId, title, body, imageUrl };
        const res = await sendAdminNotification(payload);
        const sent = Number(res?.data?.sentCount || 0);
        if (notificationResult) notificationResult.textContent = `تم الإرسال بنجاح. عدد المستقبلين: ${sent}`;
        if (notificationBody) notificationBody.value = '';
        if (notificationTitle) notificationTitle.value = '';
        if (notificationUserId) notificationUserId.value = '';
        clearNotificationPendingImage();
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
