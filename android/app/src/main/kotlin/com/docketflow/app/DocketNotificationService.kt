package com.docketflow.app

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class DocketNotificationService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val packageName = sbn.packageName ?: return

        // Intercept Outlook and Gmail
        val isOutlook = packageName == "com.microsoft.office.outlook"
        val isGmail = packageName == "com.google.android.gm"

        if (isOutlook || isGmail) {
            val extras = sbn.notification.extras
            val title = extras.getString("android.title") ?: ""
            val textStr = extras.getCharSequence("android.text")?.toString() ?: ""
            val bigTextStr = extras.getCharSequence("android.bigText")?.toString() ?: ""

            val contentToAnalyze = if (bigTextStr.isNotEmpty()) bigTextStr else textStr
            val fullPayload = "$title $contentToAnalyze".lowercase()

            val triggers = listOf(
                "inspection", "audit", "site visit", "monitoring", "compliance", "survey",
                "docket", "ticket", "work order", "dispatch", "schedule", "review", "checklist"
            )

            if (triggers.any { fullPayload.contains(it) }) {
                val broadcast = Intent("com.docketflow.NEW_DOCKET_DETECTED")
                broadcast.putExtra("title", title)
                broadcast.putExtra("text", contentToAnalyze)
                broadcast.putExtra("timestamp", sbn.postTime)
                broadcast.putExtra("source", if (isOutlook) "Outlook" else "Gmail")
                sendBroadcast(broadcast)
            }
        }
    }
}
