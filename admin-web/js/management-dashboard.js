import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js';
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-auth.js';
import {
  getFirestore,
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  setDoc,
  deleteDoc,
  serverTimestamp
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-firestore.js';
import {
  configForEnv,
  resolveAdminEnv,
  staticAdminEmails
} from './firebase-config.js';

const STORAGE_KEY = 'speedstar-management-os-v4';

const activeEnv = resolveAdminEnv();
const firebaseConfig = configForEnv(activeEnv);
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const COLLECTIONS = {
  projects: 'managementProjects',
  tasks: 'managementTasks',
  employees: 'managementEmployees',
  approvals: 'managementApprovals',
  finances: 'managementFinances',
  audit: 'managementAudit',
  followups: 'managementFollowups'
};

const ROLE_LABEL = {
  admin: 'مسؤول النظام',
  ceo: 'الرئيس التنفيذي',
  ops: 'العمليات',
  finance: 'المالية',
  hr: 'الموارد البشرية',
  viewer: 'مشاهدة فقط'
};

const ADMIN_PERMISSION_DEFS = {
  dashboard: 'لوحة القيادة',
  finance: 'المالية والتحويلات',
  orders: 'متابعة الطلبات والتشغيل',
  employees: 'عرض الموظفين',
  map: 'الخريطة الحية',
  approvals: 'طلبات الاعتماد',
  support: 'الدعم الفني',
  notifications: 'الإشعارات',
  config: 'Remote Config وتشغيل المدن',
  admins: 'إدارة المسؤولين'
};

const ALL_ADMIN_PERMISSIONS = Object.keys(ADMIN_PERMISSION_DEFS);
const GUARANTEED_ADMIN_EMAILS = new Set(staticAdminEmails.map((email) => String(email || '').toLowerCase()));

const ACTION_PERMISSION_REQUIREMENTS = {
  'project:add': ['orders', 'dashboard'],
  'project:edit': ['orders'],
  'task:add': ['orders'],
  'task:advance': ['orders'],
  'employee:view': ['employees'],
  'followup:manage': ['orders', 'approvals'],
  'employee:add': ['admins'],
  'employee:edit': ['admins'],
  'admins:manage': ['admins'],
  'approval:add': ['approvals'],
  'approval:decide': ['approvals'],
  'finance:add': ['finance'],
  'export:all': ['dashboard', 'orders', 'finance', 'approvals', 'admins']
};

const createId = (prefix) => `${prefix}-${Math.random().toString(36).slice(2, 9)}`;
const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
const todayISO = () => new Date().toISOString().slice(0, 10);

const initialState = {
  projects: [
    { id: createId('proj'), name: 'توسع المدن الجديدة', owner: 'عبادة', status: 'active', progress: 62, budget: 500000, dueDate: '2026-08-15', lastEditedBy: 'عبادة', lastEditedAt: new Date().toISOString() },
    { id: createId('proj'), name: 'تحسين تجربة العميل', owner: 'سارة', status: 'risk', progress: 38, budget: 220000, dueDate: '2026-07-30', lastEditedBy: 'سارة', lastEditedAt: new Date().toISOString() },
    { id: createId('proj'), name: 'منصة الموردين', owner: 'يوسف', status: 'planning', progress: 15, budget: 150000, dueDate: '2026-09-20', lastEditedBy: 'يوسف', lastEditedAt: new Date().toISOString() }
  ],
  tasks: [
    { id: createId('task'), title: 'إغلاق متطلبات مرحلة الخرطوم', projectId: '', assignee: 'سارة', priority: 'critical', status: 'in_progress', dueDate: '2026-07-02', description: 'تجهيز خطة التشغيل للأسبوعين القادمين', lastEditedBy: 'عبادة', lastEditedAt: new Date().toISOString() },
    { id: createId('task'), title: 'مراجعة سياسة الخصومات', projectId: '', assignee: 'مريم', priority: 'high', status: 'review', dueDate: '2026-07-05', description: 'التأكد من تأثيرها على هامش الربح', lastEditedBy: 'مريم', lastEditedAt: new Date().toISOString() }
  ],
  employees: [
    { id: createId('emp'), name: 'عبادة', role: 'الرئيس التنفيذي', systemRole: 'ceo', department: 'الإدارة العليا', kpi: 'نمو الإيرادات', workload: 8, lastEditedBy: 'النظام', lastEditedAt: new Date().toISOString() },
    { id: createId('emp'), name: 'سارة', role: 'مديرة العمليات', systemRole: 'ops', department: 'العمليات', kpi: 'نسبة الالتزام التشغيلي', workload: 7, lastEditedBy: 'النظام', lastEditedAt: new Date().toISOString() },
    { id: createId('emp'), name: 'مريم', role: 'مديرة مالية', systemRole: 'finance', department: 'المالية', kpi: 'صافي الربح', workload: 6, lastEditedBy: 'النظام', lastEditedAt: new Date().toISOString() },
    { id: createId('emp'), name: 'يوسف', role: 'مسؤول الموارد البشرية', systemRole: 'hr', department: 'الموارد البشرية', kpi: 'الاحتفاظ بالكفاءات', workload: 5, lastEditedBy: 'النظام', lastEditedAt: new Date().toISOString() }
  ],
  approvals: [
    { id: createId('apr'), type: 'budget', title: 'اعتماد ميزانية حملة الربع الثالث', notes: 'حملة رقمية + ميدانية', status: 'pending', requestedBy: 'مريم', decidedBy: '', decidedAt: '', createdAt: new Date().toISOString() }
  ],
  finances: [
    { id: createId('fin'), type: 'income', title: 'إيراد عقود تشغيل', amount: 92000, projectId: '', date: todayISO(), notes: 'دفعة أولى', lastEditedBy: 'مريم', lastEditedAt: new Date().toISOString() },
    { id: createId('fin'), type: 'expense', title: 'مصاريف تشغيلية', amount: 31000, projectId: '', date: todayISO(), notes: 'رواتب + لوجستيات', lastEditedBy: 'مريم', lastEditedAt: new Date().toISOString() }
  ],
  audit: [
    { id: createId('aud'), action: 'تهيئة النظام', details: 'تم تحميل النسخة التنفيذية', actor: 'النظام', time: new Date().toLocaleString('ar-EG') }
  ],
  followups: [],
  lastAction: ''
};

let state = loadState();
let currentUser = null;
let currentAdminPermissions = new Set();
let currentAdminExplicitPermissions = new Set();
let authTransitionInProgress = false;
let adminProfiles = [];
let dataUnsubscribers = [];
let currentUserAdminDocUnsubscribe = null;
let restaurantsSource = [];
let restaurantApplicationsSource = [];
let couriersSource = [];
let courierApplicationsSource = [];
const CEO_EMAIL = 'aluqili7@gmail.com';

const el = {
  navLinks: Array.from(document.querySelectorAll('#navLinks a')),
  sections: Array.from(document.querySelectorAll('main section[id]')),
  todayLabel: document.getElementById('todayLabel'),
  sessionUserLabel: document.getElementById('sessionUserLabel'),
  sessionRoleLabel: document.getElementById('sessionRoleLabel'),
  sessionLastActionLabel: document.getElementById('sessionLastActionLabel'),
  adminBadge: document.getElementById('adminBadge'),
  authModal: document.getElementById('authModal'),
  authForm: document.getElementById('authForm'),
  authUsername: document.getElementById('authUsername'),
  authPassword: document.getElementById('authPassword'),
  authFeedback: document.getElementById('authFeedback'),
  logoutBtn: document.getElementById('logoutBtn'),
  exportAllBtn: document.getElementById('exportAllBtn'),
  exportWeeklyBtn: document.getElementById('exportWeeklyBtn'),
  exportMonthlyBtn: document.getElementById('exportMonthlyBtn'),
  openTaskQuickBtn: document.getElementById('openTaskQuickBtn'),
  openProjectQuickBtn: document.getElementById('openProjectQuickBtn'),
  kpiCards: document.getElementById('kpiCards'),
  projectHealth: document.getElementById('projectHealth'),
  reportCards: document.getElementById('reportCards'),
  projectForm: document.getElementById('projectForm'),
  projectName: document.getElementById('projectName'),
  projectOwner: document.getElementById('projectOwner'),
  projectStatus: document.getElementById('projectStatus'),
  projectBudget: document.getElementById('projectBudget'),
  projectDueDate: document.getElementById('projectDueDate'),
  projectTableBody: document.getElementById('projectTableBody'),
  taskForm: document.getElementById('taskForm'),
  taskTitle: document.getElementById('taskTitle'),
  taskProject: document.getElementById('taskProject'),
  taskAssignee: document.getElementById('taskAssignee'),
  taskPriority: document.getElementById('taskPriority'),
  taskDueDate: document.getElementById('taskDueDate'),
  taskDescription: document.getElementById('taskDescription'),
  taskFilterProject: document.getElementById('taskFilterProject'),
  taskFilterAssignee: document.getElementById('taskFilterAssignee'),
  taskFilterStatus: document.getElementById('taskFilterStatus'),
  taskKanban: document.getElementById('taskKanban'),
  employeeForm: document.getElementById('employeeForm'),
  employeeId: document.getElementById('employeeId'),
  employeeName: document.getElementById('employeeName'),
  employeeRolePreset: document.getElementById('employeeRolePreset'),
  employeeRole: document.getElementById('employeeRole'),
  employeeSystemRole: document.getElementById('employeeSystemRole'),
  employeeDepartment: document.getElementById('employeeDepartment'),
  employeeKpi: document.getElementById('employeeKpi'),
  employeeWorkload: document.getElementById('employeeWorkload'),
  employeeSubmitBtn: document.getElementById('employeeSubmitBtn'),
  employeeCancelEditBtn: document.getElementById('employeeCancelEditBtn'),
  employeeCards: document.getElementById('employeeCards'),
  adminForm: document.getElementById('adminForm'),
  adminUid: document.getElementById('adminUid'),
  adminEmail: document.getElementById('adminEmail'),
  adminRole: document.getElementById('adminRole'),
  adminActive: document.getElementById('adminActive'),
  adminPermissionsGrid: document.getElementById('adminPermissionsGrid'),
  adminSubmitBtn: document.getElementById('adminSubmitBtn'),
  adminResetBtn: document.getElementById('adminResetBtn'),
  adminFormFeedback: document.getElementById('adminFormFeedback'),
  adminsTableBody: document.getElementById('adminsTableBody'),
  refreshAdminsBtn: document.getElementById('refreshAdminsBtn'),
  approvalForm: document.getElementById('approvalForm'),
  approvalType: document.getElementById('approvalType'),
  approvalTitle: document.getElementById('approvalTitle'),
  approvalNotes: document.getElementById('approvalNotes'),
  approvalList: document.getElementById('approvalList'),
  financeForm: document.getElementById('financeForm'),
  financeType: document.getElementById('financeType'),
  financeTitle: document.getElementById('financeTitle'),
  financeAmount: document.getElementById('financeAmount'),
  financeProject: document.getElementById('financeProject'),
  financeDate: document.getElementById('financeDate'),
  financeNotes: document.getElementById('financeNotes'),
  financeSummary: document.getElementById('financeSummary'),
  financeList: document.getElementById('financeList'),
  fieldOpsForm: document.getElementById('fieldOpsForm'),
  fieldOpsRecordId: document.getElementById('fieldOpsRecordId'),
  fieldOpsEntityType: document.getElementById('fieldOpsEntityType'),
  fieldOpsEntityId: document.getElementById('fieldOpsEntityId'),
  fieldOpsEntityName: document.getElementById('fieldOpsEntityName'),
  fieldOpsAssignedTo: document.getElementById('fieldOpsAssignedTo'),
  fieldOpsStage: document.getElementById('fieldOpsStage'),
  fieldOpsVisitStatus: document.getElementById('fieldOpsVisitStatus'),
  fieldOpsDecision: document.getElementById('fieldOpsDecision'),
  fieldOpsDecisionReason: document.getElementById('fieldOpsDecisionReason'),
  fieldOpsNextStep: document.getElementById('fieldOpsNextStep'),
  fieldOpsNotes: document.getElementById('fieldOpsNotes'),
  fieldOpsSubmitBtn: document.getElementById('fieldOpsSubmitBtn'),
  fieldOpsResetBtn: document.getElementById('fieldOpsResetBtn'),
  fieldOpsSummary: document.getElementById('fieldOpsSummary'),
  restaurantsPipelineBody: document.getElementById('restaurantsPipelineBody'),
  couriersPipelineBody: document.getElementById('couriersPipelineBody'),
  completedPipelineBody: document.getElementById('completedPipelineBody'),
  auditLogList: document.getElementById('auditLogList'),
  exportScopeButtons: Array.from(document.querySelectorAll('.export-scope-btn'))
};

function loadState() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (!saved) return { ...initialState };
    const parsed = JSON.parse(saved);
    return {
      ...initialState,
      ...parsed,
      projects: parsed.projects || initialState.projects,
      tasks: parsed.tasks || initialState.tasks,
      employees: (parsed.employees || initialState.employees).map((employee) => ({
        ...employee,
        systemRole: employee.systemRole || 'viewer'
      })),
      approvals: parsed.approvals || initialState.approvals,
      finances: parsed.finances || initialState.finances,
      audit: parsed.audit || initialState.audit,
      followups: parsed.followups || initialState.followups
    };
  } catch (error) {
    console.error('Failed loading state', error);
    return { ...initialState };
  }
}

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

