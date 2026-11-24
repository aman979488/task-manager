package com.atech.map

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore

class FlashActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_GOT_IT = "com.atech.map.ACTION_FLASH_GOT_IT"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_GOT_IT) {
            val flashId = intent.getStringExtra("flashId")
            val notifId = intent.getIntExtra("notificationId", -1)

            if (notifId != -1) {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(notifId)
            }

            if (!flashId.isNullOrBlank()) {
                try {
                    FirebaseFirestore.getInstance()
                        .collection("flashMessages")
                        .document(flashId)
                        .update(
                            mapOf(
                                "status" to "seen",
                                "seenAt" to FieldValue.serverTimestamp()
                            )
                        )
                } catch (_: Exception) {}
            }
        }
    }
}
