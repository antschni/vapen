package dev.vapen.app.protocol

import android.content.Context

/**
 * Position in the device's puff record list.
 *
 * [tailDeviceSeconds] is the timestamp of the record at `nextOffset - 1`, used to detect that the
 * device list changed (cleared, rotated). [newestDeviceSeconds] is the newest record ever synced.
 */
data class HistoryCursor(
    val nextOffset: Int = 0,
    val tailDeviceSeconds: Long = 0,
    val newestDeviceSeconds: Long = 0,
    val linked: Boolean = false,
)

interface HistoryCursorStore {
    fun load(deviceKey: String): HistoryCursor
    fun save(deviceKey: String, cursor: HistoryCursor)
}

class InMemoryHistoryCursorStore : HistoryCursorStore {
    private val cursors = mutableMapOf<String, HistoryCursor>()
    override fun load(deviceKey: String): HistoryCursor = cursors[deviceKey] ?: HistoryCursor()
    override fun save(deviceKey: String, cursor: HistoryCursor) {
        cursors[deviceKey] = cursor
    }
}

class SharedPrefsHistoryCursorStore(context: Context) : HistoryCursorStore {
    private val prefs = context.applicationContext.getSharedPreferences("vapen_history_cursor", Context.MODE_PRIVATE)

    override fun load(deviceKey: String): HistoryCursor = HistoryCursor(
        nextOffset = prefs.getInt("$deviceKey.offset", 0),
        tailDeviceSeconds = prefs.getLong("$deviceKey.tail", 0),
        newestDeviceSeconds = prefs.getLong("$deviceKey.newest", 0),
        linked = prefs.getBoolean("$deviceKey.linked", false),
    )

    override fun save(deviceKey: String, cursor: HistoryCursor) {
        prefs.edit()
            .putInt("$deviceKey.offset", cursor.nextOffset)
            .putLong("$deviceKey.tail", cursor.tailDeviceSeconds)
            .putLong("$deviceKey.newest", cursor.newestDeviceSeconds)
            .putBoolean("$deviceKey.linked", cursor.linked)
            .apply()
    }
}