async function upsertRecord(collectionKey, record) {
  const collectionName = COLLECTIONS[collectionKey];
  if (!collectionName || !record?.id) return;
  try {
    await setDoc(doc(db, collectionName, record.id), {
      ...record,
      updatedByUid: currentUser?.uid || '',
      updatedByEmail: currentUser?.email || '',
      updatedAt: serverTimestamp()
    }, { merge: true });
  } catch (error) {
    console.warn(`Failed upsert for ${collectionName}`, error);
  }
}

async function deleteRecord(collectionKey, id) {
  const collectionName = COLLECTIONS[collectionKey];
  if (!collectionName || !id) return;
  try {
    await deleteDoc(doc(db, collectionName, id));
  } catch (error) {
    console.warn(`Failed delete for ${collectionName}`, error);
  }
}

function parseDateValue(value) {
  if (!value) return '';
  if (typeof value?.toDate === 'function') {
    return value.toDate().toISOString();
  }
  return String(value);
}

async function ensureCollectionSeeded(collectionKey, records = []) {
  const collectionName = COLLECTIONS[collectionKey];
  if (!collectionName) return;
  try {
    const snap = await getDocs(collection(db, collectionName));
    if (!snap.empty) return;
    if (!Array.isArray(records) || !records.length) return;
    await Promise.all(records.filter((record) => record?.id).map((record) => upsertRecord(collectionKey, record)));
  } catch (error) {
    console.warn(`Skipped seeding ${collectionName}`, error);
  }
}

async function ensureRealtimeCollectionsInitialized() {
  await ensureCollectionSeeded('projects', state.projects || []);
  await ensureCollectionSeeded('tasks', state.tasks || []);
  await ensureCollectionSeeded('employees', state.employees || []);
  await ensureCollectionSeeded('approvals', state.approvals || []);
  await ensureCollectionSeeded('finances', state.finances || []);
  await ensureCollectionSeeded('audit', state.audit || []);
  await ensureCollectionSeeded('followups', state.followups || []);
}

function normalizeProjectDoc(item) {
  const data = item.data() || {};
  return {
    id: item.id,
    name: String(data.name || ''),
    owner: String(data.owner || ''),
    status: String(data.status || 'planning'),
    progress: Number(data.progress || 0),
    budget: Number(data.budget || 0),
    dueDate: String(data.dueDate || ''),
    lastEditedBy: String(data.lastEditedBy || data.updatedByEmail || 'النظام'),
    lastEditedAt: parseDateValue(data.lastEditedAt || data.updatedAt)
  };
}

function normalizeTaskDoc(item) {
  const data = item.data() || {};
  return {
    id: item.id,
    title: String(data.title || ''),
    projectId: String(data.projectId || ''),
    assignee: String(data.assignee || ''),
    priority: String(data.priority || 'medium'),
    status: String(data.status || 'todo'),
    dueDate: String(data.dueDate || ''),
    description: String(data.description || ''),
    lastEditedBy: String(data.lastEditedBy || data.updatedByEmail || 'النظام'),
    lastEditedAt: parseDateValue(data.lastEditedAt || data.updatedAt)
  };
}

function normalizeEmployeeDoc(item) {
  const data = item.data() || {};
  return {
    id: item.id,
    name: String(data.name || ''),
    role: String(data.role || 'موظف'),
    systemRole: String(data.systemRole || 'viewer'),
    department: String(data.department || ''),
    kpi: String(data.kpi || ''),
    workload: Number(data.workload || 0),
    lastEditedBy: String(data.lastEditedBy || data.updatedByEmail || 'النظام'),
    lastEditedAt: parseDateValue(data.lastEditedAt || data.updatedAt)
  };
}

function normalizeApprovalDoc(item) {
  const data = item.data() || {};
  return {
    id: item.id,
    type: String(data.type || 'policy'),
    title: String(data.title || ''),
    notes: String(data.notes || ''),
    status: String(data.status || 'pending'),
    requestedBy: String(data.requestedBy || ''),
    decidedBy: String(data.decidedBy || ''),
    decidedAt: parseDateValue(data.decidedAt),
    createdAt: parseDateValue(data.createdAt || data.updatedAt)
  };
}

function normalizeFinanceDoc(item) {
  const data = item.data() || {};
  return {
    id: item.id,
    type: String(data.type || 'expense'),
    title: String(data.title || ''),
    amount: Number(data.amount || 0),
    projectId: String(data.projectId || ''),
    date: String(data.date || todayISO()),
    notes: String(data.notes || ''),
    lastEditedBy: String(data.lastEditedBy || data.updatedByEmail || 'النظام'),
    lastEditedAt: parseDateValue(data.lastEditedAt || data.updatedAt)
  };
}

function normalizeAuditDoc(item) {
  const data = item.data() || {};
  return {
    id: item.id,
    action: String(data.action || ''),
    details: String(data.details || ''),
    actor: String(data.actor || 'النظام'),
    time: String(data.time || new Date().toLocaleString('ar-EG'))
  };
}

function normalizeFollowupDoc(item) {
  const data = item.data() || {};
  return {
    id: item.id,
    entityType: String(data.entityType || 'restaurant'),
    entityId: String(data.entityId || ''),
    entityName: String(data.entityName || ''),
    assignedTo: String(data.assignedTo || ''),
    stage: String(data.stage || 'lead_contact'),
    visitStatus: String(data.visitStatus || 'unknown'),
    decision: String(data.decision || 'pending'),
    decisionReason: String(data.decisionReason || ''),
    nextStep: String(data.nextStep || ''),
    notes: String(data.notes || ''),
    sourceStatus: String(data.sourceStatus || ''),
    lastEditedBy: String(data.lastEditedBy || data.updatedByEmail || 'النظام'),
    lastEditedAt: parseDateValue(data.lastEditedAt || data.updatedAt),
    createdBy: String(data.createdBy || data.updatedByEmail || 'النظام'),
    createdAt: parseDateValue(data.createdAt || data.updatedAt)
  };
}

function normalizeRestaurantSourceDoc(item) {
  const data = item.data() || {};
  return {
    id: item.id,
    name: String(data.name || data.restaurantName || data.storeName || data.title || item.id),
    approvalStatus: String(data.approvalStatus || (data.isApproved ? 'approved' : 'pending')),
    isApproved: data.isApproved === true
  };
}

function normalizeApplicationSourceDoc(item) {
  const data = item.data() || {};
  return {
    id: item.id,
    name: String(data.name || data.restaurantName || data.storeName || data.ownerName || item.id),
    status: String(data.status || data.approvalStatus || 'pending'),
    assignedTo: String(data.assignedTo || data.assignee || '')
  };
}

function normalizeCourierSourceDoc(item) {
  const data = item.data() || {};
  return {
    id: item.id,
    name: String(data.name || data.fullName || data.displayName || item.id),
    approvalStatus: String(data.approvalStatus || (data.isApproved ? 'approved' : 'pending')),
    isApproved: data.isApproved === true
  };
}

function stopRealtimeSync() {
  dataUnsubscribers.forEach((unsubscribe) => unsubscribe?.());
  dataUnsubscribers = [];
  currentUserAdminDocUnsubscribe?.();
  currentUserAdminDocUnsubscribe = null;
}

function startCurrentUserAdminSync() {
  currentUserAdminDocUnsubscribe?.();
  currentUserAdminDocUnsubscribe = null;
  if (!currentUser?.uid) return;

  currentUserAdminDocUnsubscribe = onSnapshot(
    doc(db, 'admins', currentUser.uid),
    (snap) => {
      const data = snap.exists() ? (snap.data() || {}) : {};
      const isStatic = GUARANTEED_ADMIN_EMAILS.has(String(currentUser?.email || '').toLowerCase());
      const permissions = normalizeAdminPermissions(data.permissions, { fallbackToAll: isStatic });
      const explicitPermissions = normalizeAdminPermissions(data.permissions, { fallbackToAll: false });
      currentAdminPermissions = new Set(permissions);
      currentAdminExplicitPermissions = new Set(explicitPermissions);
      if (data.role) {
        currentUser = { ...currentUser, role: String(data.role || currentUser.role || 'admin') };
      }
      render();
    },
    (error) => {
      console.warn('Current admin profile listener failed', error);
    }
  );
}

