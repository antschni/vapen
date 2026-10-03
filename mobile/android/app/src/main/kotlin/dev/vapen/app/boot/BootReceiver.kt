package dev.vapen.app.boot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import dev.vapen.app.service.TrackingController
import dev.vapen.app.service.VapenTrackingService

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        TrackingController.init(context.applicationContext)
        if (TrackingController.credentials.trackingEnabled && TrackingController.credentials.get() != null) {
            context.startForegroundService(Intent(context, VapenTrackingService::class.java))
        }
    }
}
