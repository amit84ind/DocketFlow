package com.docketflow.app.docketflow

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val EVENT_CHANNEL = "com.docketflow/notifications"
    private val METHOD_CHANNEL = "com.docketflow/settings"
    private var eventSink: EventChannel.EventSink? = null
    private var pendingSharedText: String? = null

    private val notificationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.docketflow.NEW_DOCKET_DETECTED") {
                val title = intent.getStringExtra("title") ?: ""
                val text = intent.getStringExtra("text") ?: ""
                val timestamp = intent.getLongExtra("timestamp", System.currentTimeMillis())
                val source = intent.getStringExtra("source") ?: "Outlook"

                val data = mapOf(
                    "title" to title,
                    "text" to text,
                    "timestamp" to timestamp,
                    "source" to source
                )
                eventSink?.success(data)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action

        if (Intent.ACTION_SEND == action || Intent.ACTION_PROCESS_TEXT == action) {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                ?: intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
                ?: ""
            val sharedSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: "Outlook Shared Docket"

            if (sharedText.isNotEmpty()) {
                pendingSharedText = "$sharedSubject\n$sharedText"
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        handleIntent(this.intent)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler(
            MethodChannel.MethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationServiceEnabled" -> {
                        val enabled = isNotificationServiceEnabled()
                        result.success(enabled)
                    }
                    "openNotificationSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            this@MainActivity.startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Cannot open settings", null)
                        }
                    }
                    "getPendingSharedText" -> {
                        val text = pendingSharedText
                        pendingSharedText = null
                        result.success(text)
                    }
                    else -> result.notImplemented()
                }
            }
        )
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (flat != null) {
            val names = flat.split(":")
            for (name in names) {
                val cn = ComponentName.unflattenFromString(name)
                if (cn != null && cn.packageName == pkgName) {
                    return true
                }
            }
        }
        return false
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter("com.docketflow.NEW_DOCKET_DETECTED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notificationReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(notificationReceiver, filter)
        }
    }

    override fun onStop() {
        super.onStop()
        try {
            unregisterReceiver(notificationReceiver)
        } catch (e: Exception) {
            // Ignored if not registered
        }
    }
}