function startRealtimeSync() {
  stopRealtimeSync();

  dataUnsubscribers.push(
    onSnapshot(
      collection(db, COLLECTIONS.projects),
      (snap) => {
        state.projects = snap.docs.map(normalizeProjectDoc);
        saveState();
        render();
      },
      (error) => {
        console.warn('Projects realtime listener failed', error);
      }
    )
  );

  dataUnsubscribers.push(
    onSnapshot(
      collection(db, COLLECTIONS.tasks),
      (snap) => {
        state.tasks = snap.docs.map(normalizeTaskDoc);
        saveState();
        render();
      },
      (error) => {
        console.warn('Tasks realtime listener failed', error);
      }
    )
  );

  dataUnsubscribers.push(
    onSnapshot(
      collection(db, COLLECTIONS.employees),
      (snap) => {
        state.employees = snap.docs.map(normalizeEmployeeDoc);
        saveState();
        render();
      },
      (error) => {
        console.warn('Employees realtime listener failed', error);
      }
    )
  );

  dataUnsubscribers.push(
    onSnapshot(
      collection(db, COLLECTIONS.approvals),
      (snap) => {
        state.approvals = snap.docs.map(normalizeApprovalDoc);
        saveState();
        render();
      },
      (error) => {
        console.warn('Approvals realtime listener failed', error);
      }
    )
  );

  dataUnsubscribers.push(
    onSnapshot(
      collection(db, COLLECTIONS.finances),
      (snap) => {
        state.finances = snap.docs.map(normalizeFinanceDoc);
        saveState();
        render();
      },
      (error) => {
        console.warn('Finances realtime listener failed', error);
      }
    )
  );

  dataUnsubscribers.push(
    onSnapshot(
      collection(db, COLLECTIONS.audit),
      (snap) => {
        state.audit = snap.docs.map(normalizeAuditDoc);
        saveState();
        render();
      },
      (error) => {
        console.warn('Audit realtime listener failed', error);
      }
    )
  );

  dataUnsubscribers.push(
    onSnapshot(
      collection(db, COLLECTIONS.followups),
      (snap) => {
        state.followups = snap.docs.map(normalizeFollowupDoc);
        saveState();
        render();
      },
      (error) => {
        console.warn('Followups realtime listener failed', error);
      }
    )
  );

  dataUnsubscribers.push(
    onSnapshot(
      collection(db, 'admins'),
      (snap) => {
        adminProfiles = snap.docs.map((item) => {
          const data = item.data() || {};
          return {
            id: item.id,
            uid: String(data.uid || item.id),
            email: String(data.email || ''),
            role: String(data.role || 'admin'),
            active: data.active === true || data.role === 'admin',
            permissions: normalizeAdminPermissions(data.permissions, { fallbackToAll: true })
          };
        });
        renderAdminsTable();
      },
      (error) => {
        console.warn('Admins realtime listener failed', error);
      }
    )
  );

  dataUnsubscribers.push(
    onSnapshot(
      collection(db, 'restaurants'),
      (snap) => {
        restaurantsSource = snap.docs.map(normalizeRestaurantSourceDoc);
        render();
      },
      (error) => {
        console.warn('Restaurants source listener failed', error);
      }
    )
  );

  dataUnsubscribers.push(
    onSnapshot(
      collection(db, 'restaurantApplications'),
      (snap) => {
        restaurantApplicationsSource = snap.docs.map(normalizeApplicationSourceDoc);
        render();
      },
      (error) => {
        console.warn('Restaurant applications listener failed', error);
      }
    )
  );

  dataUnsubscribers.push(
    onSnapshot(
      collection(db, 'drivers'),
      (snap) => {
        couriersSource = snap.docs.map(normalizeCourierSourceDoc);
        render();
      },
      (error) => {
        console.warn('Couriers source listener failed', error);
      }
    )
  );

  dataUnsubscribers.push(
    onSnapshot(
      collection(db, 'courierApplications'),
      (snap) => {
        courierApplicationsSource = snap.docs.map(normalizeApplicationSourceDoc);
        render();
      },
      (error) => {
        console.warn('Courier applications listener failed', error);
      }
    )
  );
}

async function loadEmployeesFromFirestore() {
  try {
    const snap = await getDocs(collection(db, 'managementEmployees'));
    if (snap.empty) return;

    state.employees = snap.docs.map((item) => {
      const data = item.data() || {};
      return {
        id: item.id,
        name: String(data.name || ''),
        role: String(data.role || 'موظف'),
        systemRole: String(data.systemRole || 'viewer'),
        department: String(data.department || ''),
        kpi: String(data.kpi || ''),
        workload: Number(data.workload || 0),
        lastEditedBy: String(data.lastEditedBy || 'النظام'),
        lastEditedAt: String(data.lastEditedAt || new Date().toISOString())
      };
    });

    saveState();
  } catch (error) {
    console.warn('Failed loading employees from Firestore, fallback to local state.', error);
  }
}

async function upsertEmployeeInFirestore(employee) {
  try {
    await setDoc(doc(db, 'managementEmployees', employee.id), {
      name: employee.name,
      role: employee.role,
      systemRole: employee.systemRole,
      department: employee.department,
      kpi: employee.kpi,
      workload: Number(employee.workload || 0),
      lastEditedBy: employee.lastEditedBy,
      lastEditedAt: employee.lastEditedAt,
      updatedByUid: currentUser?.uid || '',
      updatedAt: serverTimestamp()
    }, { merge: true });
  } catch (error) {
    console.warn('Failed syncing employee to Firestore.', error);
  }
}

async function removeEmployeeFromFirestore(employeeId) {
  try {
    await deleteDoc(doc(db, 'managementEmployees', employeeId));
  } catch (error) {
    console.warn('Failed deleting employee from Firestore.', error);
  }
}

function roleLabel(role) {
  return ROLE_LABEL[role] || role;
}

function formatPermissionsSummary(permissions) {
  const normalized = normalizeAdminPermissions(permissions, { fallbackToAll: false });
  if (!normalized.length) return '-';
  return normalized.map((item) => ADMIN_PERMISSION_DEFS[item] || item).join('، ');
}

function renderAdminPermissionsChecklist(selected = ALL_ADMIN_PERMISSIONS) {
  if (!el.adminPermissionsGrid) return;
  const selectedSet = new Set(selected);
  el.adminPermissionsGrid.innerHTML = ALL_ADMIN_PERMISSIONS.map((permission) => `
    <label><input type="checkbox" name="adminPermission" value="${permission}" ${selectedSet.has(permission) ? 'checked' : ''} /> ${escapeHtml(ADMIN_PERMISSION_DEFS[permission] || permission)}</label>
  `).join('');
}

function resetAdminForm() {
  if (!el.adminForm) return;
  el.adminForm.reset();
  if (el.adminRole) el.adminRole.value = 'admin';
  if (el.adminActive) el.adminActive.checked = true;
  if (el.adminSubmitBtn) el.adminSubmitBtn.textContent = 'حفظ بيانات الأدمن';
  if (el.adminFormFeedback) el.adminFormFeedback.textContent = '';
  const defaultPermissions = ALL_ADMIN_PERMISSIONS.filter((permission) => permission !== 'employees');
  renderAdminPermissionsChecklist(defaultPermissions);
}

function fillAdminForm(item) {
  if (!el.adminForm) return;
  el.adminUid.value = item.uid || item.id;
  el.adminEmail.value = item.email || '';
  el.adminRole.value = item.role || 'admin';
  el.adminActive.checked = item.active === true;
  renderAdminPermissionsChecklist(item.permissions || []);
  if (el.adminSubmitBtn) el.adminSubmitBtn.textContent = 'تحديث بيانات الأدمن';
  activateSection('admins-panel');
}

function renderAdminsTable() {
  if (!el.adminsTableBody) return;

  if (!canManageAdminsPanel() || !hasPermission('admins:manage')) {
    el.adminsTableBody.innerHTML = '<tr><td colspan="6">لا تملك صلاحية إدارة المسؤولين.</td></tr>';
    return;
  }

  if (!adminProfiles.length) {
    el.adminsTableBody.innerHTML = '<tr><td colspan="6">لا توجد بيانات مسؤولين حالياً.</td></tr>';
    return;
  }

  el.adminsTableBody.innerHTML = adminProfiles.map((item) => `
    <tr>
      <td>${escapeHtml(item.email || '-')}</td>
      <td>${escapeHtml(item.uid)}</td>
      <td>${escapeHtml(item.role)}</td>
      <td>${escapeHtml(formatPermissionsSummary(item.permissions))}</td>
      <td>${item.active ? 'نشط' : 'غير نشط'}</td>
      <td>
        <button class="ghost-btn small" data-action="admin-edit" data-id="${item.id}">تعديل</button>
        <button class="ghost-btn small" data-action="admin-toggle" data-id="${item.id}">${item.active ? 'تعطيل' : 'تفعيل'}</button>
        <button class="ghost-btn small" data-action="admin-delete" data-id="${item.id}">حذف</button>
      </td>
    </tr>
  `).join('');
}

async function loadAdminsFromFirestore() {
  if (!canManageAdminsPanel() || !hasPermission('admins:manage')) {
    adminProfiles = [];
    renderAdminsTable();
    return;
  }

  const snap = await getDocs(collection(db, 'admins'));
  adminProfiles = snap.docs.map((item) => {
    const data = item.data() || {};
    return {
      id: item.id,
      uid: String(data.uid || item.id),
      email: String(data.email || ''),
      role: String(data.role || 'admin'),
      active: data.active === true || data.role === 'admin',
      permissions: normalizeAdminPermissions(data.permissions, { fallbackToAll: true })
    };
  });

  renderAdminsTable();
}

async function saveAdminProfile() {
  if (!requirePermission('admins:manage', 'إدارة المسؤولين')) return;

  const uid = el.adminUid.value.trim();
  const email = el.adminEmail.value.trim().toLowerCase();
  const role = el.adminRole.value;
  const active = el.adminActive.checked;
  const permissions = Array.from(el.adminPermissionsGrid.querySelectorAll('input[name="adminPermission"]:checked')).map((item) => item.value);

  if (!uid || !email) {
    el.adminFormFeedback.textContent = 'الرجاء إدخال UID والبريد الإلكتروني.';
    return;
  }

  await setDoc(doc(db, 'admins', uid), {
    uid,
    email,
    role,
    active,
    permissions,
    updatedByUid: currentUser?.uid || '',
    updatedByEmail: currentUser?.email || '',
    updatedAt: serverTimestamp()
  }, { merge: true });

  pushAudit('تحديث مسؤول', `${email} (${active ? 'نشط' : 'غير نشط'})`);
  saveState();
  el.adminFormFeedback.textContent = 'تم حفظ بيانات المسؤول بنجاح.';
  await loadAdminsFromFirestore();
}

