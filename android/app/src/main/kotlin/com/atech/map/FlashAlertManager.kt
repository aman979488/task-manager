package com.atech.map

import android.app.ActivityManager
import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat

object FlashAlertManager {

    const val CHANNEL_ID = "flash_alerts_channel"
    private const val CHANNEL_NAME = "Flash Alerts & Alarms"
    private const val NOTIFICATION_ID_BASE = 88000

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val existing = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (existing != null) return

            val alarmSound: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()

            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Urgent full-screen flash messages and alerts"
                setSound(alarmSound, audioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 250, 500, 250, 500)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }

            notificationManager.createNotificationChannel(channel)
        }
    }

    fun showFlashAlert(context: Context, data: Map<String, String>) {
        createNotificationChannel(context)

        val flashId = data["flashId"] ?: System.currentTimeMillis().toString()
        val senderName = data["title"] ?: data["senderName"] ?: "Staff"
        val text = data["body"] ?: data["text"] ?: ""

        val notifId = (NOTIFICATION_ID_BASE + (flashId.hashCode() and 0x7fff))

        // 1. Acquire WakeLock to turn on screen immediately even if phone is in deep sleep / locked
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "task_manager:FlashAlertWakeLock"
            )
            wakeLock.acquire(10000) // 10 seconds timeout
        } catch (_: Exception) {}

        // 2. Prepare Intent for FlashAlertActivity
        val alertIntent = Intent(context, FlashAlertActivity::class.java).apply {
            putExtra("flashId", flashId)
            putExtra("senderName", senderName)
            putExtra("text", text)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            notifId,
            alertIntent,
            flags
        )

        // "Got it" action directly on notification
        val actionIntent = Intent(context, FlashActionReceiver::class.java).apply {
            putExtra("flashId", flashId)
            putExtra("notificationId", notifId)
            action = FlashActionReceiver.ACTION_GOT_IT
        }
        val actionPendingIntent = PendingIntent.getBroadcast(
            context,
            notifId + 1,
            actionIntent,
            flags
        )

        val alarmSound: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        // 3. Build high-priority notification with fullScreenIntent
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(senderName)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .setAutoCancel(true)
            .setOngoing(true)
            .setSound(alarmSound)
            .setVibrate(longArrayOf(0, 500, 250, 500, 250, 500))
            .addAction(R.drawable.ic_flash_bolt, "Got it", actionPendingIntent)
            .build()

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(notifId, notification)

        // 4. Also launch FlashAlertActivity directly
        try {
            context.startActivity(alertIntent)
        } catch (_: Exception) {
            // Android 10+ background activity start restrictions handled by fullScreenIntent
        }
    }

    fun cancelNotification(context: Context, flashId: String?) {
        val notifId = if (flashId != null) {
            NOTIFICATION_ID_BASE + (flashId.hashCode() and 0x7fff)
        } else {
            null
        }
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (notifId != null) {
            notificationManager.cancel(notifId)
        } else {
            notificationManager.cancelAll()
        }
    }

    fun isDeviceLocked(context: Context): Boolean {
        val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        return keyguardManager?.isKeyguardLocked == true
    }

    fun isAppInForeground(context: Context): Boolean {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return false
        val processes = activityManager.runningAppProcesses ?: return false
        val pkg = context.packageName
        for (proc in processes) {
            if (proc.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                proc.processName == pkg) {
                return true
            }
        }
        return false
    }
}
