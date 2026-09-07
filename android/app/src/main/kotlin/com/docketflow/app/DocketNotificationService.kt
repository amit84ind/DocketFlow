package com.docketflow.app

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class DocketNotificationService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val packageName = sbn.packageName ?: return

        // Intercept Outlook and Gmail
        if (packageName == "com.google.android.gm" || packageName == "com.microsoft.office.outlook") {
            val extras = sbn.notification.extras
            val title = extras.getString("android.title") ?: ""
            val text = extras.getCharSequence("android.text")?.toString() ?: ""
            val fullPayload = "$title $text".lowercase()

            val triggers = listOf("inspection", "audit", "site visit", "monitoring", "compliance", "survey")
            if (triggers.any { fullPayload.contains(it) }) {
                val broadcast = Intent("com.docketflow.NEW_DOCKET_DETECTED")
                broadcast.putExtra("title", title)
                broadcast.putExtra("text", text)
                broadcast.putExtra("timestamp", sbn.postTime)
                sendBroadcast(broadcast)
            }
        }
    }
}
