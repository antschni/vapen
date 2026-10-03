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
                    activity.startIntentSenderForResult(chooserLauncher, REQUEST_CODE, null, 0, 0, 0)
                    PendingAssociation.callback = onResult
                }

                override fun onFailure(error: CharSequence?) {
                    onResult(null)
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
        } else null
        PendingAssociation.callback?.invoke(address)
        PendingAssociation.callback = null
    }

    const val REQUEST_CODE = 9911

    private object PendingAssociation {
        var callback: ((String?) -> Unit)? = null
    }
}