async function handleAdminsTableAction(event) {
  const button = event.target.closest('button[data-action]');
  if (!button) return;
  const action = button.dataset.action;
  if (action !== 'admin-edit' && action !== 'admin-toggle' && action !== 'admin-delete') return;

  const id = button.dataset.id;
  const item = adminProfiles.find((entry) => entry.id === id || entry.uid === id);
  if (!item) return;

  if (action === 'admin-edit') {
    fillAdminForm(item);
    return;
  }

  if (action === 'admin-delete') {
    if (!requirePermission('admins:manage', 'إدارة المسؤولين')) return;
    if (item.uid === currentUser?.uid || String(item.email || '').toLowerCase() === CEO_EMAIL) {
      el.adminFormFeedback.textContent = 'لا يمكن حذف حساب الرئيس التنفيذي الحالي.';
      return;
    }
    await deleteDoc(doc(db, 'admins', item.uid));
    pushAudit('حذف مسؤول', item.email || item.uid);
    saveState();
    await loadAdminsFromFirestore();
    return;
  }

  if (!requirePermission('admins:manage', 'إدارة المسؤولين')) return;
  await setDoc(doc(db, 'admins', item.uid), {
    active: !item.active,
    updatedByUid: currentUser?.uid || '',
    updatedByEmail: currentUser?.email || '',
    updatedAt: serverTimestamp()
  }, { merge: true });

  pushAudit(item.active ? 'تعطيل مسؤول' : 'تفعيل مسؤول', item.email || item.uid);
  saveState();
  await loadAdminsFromFirestore();
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

async function loadAdminAccessProfile(user) {
  if (!user) {
    return { allowed: false, permissions: [], explicitPermissions: [], isStaticAdmin: false, role: 'viewer' };
  }

  const normalizedEmail = String(user.email || '').toLowerCase();
  if (GUARANTEED_ADMIN_EMAILS.has(normalizedEmail)) {
    const adminDoc = await getDoc(doc(db, 'admins', user.uid));
    const adminData = adminDoc.exists() ? (adminDoc.data() || {}) : {};
    return {
      allowed: true,
      permissions: [...ALL_ADMIN_PERMISSIONS],
      explicitPermissions: normalizeAdminPermissions(adminData.permissions, { fallbackToAll: false }),
      isStaticAdmin: true,
      role: 'admin'
    };
  }

  const adminDoc = await getDoc(doc(db, 'admins', user.uid));
  if (!adminDoc.exists()) {
    return { allowed: false, permissions: [], explicitPermissions: [], isStaticAdmin: false, role: 'viewer' };
  }

  const data = adminDoc.data() || {};
  const allowed = data.role === 'admin' || data.active === true;
  return {
    allowed,
    permissions: normalizeAdminPermissions(data.permissions, { fallbackToAll: true }),
    explicitPermissions: normalizeAdminPermissions(data.permissions, { fallbackToAll: false }),
    isStaticAdmin: false,
    role: String(data.role || 'admin')
  };
}

function hasPermission(permission) {
  if (!currentUser) return false;
  const required = ACTION_PERMISSION_REQUIREMENTS[permission] || [];
  if (!required.length) return true;
  return required.some((adminPermission) => currentAdminPermissions.has(adminPermission));
}

function setLastAction(actionText) {
  state.lastAction = `${actionText} بواسطة ${getActorName()}`;
  saveState();
}

function getActorName() {
  return currentUser?.displayName || currentUser?.email || 'غير معروف';
}

function isCeoEmailUser() {
  return String(currentUser?.email || '').toLowerCase() === CEO_EMAIL;
}

function canManageAdminsPanel() {
  return isCeoEmailUser();
}

function canViewEmployeesPanel() {
  return isCeoEmailUser() || currentAdminExplicitPermissions.has('employees');
}

function openAuthModal() {
  el.authModal.classList.remove('hidden');
  el.authModal.setAttribute('aria-hidden', 'false');
  el.authFeedback.textContent = 'سجل بنفس بريد وكلمة مرور موقع الادمن.';
  el.authUsername.focus();
}

function closeAuthModal() {
  el.authModal.classList.add('hidden');
  el.authModal.setAttribute('aria-hidden', 'true');
}

function requirePermission(permission, actionLabel) {
  if (!currentUser) {
    openAuthModal();
    return false;
  }
  if (permission === 'admins:manage' && !canManageAdminsPanel()) {
    el.authFeedback.textContent = 'إدارة المسؤولين متاحة للرئيس التنفيذي فقط.';
    return false;
  }
  if ((permission === 'employee:add' || permission === 'employee:edit') && !isCeoEmailUser()) {
    el.authFeedback.textContent = 'إدارة بيانات الموظفين متاحة للرئيس التنفيذي فقط.';
    return false;
  }
  if (!hasPermission(permission)) {
    el.authFeedback.textContent = `ليس لديك صلاحية: ${actionLabel}`;
    return false;
  }
  return true;
}

function pushAudit(action, details) {
  const entry = {
    id: createId('aud'),
    action,
    details,
    actor: getActorName(),
    time: new Date().toLocaleString('ar-EG')
  };
  state.audit = [entry, ...(state.audit || [])].slice(0, 300);
  void upsertRecord('audit', {
    ...entry,
    createdAt: new Date().toISOString()
  });
  setLastAction(action);
}

function updateNavActive(targetId) {
  el.navLinks.forEach((link) => {
    link.classList.toggle('active', link.getAttribute('href') === `#${targetId}`);
  });
}

function activateSection(targetId) {
  const fallbackId = 'executive';
  let nextId = el.sections.some((section) => section.id === targetId) ? targetId : fallbackId;
  if (nextId === 'admins-panel' && !canManageAdminsPanel()) {
    nextId = fallbackId;
  }
  if (nextId === 'employees' && !canViewEmployeesPanel()) {
    nextId = fallbackId;
  }
  el.sections.forEach((section) => {
    const isActive = section.id === nextId;
    section.classList.toggle('is-active', isActive);
    section.hidden = !isActive;
    section.style.display = isActive
      ? (section.classList.contains('section-grid') ? 'grid' : 'block')
      : 'none';
  });
  updateNavActive(nextId);
  try {
    history.replaceState(null, '', `#${nextId}`);
  } catch (_) {
  }
}

function attachNavBehavior() {
  el.navLinks.forEach((link) => {
    link.addEventListener('click', (event) => {
      const id = link.getAttribute('href')?.replace('#', '');
      if (!id) return;
      event.preventDefault();
      activateSection(id);
    });
  });

  const hashId = String(window.location.hash || '').replace('#', '').trim();
  activateSection(hashId || 'executive');
}

function getProjectName(projectId) {
  const project = state.projects.find((item) => item.id === projectId);
  return project ? project.name : '-';
}

function formatCurrency(value) {
  return `${Number(value || 0).toLocaleString('ar-EG')} ر.س`;
}

function statusLabel(status) {
  return {
    planning: 'تخطيط',
    active: 'نشط',
    risk: 'مخاطر',
    done: 'مكتمل',
    todo: 'To Do',
    in_progress: 'In Progress',
    review: 'Review'
  }[status] || status;
}

function nextTaskStatus(status) {
  return {
    todo: 'in_progress',
    in_progress: 'review',
    review: 'done',
    done: 'done'
  }[status] || 'todo';
}

function renderSessionHeader() {
  const userText = currentUser ? `${currentUser.displayName} (${currentUser.email})` : '-';
  const roleText = currentUser ? roleLabel(currentUser.role) : '-';
  el.sessionUserLabel.textContent = `المستخدم: ${userText}`;
  el.sessionRoleLabel.textContent = `الدور: ${roleText}`;
  el.sessionLastActionLabel.textContent = `آخر إجراء: ${state.lastAction || '-'}`;
  if (currentUser) {
    el.adminBadge.textContent = `نشط: ${currentUser.displayName}`;
    el.adminBadge.classList.add('logged-in');
    el.logoutBtn.style.display = 'inline-flex';
  } else {
    el.adminBadge.textContent = 'تسجيل الدخول مطلوب';
    el.adminBadge.classList.remove('logged-in');
    el.logoutBtn.style.display = 'none';
  }
}

function renderExecutive() {
  el.todayLabel.textContent = new Date().toLocaleDateString('ar-EG', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });

  const pendingApprovals = state.approvals.filter((a) => a.status === 'pending').length;
  const openTasks = state.tasks.filter((task) => task.status !== 'done').length;
  const riskyProjects = state.projects.filter((project) => project.status === 'risk').length;
  const totalBudget = state.projects.reduce((sum, project) => sum + Number(project.budget || 0), 0);

  el.kpiCards.innerHTML = [
    { label: 'المشاريع', value: state.projects.length },
    { label: 'المهام المفتوحة', value: openTasks },
    { label: 'الموافقات المعلقة', value: pendingApprovals },
    { label: 'المشاريع ذات المخاطر', value: riskyProjects },
    { label: 'عدد الموظفين', value: state.employees.length },
    { label: 'إجمالي الميزانيات', value: formatCurrency(totalBudget) },
    { label: 'عمليات مالية', value: state.finances.length },
    { label: 'نسبة إنجاز عامة', value: `${Math.round(averageProjectProgress())}%` }
  ].map((item) => `
    <div class="stat-card">
      <span class="label">${escapeHtml(item.label)}</span>
      <h4>${escapeHtml(item.value)}</h4>
    </div>
  `).join('');

  el.projectHealth.innerHTML = state.projects.map((project) => `
    <div class="health-item">
      <div class="health-title">${escapeHtml(project.name)}</div>
      <div class="health-meta">الحالة: ${escapeHtml(statusLabel(project.status))}</div>
      <div class="health-meta">التقدم: ${project.progress}%</div>
      <div class="health-meta">المالك: ${escapeHtml(project.owner)}</div>
      <div class="health-meta">التسليم: ${escapeHtml(project.dueDate)}</div>
    </div>
  `).join('');
}

function averageProjectProgress() {
  if (!state.projects.length) return 0;
  const sum = state.projects.reduce((acc, project) => acc + Number(project.progress || 0), 0);
  return sum / state.projects.length;
}

function renderProjectTable() {
  el.projectTableBody.innerHTML = state.projects.map((project) => `
    <tr>
      <td>${escapeHtml(project.name)}</td>
      <td>${escapeHtml(project.owner)}</td>
      <td><span class="status-badge ${escapeHtml(project.status)}">${escapeHtml(statusLabel(project.status))}</span></td>
      <td>${project.progress}%</td>
      <td>${formatCurrency(project.budget)}</td>
      <td>${escapeHtml(project.dueDate)}</td>
      <td>${escapeHtml(project.lastEditedBy || '-')}</td>
      <td>
        <button class="ghost-btn small" data-action="project-advance" data-id="${project.id}">+10%</button>
        <button class="ghost-btn small" data-action="project-risk" data-id="${project.id}">تحويل لمخاطر</button>
        <button class="ghost-btn small" data-action="project-delete" data-id="${project.id}">حذف</button>
      </td>
    </tr>
  `).join('');
}

function refreshProjectSelectors() {
  const options = ['<option value="">بدون مشروع</option>', ...state.projects.map((project) => `<option value="${project.id}">${escapeHtml(project.name)}</option>`)];
  el.taskProject.innerHTML = options.join('');
  el.financeProject.innerHTML = options.join('');

  const filterOptions = ['<option value="all">كل المشاريع</option>', ...state.projects.map((project) => `<option value="${project.id}">${escapeHtml(project.name)}</option>`)];
  el.taskFilterProject.innerHTML = filterOptions.join('');
}

function refreshEmployeeSelectors() {
  const options = ['<option value="">اختر موظفًا</option>', ...state.employees.map((employee) => `<option value="${escapeHtml(employee.name)}">${escapeHtml(employee.name)}</option>`)];
  el.taskAssignee.innerHTML = options.join('');

  const filterOptions = ['<option value="all">كل الموظفين</option>', ...state.employees.map((employee) => `<option value="${escapeHtml(employee.name)}">${escapeHtml(employee.name)}</option>`)];
  el.taskFilterAssignee.innerHTML = filterOptions.join('');
}

function renderTaskKanban() {
  const filterProject = el.taskFilterProject.value || 'all';
  const filterAssignee = el.taskFilterAssignee.value || 'all';
  const filterStatus = el.taskFilterStatus.value || 'all';

  const filtered = state.tasks.filter((task) => {
    const statusOk = filterStatus === 'all' || task.status === filterStatus;
    const projectOk = filterProject === 'all' || task.projectId === filterProject;
    const assigneeOk = filterAssignee === 'all' || task.assignee === filterAssignee;
    return statusOk && projectOk && assigneeOk;
  });

  const columns = [
    { key: 'todo', label: 'To Do' },
    { key: 'in_progress', label: 'In Progress' },
    { key: 'review', label: 'Review' },
    { key: 'done', label: 'Done' }
  ];

  el.taskKanban.innerHTML = columns.map((column) => {
    const cards = filtered.filter((task) => task.status === column.key).map((task) => `
      <div class="task-card">
        <h5>${escapeHtml(task.title)}</h5>
        <div class="task-meta">المشروع: ${escapeHtml(getProjectName(task.projectId))}</div>
        <div class="task-meta">المسؤول: ${escapeHtml(task.assignee || '-')}</div>
        <div class="task-meta">الأولوية: ${escapeHtml(task.priority)}</div>
        <div class="task-meta">الاستحقاق: ${escapeHtml(task.dueDate)}</div>
        <div class="task-meta">آخر تعديل: ${escapeHtml(task.lastEditedBy || '-')}</div>
        <div class="item-actions">
          <button class="ghost-btn small" data-action="task-advance" data-id="${task.id}">التالي</button>
          <button class="ghost-btn small" data-action="task-delete" data-id="${task.id}">حذف</button>
        </div>
      </div>
    `).join('');

    return `
      <div class="kanban-col">
        <div class="kanban-title">${escapeHtml(column.label)}</div>
        ${cards || '<div class="task-meta">لا توجد مهام</div>'}
      </div>
    `;
  }).join('');
}

