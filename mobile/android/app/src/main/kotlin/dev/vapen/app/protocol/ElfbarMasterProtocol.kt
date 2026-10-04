package dev.vapen.app.protocol

import dev.vapen.app.ble.BleConstants
import dev.vapen.app.ble.BleProfile
import dev.vapen.app.ble.GattSession
import kotlinx.coroutines.delay
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID

class ElfbarMasterProtocol : VapeProtocol {
    override val model: String = "elfbar_master"

    override fun matches(advertisement: Advertisement): Boolean {
        val name = advertisement.name?.lowercase() ?: return false
        return BleConstants.NAME_HINTS.any { name.contains(it) }
    }

    override suspend fun initialize(session: GattSession, profile: BleProfile) {
        session.requestMtu(247)
        // InnoGate-style session arm (observed on fff4 on similar fff0 gadgets).
        profile.armPairUuid?.let { arm ->
            runCatching {
                session.write(
                    profile.serviceUuid,
                    arm,
                    byteArrayOf(0x01, 0x00),
                    withResponse = true,
                )
            }
            delay(250)
        }
        // Framed handshake + enable telemetry stream (lab capture: notify on fff2, 0xAA frames).
        session.write(
            profile.serviceUuid,
            profile.txUuid,
            InnogateFrameCodec.encode(BleConstants.CMD_HANDSHAKE_1, byteArrayOf(0x01)),
            withResponse = false,
        )
        delay(150)
        session.write(
            profile.serviceUuid,
            profile.txUuid,
            InnogateFrameCodec.encode(BleConstants.CMD_HANDSHAKE_2, byteArrayOf(0x00)),
            withResponse = false,
        )
        delay(150)
    }

    override fun decode(characteristic: UUID, value: ByteArray, receivedAtMillis: Long): List<DeviceMessage> {
        if (value.isEmpty()) return emptyList()
        val (frames, _) = InnogateFrameCodec.decodeFrames(value)
        if (frames.isEmpty()) {
            return listOf(DeviceMessage.Unknown(characteristic, value))
        }
        val at = Instant.ofEpochMilli(receivedAtMillis)
        return frames.mapNotNull { frame -> mapFrame(frame, at, value) }
    }

    private fun mapFrame(frame: DecodedFrame, at: Instant, raw: ByteArray): DeviceMessage? {
        return when (frame.opcode) {
            BleConstants.OPC_PUFF_STARTED -> DeviceMessage.PuffStarted(at)
            BleConstants.OPC_PUFF_DONE -> parsePuffDone(frame.payload, at, raw)
            BleConstants.OPC_HISTORY_PUFF -> {
                parsePuffDone(frame.payload, at, raw)?.let { puff ->
                    DeviceMessage.HistoryPuff(puff.startedAt, puff.durationMs, puff.deviceIndex, puff.raw)
                }
            }
            BleConstants.OPC_STATUS -> parseStatus(frame.payload, at)
            else -> null
        }
    }

    private fun parsePuffDone(payload: ByteArray, at: Instant, raw: ByteArray): DeviceMessage.PuffCompleted? {
        if (payload.size < 6) return null
        val buf = ByteBuffer.wrap(payload).order(ByteOrder.LITTLE_ENDIAN)
        val index = buf.int.toLong()
        val duration = buf.short.toInt() and 0xFFFF
        if (duration !in 1..60_000) return null
        return DeviceMessage.PuffCompleted(
            startedAt = at.minusMillis(duration.toLong()),
            durationMs = duration,
            deviceIndex = index,
            raw = raw,
        )
    }

    private fun parseStatus(payload: ByteArray, at: Instant): DeviceMessage.Status? {
        if (payload.size < 2) return null
        val battery = payload[0].toInt() and 0xFF
        val liquid = payload[1].toInt() and 0xFF
        val flags = payload.getOrNull(2)?.toInt()?.and(0xFF) ?: 0
        val counter = if (payload.size >= 7) {
            ByteBuffer.wrap(payload, 3, 4).order(ByteOrder.LITTLE_ENDIAN).int.toLong()
        } else null
        return DeviceMessage.Status(
            battery = battery.coerceIn(0, 100),
            charging = (flags and 0x01) != 0,
            liquid = liquid.coerceIn(0, 100),
            counterTotal = counter,
            powerMode = when (payload.getOrNull(7)?.toInt()) {
                1 -> "eco"
                2 -> "normal"
                3 -> "boost"
                else -> "normal"
            },
            childLock = (flags and 0x02) != 0,
            firmware = null,
            recordedAt = at,
        )
    }

    override suspend fun requestStatus(session: GattSession, profile: BleProfile) {
        val frame = InnogateFrameCodec.encode(BleConstants.CMD_REQUEST_STATUS)
        session.write(profile.serviceUuid, profile.txUuid, frame, withResponse = false)
    }

    override suspend fun requestHistory(session: GattSession, profile: BleProfile, sinceDeviceIndex: Long?) {
        val payload = ByteArray(4)
        ByteBuffer.wrap(payload).order(ByteOrder.LITTLE_ENDIAN).putInt((sinceDeviceIndex ?: 0L).toInt())
        val frame = InnogateFrameCodec.encode(BleConstants.CMD_REQUEST_HISTORY, payload)
        session.write(profile.serviceUuid, profile.txUuid, frame, withResponse = false)
    }

    override fun hardwareId(info: DeviceInfo): String {
        val source = info.serialNumber?.lowercase() ?: info.bleMac.lowercase()
        val digest = MessageDigest.getInstance("SHA-256").digest(source.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }
}
