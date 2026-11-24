package com.atech.map

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.View
import android.view.WindowManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.button.MaterialButton
import com.google.android.material.chip.Chip
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore

class FlashAlertActivity : AppCompatActivity() {

    private var flashId: String? = null
    private var senderName: String? = null
    private var messageText: String? = null

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var pulseAnimator: ObjectAnimator? = null
    private var isSubmitting = false

    private lateinit var tvSender: TextView
    private lateinit var tvMessage: TextView
    private lateinit var tvStatusError: TextView
    private lateinit var progressSubmitting: ProgressBar
    private lateinit var layoutIconPulse: FrameLayout
    private lateinit var layoutOtherResponse: LinearLayout
    private lateinit var etOtherResponse: EditText
    private lateinit var btnSendOther: MaterialButton
    private lateinit var btnGotIt: MaterialButton

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Configure window to show over lock screen and wake up screen
        setupLockScreenFlags()

        setContentView(R.layout.activity_flash_alert)

        // Read intent data
        flashId = intent.getStringExtra("flashId")
        senderName = intent.getStringExtra("senderName") ?: "Staff"
        messageText = intent.getStringExtra("text") ?: intent.getStringExtra("body") ?: ""

        initViews()
        setupListeners()
        startPulseAnimation()
        startAlarmAlert()
    }

    private fun setupLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )
    }

    private fun initViews() {
        tvSender = findViewById(R.id.tvSender)
        tvMessage = findViewById(R.id.tvMessage)
        tvStatusError = findViewById(R.id.tvStatusError)
        progressSubmitting = findViewById(R.id.progressSubmitting)
        layoutIconPulse = findViewById(R.id.layoutIconPulse)
        layoutOtherResponse = findViewById(R.id.layoutOtherResponse)
        etOtherResponse = findViewById(R.id.etOtherResponse)
        btnSendOther = findViewById(R.id.btnSendOther)
        btnGotIt = findViewById(R.id.btnGotIt)

        val cleanSender = senderName?.replace("⚡", "")?.trim() ?: "Staff"
        tvSender.text = "Message from $cleanSender"
        tvMessage.text = if (messageText.isNullOrBlank()) "Important message received" else messageText
    }

    private fun setupListeners() {
        val chipFinished = findViewById<Chip>(R.id.chipFinished)
        val chipInProcess = findViewById<Chip>(R.id.chipInProcess)
        val chipWillTakeTime = findViewById<Chip>(R.id.chipWillTakeTime)
        val chipForgot = findViewById<Chip>(R.id.chipForgot)
        val chipOthers = findViewById<Chip>(R.id.chipOthers)

        chipFinished.setOnClickListener { submitResponse(response = "Finished") }
        chipInProcess.setOnClickListener { submitResponse(response = "In process") }
        chipWillTakeTime.setOnClickListener { submitResponse(response = "Will take time") }
        chipForgot.setOnClickListener { submitResponse(response = "Forgot") }

        chipOthers.setOnClickListener {
            layoutOtherResponse.visibility = View.VISIBLE
            etOtherResponse.requestFocus()
        }

        btnSendOther.setOnClickListener {
            val customText = etOtherResponse.text.toString().trim()
            if (customText.isNotEmpty()) {
                submitResponse(response = "Others", responseText = customText)
            }
        }

        btnGotIt.setOnClickListener {
            submitResponse()
        }
    }

    private fun startPulseAnimation() {
        val scaleX = PropertyValuesHolder.ofFloat(View.SCALE_X, 0.92f, 1.12f)
        val scaleY = PropertyValuesHolder.ofFloat(View.SCALE_Y, 0.92f, 1.12f)
        pulseAnimator = ObjectAnimator.ofPropertyValuesHolder(layoutIconPulse, scaleX, scaleY).apply {
            duration = 900
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            start()
        }
    }

    private fun startAlarmAlert() {
        // Start vibration
        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            val pattern = longArrayOf(0, 500, 250, 500, 250, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (_: Exception) {}

        // Start alarm sound
        try {
            var alarmUri: Uri? = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (alarmUri == null) {
                alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }

            if (alarmUri != null) {
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(this@FlashAlertActivity, alarmUri)
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    isLooping = true
                    prepare()
                    start()
                }
            }
        } catch (_: Exception) {}
    }

    private fun stopAlarmAlert() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (_: Exception) {}

        try {
            vibrator?.cancel()
            vibrator = null
        } catch (_: Exception) {}
    }

    private fun submitResponse(response: String? = null, responseText: String? = null) {
        if (isSubmitting) return
        isSubmitting = true
        stopAlarmAlert()

        progressSubmitting.visibility = View.VISIBLE
        btnGotIt.isEnabled = false
        btnSendOther.isEnabled = false

        val id = flashId
        if (id.isNullOrBlank()) {
            dismissAndClose()
            return
        }

        try {
            val db = FirebaseFirestore.getInstance()
            val updateData = mutableMapOf<String, Any>(
                "status" to "seen",
                "seenAt" to FieldValue.serverTimestamp()
            )
            if (response != null) {
                updateData["response"] = response
                updateData["respondedAt"] = FieldValue.serverTimestamp()
                if (responseText != null) {
                    updateData["responseText"] = responseText
                }
            }

            db.collection("flashMessages").document(id)
                .update(updateData)
                .addOnCompleteListener {
                    dismissAndClose()
                }
        } catch (e: Exception) {
            // Even if offline, dismiss so lock screen returns cleanly
            dismissAndClose()
        }
    }

    private fun dismissAndClose() {
        FlashAlertManager.cancelNotification(this, flashId)
        finishAndRemoveTask()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        stopAlarmAlert()
        dismissAndClose()
        @Suppress("DEPRECATION")
        super.onBackPressed()
    }

    override fun onDestroy() {
        stopAlarmAlert()
        pulseAnimator?.cancel()
        super.onDestroy()
    }
}
