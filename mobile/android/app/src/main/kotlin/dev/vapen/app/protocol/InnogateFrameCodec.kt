package dev.vapen.app.protocol

import dev.vapen.app.ble.BleConstants

/**
 * InnoGate "CIG" framing (ELFA MASTER):
 *
 * ```
 * [header][command][length u16 BE][payload…]
 * header = version << 6 | encrypted << 4 | seq & 0x0F   (version 0, never encrypted here)
 * ```
 *
 * Responses echo the sequence nibble and set bit 7 of the command (`command | 0x80`).
 * Pure Kotlin for unit tests.
 */
object InnogateFrameCodec {
    const val HEADER_SIZE = 4

    fun encode(seq: Int, command: Int, payload: ByteArray = byteArrayOf()): ByteArray {
        require(payload.size <= 0xFFFF) { "payload too large" }
        val out = ByteArray(HEADER_SIZE + payload.size)
        out[0] = (seq and 0x0F).toByte()
        out[1] = command.toByte()
        out[2] = (payload.size ushr 8).toByte()
        out[3] = payload.size.toByte()
        payload.copyInto(out, HEADER_SIZE)
        return out
    }

    fun decode(value: ByteArray): CigFrame? {
        if (value.size < HEADER_SIZE) return null
        val header = value[0].toInt() and 0xFF
        val command = value[1].toInt() and 0xFF
        val declared = ((value[2].toInt() and 0xFF) shl 8) or (value[3].toInt() and 0xFF)
        val available = value.size - HEADER_SIZE
        if (declared > available) return null
        val payload = value.copyOfRange(HEADER_SIZE, HEADER_SIZE + declared)
        return CigFrame(header, command, payload)
    }
}

class CigFrame(val header: Int, val command: Int, val payload: ByteArray) {
    val seq: Int get() = header and 0x0F
    val encrypted: Boolean get() = header and 0x10 != 0
    val isResponse: Boolean get() = command and BleConstants.RESPONSE_FLAG != 0

    fun u8(index: Int): Int? = payload.getOrNull(index)?.toInt()?.and(0xFF)
}
