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
    suspend fun initialize(session: GattSession, profile: BleProfile)
    fun decode(characteristic: UUID, value: ByteArray, receivedAtMillis: Long): List<DeviceMessage>
    suspend fun requestStatus(session: GattSession, profile: BleProfile)
    suspend fun requestHistory(session: GattSession, profile: BleProfile, sinceDeviceIndex: Long?)
    fun hardwareId(info: DeviceInfo): String
}
