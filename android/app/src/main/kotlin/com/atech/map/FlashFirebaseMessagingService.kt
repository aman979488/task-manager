package com.atech.map

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class FlashFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        val data = remoteMessage.data
        val type = data["type"]

        Log.d(TAG, "Message received, type: $type, data: $data")

        if (type == "flash") {
            val isForeground = FlashAlertManager.isAppInForeground(this)
            val isLocked = FlashAlertManager.isDeviceLocked(this)

            if (isForeground && !isLocked) {
                // If app is currently visible and active in foreground, in-app overlay handles it
                Log.d(TAG, "App is active in foreground and unlocked. In-app overlay will display.")
            } else {
                // Mobile locked, screen off, or app in recents / killed -> launch full-screen alert
                Log.d(TAG, "Triggering native full-screen FlashAlert! (isLocked=$isLocked, isForeground=$isForeground)")
                FlashAlertManager.showFlashAlert(this, data)
            }
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "New FCM token received: $token")
    }

    companion object {
        private const val TAG = "FlashFCMService"
    }
}
