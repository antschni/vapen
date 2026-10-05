package dev.vapen.app.data

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

data class NativeCredentials(
    val baseUrl: String,
    val deviceId: String,
    val deviceToken: String,
    val hardwareId: String,
)

class CredentialStore(context: Context) {
    private val prefs: SharedPreferences = openPrefs(context.applicationContext)

    private fun openPrefs(context: Context): SharedPreferences {
        return try {
            EncryptedSharedPreferences.create(
                context,
                "vapen_credentials",
                MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        } catch (e: Exception) {
            Log.w(TAG, "Encrypted credentials unavailable, using fallback store", e)
            context.getSharedPreferences(FALLBACK_PREFS, Context.MODE_PRIVATE)
        }
    }

    fun save(credentials: NativeCredentials) {
        prefs.edit()
            .putString(KEY_BASE_URL, credentials.baseUrl)
            .putString(KEY_DEVICE_ID, credentials.deviceId)
            .putString(KEY_DEVICE_TOKEN, credentials.deviceToken)
            .putString(KEY_HARDWARE_ID, credentials.hardwareId)
            .putBoolean(KEY_TRACKING_ENABLED, true)
            .apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    fun get(): NativeCredentials? {
        val baseUrl = prefs.getString(KEY_BASE_URL, null) ?: return null
        val deviceId = prefs.getString(KEY_DEVICE_ID, null) ?: return null
        val token = prefs.getString(KEY_DEVICE_TOKEN, null) ?: return null
        val hardwareId = prefs.getString(KEY_HARDWARE_ID, null) ?: return null
        return NativeCredentials(baseUrl, deviceId, token, hardwareId)
    }

    var pairedBleAddress: String?
        get() = prefs.getString(KEY_PAIRED_ADDRESS, null)
        set(value) = prefs.edit().putString(KEY_PAIRED_ADDRESS, value).apply()

    var trackingEnabled: Boolean
        get() = prefs.getBoolean(KEY_TRACKING_ENABLED, false)
        set(value) = prefs.edit().putBoolean(KEY_TRACKING_ENABLED, value).apply()

    var simulationEnabled: Boolean
        get() = prefs.getBoolean(KEY_SIMULATION, false)
        set(value) = prefs.edit().putBoolean(KEY_SIMULATION, value).apply()

    companion object {
        private const val TAG = "CredentialStore"
        private const val FALLBACK_PREFS = "vapen_credentials_fallback"
        private const val KEY_BASE_URL = "base_url"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_DEVICE_TOKEN = "device_token"
        private const val KEY_HARDWARE_ID = "hardware_id"
        private const val KEY_PAIRED_ADDRESS = "paired_ble_address"
        private const val KEY_TRACKING_ENABLED = "tracking_enabled"
        private const val KEY_SIMULATION = "simulation_enabled"
    }
}
