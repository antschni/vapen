package dev.vapen.app.protocol

import dev.vapen.app.ble.BleConstants
import dev.vapen.app.ble.GattSession
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

    override suspend fun initialize(session: GattSession) {
        session.requestMtu(247)
        // Hypothesized handshake — no-op if device ignores.
        session.write(
            BleConstants.VENDOR_FFF0,
            BleConstants.VENDOR_FFF1,
            InnogateFrameCodec.encode(BleConstants.CMD_HANDSHAKE_1, byteArrayOf(0x01)),
            withResponse = false,
        )
    }

    override fun decode(characteristic: UUID, value: ByteArray, receivedAtMillis: Long): List<DeviceMessage> {
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
            BleConstants.OPC_STATUS -> parseStatus(frame.payload, at)
            else -> DeviceMessage.Unknown(UUID.randomUUID(), raw)
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
        if (payload.size < 4) return null
        val battery = payload[0].toInt() and 0xFF
        val liquid = payload[1].toInt() and 0xFF
        val flags = payload[2].toInt() and 0xFF
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

    override suspend fun requestStatus(session: GattSession) {
        val frame = InnogateFrameCodec.encode(BleConstants.CMD_REQUEST_STATUS)
        writeOnAnyProfile(session, frame)
    }

    override suspend fun requestHistory(session: GattSession, sinceDeviceIndex: Long?) {
        val payload = ByteArray(4)
        ByteBuffer.wrap(payload).order(ByteOrder.LITTLE_ENDIAN).putInt((sinceDeviceIndex ?: 0L).toInt())
        val frame = InnogateFrameCodec.encode(BleConstants.CMD_REQUEST_HISTORY, payload)
        writeOnAnyProfile(session, frame)
    }

    private suspend fun writeOnAnyProfile(session: GattSession, frame: ByteArray) {
        session.write(BleConstants.NUS_SERVICE, BleConstants.NUS_TX, frame, false)
        session.write(BleConstants.VENDOR_FFF0, BleConstants.VENDOR_FFF1, frame, false)
    }

    override fun hardwareId(info: DeviceInfo): String {
        val source = info.serialNumber?.lowercase() ?: info.bleMac.lowercase()
        val digest = MessageDigest.getInstance("SHA-256").digest(source.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }
}
