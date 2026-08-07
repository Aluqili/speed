package com.aluqili.speedstar.courier

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.GeoPoint
import com.google.firebase.firestore.ListenerRegistration

class CourierLocationForegroundService : Service() {
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private val firestore: FirebaseFirestore by lazy { FirebaseFirestore.getInstance() }
    private var locationCallback: LocationCallback? = null
    private var activeOrdersListener: ListenerRegistration? = null
    private var driverId: String = ""
    private var activeOrderId: String? = null
    private var lastLat: Double? = null
    private var lastLng: Double? = null
    private var lastWriteMs: Long = 0L

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            clearStoredDriverId()
            stopSelf()
            return START_NOT_STICKY
        }

        val requestedDriverId = intent?.getStringExtra(EXTRA_DRIVER_ID)?.trim().orEmpty()
        val nextDriverId = requestedDriverId.ifEmpty { getStoredDriverId() }
        if (nextDriverId.isEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }

        driverId = nextDriverId
        storeDriverId(nextDriverId)
        startForeground(NOTIFICATION_ID, buildNotification())
        listenForActiveOrder()
        startLocationUpdates()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        locationCallback?.let { fusedLocationClient.removeLocationUpdates(it) }
        locationCallback = null
        activeOrdersListener?.remove()
        activeOrdersListener = null
        super.onDestroy()
    }

    private fun startLocationUpdates() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            stopSelf()
            return
        }

        if (locationCallback != null) return

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5000L)
            .setMinUpdateDistanceMeters(20f)
            .setMinUpdateIntervalMillis(20_000L)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { writeLocation(it) }
            }
        }

        fusedLocationClient.requestLocationUpdates(
            request,
            locationCallback as LocationCallback,
            mainLooper
        )
    }

    private fun listenForActiveOrder() {
        activeOrdersListener?.remove()
        activeOrdersListener = firestore.collection("orders")
            .whereEqualTo("assignedDriverId", driverId)
            .addSnapshotListener { snapshot, _ ->
                val active = snapshot?.documents
                    ?.filter { doc ->
                        val status = (doc.getString("orderStatus") ?: doc.getString("status") ?: "").trim()
                        ACTIVE_STATUSES.contains(status)
                    }
                    ?.sortedByDescending { doc ->
                        timestampMs(doc.get("acceptedAt"))
                            ?: timestampMs(doc.get("updatedAt"))
                            ?: 0L
                    }
                    .orEmpty()

                activeOrderId = active.firstOrNull()?.id
            }
    }

    private fun timestampMs(value: Any?): Long? {
        return when (value) {
            is Timestamp -> value.toDate().time
            is java.util.Date -> value.time
            is Number -> value.toLong()
            else -> null
        }
    }

    private fun writeLocation(location: Location) {
        val id = driverId.trim()
        if (id.isEmpty()) return

        val lat = location.latitude
        val lng = location.longitude
        val nowMs = System.currentTimeMillis()
        val previousLat = lastLat
        val previousLng = lastLng

        if (previousLat != null && previousLng != null) {
            val result = FloatArray(1)
            Location.distanceBetween(previousLat, previousLng, lat, lng, result)
            if (result[0] < 20f && nowMs - lastWriteMs < 20_000L) return
        }

        val point = GeoPoint(lat, lng)
        val locationMap = hashMapOf(
            "lat" to lat,
            "lng" to lng,
            "latitude" to lat,
            "longitude" to lng,
            "accuracy" to location.accuracy,
            "heading" to location.bearing,
            "speed" to location.speed
        )

        val driverPatch = hashMapOf<String, Any>(
            "location" to point,
            "currentLocation" to locationMap,
            "lastLocation" to point,
            "latitude" to lat,
            "longitude" to lng,
            "lastLocationUpdate" to FieldValue.serverTimestamp(),
            "lastUpdated" to FieldValue.serverTimestamp(),
            "updatedAt" to FieldValue.serverTimestamp()
        )
        activeOrderId?.let { driverPatch["activeOrderId"] = it }

        firestore.collection("drivers").document(id).set(driverPatch, com.google.firebase.firestore.SetOptions.merge())

        activeOrderId?.let { orderId ->
            firestore.collection("orders").document(orderId).set(
                hashMapOf(
                    "driverLocation" to point,
                    "driverCurrentLocation" to locationMap,
                    "driverLat" to lat,
                    "driverLng" to lng,
                    "driverLocationUpdatedAt" to FieldValue.serverTimestamp(),
                    "lastLocationUpdate" to FieldValue.serverTimestamp()
                ),
                com.google.firebase.firestore.SetOptions.merge()
            )
        }

        lastLat = lat
        lastLng = lng
        lastWriteMs = nowMs
    }

    private fun buildNotification() =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SpeedStar Courier")
            .setContentText("Live location tracking is active")
            .setSmallIcon(R.drawable.ic_stat_speedstar)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Courier live location",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun getStoredDriverId(): String =
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getString(PREF_DRIVER_ID, "") ?: ""

    private fun storeDriverId(value: String) {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .edit()
            .putString(PREF_DRIVER_ID, value)
            .apply()
    }

    private fun clearStoredDriverId() {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .edit()
            .remove(PREF_DRIVER_ID)
            .apply()
    }

    companion object {
        const val ACTION_STOP = "com.aluqili.speedstar.courier.STOP_LOCATION_SERVICE"
        const val EXTRA_DRIVER_ID = "driverId"
        private const val PREFS_NAME = "courier_location_service"
        private const val PREF_DRIVER_ID = "driver_id"
        private const val CHANNEL_ID = "courier_live_location"
        private const val NOTIFICATION_ID = 23041
        private val ACTIVE_STATUSES = setOf(
            "courier_assigned",
            "pickup_ready",
            "picked_up",
            "arrived_to_client",
            "جاهز للتوصيل",
            "قيد التوصيل",
            "وصل إلى العميل"
        )

        fun startIntent(context: Context, driverId: String): Intent =
            Intent(context, CourierLocationForegroundService::class.java).apply {
                putExtra(EXTRA_DRIVER_ID, driverId)
            }

        fun stopIntent(context: Context): Intent =
            Intent(context, CourierLocationForegroundService::class.java).apply {
                action = ACTION_STOP
            }
    }
}
