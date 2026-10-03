package dev.vapen.app.protocol

import dev.vapen.app.ble.BleConstants

/**
 * Hypothesized InnoGate / ELFA framing — see docs/elfbar-protocol.md.
 * Pure Kotlin for unit tests.
 */
object InnogateFrameCodec {
    fun encode(opcode: Int, payload: ByteArray = byteArrayOf()): ByteArray {
        val len = 1 + payload.size
        val body = ByteArray(2 + len)
        body[0] = BleConstants.FRAME_MAGIC.toByte()
        body[1] = len.toByte()
        body[2] = opcode.toByte()
        payload.copyInto(body, 3)
        val checksum = body.drop(1).sumOf { it.toInt() and 0xFF } and 0xFF
        return body + checksum.toByte()
    }

    fun decodeFrames(buffer: ByteArray): Pair<List<DecodedFrame>, ByteArray> {
        val frames = mutableListOf<DecodedFrame>()
        var i = 0
        while (i < buffer.size) {
            if (buffer[i].toInt() and 0xFF != BleConstants.FRAME_MAGIC) {
                i++
                continue
            }
            if (i + 3 > buffer.size) break
            val len = buffer[i + 1].toInt() and 0xFF
            val total = 2 + len + 1
            if (i + total > buffer.size) break
            val opcode = buffer[i + 2].toInt() and 0xFF
            val payload = buffer.copyOfRange(i + 3, i + 2 + len)
            val checksum = buffer[i + 2 + len].toInt() and 0xFF
            val expected = buffer.copyOfRange(i + 1, i + 2 + len).sumOf { it.toInt() and 0xFF } and 0xFF
            if (checksum == expected) {
                frames.add(DecodedFrame(opcode, payload))
            }
            i += total
        }
        val remainder = if (i < buffer.size) buffer.copyOfRange(i, buffer.size) else byteArrayOf()
        return frames to remainder
    }
}

data class DecodedFrame(val opcode: Int, val payload: ByteArray)
