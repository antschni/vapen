package dev.vapen.app.protocol

import dev.vapen.app.ble.BleConstants
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder

class InnogateFrameCodecTest {
    @Test
    fun roundTrip_puffDone() {
        val payload = ByteBuffer.allocate(6).order(ByteOrder.LITTLE_ENDIAN).apply {
            putInt(42)
            putShort(2350)
        }.array()
        val frame = InnogateFrameCodec.encode(BleConstants.OPC_PUFF_DONE, payload)
        val (frames, _) = InnogateFrameCodec.decodeFrames(frame)
        assertEquals(1, frames.size)
        assertEquals(BleConstants.OPC_PUFF_DONE, frames[0].opcode)
    }

    @Test
    fun decode_labCapture_puffNotify() {
        val hex = "aa07032a000000260963"
        val bytes = hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        val protocol = ElfbarMasterProtocol()
        val messages = protocol.decode(java.util.UUID.randomUUID(), bytes, System.currentTimeMillis())
        assertTrue(messages.any { it is dev.vapen.app.protocol.DeviceMessage.PuffCompleted })
    }

    @Test
    fun decoder_fixture_status() {
        val payload = byteArrayOf(76, 40, 0x00, 0x00, 0x00, 0x00, 0x2A)
        val bytes = InnogateFrameCodec.encode(BleConstants.OPC_STATUS, payload)
        val protocol = ElfbarMasterProtocol()
        val messages = protocol.decode(java.util.UUID.randomUUID(), bytes, System.currentTimeMillis())
        assertTrue(messages.any { it is dev.vapen.app.protocol.DeviceMessage.Status })
    }
}
