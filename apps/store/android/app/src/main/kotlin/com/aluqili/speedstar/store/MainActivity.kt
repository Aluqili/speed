package com.aluqili.speedstar.store

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val alertServiceChannel = "speedstar/store_alert_service"

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		ensureNotificationChannels()
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, alertServiceChannel)
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
					else -> result.notImplemented()
				}
			}
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
			"speedstar_store_orders_incoming_v6",
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
			NotificationManager.IMPORTANCE_LOW,
		).apply {
			description = "تنبيه مستمر حتى قبول الطلب أو رفضه"
			setSound(null, null)
			enableVibration(false)
			setShowBadge(false)
		}

		manager.createNotificationChannel(alertsChannel)
		manager.createNotificationChannel(ordersChannel)
		manager.createNotificationChannel(serviceChannel)
	}
}

