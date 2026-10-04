package dev.vapen.app.protocol

import dev.vapen.app.ble.BleProfile
import dev.vapen.app.ble.GattSession
import java.util.UUID

data class Advertisement(
    val name: String?,
    val address: String,
    val rssi: Int,
    val manufacturerHex: String?,
    val serviceUuids: List<UUID>,
)

data class DeviceInfo(val serialNumber: String?, val bleMac: String)

interface VapeProtocol {
    val model: String
    fun matches(advertisement: Advertisement): Boolean

    /** Selects per-device persisted state (history cursor, link flag). */
    fun bindDevice(deviceKey: String) {}

    /** Subscribes, runs the vendor handshake and returns initial messages. Throws [ProtocolException]. */
    suspend fun initialize(session: GattSession, profile: BleProfile): List<DeviceMessage>

    /** Must be called for every notification, synchronously and in arrival order. */
    fun onNotification(characteristic: UUID, value: ByteArray, receivedAtMillis: Long): List<DeviceMessage>

    suspend fun requestStatus(session: GattSession, profile: BleProfile): List<DeviceMessage>

    /** Fetches puff records not yet seen. */
    suspend fun syncHistory(session: GattSession, profile: BleProfile): List<DeviceMessage>

    fun hardwareId(info: DeviceInfo): String
}
