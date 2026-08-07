package com.aluqili.speedstar.store

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val alertServiceChannel = "speedstar/store_alert_service"
	private var pendingOrderAlertTap: Map<String, String>? = null
	private var orderAlertMethodChannel: MethodChannel? = null

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		captureOrderAlertTap(intent)
		ensureNotificationChannels()
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		captureOrderAlertTap(intent)
		pendingOrderAlertTap?.let {
			orderAlertMethodChannel?.invokeMethod("orderAlertTapped", it)
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		orderAlertMethodChannel = MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			alertServiceChannel,
		).also { channel ->
			channel
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"startOrderAlert" -> {
						OrderAlertForegroundService.start(
							context = this,
							title = call.argument<String>("title"),
							body = call.argument<String>("body"),
							orderId = call.argument<String>("orderId"),
						)
						result.success(null)
					}
					"stopOrderAlert" -> {
						OrderAlertForegroundService.stop(this)
						result.success(null)
					}
					"consumeOrderAlertTap" -> {
						result.success(pendingOrderAlertTap)
						pendingOrderAlertTap = null
					}
					else -> result.notImplemented()
				}
			}
		}
	}

	private fun captureOrderAlertTap(intent: Intent?) {
		val orderId = intent?.getStringExtra(OrderAlertForegroundService.EXTRA_ORDER_ID)
			?.trim()
			.orEmpty()
		if (orderId.isEmpty()) return
		pendingOrderAlertTap = mapOf(
			"orderId" to orderId,
			"type" to "store_new_order",
			"title" to intent?.getStringExtra(OrderAlertForegroundService.EXTRA_TITLE).orEmpty(),
			"body" to intent?.getStringExtra(OrderAlertForegroundService.EXTRA_BODY).orEmpty(),
		)
	}

	private fun ensureNotificationChannels() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
			return
		}

		val manager = getSystemService(NotificationManager::class.java) ?: return
		val ringtoneUri = Uri.parse("android.resource://$packageName/raw/incoming_order")
		val ringtoneAudio = AudioAttributes.Builder()
			.setUsage(AudioAttributes.USAGE_NOTIFICATION)
			.setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
			.build()

		val alertsChannel = NotificationChannel(
			"speedstar_alerts",
			"SpeedStar Alerts",
			NotificationManager.IMPORTANCE_HIGH,
		).apply {
			description = "تنبيهات الطلبات والتحديثات"
			enableVibration(true)
		}

		val ordersChannel = NotificationChannel(
			"speedstar_store_orders_incoming_v7",
			"SpeedStar Orders",
			NotificationManager.IMPORTANCE_HIGH,
		).apply {
			description = "تنبيهات الطلبات الجديدة والعروض الفورية"
			enableVibration(true)
			setSound(ringtoneUri, ringtoneAudio)
			lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
		}

		val serviceChannel = NotificationChannel(
			OrderAlertForegroundService.SERVICE_CHANNEL_ID,
			"SpeedStar Active Order Alert",
			NotificationManager.IMPORTANCE_HIGH,
		).apply {
			description = "تنبيه مستمر حتى قبول الطلب أو رفضه"
			setSound(null, null)
			enableVibration(false)
			setShowBadge(false)
			lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
		}

		manager.createNotificationChannel(alertsChannel)
		manager.createNotificationChannel(ordersChannel)
		manager.createNotificationChannel(serviceChannel)
	}
}

