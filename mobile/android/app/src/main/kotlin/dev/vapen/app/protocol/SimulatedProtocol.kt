package dev.vapen.app.protocol

import dev.vapen.app.ble.BleProfile
import dev.vapen.app.ble.GattSession
import kotlinx.coroutines.delay
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID
import kotlin.random.Random

class SimulatedProtocol : VapeProtocol {
    override val model: String = "elfbar_master"

    private var puffIndex = 0L
    private var battery = 78
    private var liquid = 42

    override fun matches(advertisement: Advertisement): Boolean = true

    override suspend fun initialize(session: GattSession, profile: BleProfile): List<DeviceMessage> {
        delay(300)
        return emptyList()
    }

    override fun onNotification(characteristic: UUID, value: ByteArray, receivedAtMillis: Long): List<DeviceMessage> =
        emptyList()

    override suspend fun requestStatus(session: GattSession, profile: BleProfile): List<DeviceMessage> = emptyList()

    override suspend fun syncHistory(session: GattSession, profile: BleProfile): List<DeviceMessage> = emptyList()

    fun nextSimulatedPuff(): DeviceMessage.PuffCompleted {
        puffIndex++
        val duration = Random.nextInt(1200, 4500)
        val started = Instant.now().minusMillis(duration.toLong())
        return DeviceMessage.PuffCompleted(
            startedAt = started,
            durationMs = duration,
            deviceIndex = started.epochSecond,
            raw = byteArrayOf(0xA5.toByte(), duration.toByte()),
        )
    }

    fun nextSimulatedStatus(): DeviceMessage.Status {
        battery = (battery - Random.nextInt(0, 2)).coerceIn(10, 100)
        liquid = (liquid - Random.nextInt(0, 1)).coerceIn(5, 100)
        return DeviceMessage.Status(
            battery = battery,
            charging = false,
            liquid = liquid,
            counterTotal = puffIndex,
            powerMode = "normal",
            childLock = false,
            firmware = "sim-1.0.0",
            recordedAt = Instant.now(),
        )
    }

    override fun hardwareId(info: DeviceInfo): String {
        val source = "simulated-${info.bleMac.lowercase()}"
        val digest = MessageDigest.getInstance("SHA-256").digest(source.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }
}
