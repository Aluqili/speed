package com.aluqili.speedstar.courier

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "speedstar_courier/location_service"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundTracking" -> {
                    val driverId = call.argument<String>("driverId")?.trim().orEmpty()
                    if (driverId.isEmpty()) {
                        result.error("invalid_driver_id", "driverId is required", null)
                        return@setMethodCallHandler
                    }

                    val intent = CourierLocationForegroundService.startIntent(this, driverId)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }

                "stopForegroundTracking" -> {
                    val intent = CourierLocationForegroundService.stopIntent(this)
                    startService(intent)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}
