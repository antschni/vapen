package dev.vapen.app.boot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import dev.vapen.app.service.TrackingController
import dev.vapen.app.service.TrackingServiceLauncher

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        TrackingController.init(context.applicationContext)
        // Resume only after device boot — not on APK replace (FGS may start before BLE permission is granted).
        if (action != Intent.ACTION_BOOT_COMPLETED) return
        if (TrackingController.credentials.trackingEnabled && TrackingController.credentials.get() != null) {
            TrackingServiceLauncher.tryStart(context.applicationContext)
        }
    }
}
