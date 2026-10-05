package dev.vapen.app.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import dev.vapen.app.MainActivity
import dev.vapen.app.upload.UploadWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class VapenTrackingService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        TrackingController.init(applicationContext)
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification(this, lastText ?: "Verbindung wird aufgebaut…")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: SecurityException) {
            stopSelf()
            return START_NOT_STICKY
        }
        scope.launch {
            if (TrackingController.credentials.trackingEnabled) {
                TrackingController.resumeBleIfConfigured()
            }
            runCatching { TrackingController.uploader.flush() }
            enqueueUploadWorker()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Tracking",
            NotificationManager.IMPORTANCE_LOW,
        )
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(channel)
    }

    private fun enqueueUploadWorker() {
        val request = OneTimeWorkRequestBuilder<UploadWorker>()
            .setConstraints(
                androidx.work.Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            )
            .build()
        WorkManager.getInstance(this).enqueueUniqueWork(
            "vapen_upload",
            ExistingWorkPolicy.KEEP,
            request,
        )
    }

    companion object {
        const val CHANNEL_ID = "vapen_tracking"
        const val NOTIFICATION_ID = 1001

        @Volatile private var lastText: String? = null

        /** Replaces the foreground notification text; no-op while the service is not running. */
        fun updateNotification(context: Context, text: String) {
            if (text == lastText) return
            lastText = text
            val nm = context.getSystemService(NotificationManager::class.java)
            if (nm.activeNotifications.none { it.id == NOTIFICATION_ID }) return
            nm.notify(NOTIFICATION_ID, buildNotification(context, text))
        }

        private fun buildNotification(context: Context, text: String): Notification {
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setContentTitle("Vapen Tracking")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(open)
                .addAction(0, "App öffnen", open)
                .build()
        }
    }
}
