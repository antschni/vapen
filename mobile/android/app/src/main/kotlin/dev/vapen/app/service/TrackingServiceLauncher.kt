package dev.vapen.app.service

import android.content.Context
import android.content.Intent
import android.os.Build
import dev.vapen.app.ble.BlePermissions

object TrackingServiceLauncher {
    /** Starts the tracking FGS when runtime requirements are met (Android 12+ BLE connect, etc.). */
    fun tryStart(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !BlePermissions.hasConnectPermissions(context)
        ) {
            return false
        }
        return try {
            context.startForegroundService(Intent(context, VapenTrackingService::class.java))
            true
        } catch (_: Exception) {
            false
        }
    }
}
