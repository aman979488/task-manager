package com.example.task_manager

import android.Manifest
import android.content.ContentResolver
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.CallLog
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val callLogExecutor = Executors.newSingleThreadExecutor()
    private var pendingCallLogResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALL_HISTORY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRecentCalls" -> getRecentCalls(result)
                "openCallLogSettings" -> openCallLogSettings(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun getRecentCalls(result: MethodChannel.Result) {
        if (pendingCallLogResult != null) {
            result.error("ALREADY_RUNNING", "A call-log request is already in progress.", null)
            return
        }

        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_CALL_LOG,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingCallLogResult = result
            requestPermissions(
                arrayOf(Manifest.permission.READ_CALL_LOG),
                CALL_LOG_PERMISSION_REQUEST,
            )
            return
        }

        queryRecentCalls(result)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CALL_LOG_PERMISSION_REQUEST) return

        val result = pendingCallLogResult ?: return
        pendingCallLogResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            queryRecentCalls(result)
        } else {
            result.error(
                "PERMISSION_NOT_GRANTED",
                "Call-log permission was not granted.",
                null,
            )
        }
    }

    private fun queryRecentCalls(result: MethodChannel.Result) {
        callLogExecutor.execute {
            try {
                val projection = arrayOf(
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.CACHED_NAME,
                    CallLog.Calls.TYPE,
                    CallLog.Calls.DATE,
                    CallLog.Calls.DURATION,
                )
                val cursor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val queryArgs = Bundle().apply {
                        putString(
                            ContentResolver.QUERY_ARG_SQL_SORT_ORDER,
                            "${CallLog.Calls.DATE} DESC",
                        )
                        putString(ContentResolver.QUERY_ARG_SQL_LIMIT, MAX_CALLS.toString())
                    }
                    contentResolver.query(
                        CallLog.Calls.CONTENT_URI,
                        projection,
                        queryArgs,
                        null,
                    )
                } else {
                    contentResolver.query(
                        CallLog.Calls.CONTENT_URI,
                        projection,
                        null,
                        null,
                        "${CallLog.Calls.DATE} DESC",
                    )
                }

                val calls = mutableListOf<Map<String, Any?>>()
                cursor?.use { rows: Cursor ->
                    val numberIndex = rows.getColumnIndex(CallLog.Calls.NUMBER)
                    val nameIndex = rows.getColumnIndex(CallLog.Calls.CACHED_NAME)
                    val typeIndex = rows.getColumnIndex(CallLog.Calls.TYPE)
                    val dateIndex = rows.getColumnIndex(CallLog.Calls.DATE)
                    val durationIndex = rows.getColumnIndex(CallLog.Calls.DURATION)

                    while (rows.moveToNext()) {
                        calls.add(
                            mapOf(
                                "number" to rows.getString(numberIndex),
                                "name" to rows.getString(nameIndex),
                                "type" to rows.getInt(typeIndex),
                                "timestamp" to rows.getLong(dateIndex),
                                "duration" to rows.getInt(durationIndex),
                            ),
                        )
                    }
                }
                runOnUiThread { result.success(calls) }
            } catch (error: SecurityException) {
                runOnUiThread {
                    result.error("PERMISSION_NOT_GRANTED", error.message, null)
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("CALL_LOG_QUERY_FAILED", error.message, null)
                }
            }
        }
    }

    private fun openCallLogSettings(result: MethodChannel.Result) {
        try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName"),
                ),
            )
            result.success(null)
        } catch (error: Exception) {
            result.error("SETTINGS_UNAVAILABLE", error.message, null)
        }
    }

    companion object {
        private const val CALL_HISTORY_CHANNEL = "task_manager/call_history"
        private const val CALL_LOG_PERMISSION_REQUEST = 4821
        private const val MAX_CALLS = 500
    }
}