function renderEmployees() {
  if (!canViewEmployeesPanel()) {
    el.employeeCards.innerHTML = '<div class="employee-card"><div class="employee-meta">عرض الموظفين متاح فقط للرئيس التنفيذي أو من يمنحه هذه الصلاحية.</div></div>';
    return;
  }

  const canEdit = hasPermission('employee:edit') && isCeoEmailUser();
  el.employeeCards.innerHTML = state.employees.map((employee) => `
    <div class="employee-card">
      <h4>${escapeHtml(employee.name)}</h4>
      <div class="employee-meta">الدور: ${escapeHtml(employee.role)}</div>
      <div class="employee-meta">دور النظام: ${escapeHtml(roleLabel(employee.systemRole || 'viewer'))}</div>
      <div class="employee-meta">القسم: ${escapeHtml(employee.department)}</div>
      <div class="employee-meta">KPI: ${escapeHtml(employee.kpi)}</div>
      <div class="employee-meta">الحمل: ${escapeHtml(employee.workload)}/10</div>
      <div class="employee-meta">آخر تعديل: ${escapeHtml(employee.lastEditedBy || '-')}</div>
      ${canEdit ? `
        <div class="item-actions">
          <button class="ghost-btn small" data-action="employee-edit" data-id="${employee.id}">تعديل</button>
          <button class="ghost-btn small" data-action="employee-delete" data-id="${employee.id}">حذف</button>
        </div>
      ` : ''}
    </div>
  `).join('');
}

function renderApprovals() {
  el.approvalList.innerHTML = state.approvals.map((approval) => {
    const canDecide = hasPermission('approval:decide') && approval.status === 'pending';
    return `
      <div class="approval-card">
        <h5>${escapeHtml(approval.title)}</h5>
        <div class="approval-meta">النوع: ${escapeHtml(statusLabel(approval.type))}</div>
        <div class="approval-meta">الملاحظات: ${escapeHtml(approval.notes || '-')}</div>
        <div class="approval-meta">الحالة: <span class="status-badge ${escapeHtml(approval.status === 'pending' ? 'review' : approval.status === 'approved' ? 'done' : 'risk')}">${escapeHtml(approval.status === 'approved' ? 'معتمد' : approval.status === 'rejected' ? 'مرفوض' : 'معلق')}</span></div>
        <div class="approval-meta">المقدم: ${escapeHtml(approval.requestedBy)}</div>
        <div class="approval-meta">القرار: ${escapeHtml(approval.decidedBy || '-')}</div>
        ${canDecide ? `
          <div class="item-actions">
            <button class="ghost-btn small" data-action="approval-approve" data-id="${approval.id}">اعتماد</button>
            <button class="ghost-btn small" data-action="approval-reject" data-id="${approval.id}">رفض</button>
          </div>
        ` : ''}
      </div>
    `;
  }).join('');
}

function renderFinance() {
  const income = state.finances.filter((item) => item.type === 'income').reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const expense = state.finances.filter((item) => item.type === 'expense').reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const balance = income - expense;

  el.financeSummary.innerHTML = `
    <div class="summary-box">
      <span>إجمالي الإيراد</span>
      <strong>${formatCurrency(income)}</strong>
    </div>
    <div class="summary-box">
      <span>إجمالي المصروف</span>
      <strong>${formatCurrency(expense)}</strong>
    </div>
    <div class="summary-box highlight">
      <span>الرصيد</span>
      <strong>${formatCurrency(balance)}</strong>
    </div>
  `;

  el.financeList.innerHTML = state.finances
    .slice()
    .sort((a, b) => new Date(b.date) - new Date(a.date))
    .map((item) => `
      <div class="finance-card">
        <h5>${escapeHtml(item.title)}</h5>
        <div class="finance-meta">النوع: ${escapeHtml(item.type === 'income' ? 'إيراد' : 'مصروف')}</div>
        <div class="finance-meta">القيمة: ${formatCurrency(item.amount)}</div>
        <div class="finance-meta">المشروع: ${escapeHtml(getProjectName(item.projectId))}</div>
        <div class="finance-meta">التاريخ: ${escapeHtml(item.date)}</div>
        <div class="finance-meta">آخر تعديل: ${escapeHtml(item.lastEditedBy || '-')}</div>
      </div>
    `).join('');
}

const STAGE_LABELS = {
  lead_contact: 'بدء تواصل',
  visit_scheduled: 'زيارة مجدولة',
  visited: 'تمت الزيارة',
  docs_pending: 'نواقص مستندات',
  approved: 'معتمد',
  rejected: 'مرفوض',
  onboarded: 'مفعّل تشغيليًا',
  stalled: 'متوقف'
};

const VISIT_LABELS = {
  unknown: 'غير محدد',
  pending: 'بانتظار الزيارة',
  completed: 'تمت الزيارة',
  not_done: 'لم تتم'
};

const DECISION_LABELS = {
  pending: 'معلق',
  approved: 'مقبول',
  rejected: 'مرفوض'
};

const SOURCE_STATUS_LABELS = {
  registered: 'مسجل',
  applied: 'طلب جديد',
  unregistered: 'غير مسجل'
};

const STAGE_ORDER = ['lead_contact', 'visit_scheduled', 'visited', 'docs_pending', 'approved', 'onboarded'];

function mapById(items = []) {
  const out = new Map();
  items.forEach((item) => {
    if (item?.id) out.set(item.id, item);
  });
  return out;
}

function followupByEntity(entityType, entityId) {
  return (state.followups || []).find((item) => item.entityType === entityType && item.entityId === entityId) || null;
}

function inferDecisionFromStatus(statusValue) {
  const status = String(statusValue || '').toLowerCase();
  if (status === 'approved' || status === 'active') return 'approved';
  if (status === 'rejected' || status === 'declined') return 'rejected';
  return 'pending';
}

function nextStage(stage) {
  const idx = STAGE_ORDER.indexOf(stage);
  if (idx < 0 || idx >= STAGE_ORDER.length - 1) return stage || 'lead_contact';
  return STAGE_ORDER[idx + 1];
}

function isFollowupCompleted(row) {
  if (!row) return false;
  return row.stage === 'onboarded'
    || row.stage === 'approved'
    || row.stage === 'rejected'
    || row.decision === 'approved'
    || row.decision === 'rejected';
}

function buildPipelineRows(entityType) {
  const sourceList = entityType === 'restaurant' ? restaurantsSource : couriersSource;
  const applicationsList = entityType === 'restaurant' ? restaurantApplicationsSource : courierApplicationsSource;

  const sourceMap = mapById(sourceList);
  const applicationMap = mapById(applicationsList);
  const followups = (state.followups || []).filter((item) => item.entityType === entityType);
  const followupMap = new Map(followups.map((item) => [item.entityId, item]));

  // Show only new leads (applications + explicit followups), not all already-registered entities.
  const entityIds = new Set([
    ...applicationsList.map((item) => item.id),
    ...followups.map((item) => item.entityId)
  ].filter(Boolean));

  const rows = Array.from(entityIds).map((entityId) => {
    const source = sourceMap.get(entityId);
    const application = applicationMap.get(entityId);
    const followup = followupMap.get(entityId);

    const sourceStatus = source
      ? 'registered'
      : application
        ? 'applied'
        : (followup?.sourceStatus || 'unregistered');

    const sourceDecision = inferDecisionFromStatus(source?.approvalStatus || application?.status);
    const decision = followup?.decision || sourceDecision;

    const stage = followup?.stage
      || (decision === 'approved' && source ? 'onboarded' : source ? 'approved' : application ? 'docs_pending' : 'lead_contact');

    const visitStatus = followup?.visitStatus || (stage === 'visited' || stage === 'approved' || stage === 'onboarded' ? 'completed' : 'unknown');

    return {
      entityType,
      entityId,
      entityName: followup?.entityName || source?.name || application?.name || entityId,
      sourceStatus,
      decision,
      stage,
      visitStatus,
      nextStep: followup?.nextStep || '',
      assignedTo: followup?.assignedTo || application?.assignedTo || '',
      notes: followup?.notes || '',
      decisionReason: followup?.decisionReason || '',
      followupId: followup?.id || '',
      lastEditedBy: followup?.lastEditedBy || '-',
      lastEditedAt: followup?.lastEditedAt || ''
    };
  });

  return rows.sort((a, b) => {
    const aPending = a.decision === 'pending' ? 0 : 1;
    const bPending = b.decision === 'pending' ? 0 : 1;
    if (aPending !== bPending) return aPending - bPending;
    return String(a.entityName || '').localeCompare(String(b.entityName || ''), 'ar');
  });
}

function buildActivePipelineRows(entityType) {
  return buildPipelineRows(entityType).filter((row) => !isFollowupCompleted(row));
}

function buildCompletedPipelineRows() {
  const combined = [...buildPipelineRows('restaurant'), ...buildPipelineRows('courier')];
  return combined
    .filter((row) => isFollowupCompleted(row))
    .sort((a, b) => new Date(b.lastEditedAt || 0).getTime() - new Date(a.lastEditedAt || 0).getTime());
}

function stageBadgeClass(stage) {
  if (stage === 'approved' || stage === 'onboarded') return 'done';
  if (stage === 'rejected' || stage === 'stalled') return 'risk';
  if (stage === 'visited' || stage === 'visit_scheduled' || stage === 'docs_pending') return 'review';
  return 'planning';
}

function decisionBadgeClass(decision) {
  if (decision === 'approved') return 'done';
  if (decision === 'rejected') return 'risk';
  return 'review';
}

function renderPipelineTableRows(rows = []) {
  if (!rows.length) {
    return '<tr><td colspan="10">لا توجد بيانات حالياً.</td></tr>';
  }

  return rows.map((row) => `
    <tr>
      <td>${escapeHtml(row.entityName)}</td>
      <td>${escapeHtml(row.entityId)}</td>
      <td>${escapeHtml(SOURCE_STATUS_LABELS[row.sourceStatus] || row.sourceStatus)}</td>
      <td>${escapeHtml(VISIT_LABELS[row.visitStatus] || row.visitStatus)}</td>
      <td><span class="status-badge ${decisionBadgeClass(row.decision)}">${escapeHtml(DECISION_LABELS[row.decision] || row.decision)}</span></td>
      <td><span class="status-badge ${stageBadgeClass(row.stage)}">${escapeHtml(STAGE_LABELS[row.stage] || row.stage)}</span></td>
      <td>${escapeHtml(row.nextStep || '-')}</td>
      <td>${escapeHtml(row.assignedTo || '-')}</td>
      <td>${escapeHtml(row.lastEditedBy || '-')}</td>
      <td>
        <button class="ghost-btn small" data-action="followup-edit" data-type="${row.entityType}" data-id="${row.entityId}">تعديل</button>
        <button class="ghost-btn small" data-action="followup-advance" data-type="${row.entityType}" data-id="${row.entityId}">التالي</button>
        <button class="ghost-btn small" data-action="followup-approve" data-type="${row.entityType}" data-id="${row.entityId}">اعتماد</button>
        <button class="ghost-btn small" data-action="followup-reject" data-type="${row.entityType}" data-id="${row.entityId}">رفض</button>
      </td>
    </tr>
  `).join('');
}

function renderCompletedTableRows(rows = []) {
  if (!rows.length) {
    return '<tr><td colspan="8">لا توجد حالات مكتملة حالياً.</td></tr>';
  }

  return rows.map((row) => `
    <tr>
      <td>${escapeHtml(row.entityType === 'restaurant' ? 'مطعم' : 'مندوب')}</td>
      <td>${escapeHtml(row.entityName)}</td>
      <td>${escapeHtml(row.entityId)}</td>
      <td><span class="status-badge ${decisionBadgeClass(row.decision)}">${escapeHtml(DECISION_LABELS[row.decision] || row.decision)}</span></td>
      <td><span class="status-badge ${stageBadgeClass(row.stage)}">${escapeHtml(STAGE_LABELS[row.stage] || row.stage)}</span></td>
      <td>${escapeHtml(row.assignedTo || '-')}</td>
      <td>${escapeHtml(row.lastEditedBy || '-')}</td>
      <td>
        <button class="ghost-btn small" data-action="followup-edit" data-type="${row.entityType}" data-id="${row.entityId}">عرض/تعديل</button>
      </td>
    </tr>
  `).join('');
}

