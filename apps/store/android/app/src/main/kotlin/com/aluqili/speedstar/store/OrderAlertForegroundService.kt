package com.aluqili.speedstar.store

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class OrderAlertForegroundService : Service() {
	private var mediaPlayer: MediaPlayer? = null

	override fun onBind(intent: Intent?): IBinder? = null

	override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
		when (intent?.action) {
			ACTION_STOP -> {
				stopPlayback()
				stopForeground(STOP_FOREGROUND_REMOVE)
				stopSelf()
				return START_NOT_STICKY
			}
			ACTION_START -> {
				val title = intent.getStringExtra(EXTRA_TITLE)
					?: "طلب جديد"
				val body = intent.getStringExtra(EXTRA_BODY)
					?: "لديك طلب جديد بانتظار القبول أو الرفض."
				startForeground(NOTIFICATION_ID, buildNotification(title, body))
				startPlaybackIfNeeded()
				return START_STICKY
			}
		}

		return START_STICKY
	}

	override fun onDestroy() {
		stopPlayback()
		super.onDestroy()
	}

	private fun buildNotification(title: String, body: String): Notification {
		val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
		val contentIntent = PendingIntent.getActivity(
			this,
			0,
			launchIntent,
			PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentMutableFlag(),
		)

		return NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
			.setSmallIcon(R.drawable.ic_stat_speedstar)
			.setContentTitle(title)
			.setContentText(body)
			.setCategory(NotificationCompat.CATEGORY_ALARM)
			.setPriority(NotificationCompat.PRIORITY_MAX)
			.setOngoing(true)
			.setOnlyAlertOnce(true)
			.setSilent(true)
			.setAutoCancel(false)
			.setContentIntent(contentIntent)
			.build()
	}

	private fun startPlaybackIfNeeded() {
		if (mediaPlayer?.isPlaying == true) {
			return
		}

		stopPlayback()

		val audioAttributes = AudioAttributes.Builder()
			.setUsage(AudioAttributes.USAGE_ALARM)
			.setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
			.build()
		val soundUri = Uri.parse("android.resource://$packageName/raw/incoming_order")

		mediaPlayer = MediaPlayer().apply {
			setAudioAttributes(audioAttributes)
			setDataSource(this@OrderAlertForegroundService, soundUri)
			isLooping = true
			prepare()
			start()
		}
	}

	private fun stopPlayback() {
		mediaPlayer?.runCatching {
			if (isPlaying) stop()
			reset()
			release()
		}
		mediaPlayer = null
	}

	private fun pendingIntentMutableFlag(): Int {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			PendingIntent.FLAG_IMMUTABLE
		} else {
			0
		}
	}

	companion object {
		const val SERVICE_CHANNEL_ID = "speedstar_store_alert_service_v1"
		private const val NOTIFICATION_ID = 88041
		private const val ACTION_START = "com.aluqili.speedstar.store.action.START_ORDER_ALERT"
		private const val ACTION_STOP = "com.aluqili.speedstar.store.action.STOP_ORDER_ALERT"
		private const val EXTRA_TITLE = "extra_title"
		private const val EXTRA_BODY = "extra_body"
		private const val EXTRA_ORDER_ID = "extra_order_id"

		fun start(context: Context, title: String?, body: String?, orderId: String?) {
			val intent = Intent(context, OrderAlertForegroundService::class.java).apply {
				action = ACTION_START
				putExtra(EXTRA_TITLE, title)
				putExtra(EXTRA_BODY, body)
				putExtra(EXTRA_ORDER_ID, orderId)
			}
			ContextCompat.startForegroundService(context, intent)
		}

		fun stop(context: Context) {
			val intent = Intent(context, OrderAlertForegroundService::class.java).apply {
				action = ACTION_STOP
			}
			context.startService(intent)
		}
	}
}