package dev.vapen.app.protocol

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class InnogateFrameCodecTest {
    @Test
    fun encode_withoutPayload_matchesInnoGateLayout() {
        val frame = InnogateFrameCodec.encode(seq = 3, command = 0x05)
        assertArrayEquals(byteArrayOf(0x03, 0x05, 0x00, 0x00), frame)
    }

    @Test
    fun encode_lengthIsBigEndianAndSeqIsMasked() {
        val payload = ByteArray(0x0102) { it.toByte() }
        val frame = InnogateFrameCodec.encode(seq = 0x1F, command = 0x33, payload = payload)
        assertEquals(0x0F, frame[0].toInt())
        assertEquals(0x33, frame[1].toInt())
        assertEquals(0x01, frame[2].toInt())
        assertEquals(0x02, frame[3].toInt())
        assertEquals(4 + payload.size, frame.size)
    }

    @Test
    fun decode_roundTrip() {
        val encoded = InnogateFrameCodec.encode(seq = 7, command = 0x92, payload = byteArrayOf(76))
        val frame = InnogateFrameCodec.decode(encoded)!!
        assertEquals(7, frame.seq)
        assertEquals(0x92, frame.command)
        assertTrue(frame.isResponse)
        assertFalse(frame.encrypted)
        assertEquals(76, frame.u8(0))
    }

    @Test
    fun decode_rejectsTruncatedFrames() {
        assertNull(InnogateFrameCodec.decode(bytes(0x00, 0x92, 0x00)))
        assertNull(InnogateFrameCodec.decode(bytes(0x00, 0x92, 0x00, 0x02, 0x01)))
    }

    @Test
    fun decode_ignoresTrailingBytes() {
        val frame = InnogateFrameCodec.decode(bytes(0x00, 0x92, 0x00, 0x01, 0x50, 0x7F))!!
        assertArrayEquals(bytes(0x50), frame.payload)
    }

    private fun bytes(vararg values: Int) = ByteArray(values.size) { values[it].toByte() }
}