function renderFieldOps() {
  if (!el.restaurantsPipelineBody || !el.couriersPipelineBody || !el.completedPipelineBody || !el.fieldOpsSummary) return;

  const restaurantsRows = buildActivePipelineRows('restaurant');
  const couriersRows = buildActivePipelineRows('courier');
  const completedRows = buildCompletedPipelineRows();

  const pendingRestaurants = restaurantsRows.filter((item) => item.decision === 'pending').length;
  const pendingCouriers = couriersRows.filter((item) => item.decision === 'pending').length;
  const completedVisits = [...restaurantsRows, ...couriersRows].filter((item) => item.visitStatus === 'completed').length;
  const stalled = [...restaurantsRows, ...couriersRows].filter((item) => item.stage === 'stalled').length;

  el.fieldOpsSummary.innerHTML = [
    { label: 'مطاعم جديدة قيد المتابعة', value: restaurantsRows.length },
    { label: 'مندوبون جدد قيد المتابعة', value: couriersRows.length },
    { label: 'مطاعم معلقة', value: pendingRestaurants },
    { label: 'مندوبون معلقون', value: pendingCouriers },
    { label: 'زيارات مكتملة', value: completedVisits },
    { label: 'حالات متوقفة', value: stalled },
    { label: 'حالات مكتملة', value: completedRows.length }
  ].map((item) => `
    <div class="stat-card">
      <span class="label">${escapeHtml(item.label)}</span>
      <h4>${escapeHtml(item.value)}</h4>
    </div>
  `).join('');

  el.restaurantsPipelineBody.innerHTML = renderPipelineTableRows(restaurantsRows);
  el.couriersPipelineBody.innerHTML = renderPipelineTableRows(couriersRows);
  el.completedPipelineBody.innerHTML = renderCompletedTableRows(completedRows);
}

function resetFieldOpsForm() {
  if (!el.fieldOpsForm) return;
  el.fieldOpsForm.reset();
  el.fieldOpsRecordId.value = '';
  if (el.fieldOpsEntityType) el.fieldOpsEntityType.value = 'restaurant';
  if (el.fieldOpsVisitStatus) el.fieldOpsVisitStatus.value = 'unknown';
  if (el.fieldOpsDecision) el.fieldOpsDecision.value = 'pending';
  if (el.fieldOpsStage) el.fieldOpsStage.value = 'lead_contact';
  if (el.fieldOpsSubmitBtn) el.fieldOpsSubmitBtn.textContent = 'حفظ المتابعة';
}

function populateFieldOpsForm(row) {
  if (!el.fieldOpsForm || !row) return;
  el.fieldOpsRecordId.value = row.followupId || '';
  el.fieldOpsEntityType.value = row.entityType || 'restaurant';
  el.fieldOpsEntityId.value = row.entityId || '';
  el.fieldOpsEntityName.value = row.entityName || '';
  el.fieldOpsAssignedTo.value = row.assignedTo || '';
  el.fieldOpsStage.value = row.stage || 'lead_contact';
  el.fieldOpsVisitStatus.value = row.visitStatus || 'unknown';
  el.fieldOpsDecision.value = row.decision || 'pending';
  el.fieldOpsDecisionReason.value = row.decisionReason || '';
  el.fieldOpsNextStep.value = row.nextStep || '';
  el.fieldOpsNotes.value = row.notes || '';
  if (el.fieldOpsSubmitBtn) el.fieldOpsSubmitBtn.textContent = 'تحديث المتابعة';
  activateSection('field-ops');
  el.fieldOpsEntityName.focus();
}

function getPipelineRow(entityType, entityId) {
  const rows = buildPipelineRows(entityType);
  return rows.find((row) => row.entityId === entityId) || null;
}

async function handleFieldOpsSubmit(event) {
  event.preventDefault();
  if (!requirePermission('followup:manage', 'إدارة المتابعة الميدانية')) return;

  const entityType = el.fieldOpsEntityType.value;
  const entityId = el.fieldOpsEntityId.value.trim();
  const entityName = el.fieldOpsEntityName.value.trim();
  if (!entityId || !entityName) return;

  const existing = followupByEntity(entityType, entityId);
  const nowIso = new Date().toISOString();
  const record = {
    id: existing?.id || el.fieldOpsRecordId.value.trim() || createId('fup'),
    entityType,
    entityId,
    entityName,
    assignedTo: el.fieldOpsAssignedTo.value.trim(),
    stage: el.fieldOpsStage.value,
    visitStatus: el.fieldOpsVisitStatus.value,
    decision: el.fieldOpsDecision.value,
    decisionReason: el.fieldOpsDecisionReason.value.trim(),
    nextStep: el.fieldOpsNextStep.value.trim(),
    notes: el.fieldOpsNotes.value.trim(),
    sourceStatus: getPipelineRow(entityType, entityId)?.sourceStatus || 'unregistered',
    createdBy: existing?.createdBy || getActorName(),
    createdAt: existing?.createdAt || nowIso,
    lastEditedBy: getActorName(),
    lastEditedAt: nowIso
  };

  state.followups = [...(state.followups || []).filter((item) => !(item.entityType === entityType && item.entityId === entityId)), record];
  void upsertRecord('followups', record);
  pushAudit('تحديث متابعة ميدانية', `${entityType === 'restaurant' ? 'مطعم' : 'مندوب'}: ${entityName}`);
  saveState();
  resetFieldOpsForm();
  render();
}

function handleFieldOpsTableAction(event) {
  const button = event.target.closest('button[data-action]');
  if (!button) return;

  const action = button.dataset.action;
  const entityType = button.dataset.type;
  const entityId = button.dataset.id;
  if (!entityType || !entityId) return;

  const row = getPipelineRow(entityType, entityId);
  if (!row) return;

  if (action === 'followup-edit') {
    populateFieldOpsForm(row);
    return;
  }

  if (!requirePermission('followup:manage', 'إدارة المتابعة الميدانية')) return;

  const existing = followupByEntity(entityType, entityId);
  const nowIso = new Date().toISOString();
  const record = {
    id: existing?.id || createId('fup'),
    entityType,
    entityId,
    entityName: row.entityName,
    assignedTo: existing?.assignedTo || row.assignedTo || '',
    stage: existing?.stage || row.stage || 'lead_contact',
    visitStatus: existing?.visitStatus || row.visitStatus || 'unknown',
    decision: existing?.decision || row.decision || 'pending',
    decisionReason: existing?.decisionReason || row.decisionReason || '',
    nextStep: existing?.nextStep || row.nextStep || '',
    notes: existing?.notes || row.notes || '',
    sourceStatus: row.sourceStatus || existing?.sourceStatus || 'unregistered',
    createdBy: existing?.createdBy || getActorName(),
    createdAt: existing?.createdAt || nowIso,
    lastEditedBy: getActorName(),
    lastEditedAt: nowIso
  };

  if (action === 'followup-advance') {
    record.stage = nextStage(record.stage);
    if (record.stage === 'visited') record.visitStatus = 'completed';
    if (!record.nextStep) record.nextStep = 'استكمال المرحلة التالية';
  }

  if (action === 'followup-approve') {
    record.decision = 'approved';
    record.stage = 'approved';
    record.visitStatus = record.visitStatus === 'unknown' ? 'completed' : record.visitStatus;
    if (!record.nextStep) record.nextStep = 'التجهيز للتفعيل التشغيلي';
  }

  if (action === 'followup-reject') {
    record.decision = 'rejected';
    record.stage = 'rejected';
    if (!record.nextStep) record.nextStep = 'مراجعة أسباب الرفض وإعادة التقديم';
  }

  state.followups = [...(state.followups || []).filter((item) => !(item.entityType === entityType && item.entityId === entityId)), record];
  void upsertRecord('followups', record);
  pushAudit('إجراء متابعة ميدانية', `${entityType === 'restaurant' ? 'مطعم' : 'مندوب'}: ${row.entityName} (${action})`);
  saveState();
  render();
}

function renderReports() {
  const doneTasks = state.tasks.filter((task) => task.status === 'done').length;
  const totalTasks = state.tasks.length;
  const approvalRate = state.approvals.length ? Math.round((state.approvals.filter((a) => a.status === 'approved').length / state.approvals.length) * 100) : 0;
  const avgLoad = state.employees.length ? (state.employees.reduce((sum, item) => sum + Number(item.workload || 0), 0) / state.employees.length).toFixed(1) : '0';

  const cards = [
    { title: 'أداء التنفيذ', text: `تم إنجاز ${doneTasks} من ${totalTasks} مهمة (${totalTasks ? Math.round((doneTasks / totalTasks) * 100) : 0}%).` },
    { title: 'اعتماد القرارات', text: `نسبة الموافقات المعتمدة حاليًا ${approvalRate}% مع متابعة الطلبات المعلقة.` },
    { title: 'استدامة الفريق', text: `متوسط الحمل التشغيلي الحالي ${avgLoad}/10، ويوصى بتوازن الموارد.` },
    { title: 'صحة التسليم', text: `المشاريع ذات المخاطر: ${state.projects.filter((p) => p.status === 'risk').length}، والمشاريع النشطة: ${state.projects.filter((p) => p.status === 'active').length}.` }
  ];

  el.reportCards.innerHTML = cards.map((card) => `
    <div class="report-card">
      <h4>${escapeHtml(card.title)}</h4>
      <p class="report-meta">${escapeHtml(card.text)}</p>
    </div>
  `).join('');
}

function renderAudit() {
  el.auditLogList.innerHTML = state.audit.slice(0, 100).map((entry) => `
    <div class="audit-card">
      <h5>${escapeHtml(entry.action)}</h5>
      <div class="audit-meta">${escapeHtml(entry.details || '-')}</div>
      <div class="audit-meta">${escapeHtml(entry.actor)} · ${escapeHtml(entry.time)}</div>
    </div>
  `).join('');
}

function render() {
  renderSessionHeader();
  renderExecutive();
  refreshProjectSelectors();
  refreshEmployeeSelectors();
  renderProjectTable();
  renderTaskKanban();
  renderEmployees();
  renderAdminsTable();
  renderApprovals();
  renderFinance();
  renderFieldOps();
  renderReports();
  renderAudit();

  const canManageEmployees = isCeoEmailUser();
  const canViewEmployees = canViewEmployeesPanel();
  const canManageAdmins = canManageAdminsPanel();
  if (el.employeeForm) {
    el.employeeForm.style.display = (canManageEmployees && canViewEmployees) ? 'grid' : 'none';
  }

  const employeesNavLink = el.navLinks.find((link) => link.getAttribute('href') === '#employees');
  if (employeesNavLink) {
    employeesNavLink.style.display = canViewEmployees ? 'block' : 'none';
  }

  const adminsNavLink = el.navLinks.find((link) => link.getAttribute('href') === '#admins-panel');
  if (adminsNavLink) {
    adminsNavLink.style.display = canManageAdmins ? 'block' : 'none';
  }

  if (!canViewEmployees && el.sections.find((section) => section.id === 'employees')?.classList.contains('is-active')) {
    activateSection('executive');
  }

  if (!canManageAdmins && el.sections.find((section) => section.id === 'admins-panel')?.classList.contains('is-active')) {
    activateSection('executive');
  }
}

function handleProjectSubmit(event) {
  event.preventDefault();
  if (!requirePermission('project:add', 'إضافة مشروع')) return;

  const project = {
    id: createId('proj'),
    name: el.projectName.value.trim(),
    owner: el.projectOwner.value.trim(),
    status: el.projectStatus.value,
    progress: 0,
    budget: Number(el.projectBudget.value || 0),
    dueDate: el.projectDueDate.value,
    lastEditedBy: getActorName(),
    lastEditedAt: new Date().toISOString()
  };

  if (!project.name || !project.owner) return;

  state.projects.unshift(project);
  void upsertRecord('projects', project);
  pushAudit('إضافة مشروع', project.name);
  saveState();
  el.projectForm.reset();
  render();
}

