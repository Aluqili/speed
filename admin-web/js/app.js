import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js';
import {
  getAuth,
  onAuthStateChanged,
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
  serverTimestamp,
  getDocs,
  writeBatch
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-firestore.js';

import { firebaseConfig, staticAdminEmails } from './firebase-config.js';

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
const fns = getFunctions(app, 'us-central1');
const setUserAdminRole = httpsCallable(fns, 'setUserAdminRole');
const approveRestaurantApplication = httpsCallable(fns, 'approveRestaurantApplication');
const approveCourierApplication = httpsCallable(fns, 'approveCourierApplication');
const normalizeStateIdsBatch = httpsCallable(fns, 'normalizeStateIdsBatch');
const sendAdminNotification = httpsCallable(fns, 'sendAdminNotification');

const loginCard = document.getElementById('loginCard');
const appPanel = document.getElementById('appPanel');
const loginForm = document.getElementById('loginForm');
const logoutBtn = document.getElementById('logoutBtn');
const authState = document.getElementById('authState');

const statsGrid = document.getElementById('statsGrid');
const financeGrid = document.getElementById('financeGrid');
const ordersTable = document.getElementById('ordersTable');
const restaurantsTable = document.getElementById('restaurantsTable');
const couriersTable = document.getElementById('couriersTable');
const adminsTable = document.getElementById('adminsTable');
const supportRoot = document.getElementById('supportRoot');
const supportConversationList = document.getElementById('supportConversationList');
const supportConversationHeader = document.getElementById('supportConversationHeader');
const supportMessagesPane = document.getElementById('supportMessagesPane');
const supportReplyInput = document.getElementById('supportReplyInput');
const supportSendBtn = document.getElementById('supportSendBtn');
const supportToggleStatusBtn = document.getElementById('supportToggleStatusBtn');
const supportSearchInput = document.getElementById('supportSearchInput');
const supportAppFilter = document.getElementById('supportAppFilter');
const supportStatusFilter = document.getElementById('supportStatusFilter');
const notificationForm = document.getElementById('notificationForm');
const notificationTargetType = document.getElementById('notificationTargetType');
const notificationUserRole = document.getElementById('notificationUserRole');
const notificationUserId = document.getElementById('notificationUserId');
const notificationTitle = document.getElementById('notificationTitle');
const notificationBody = document.getElementById('notificationBody');
const notificationSendBtn = document.getElementById('notificationSendBtn');
const notificationResult = document.getElementById('notificationResult');
const pendingTable = document.getElementById('pendingTable');
const storeDetailsPanel = document.getElementById('storeDetailsPanel');
const courierDetailsPanel = document.getElementById('courierDetailsPanel');
const addAdminForm = document.getElementById('addAdminForm');
const adminEmailInput = document.getElementById('adminEmailInput');
const normalizeStateForm = document.getElementById('normalizeStateForm');
const normalizeLimitInput = document.getElementById('normalizeLimitInput');
const normalizeStateResult = document.getElementById('normalizeStateResult');
const mapDetails = document.getElementById('mapDetails');
const mapLegendBar = document.getElementById('mapLegendBar');

const tabs = Array.from(document.querySelectorAll('.tab'));
const tabPanels = Array.from(document.querySelectorAll('.tab-panel'));

let unsubscribers = [];
let addAdminFormBound = false;
let normalizeStateFormBound = false;
let liveMap = null;
let mapBootstrapped = false;
let mapAutoFitted = false;
let mapLegendControlAdded = false;
let supportConversations = [];
let supportMessagesByConversation = new Map();
let supportSelectedConversationId = '';
let supportUiBound = false;
let notificationFormBound = false;

const mapState = {
  drivers: new Map(),
  clients: new Map(),
  restaurants: new Map(),
  orders: new Map()
};

const markerState = {
  drivers: new Map(),
  clients: new Map(),
  restaurants: new Map(),
  orders: new Map()
};

const lineState = {
  orders: new Map()
};

let leafletReadyPromise = null;

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
        existing.addEventListener('load', () => resolve(), { once: true });
        existing.addEventListener('error', () => reject(new Error(`failed script: ${src}`)), { once: true });
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

    let styleLoaded = false;
    for (const href of styleCandidates) {
      try {
        await loadExternalStyle(href);
        styleLoaded = true;
        break;
      } catch (_) {
      }
    }

    if (!styleLoaded) {
      throw new Error('تعذر تحميل ملف أنماط الخريطة.');
    }

    for (const src of scriptCandidates) {
      try {
        await loadExternalScript(src);
        if (window.L) return;
      } catch (_) {
      }
    }

    throw new Error('تعذر تحميل مكتبة الخريطة.');
  })();

  await leafletReadyPromise;
}

function clearSubscriptions() {
  unsubscribers.forEach((fn) => fn());
  unsubscribers = [];
}

function setHtml(target, html) {
  target.innerHTML = html;
}

