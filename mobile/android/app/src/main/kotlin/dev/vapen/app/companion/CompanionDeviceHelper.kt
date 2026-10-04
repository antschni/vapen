package dev.vapen.app.companion

import android.app.Activity
import android.companion.AssociationRequest
import android.companion.BluetoothDeviceFilter
import android.companion.CompanionDeviceManager
import android.os.Build
import androidx.annotation.RequiresApi

object CompanionDeviceHelper {
    @RequiresApi(Build.VERSION_CODES.O)
    fun associate(activity: Activity, onResult: (String?) -> Unit) {
        PendingAssociation.callback = onResult
        val manager = activity.getSystemService(CompanionDeviceManager::class.java)
        val filter = BluetoothDeviceFilter.Builder()
            .setNamePattern(java.util.regex.Pattern.compile("(?i).*(elfa|master|elfbar).*"))
            .build()
        val request = AssociationRequest.Builder()
            .addDeviceFilter(filter)
            .setSingleDevice(true)
            .build()
        manager.associate(
            request,
            object : CompanionDeviceManager.Callback() {
                override fun onDeviceFound(chooserLauncher: android.content.IntentSender) {
                    try {
                        activity.startIntentSenderForResult(chooserLauncher, REQUEST_CODE, null, 0, 0, 0)
                    } catch (_: Exception) {
                        PendingAssociation.deliver(null)
                    }
                }

                override fun onFailure(error: CharSequence?) {
                    PendingAssociation.deliver(null)
                }
            },
            null,
        )
    }

    fun handleActivityResult(resultCode: Int, data: android.content.Intent?) {
        val address = if (resultCode == Activity.RESULT_OK && data != null) {
            val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                data.getParcelableExtra(CompanionDeviceManager.EXTRA_DEVICE, android.bluetooth.BluetoothDevice::class.java)
            } else {
                @Suppress("DEPRECATION")
                data.getParcelableExtra(CompanionDeviceManager.EXTRA_DEVICE)
            }
            device?.address
        } else {
            null
        }
        PendingAssociation.deliver(address)
    }

    const val REQUEST_CODE = 9911

    private object PendingAssociation {
        var callback: ((String?) -> Unit)? = null

        /** Invokes the pending callback at most once (CDM may report both activity result and onFailure). */
        fun deliver(address: String?) {
            val cb = callback ?: return
            callback = null
            cb(address)
        }
    }
}