function handleTaskSubmit(event) {
  event.preventDefault();
  if (!requirePermission('task:add', 'إضافة مهمة')) return;

  const task = {
    id: createId('task'),
    title: el.taskTitle.value.trim(),
    projectId: el.taskProject.value,
    assignee: el.taskAssignee.value,
    priority: el.taskPriority.value,
    status: 'todo',
    dueDate: el.taskDueDate.value,
    description: el.taskDescription.value.trim(),
    lastEditedBy: getActorName(),
    lastEditedAt: new Date().toISOString()
  };

  if (!task.title) return;

  state.tasks.unshift(task);
  void upsertRecord('tasks', task);
  pushAudit('إضافة مهمة', task.title);
  saveState();
  el.taskForm.reset();
  render();
}

async function handleEmployeeSubmit(event) {
  event.preventDefault();
  const editingId = el.employeeId.value.trim();
  const isEditMode = Boolean(editingId);
  if (!requirePermission(isEditMode ? 'employee:edit' : 'employee:add', isEditMode ? 'تعديل موظف' : 'إضافة موظف')) return;

  const employee = {
    id: editingId || createId('emp'),
    name: el.employeeName.value.trim(),
    role: el.employeeRole.value.trim(),
    systemRole: el.employeeSystemRole.value,
    department: el.employeeDepartment.value.trim(),
    kpi: el.employeeKpi.value.trim(),
    workload: Number(el.employeeWorkload.value || 0),
    lastEditedBy: getActorName(),
    lastEditedAt: new Date().toISOString()
  };

  if (!employee.name || !employee.role) return;

  if (isEditMode) {
    state.employees = state.employees.map((item) => (item.id === editingId ? employee : item));
    pushAudit('تعديل موظف', `${employee.name} (${roleLabel(employee.systemRole)})`);
  } else {
    state.employees.unshift(employee);
    pushAudit('إضافة موظف', `${employee.name} (${roleLabel(employee.systemRole)})`);
  }

  await upsertEmployeeInFirestore(employee);
  saveState();
  resetEmployeeForm();
  render();
}

function resetEmployeeForm() {
  el.employeeForm.reset();
  el.employeeId.value = '';
  if (el.employeeRolePreset) {
    el.employeeRolePreset.value = '';
  }
  if (el.employeeSystemRole) {
    el.employeeSystemRole.value = 'viewer';
  }
  if (el.employeeSubmitBtn) {
    el.employeeSubmitBtn.textContent = 'حفظ الموظف';
  }
}

function populateEmployeeForm(employee) {
  el.employeeId.value = employee.id;
  el.employeeName.value = employee.name || '';
  el.employeeRole.value = employee.role || '';
  if (el.employeeRolePreset) {
    const hasExact = Array.from(el.employeeRolePreset.options || []).some((opt) => opt.value === employee.role);
    el.employeeRolePreset.value = hasExact ? employee.role : '';
  }
  el.employeeSystemRole.value = employee.systemRole || 'viewer';
  el.employeeDepartment.value = employee.department || '';
  el.employeeKpi.value = employee.kpi || '';
  el.employeeWorkload.value = String(employee.workload ?? 0);
  if (el.employeeSubmitBtn) {
    el.employeeSubmitBtn.textContent = 'تحديث الموظف';
  }
  activateSection('employees');
  el.employeeName.focus();
}

async function handleEmployeeCardAction(event) {
  const button = event.target.closest('button[data-action]');
  if (!button) return;
  const action = button.dataset.action;
  if (action !== 'employee-edit' && action !== 'employee-delete') return;

  const id = button.dataset.id;
  const employee = state.employees.find((item) => item.id === id);
  if (!employee) return;

  if (action === 'employee-edit') {
    if (!requirePermission('employee:edit', 'تعديل موظف')) return;
    populateEmployeeForm(employee);
    return;
  }

  if (!requirePermission('employee:edit', 'حذف موظف')) return;
  state.employees = state.employees.filter((item) => item.id !== id);
  await removeEmployeeFromFirestore(id);
  pushAudit('حذف موظف', employee.name);
  saveState();
  resetEmployeeForm();
  render();
}

function handleApprovalSubmit(event) {
  event.preventDefault();
  if (!requirePermission('approval:add', 'إضافة طلب موافقة')) return;

  const approval = {
    id: createId('apr'),
    type: el.approvalType.value,
    title: el.approvalTitle.value.trim(),
    notes: el.approvalNotes.value.trim(),
    status: 'pending',
    requestedBy: getActorName(),
    decidedBy: '',
    decidedAt: '',
    createdAt: new Date().toISOString()
  };

  if (!approval.title) return;

  state.approvals.unshift(approval);
  void upsertRecord('approvals', approval);
  pushAudit('إرسال طلب موافقة', approval.title);
  saveState();
  el.approvalForm.reset();
  render();
}

function handleFinanceSubmit(event) {
  event.preventDefault();
  if (!requirePermission('finance:add', 'إضافة عملية مالية')) return;

  const item = {
    id: createId('fin'),
    type: el.financeType.value,
    title: el.financeTitle.value.trim(),
    amount: Number(el.financeAmount.value || 0),
    projectId: el.financeProject.value,
    date: el.financeDate.value,
    notes: el.financeNotes.value.trim(),
    lastEditedBy: getActorName(),
    lastEditedAt: new Date().toISOString()
  };

  if (!item.title || item.amount <= 0) return;

  state.finances.unshift(item);
  void upsertRecord('finances', item);
  pushAudit('تسجيل عملية مالية', item.title);
  saveState();
  el.financeForm.reset();
  render();
}

function handleProjectTableAction(event) {
  const button = event.target.closest('button[data-action]');
  if (!button) return;
  const action = button.dataset.action;
  const id = button.dataset.id;
  const project = state.projects.find((item) => item.id === id);
  if (!project) return;

  if (action === 'project-advance') {
    if (!requirePermission('project:edit', 'تحديث مشروع')) return;
    project.progress = Math.min(100, Number(project.progress || 0) + 10);
    if (project.progress === 100) project.status = 'done';
    project.lastEditedBy = getActorName();
    project.lastEditedAt = new Date().toISOString();
    void upsertRecord('projects', project);
    pushAudit('رفع تقدم مشروع', project.name);
  }

  if (action === 'project-risk') {
    if (!requirePermission('project:edit', 'تحديث مشروع')) return;
    project.status = 'risk';
    project.lastEditedBy = getActorName();
    project.lastEditedAt = new Date().toISOString();
    void upsertRecord('projects', project);
    pushAudit('تحديد مشروع عالي المخاطر', project.name);
  }

  if (action === 'project-delete') {
    if (!requirePermission('project:edit', 'حذف مشروع')) return;
    const linkedTasks = state.tasks.filter((task) => task.projectId === id);
    state.projects = state.projects.filter((item) => item.id !== id);
    state.tasks = state.tasks.filter((task) => task.projectId !== id);
    void deleteRecord('projects', id);
    linkedTasks.forEach((task) => {
      void deleteRecord('tasks', task.id);
    });
    pushAudit('حذف مشروع', project.name);
  }

  saveState();
  render();
}

function handleTaskBoardAction(event) {
  const button = event.target.closest('button[data-action]');
  if (!button) return;
  const action = button.dataset.action;
  const id = button.dataset.id;
  const task = state.tasks.find((item) => item.id === id);
  if (!task) return;

  if (action === 'task-advance') {
    if (!requirePermission('task:advance', 'تحريك المهمة')) return;
    task.status = nextTaskStatus(task.status);
    task.lastEditedBy = getActorName();
    task.lastEditedAt = new Date().toISOString();
    void upsertRecord('tasks', task);
    pushAudit('تحريك مهمة', task.title);
  }

  if (action === 'task-delete') {
    if (!requirePermission('task:advance', 'حذف المهمة')) return;
    state.tasks = state.tasks.filter((item) => item.id !== id);
    void deleteRecord('tasks', id);
    pushAudit('حذف مهمة', task.title);
  }

  saveState();
  render();
}

function handleApprovalAction(event) {
  const button = event.target.closest('button[data-action]');
  if (!button) return;
  const action = button.dataset.action;
  const id = button.dataset.id;
  const approval = state.approvals.find((item) => item.id === id);
  if (!approval) return;

  if (action === 'approval-approve' || action === 'approval-reject') {
    if (!requirePermission('approval:decide', 'اتخاذ قرار الموافقة')) return;
    approval.status = action === 'approval-approve' ? 'approved' : 'rejected';
    approval.decidedBy = getActorName();
    approval.decidedAt = new Date().toISOString();
    void upsertRecord('approvals', approval);
    pushAudit(approval.status === 'approved' ? 'اعتماد طلب' : 'رفض طلب', approval.title);
    saveState();
    render();
  }
}

function filterByDays(items, dateField, days) {
  const threshold = Date.now() - days * 24 * 60 * 60 * 1000;
  return items.filter((item) => {
    const value = item[dateField];
    if (!value) return false;
    return new Date(value).getTime() >= threshold;
  });
}