function table(headers, rows) {
  if (!rows.length) return '<p class="muted">لا توجد بيانات.</p>';
  return `
    <table>
      <thead><tr>${headers.map((h) => `<th>${h}</th>`).join('')}</tr></thead>
      <tbody>${rows.join('')}</tbody>
    </table>
  `;
}

async function isAdmin(user) {
  if (!user) return false;
  if (staticAdminEmails.includes((user.email || '').toLowerCase())) return true;
  const adminDoc = await getDoc(doc(db, 'admins', user.uid));
  return adminDoc.exists() && (adminDoc.data().role === 'admin' || adminDoc.data().active === true);
}

function activateTab(id) {
  tabs.forEach((t) => t.classList.toggle('active', t.dataset.tab === id));
  tabPanels.forEach((p) => p.classList.toggle('active', p.id === id));
  if (id === 'map') {
    mountMap().finally(() => {
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

tabs.forEach((tab) => tab.addEventListener('click', () => activateTab(tab.dataset.tab)));

loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const email = document.getElementById('emailInput').value.trim();
  const password = document.getElementById('passwordInput').value;
  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (err) {
    alert(`فشل تسجيل الدخول: ${err.message}`);
  }
});

logoutBtn.addEventListener('click', async () => {
  await signOut(auth);
});

function mountDashboard() {
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

  const latestOrdersQ = query(collection(db, 'orders'), orderBy('createdAt', 'desc'), limit(20));
  unsubscribers.push(
    onSnapshot(latestOrdersQ, (snap) => {
      const rows = snap.docs.map((d) => {
        const data = d.data();
        return `<tr>
          <td>${data.orderNumber || d.id}</td>
          <td>${data.clientName || '-'}</td>
          <td>${data.status || data.orderStatus || '-'}</td>
          <td>${data.total ?? 0}</td>
        </tr>`;
      });
      setHtml(ordersTable, table(['رقم الطلب', 'العميل', 'الحالة', 'الإجمالي'], rows));
    })
  );
}

function mountFinance() {
  financeGrid.innerHTML = `
    <div class="stat"><h4>طلبات مدفوعة</h4><b id="paidOrders">...</b></div>
    <div class="stat"><h4>طلبات بانتظار السداد</h4><b id="pendingPay">...</b></div>
    <div class="stat"><h4>طلبات تحويل مكتمل</h4><b id="payoutDone">...</b></div>
  `;

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
}

function mountManagement() {
  unsubscribers.push(
    onSnapshot(query(collection(db, 'restaurants'), where('approvalStatus', '==', 'approved')), (snap) => {
      const rows = snap.docs
        .slice(0, 50)
        .map((d) => {
        const data = d.data() || {};
        const closed = data.temporarilyClosed === true;
        return `<tr>
          <td>${data.name || d.id}</td>
          <td><span class="badge ${closed ? 'open' : 'closed'}">${closed ? 'مغلق مؤقتًا' : 'مفتوح'}</span></td>
          <td>
            <button class="btn ghost" data-view-store="${d.id}">تفاصيل</button>
            <button class="btn ghost" data-toggle-store="${d.id}">${closed ? 'فتح' : 'إغلاق مؤقت'}</button>
          </td>
        </tr>`;
        });
      setHtml(restaurantsTable, table(['المتجر', 'الحالة', 'إجراء'], rows));
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
    })
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'drivers'), (snap) => {
      const rows = snap.docs.slice(0, 50).map((d) => {
        const data = d.data();
        const status = data.approvalStatus || (data.isApproved ? 'approved' : 'pending');
        const available = data.available === true;
        return `<tr>
          <td>${data.name || d.id}</td>
          <td>${status}</td>
          <td>${available ? 'متاح' : 'غير متاح'}</td>
          <td>
            <button class="btn ghost" data-view-driver="${d.id}">تفاصيل</button>
            <button class="btn ghost" data-approve-driver="${d.id}">قبول</button>
            <button class="btn danger" data-reject-driver="${d.id}">رفض</button>
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
        btn.addEventListener('click', async () => {
          const id = btn.getAttribute('data-approve-driver');
          await updateDoc(doc(db, 'drivers', id), {
            approvalStatus: 'approved',
            isApproved: true,
            updatedAt: serverTimestamp()
          });
        });
      });

      couriersTable.querySelectorAll('[data-reject-driver]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const id = btn.getAttribute('data-reject-driver');
          await updateDoc(doc(db, 'drivers', id), {
            approvalStatus: 'rejected',
            isApproved: false,
            updatedAt: serverTimestamp()
          });
        });
      });
    })
  );
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
    const activeOrderStatuses = new Set(['courier_assigned', 'pickup_ready', 'picked_up', 'arrived_to_client']);
    const activeOrdersCount = orders.filter((o) => activeOrderStatuses.has(String(o.orderStatus || o.status || ''))).length;

    const idImage = driver.idImageUrl
      ? `<div style="margin-top:8px"><a class="btn ghost" href="${escapeHtml(driver.idImageUrl)}" target="_blank" rel="noopener">فتح صورة الهوية/الرخصة</a></div>`
      : '<div class="muted" style="margin-top:8px">لا توجد صورة هوية/رخصة</div>';

    courierDetailsPanel.innerHTML = `
      <h4 style="margin:0 0 8px">تفاصيل المندوب</h4>
      <div><span class="kv"><b>المعرف:</b> ${escapeHtml(driverId)}</span><span class="kv"><b>الاسم:</b> ${escapeHtml(driver.name || '-')}</span></div>
      <div><span class="kv"><b>البريد:</b> ${escapeHtml(driver.email || '-')}</span><span class="kv"><b>الهاتف:</b> ${escapeHtml(driver.phone || '-')}</span></div>
      <div><span class="kv"><b>نوع المركبة:</b> ${escapeHtml(driver.vehicleType || '-')}</span><span class="kv"><b>رقم اللوحة:</b> ${escapeHtml(driver.vehiclePlate || '-')}</span></div>
      <div><span class="kv"><b>رقم الهوية/الرخصة:</b> ${escapeHtml(driver.nationalIdNumber || '-')}</span><span class="kv"><b>المنطقة:</b> ${escapeHtml(driver.region || '-')}</span></div>
      <div><span class="kv"><b>الموافقة:</b> ${escapeHtml(driver.approvalStatus || '-')}</span><span class="kv"><b>التوفر:</b> ${driver.available === true ? 'متاح' : 'غير متاح'}</span></div>
      <hr style="border:none;border-top:1px solid #ececec;margin:8px 0" />
      <div><span class="kv"><b>إجمالي الطلبات:</b> ${orders.length}</span><span class="kv"><b>الطلبات النشطة:</b> ${activeOrdersCount}</span></div>
      ${idImage}
      <div style="margin-top:8px; display:flex; gap:8px; flex-wrap:wrap;">
        <button class="btn ghost" id="driverImageChange-${driverId}">تعديل صورة الهوية/الرخصة</button>
        <button class="btn ghost" id="driverToggleAvailability-${driverId}">${driver.available === true ? 'إيقاف التوفر' : 'تفعيل التوفر'}</button>
        <button class="btn ghost" id="driverApprove-${driverId}">قبول</button>
        <button class="btn danger" id="driverReject-${driverId}">رفض</button>
      </div>
      <hr style="border:none;border-top:1px solid #ececec;margin:12px 0" />
      <h4 style="margin:0 0 8px">تعديل بيانات المندوب (مباشر)</h4>
      <div class="grid" style="grid-template-columns: 1fr 1fr; gap:8px;">
        <label>الاسم<input id="driverName-${driverId}" type="text" value="${escapeHtml(driver.name || '')}" /></label>
        <label>الهاتف<input id="driverPhone-${driverId}" type="text" value="${escapeHtml(driver.phone || '')}" /></label>
        <label>نوع المركبة<input id="driverVehicleType-${driverId}" type="text" value="${escapeHtml(driver.vehicleType || '')}" /></label>
        <label>رقم اللوحة<input id="driverVehiclePlate-${driverId}" type="text" value="${escapeHtml(driver.vehiclePlate || '')}" /></label>
        <label>رقم الهوية/الرخصة<input id="driverNationalId-${driverId}" type="text" value="${escapeHtml(driver.nationalIdNumber || '')}" /></label>
        <label>المنطقة<input id="driverRegion-${driverId}" type="text" value="${escapeHtml(driver.region || '')}" /></label>
      </div>
      <div style="margin-top:10px;">
        <button class="btn primary" id="driverSave-${driverId}">حفظ التعديلات</button>
      </div>
    `;

    document.getElementById(`driverSave-${driverId}`)?.addEventListener('click', async () => {
      try {
        const patch = {
          name: (document.getElementById(`driverName-${driverId}`)?.value || '').trim(),
          phone: (document.getElementById(`driverPhone-${driverId}`)?.value || '').trim(),
          vehicleType: (document.getElementById(`driverVehicleType-${driverId}`)?.value || '').trim(),
          vehiclePlate: (document.getElementById(`driverVehiclePlate-${driverId}`)?.value || '').trim(),
          nationalIdNumber: (document.getElementById(`driverNationalId-${driverId}`)?.value || '').trim(),
          region: (document.getElementById(`driverRegion-${driverId}`)?.value || '').trim(),
          updatedAt: serverTimestamp(),
        };
        await updateDoc(doc(db, 'drivers', driverId), patch);
        alert('تم حفظ بيانات المندوب بنجاح');
        await loadCourierDetails(driverId);
      } catch (err) {
        alert(`تعذر حفظ البيانات: ${err.message || err}`);
      }
    });

    document.getElementById(`driverToggleAvailability-${driverId}`)?.addEventListener('click', async () => {
      try {
        await updateDoc(doc(db, 'drivers', driverId), {
          available: driver.available !== true,
          updatedAt: serverTimestamp(),
        });
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
          approvalStatus: 'rejected',
          isApproved: false,
          available: false,
          updatedAt: serverTimestamp(),
        });
        await loadCourierDetails(driverId);
      } catch (err) {
        alert(`تعذر رفض المندوب: ${err.message || err}`);
      }
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
    const activeOrderStatuses = new Set(['store_pending', 'courier_searching', 'courier_assigned', 'pickup_ready', 'picked_up']);
    const activeOrdersCount = orders.filter((o) => activeOrderStatuses.has(String(o.orderStatus || o.status || ''))).length;

    const image = store.commercialRecordImageUrl
      ? `<div style="margin-top:8px"><a class="btn ghost" href="${escapeHtml(store.commercialRecordImageUrl)}" target="_blank" rel="noopener">فتح صورة السجل</a></div>`
      : '';

    storeDetailsPanel.innerHTML = `
      <h4 style="margin:0 0 8px">تفاصيل المتجر</h4>
      <div><span class="kv"><b>المعرف:</b> ${escapeHtml(storeId)}</span><span class="kv"><b>الاسم:</b> ${escapeHtml(store.name || '-')}</span></div>
      <div><span class="kv"><b>البريد:</b> ${escapeHtml(store.email || '-')}</span><span class="kv"><b>الهاتف:</b> ${escapeHtml(store.phone || '-')}</span></div>
      <div><span class="kv"><b>صاحب الحساب:</b> ${escapeHtml(store.ownerUid || '-')}</span><span class="kv"><b>الحالة:</b> ${escapeHtml(store.approvalStatus || '-')}</span></div>
      <div><span class="kv"><b>السجل التجاري:</b> ${escapeHtml(store.commercialRecordNumber || '-')}</span><span class="kv"><b>القبول التلقائي:</b> ${store.autoAcceptOrders === true ? 'مفعل' : 'غير مفعل'}</span></div>
      <hr style="border:none;border-top:1px solid #ececec;margin:8px 0" />
      <div><span class="kv"><b>إجمالي الطلبات:</b> ${orders.length}</span><span class="kv"><b>الطلبات النشطة:</b> ${activeOrdersCount}</span></div>
      <div><span class="kv"><b>عدد العناوين:</b> ${addressesSnap.docs.length}</span><span class="kv"><b>أقسام المنيو:</b> ${menuDocsSnap.docs.length}</span><span class="kv"><b>عناصر full_menu:</b> ${fullMenuDocsSnap.docs.length}</span></div>
      ${image}
      <hr style="border:none;border-top:1px solid #ececec;margin:12px 0" />
      <h4 style="margin:0 0 8px">إدارة القائمة الكاملة (مباشر)</h4>
      <div id="adminMenuManager-${storeId}"><span class="muted">جاري تحميل أصناف القائمة...</span></div>
    `;

    await renderAdminMenuManager(storeId);
  } catch (err) {
    storeDetailsPanel.innerHTML = `<span class="muted">تعذر تحميل التفاصيل: ${escapeHtml(err.message || err)}</span>`;
  }
}

async function renderAdminMenuManager(storeId) {
  const container = document.getElementById(`adminMenuManager-${storeId}`);
  if (!container) return;

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
    const image = imageUrl
      ? `<a class="btn ghost" href="${escapeHtml(imageUrl)}" target="_blank" rel="noopener">صورة</a>`
      : '-';

    return `<tr>
      <td>${name}</td>
      <td>${category}</td>
      <td>${Number.isFinite(price) ? price : 0}</td>
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
    <div class="grid" style="grid-template-columns: 1fr 1fr 1fr 1fr; gap:8px; margin-bottom:8px;">
      <input id="newItemName-${storeId}" type="text" placeholder="اسم الصنف" />
      <input id="newItemPrice-${storeId}" type="number" step="0.01" placeholder="السعر" />
      <input id="newItemCategory-${storeId}" type="text" placeholder="الفئة" />
      <input id="newItemImageFile-${storeId}" type="file" accept="image/*" />
    </div>
    <div style="display:flex; gap:8px; flex-wrap:wrap; margin-bottom:8px;">
      <button class="btn primary" id="addMenuItem-${storeId}">إضافة صنف</button>
      <input id="pricePct-${storeId}" type="number" step="0.01" style="max-width:120px" placeholder="%" />
      <button class="btn ghost" id="incPrices-${storeId}">زيادة الأسعار %</button>
      <button class="btn ghost" id="decPrices-${storeId}">تخفيض الأسعار %</button>
    </div>
    ${table(['الصنف', 'الفئة', 'السعر', 'الصورة', 'الحالة', 'إجراء'], rows)}
  `;

  const addBtn = document.getElementById(`addMenuItem-${storeId}`);
  addBtn?.addEventListener('click', async () => {
    const name = (document.getElementById(`newItemName-${storeId}`)?.value || '').trim();
    const priceRaw = (document.getElementById(`newItemPrice-${storeId}`)?.value || '').trim();
    const category = (document.getElementById(`newItemCategory-${storeId}`)?.value || '').trim();
    const imageInput = document.getElementById(`newItemImageFile-${storeId}`);
    const imageFile = imageInput?.files && imageInput.files.length ? imageInput.files[0] : null;

    const price = Number(priceRaw);
    if (!name) {
      alert('أدخل اسم الصنف');
      return;
    }
    if (!Number.isFinite(price) || price <= 0) {
      alert('أدخل سعرًا صحيحًا أكبر من صفر');
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
        price,
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
        if (!Number.isFinite(oldPrice) || oldPrice <= 0) return;
        const newPrice = Math.round(oldPrice * factor * 100) / 100;
        batch.update(doc(db, 'restaurants', storeId, 'full_menu', d.id), {
          price: newPrice,
          updatedAt: serverTimestamp(),
          updatedByAdminUid: auth.currentUser?.uid || null,
        });
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
      const nextPriceRaw = prompt('السعر', String(item.price ?? ''));
      if (nextPriceRaw === null) return;
      const nextPrice = Number(String(nextPriceRaw).replace(',', '.'));
      if (!Number.isFinite(nextPrice) || nextPrice <= 0) {
        alert('السعر غير صالح');
        return;
      }
      const nextCategory = prompt('الفئة', String(item.category || ''));
      if (nextCategory === null) return;

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
          price: nextPrice,
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
    }, { merge: true });
    return;
  }

  const existing = await getDoc(restaurantRef);
  if (existing.exists()) {
    await setDoc(restaurantRef, {
      approvalStatus: 'rejected',
      isApproved: false,
      temporarilyClosed: true,
      updatedAt: serverTimestamp(),
    }, { merge: true });
  }
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
            <div class="support-item-title">${escapeHtml(item.senderName || item.userId || item.id)}</div>
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
      supportToggleStatusBtn.disabled = true;
      supportSendBtn.disabled = true;
      return;
    }

    const convo = supportConversations.find((item) => item.id === supportSelectedConversationId);
    if (!convo) {
      supportConversationHeader.textContent = 'المحادثة غير متاحة حاليًا.';
      supportMessagesPane.innerHTML = '<div class="muted">لم يتم العثور على بيانات هذه المحادثة.</div>';
      supportToggleStatusBtn.disabled = true;
      supportSendBtn.disabled = true;
      return;
    }

    const messages = (supportMessagesByConversation.get(convo.id) || []).slice().sort((a, b) => a.timestampMillis - b.timestampMillis);
    const appLabel = convo.sourceApp === 'client'
      ? 'العملاء'
      : convo.sourceApp === 'courier'
        ? 'المندوبون'
        : 'المتاجر';

    supportConversationHeader.innerHTML = `
      <b>${escapeHtml(convo.senderName || convo.userId || convo.id)}</b>
      <span class="kv"><b>المحادثة:</b> ${escapeHtml(convo.id)}</span>
      <span class="kv"><b>التطبيق:</b> ${escapeHtml(appLabel)}</span>
      <span class="kv"><b>التصنيف:</b> ${escapeHtml(convo.actor)}</span>
      <span class="kv"><b>الحالة:</b> ${convo.status === 'closed' ? 'مغلقة' : 'مفتوحة'}</span>
    `;

    supportMessagesPane.innerHTML = messages.length
      ? messages.map((msg) => {
          const mine = msg.senderType === 'admin' || msg.senderId === (auth.currentUser?.uid || '');
          const body = msg.imageUrl
            ? `<a href="${escapeHtml(msg.imageUrl)}" target="_blank" rel="noopener">📷 صورة مرفقة</a>`
            : escapeHtml(msg.message || '-');
          return `
            <div class="support-bubble ${mine ? 'mine' : ''}">
              <div class="support-bubble-head">${escapeHtml(msg.senderName || msg.senderType || msg.senderId || 'مستخدم')}</div>
              <div>${body}</div>
              <div class="support-bubble-time">${escapeHtml(msg.timeText)}</div>
            </div>
          `;
        }).join('')
      : '<div class="muted">لا توجد رسائل بعد.</div>';

    supportMessagesPane.scrollTop = supportMessagesPane.scrollHeight;
    supportToggleStatusBtn.disabled = false;
    supportSendBtn.disabled = convo.status === 'closed';
    supportReplyInput.disabled = convo.status === 'closed';
    supportToggleStatusBtn.textContent = convo.status === 'closed' ? 'إعادة فتح المحادثة' : 'إغلاق المحادثة';
  };

  const sendReply = async () => {
    const text = String(supportReplyInput?.value || '').trim();
    if (!text || !supportSelectedConversationId) return;

    const convo = supportConversations.find((item) => item.id === supportSelectedConversationId);
    if (!convo || convo.status === 'closed') return;

    const userId = getConversationUserId(convo);
    if (!userId) {
      alert('تعذر تحديد صاحب المحادثة لإرسال الرد.');
      return;
    }

    try {
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
        status: 'open',
      });
      supportReplyInput.value = '';
    } catch (err) {
      alert(`تعذر إرسال الرد: ${err.message || err}`);
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
    supportSendBtn?.addEventListener('click', sendReply);
    supportToggleStatusBtn?.addEventListener('click', toggleStatus);
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
          };
        })
        .sort((a, b) => b.latestMillis - a.latestMillis);

      if (!supportSelectedConversationId && supportConversations.length) {
        supportSelectedConversationId = supportConversations[0].id;
      } else if (supportSelectedConversationId && !supportConversations.find((c) => c.id === supportSelectedConversationId)) {
        supportSelectedConversationId = supportConversations.length ? supportConversations[0].id : '';
      }

      renderConversationList();
      renderSelectedConversation();
    })
  );
}

function mountAdmins() {
  if (!addAdminFormBound) {
    addAdminForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = adminEmailInput.value.trim().toLowerCase();
      if (!email) return;
      try {
        await setUserAdminRole({ email, active: true });
        adminEmailInput.value = '';
        alert('تم منح المستخدم صلاحية الأدمن بنجاح');
      } catch (err) {
        alert(`تعذر منح صلاحية الأدمن: ${err.message}`);
      }
    });
    addAdminFormBound = true;
  }

  if (!normalizeStateFormBound && normalizeStateForm) {
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

  unsubscribers.push(
    onSnapshot(collection(db, 'admins'), (snap) => {
      const rows = snap.docs
        .map((d) => {
          const data = d.data() || {};
          const isActive = data.active === true || data.role === 'admin';
          return `<tr>
            <td>${data.email || '-'}</td>
            <td>${data.uid || d.id}</td>
            <td>${data.role || '-'}</td>
            <td><span class="badge ${isActive ? 'closed' : 'open'}">${isActive ? 'نشط' : 'غير نشط'}</span></td>
          </tr>`;
        });
      setHtml(adminsTable, table(['البريد', 'UID', 'الدور', 'الحالة'], rows));
    })
  );
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
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

function extractGeo(data, paths) {
  for (const path of paths) {
    const raw = getByPath(data, path);
    const geo = normalizeGeo(raw);
    if (geo) return geo;
  }
  return null;
}

function setMapDetails(html) {
  if (!mapDetails) return;
  mapDetails.innerHTML = html;
}

function setMapLegendSummary(text) {
  if (!mapLegendBar) return;
  mapLegendBar.textContent = text;
}

function refreshMapLegendSummary() {
  const totalDrivers = mapState.drivers.size;
  const availableDrivers = Array.from(mapState.drivers.values())
    .filter(({ data }) => data.isAvailable === true || String(data.availabilityStatus || '').toLowerCase() === 'available')
    .length;
  const activeOrders = Array.from(mapState.orders.values()).filter(({ data }) => isActiveOrder(data)).length;
  const totalRestaurants = mapState.restaurants.size;
  const totalClients = mapState.clients.size;

  setMapLegendSummary(
    `طلبات نشطة: ${activeOrders} | مندوبون متاحون: ${availableDrivers}/${totalDrivers} | مطاعم: ${totalRestaurants} | عملاء: ${totalClients}`
  );
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
    mapAutoFitted = true;
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

function activeOrdersFor(fn) {
  return Array.from(mapState.orders.values()).filter((order) => isActiveOrder(order.data) && fn(order.data));
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

  setMapDetails(`
    <h4>تفاصيل الطلب</h4>
    <div><span class="kv"><b>رقم:</b> ${escapeHtml(orderData.orderNumber || orderId)}</span><span class="kv"><b>الحالة:</b> ${escapeHtml(orderData.status || orderData.orderStatus || '-')}</span></div>
    <div><span class="kv"><b>العميل:</b> ${escapeHtml(client?.name || orderData.clientName || clientId || '-')}</span><span class="kv"><b>المندوب:</b> ${escapeHtml(driver?.name || driverId || 'غير معين')}</span></div>
    <div><span class="kv"><b>المطعم:</b> ${escapeHtml(restaurant?.name || restaurantId || '-')}</span><span class="kv"><b>الإجمالي:</b> ${escapeHtml(orderData.total ?? orderData.totalPrice ?? '-')}</span></div>
    <div><b>العناصر:</b><ul>${items}</ul></div>
  `);
}

function renderEntityDetails(type, id, data) {
  const name = data.name || data.fullName || data.displayName || id;
  if (type === 'driver') {
    const orders = activeOrdersFor((order) => order.assignedDriverId === id);
    setMapDetails(`
      <h4>المندوب</h4>
      <div><span class="kv"><b>الاسم:</b> ${escapeHtml(name)}</span><span class="kv"><b>الهاتف:</b> ${escapeHtml(data.phone || '-')}</span></div>
      <div><span class="kv"><b>الحالة:</b> ${escapeHtml(data.availabilityStatus || (data.isAvailable ? 'available' : 'unavailable'))}</span></div>
      <div><b>طلبات نشطة:</b> ${orders.length}</div>
      <ul>${orders.slice(0, 5).map((o) => `<li>${escapeHtml(o.data.orderNumber || o.id)} - ${escapeHtml(o.data.status || o.data.orderStatus || '-')}</li>`).join('') || '<li>لا يوجد</li>'}</ul>
    `);
    return;
  }

  if (type === 'client') {
    const orders = activeOrdersFor((order) => order.clientId === id);
    setMapDetails(`
      <h4>العميل</h4>
      <div><span class="kv"><b>الاسم:</b> ${escapeHtml(name)}</span><span class="kv"><b>الهاتف:</b> ${escapeHtml(data.phone || '-')}</span></div>
      <div><b>طلبات نشطة:</b> ${orders.length}</div>
      <ul>${orders.slice(0, 5).map((o) => `<li>${escapeHtml(o.data.orderNumber || o.id)} - ${escapeHtml(o.data.status || o.data.orderStatus || '-')}</li>`).join('') || '<li>لا يوجد</li>'}</ul>
    `);
    return;
  }

  const orders = activeOrdersFor((order) => order.restaurantId === id);
  setMapDetails(`
    <h4>المطعم</h4>
    <div><span class="kv"><b>الاسم:</b> ${escapeHtml(name)}</span><span class="kv"><b>الهاتف:</b> ${escapeHtml(data.phone || '-')}</span></div>
    <div><span class="kv"><b>الحالة:</b> ${escapeHtml(data.temporarilyClosed ? 'مغلق مؤقتًا' : 'مفتوح')}</span></div>
    <div><b>طلبات نشطة:</b> ${orders.length}</div>
    <ul>${orders.slice(0, 5).map((o) => `<li>${escapeHtml(o.data.orderNumber || o.id)} - ${escapeHtml(o.data.status || o.data.orderStatus || '-')}</li>`).join('') || '<li>لا يوجد</li>'}</ul>
  `);
}

function setOrUpdateMarker(stateMap, id, latLng, color, label, onClick) {
  if (!liveMap) return;
  const existing = stateMap.get(id);
  if (existing) {
    existing.setLatLng(latLng);
    existing.setStyle({ color, fillColor: color });
    existing.bindTooltip(label);
    existing.bindPopup(label);
    return;
  }

  const marker = window.L.circleMarker(latLng, {
    radius: 8,
    color,
    fillColor: color,
    fillOpacity: 0.85,
    weight: 2
  }).addTo(liveMap);
  marker.bindTooltip(label);
  marker.bindPopup(label);
  marker.on('click', onClick);
  stateMap.set(id, marker);
}

function removeMissingMarkers(stateMap, validIds) {
  stateMap.forEach((marker, id) => {
    if (!validIds.has(id)) {
      marker.remove();
      stateMap.delete(id);
    }
  });
}

function refreshDriverMarkers() {
  const validIds = new Set();
  mapState.drivers.forEach(({ data }, id) => {
    const geo = extractGeo(data, ['location', 'currentLocation', 'lastLocation', 'address.location']);
    if (!geo) return;
    validIds.add(id);
    const available = data.isAvailable === true || String(data.availabilityStatus || '').toLowerCase() === 'available';
    const color = available ? '#16a34a' : '#6b7280';
    setOrUpdateMarker(
      markerState.drivers,
      id,
      [geo.lat, geo.lng],
      color,
      `مندوب: ${data.name || id}`,
      () => renderEntityDetails('driver', id, data)
    );
  });
  removeMissingMarkers(markerState.drivers, validIds);
}

function refreshClientMarkers() {
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
      '#2563eb',
      `عميل نشط: ${data.name || id}`,
      () => renderEntityDetails('client', id, data)
    );
  });
  removeMissingMarkers(markerState.clients, validIds);
}

function refreshRestaurantMarkers() {
  const validIds = new Set();
  mapState.restaurants.forEach(({ data }, id) => {
    const geo = extractGeo(data, ['location', 'address.location']);
    if (!geo) return;
    validIds.add(id);
    setOrUpdateMarker(
      markerState.restaurants,
      id,
      [geo.lat, geo.lng],
      '#f97316',
      `مطعم: ${data.name || id}`,
      () => renderEntityDetails('restaurant', id, data)
    );
  });
  removeMissingMarkers(markerState.restaurants, validIds);
}

function refreshOrderMarkers() {
  const validIds = new Set();
  mapState.orders.forEach(({ data }, id) => {
    if (!isActiveOrder(data)) return;
    const geo = extractGeo(data, ['deliveryLocation', 'clientLocation', 'address.location']);
    if (!geo) return;
    validIds.add(id);
    setOrUpdateMarker(
      markerState.orders,
      id,
      [geo.lat, geo.lng],
      '#dc2626',
      `طلب: ${data.orderNumber || id}`,
      () => renderOrderDetails(data, id)
    );
  });
  removeMissingMarkers(markerState.orders, validIds);
}

function getRestaurantGeoByOrder(orderData) {
  const restaurantId = orderData.restaurantId;
  if (!restaurantId) return null;
  const restaurant = mapState.restaurants.get(restaurantId)?.data;
  return restaurant ? extractGeo(restaurant, ['location', 'address.location']) : null;
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
    existing.setLatLngs(points);
    existing.setStyle(options);
    return;
  }
  const polyline = window.L.polyline(points, options).addTo(liveMap);
  lineState.orders.set(orderId, polyline);
}

function removeMissingOrderLines(validIds) {
  lineState.orders.forEach((polyline, id) => {
    if (!validIds.has(id)) {
      polyline.remove();
      lineState.orders.delete(id);
    }
  });
}

function refreshOrderLines() {
  const validIds = new Set();
  mapState.orders.forEach(({ data }, id) => {
    if (!isActiveOrder(data)) return;

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
    setOrUpdateOrderLine(id, points, {
      color: withDriver ? '#f59e0b' : '#ef4444',
      weight: 3,
      opacity: 0.75,
      dashArray: withDriver ? null : '6 6'
    });
  });

  removeMissingOrderLines(validIds);
}

function refreshMapLayers() {
  refreshDriverMarkers();
  refreshClientMarkers();
  refreshRestaurantMarkers();
  refreshOrderMarkers();
  refreshOrderLines();
  refreshMapLegendSummary();
  refreshMapViewport();
}

async function mountMap() {
  const mapElement = document.getElementById('liveMap');
  if (!mapElement) return;

  try {
    await ensureLeaflet();
  } catch (error) {
    setMapDetails(`<p class="muted">${escapeHtml(error.message || 'تعذر تحميل الخريطة.')}</p>`);
    return;
  }

  if (!liveMap) {
    liveMap = window.L.map('liveMap').setView([33.3152, 44.3661], 11);
    window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap'
    }).addTo(liveMap);

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
          '🟢 مندوب متاح<br/>⚪ مندوب غير متاح<br/>🔵 عميل نشط<br/>🟠 مطعم<br/>🔴 موقع طلب نشط';
        return div;
      };
      legend.addTo(liveMap);
      mapLegendControlAdded = true;
    }
  }

  if (mapBootstrapped) {
    refreshMapLayers();
    return;
  }
  mapBootstrapped = true;

  setMapDetails('<p class="muted">اختر علامة على الخريطة لعرض التفاصيل.</p>');

  unsubscribers.push(
    onSnapshot(collection(db, 'drivers'), (snap) => {
      mapState.drivers.clear();
      snap.docs.forEach((d) => mapState.drivers.set(d.id, { id: d.id, data: d.data() }));
      refreshMapLayers();
    })
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'clients'), (snap) => {
      mapState.clients.clear();
      snap.docs.forEach((d) => mapState.clients.set(d.id, { id: d.id, data: d.data() }));
      refreshMapLayers();
    })
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'restaurants'), (snap) => {
      mapState.restaurants.clear();
      snap.docs.forEach((d) => mapState.restaurants.set(d.id, { id: d.id, data: d.data() }));
      refreshMapLayers();
    })
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'orders'), (snap) => {
      mapState.orders.clear();
      snap.docs.forEach((d) => mapState.orders.set(d.id, { id: d.id, data: d.data() }));
      refreshMapLayers();
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

async function mountPending() {
  const [courierApps, storeApps, fallbackDriverSnap, fallbackStoreSnap] = await Promise.all([
    getPendingDocs('courierApplications'),
    getPendingDocs('restaurantApplications'),
    safeGetDocs(query(collection(db, 'drivers'), where('approvalStatus', '==', 'pending'))),
    safeGetDocs(query(collection(db, 'restaurants'), where('approvalStatus', '==', 'pending')))
  ]);

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
    rows.push(`<tr>
      <td>مندوب</td>
      <td>${data.name || d.id}</td>
      <td>${data.phone || '-'}</td>
      <td>${data.email || '-'}</td>
      <td>${data.ownerUid || data.driverId || d.id}</td>
      <td>-</td>
      <td>-</td>
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
      rows.push(`<tr><td>مندوب</td><td>${data.name || d.id}</td><td>${data.phone || '-'}</td><td>${data.email || '-'}</td><td>${data.ownerUid || d.id}</td><td>-</td><td>-</td><td>-</td></tr>`);
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
  mountDashboard();
  mountFinance();
  mountManagement();
  mountAdmins();
  mountNotifications();
  mountSupport();
  try {
    await mountPending();
  } catch (err) {
    console.error('mountPending failed', err);
  }
}

onAuthStateChanged(auth, async (user) => {
  clearSubscriptions();
  if (!user) {
    authState.textContent = 'غير مسجل';
    loginCard.hidden = false;
    appPanel.hidden = true;
    logoutBtn.hidden = true;
    return;
  }

  const allowed = await isAdmin(user);
  if (!allowed) {
    await signOut(auth);
    alert('هذا الحساب ليس لديه صلاحيات Admin.');
    return;
  }

  authState.textContent = user.email || user.uid;
  loginCard.hidden = true;
  appPanel.hidden = false;
  logoutBtn.hidden = false;
  activateTab('dashboard');
  await mountAll();
});
