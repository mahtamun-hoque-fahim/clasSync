package com.classync.classync

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "classync/device")
            .setMethodCallHandler { call, result ->
                val keyguard = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        val power = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(power.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        startActivity(
                            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                .setData(Uri.parse("package:$packageName"))
                        )
                        result.success(null)
                    }
                    "canUseFullScreenIntent" -> {
                        val allowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
                            getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
                        result.success(allowed)
                    }
                    "isLocked" -> result.success(keyguard.isKeyguardLocked)
                    "unlock" -> when {
                        !keyguard.isKeyguardLocked -> result.success(true)
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O -> result.success(false)
                        else -> keyguard.requestDismissKeyguard(
                            this,
                            object : KeyguardManager.KeyguardDismissCallback() {
                                override fun onDismissSucceeded() = result.success(true)
                                override fun onDismissCancelled() = result.success(false)
                                override fun onDismissError() = result.success(false)
                            }
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
