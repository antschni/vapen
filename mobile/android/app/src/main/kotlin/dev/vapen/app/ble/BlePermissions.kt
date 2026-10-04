package dev.vapen.app.ble

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

object BlePermissions {
    fun hasScanPermissions(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_SCAN,
            ) == PackageManager.PERMISSION_GRANTED
        }
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun hasConnectPermissions(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_CONNECT,
            ) == PackageManager.PERMISSION_GRANTED
        }
        return true
    }

    fun missingScanMessage(context: Context): String? = when {
        !hasScanPermissions(context) ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                "Bluetooth-Scan-Berechtigung fehlt (Einstellungen → App → Berechtigungen)."
            } else {
                "Standort-Berechtigung fehlt (für BLE-Scan unter Android 11)."
            }
        else -> null
    }

    fun missingConnectMessage(context: Context): String? = when {
        !hasConnectPermissions(context) -> "Bluetooth-Verbindungs-Berechtigung fehlt."
        else -> null
    }
}
