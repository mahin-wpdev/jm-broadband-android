package com.jmbroadband.jm_broadband_app

import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "jm_broadband/update"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "support_tickets",
                "Arivo notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Support tickets, service updates and admin messages"
                enableVibration(true)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enqueue" -> {
                        val url = call.argument<String>("url")
                        val fileName = call.argument<String>("fileName")
                        if (url.isNullOrBlank() || fileName.isNullOrBlank()) {
                            result.error("BAD_ARGS", "Missing update URL", null)
                        } else {
                            try { result.success(enqueue(url, fileName)) }
                            catch (e: Exception) {
                                result.error("DOWNLOAD", e.message, null)
                            }
                        }
                    }
                    "status" -> {
                        val id = call.argument<Number>("id")?.toLong()
                        if (id == null) result.error("BAD_ARGS", "Missing id", null)
                        else result.success(status(id))
                    }
                    else -> result.notImplemented()
                }
            }
    }
    private fun enqueue(url: String, fileName: String): Long {
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle("Arivo ISP Billing update")
            .setDescription("Downloading app update")
            .setMimeType("application/vnd.android.package-archive")
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
            .setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalFilesDir(
                this, Environment.DIRECTORY_DOWNLOADS, fileName)
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        return manager.enqueue(request)
    }

    private fun status(id: Long): Map<String, Any?> {
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val cursor = manager.query(DownloadManager.Query().setFilterById(id))
        cursor.use {
            if (!it.moveToFirst()) return mapOf("status" to -1)
            val status = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            val local = it.getString(it.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
            val downloaded = it.getLong(
                it.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
            val total = it.getLong(
                it.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            val reason = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
            return mapOf(
                "status" to status,
                "localUri" to local,
                "downloaded" to downloaded,
                "total" to total,
                "reason" to reason)
        }
    }
}