function rowsForScope(scope, days = null) {
  const scoped = (items, dateField) => (days ? filterByDays(items, dateField, days) : items);

  if (scope === 'projects') {
    const rows = scoped(state.projects, 'lastEditedAt').map((project) => [project.name, project.owner, statusLabel(project.status), `${project.progress}%`, Number(project.budget), project.dueDate, project.lastEditedBy || '']);
    return { title: 'المشاريع', headers: ['الاسم', 'المالك', 'الحالة', 'التقدم', 'الميزانية', 'التسليم', 'آخر تعديل'], rows };
  }

  if (scope === 'tasks') {
    const rows = scoped(state.tasks, 'lastEditedAt').map((task) => [task.title, getProjectName(task.projectId), task.assignee, statusLabel(task.status), task.priority, task.dueDate, task.lastEditedBy || '']);
    return { title: 'المهام', headers: ['العنوان', 'المشروع', 'المسؤول', 'الحالة', 'الأولوية', 'الاستحقاق', 'آخر تعديل'], rows };
  }

  if (scope === 'employees') {
    if (!canViewEmployeesPanel()) {
      return { title: 'الموظفون', headers: ['تنبيه'], rows: [['غير مصرح لك بعرض بيانات الموظفين']] };
    }
    const rows = scoped(state.employees, 'lastEditedAt').map((emp) => [emp.name, emp.role, roleLabel(emp.systemRole || 'viewer'), emp.department, emp.kpi, emp.workload, emp.lastEditedBy || '']);
    return { title: 'الموظفون', headers: ['الاسم', 'الدور الوظيفي', 'دور النظام', 'القسم', 'KPI', 'الحمل', 'آخر تعديل'], rows };
  }

  if (scope === 'approvals') {
    const rows = scoped(state.approvals, 'createdAt').map((apr) => [apr.title, statusLabel(apr.type), apr.status, apr.requestedBy, apr.decidedBy || '', apr.createdAt]);
    return { title: 'الموافقات', headers: ['العنوان', 'النوع', 'الحالة', 'المقدم', 'القرار بواسطة', 'تاريخ الطلب'], rows };
  }

  if (scope === 'finance') {
    const rows = scoped(state.finances, 'date').map((fin) => [fin.title, fin.type === 'income' ? 'إيراد' : 'مصروف', Number(fin.amount), getProjectName(fin.projectId), fin.date, fin.lastEditedBy || '']);
    return { title: 'المالية', headers: ['العنوان', 'النوع', 'المبلغ', 'المشروع', 'التاريخ', 'آخر تعديل'], rows };
  }

  if (scope === 'audit') {
    const rows = scoped(state.audit, 'time').map((entry) => [entry.action, entry.details, entry.actor, entry.time]);
    return { title: 'السجل', headers: ['الإجراء', 'التفاصيل', 'المنفذ', 'الوقت'], rows };
  }

  if (scope === 'restaurants_pipeline') {
    const rows = buildActivePipelineRows('restaurant').map((item) => [
      item.entityName,
      item.entityId,
      SOURCE_STATUS_LABELS[item.sourceStatus] || item.sourceStatus,
      VISIT_LABELS[item.visitStatus] || item.visitStatus,
      DECISION_LABELS[item.decision] || item.decision,
      STAGE_LABELS[item.stage] || item.stage,
      item.nextStep || '',
      item.assignedTo || '',
      item.lastEditedBy || '',
      item.lastEditedAt || ''
    ]);
    return { title: 'متابعة المطاعم', headers: ['الاسم', 'المعرّف', 'وضع التسجيل', 'الزيارة', 'القرار', 'المرحلة', 'الخطوة التالية', 'المكلّف', 'آخر تعديل بواسطة', 'وقت التعديل'], rows };
  }

  if (scope === 'couriers_pipeline') {
    const rows = buildActivePipelineRows('courier').map((item) => [
      item.entityName,
      item.entityId,
      SOURCE_STATUS_LABELS[item.sourceStatus] || item.sourceStatus,
      VISIT_LABELS[item.visitStatus] || item.visitStatus,
      DECISION_LABELS[item.decision] || item.decision,
      STAGE_LABELS[item.stage] || item.stage,
      item.nextStep || '',
      item.assignedTo || '',
      item.lastEditedBy || '',
      item.lastEditedAt || ''
    ]);
    return { title: 'متابعة المندوبين', headers: ['الاسم', 'المعرّف', 'وضع التسجيل', 'الزيارة', 'القرار', 'المرحلة', 'الخطوة التالية', 'المكلّف', 'آخر تعديل بواسطة', 'وقت التعديل'], rows };
  }

  if (scope === 'completed_pipeline') {
    const rows = buildCompletedPipelineRows().map((item) => [
      item.entityType === 'restaurant' ? 'مطعم' : 'مندوب',
      item.entityName,
      item.entityId,
      DECISION_LABELS[item.decision] || item.decision,
      STAGE_LABELS[item.stage] || item.stage,
      item.assignedTo || '',
      item.lastEditedBy || '',
      item.lastEditedAt || ''
    ]);
    return { title: 'السجل المكتمل', headers: ['النوع', 'الاسم', 'المعرّف', 'القرار', 'المرحلة الختامية', 'المكلّف', 'آخر تعديل بواسطة', 'وقت التعديل'], rows };
  }

  if (scope === 'executive') {
    const rows = [
      ['عدد المشاريع', state.projects.length],
      ['المهام المفتوحة', state.tasks.filter((t) => t.status !== 'done').length],
      ['الموافقات المعلقة', state.approvals.filter((a) => a.status === 'pending').length],
      ['إجمالي الإيرادات', state.finances.filter((f) => f.type === 'income').reduce((s, f) => s + Number(f.amount || 0), 0)],
      ['إجمالي المصروفات', state.finances.filter((f) => f.type === 'expense').reduce((s, f) => s + Number(f.amount || 0), 0)]
    ];
    return { title: 'لوحة تنفيذية', headers: ['المؤشر', 'القيمة'], rows };
  }

  return { title: 'بيانات', headers: ['-', '-'], rows: [] };
}

function downloadWorkbook(scopes, fileName, days = null) {
  const workbook = XLSX.utils.book_new();
  scopes.forEach((scope) => {
    const section = rowsForScope(scope, days);
    const sheetData = [section.headers, ...section.rows];
    const sheet = XLSX.utils.aoa_to_sheet(sheetData);
    XLSX.utils.book_append_sheet(workbook, sheet, section.title.substring(0, 31));
  });
  XLSX.writeFile(workbook, fileName);
}

function exportAll() {
  const scopes = ['executive', 'projects', 'tasks', ...(canViewEmployeesPanel() ? ['employees'] : []), 'approvals', 'finance', 'restaurants_pipeline', 'couriers_pipeline', 'completed_pipeline', 'audit'];
  downloadWorkbook(scopes, `speedstar-os-all-${todayISO()}.xlsx`);
  pushAudit('تصدير شامل', 'Excel كامل');
  saveState();
  render();
}

function exportScope(scope) {
  downloadWorkbook([scope], `speedstar-os-${scope}-${todayISO()}.xlsx`);
  pushAudit('تصدير قسم', scope);
  saveState();
  render();
}

function exportWeekly() {
  downloadWorkbook(['executive', 'tasks', 'approvals', 'finance', 'audit'], `speedstar-weekly-${todayISO()}.xlsx`, 7);
  pushAudit('تصدير تقرير أسبوعي', 'آخر 7 أيام');
  saveState();
  render();
}

function exportMonthly() {
  downloadWorkbook(['executive', 'projects', 'tasks', 'approvals', 'finance', 'restaurants_pipeline', 'couriers_pipeline', 'completed_pipeline', 'audit'], `speedstar-monthly-${todayISO()}.xlsx`, 30);
  pushAudit('تصدير تقرير شهري', 'آخر 30 يوم');
  saveState();
  render();
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
    return 'تسجيل الدخول بالبريد وكلمة المرور غير مفعل في Firebase Auth.';
  }
  return err?.message || 'حدث خطأ غير متوقع أثناء تسجيل الدخول.';
}

async function handleAuthSubmit(event) {
  event.preventDefault();
  const email = el.authUsername.value.trim();
  const password = el.authPassword.value.trim();
  if (!email || !password) {
    el.authFeedback.textContent = 'الرجاء إدخال البريد الإلكتروني وكلمة المرور.';
    return;
  }

  const submitBtn = el.authForm.querySelector('button[type="submit"]');
  if (submitBtn) submitBtn.disabled = true;
  el.authFeedback.textContent = 'جاري تسجيل الدخول...';
  try {
    await signInWithEmailAndPassword(auth, email, password);
    el.authFeedback.textContent = 'تم تسجيل الدخول، جاري التحقق من الصلاحيات...';
  } catch (err) {
    el.authFeedback.textContent = `فشل تسجيل الدخول: ${mapAuthErrorMessage(err)}`;
  } finally {
    if (submitBtn) submitBtn.disabled = false;
  }
}

function showSignedOutUi() {
  stopRealtimeSync();
  currentUser = null;
  currentAdminPermissions = new Set();
  currentAdminExplicitPermissions = new Set();
  adminProfiles = [];
  resetAdminForm();
  render();
  openAuthModal();
}

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

    if (profile?.allowed !== true) {
      el.authFeedback.textContent = 'هذا الحساب ليس لديه صلاحيات Admin.';
      await signOut(auth);
      return;
    }

    currentAdminPermissions = new Set(profile.permissions || []);
    currentAdminExplicitPermissions = new Set(profile.explicitPermissions || []);
    currentUser = {
      uid: user.uid,
      email: user.email || '',
      displayName: user.displayName || user.email || user.uid,
      role: profile.role || 'admin'
    };

    startCurrentUserAdminSync();

    try {
      await ensureRealtimeCollectionsInitialized();
      startRealtimeSync();
    } catch (syncError) {
      console.warn('Realtime sync bootstrap failed. Continuing with local state.', syncError);
    }
    await loadAdminsFromFirestore();
    closeAuthModal();
    pushAudit('تسجيل دخول', `${currentUser.displayName} (${roleLabel(currentUser.role)})`);
    saveState();
    render();
  } catch (err) {
    console.error('handleAuthenticatedUser failed', err);
    el.authFeedback.textContent = `تعذر إكمال تسجيل الدخول: ${mapAuthErrorMessage(err)}`;
    try {
      await signOut(auth);
    } catch (_) {
    }
  } finally {
    authTransitionInProgress = false;
  }
}

function initializeTaskProjectDefaults() {
  state.tasks = state.tasks.map((task) => {
    if (task.projectId) return task;
    const firstProject = state.projects[0];
    return { ...task, projectId: firstProject?.id || '' };
  });
}

function attachEventHandlers() {
  el.authForm.addEventListener('submit', handleAuthSubmit);
  el.logoutBtn.addEventListener('click', async () => {
    pushAudit('تسجيل خروج', '-');
    saveState();
    await signOut(auth);
  });
  el.adminBadge.addEventListener('click', () => {
    if (!currentUser) openAuthModal();
  });

  el.projectForm.addEventListener('submit', handleProjectSubmit);
  el.taskForm.addEventListener('submit', handleTaskSubmit);
  el.employeeForm.addEventListener('submit', handleEmployeeSubmit);
  el.employeeRolePreset?.addEventListener('change', () => {
    const selected = el.employeeRolePreset.value.trim();
    if (selected) {
      el.employeeRole.value = selected;
    }
  });
  el.employeeCancelEditBtn.addEventListener('click', resetEmployeeForm);
  el.adminForm?.addEventListener('submit', async (event) => {
    event.preventDefault();
    await saveAdminProfile();
  });
  el.adminResetBtn?.addEventListener('click', resetAdminForm);
  el.refreshAdminsBtn?.addEventListener('click', async () => {
    await loadAdminsFromFirestore();
  });
  el.approvalForm.addEventListener('submit', handleApprovalSubmit);
  el.financeForm.addEventListener('submit', handleFinanceSubmit);
  el.fieldOpsForm?.addEventListener('submit', handleFieldOpsSubmit);
  el.fieldOpsResetBtn?.addEventListener('click', resetFieldOpsForm);

  el.projectTableBody.addEventListener('click', handleProjectTableAction);
  el.taskKanban.addEventListener('click', handleTaskBoardAction);
  el.employeeCards.addEventListener('click', handleEmployeeCardAction);
  el.adminsTableBody?.addEventListener('click', (event) => {
    void handleAdminsTableAction(event);
  });
  el.approvalList.addEventListener('click', handleApprovalAction);
  el.restaurantsPipelineBody?.addEventListener('click', handleFieldOpsTableAction);
  el.couriersPipelineBody?.addEventListener('click', handleFieldOpsTableAction);
  el.completedPipelineBody?.addEventListener('click', handleFieldOpsTableAction);

  el.taskFilterProject.addEventListener('change', renderTaskKanban);
  el.taskFilterAssignee.addEventListener('change', renderTaskKanban);
  el.taskFilterStatus.addEventListener('change', renderTaskKanban);

  el.openTaskQuickBtn.addEventListener('click', () => {
    activateSection('tasks');
    el.taskTitle.focus();
  });

  el.openProjectQuickBtn.addEventListener('click', () => {
    activateSection('portfolio');
    el.projectName.focus();
  });

  el.exportAllBtn.addEventListener('click', () => {
    if (!requirePermission('export:all', 'التصدير')) return;
    exportAll();
  });

  el.exportWeeklyBtn.addEventListener('click', () => {
    if (!requirePermission('export:all', 'تصدير أسبوعي')) return;
    exportWeekly();
  });

  el.exportMonthlyBtn.addEventListener('click', () => {
    if (!requirePermission('export:all', 'تصدير شهري')) return;
    exportMonthly();
  });

  el.exportScopeButtons.forEach((button) => {
    button.addEventListener('click', () => {
      if (!requirePermission('export:all', 'تصدير قسم')) return;
      exportScope(button.dataset.exportScope);
    });
  });

  document.getElementById('addProjectBtn').addEventListener('click', () => {
    if (!requirePermission('project:add', 'إضافة مشروع')) return;
    activateSection('portfolio');
    el.projectName.focus();
  });
}

function bootstrap() {
  attachNavBehavior();
  attachEventHandlers();
  initializeTaskProjectDefaults();
  resetEmployeeForm();
  resetFieldOpsForm();
  resetAdminForm();
  render();

  onAuthStateChanged(auth, (user) => {
    if (user) {
      void handleAuthenticatedUser(user);
      return;
    }
    showSignedOutUi();
  });
}

bootstrap();
