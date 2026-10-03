package dev.vapen.app.companion

import android.companion.CompanionDeviceService
import android.content.Intent
import android.os.Build
import androidx.annotation.RequiresApi
import dev.vapen.app.service.VapenTrackingService

/**
 * Wakes tracking when an associated BLE device appears (Companion Device Manager).
 */
@RequiresApi(Build.VERSION_CODES.S)
class VapenCompanionDeviceService : CompanionDeviceService() {
    override fun onDeviceAppeared(address: String) {
        startForegroundService(Intent(this, VapenTrackingService::class.java))
    }

    override fun onDeviceDisappeared(address: String) {
        // Keep service in low-power wait state; full BLE session handles reconnect.
    }
}
