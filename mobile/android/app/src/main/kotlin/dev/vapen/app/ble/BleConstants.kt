package dev.vapen.app.ble

import java.util.UUID

object BleConstants {
    val NUS_SERVICE: UUID = UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    val NUS_TX: UUID = UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    val NUS_RX: UUID = UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e")

    val VENDOR_FFF0: UUID = UUID.fromString("0000fff0-0000-1000-8000-00805f9b34fb")
    val VENDOR_FFF1: UUID = UUID.fromString("0000fff1-0000-1000-8000-00805f9b34fb")
    val VENDOR_FFF2: UUID = UUID.fromString("0000fff2-0000-1000-8000-00805f9b34fb")
    val VENDOR_FFF3: UUID = UUID.fromString("0000fff3-0000-1000-8000-00805f9b34fb")
    val VENDOR_FFF4: UUID = UUID.fromString("0000fff4-0000-1000-8000-00805f9b34fb")
    val VENDOR_FFF5: UUID = UUID.fromString("0000fff5-0000-1000-8000-00805f9b34fb")

    const val FRAME_MAGIC: Int = 0xAA
    const val OPC_STATUS: Int = 0x01
    const val OPC_PUFF_STARTED: Int = 0x02
    const val OPC_PUFF_DONE: Int = 0x03
    const val OPC_HISTORY_PUFF: Int = 0x04
    const val CMD_HANDSHAKE_1: Int = 0x10
    const val CMD_HANDSHAKE_2: Int = 0x11
    const val CMD_REQUEST_STATUS: Int = 0x20
    const val CMD_REQUEST_HISTORY: Int = 0x21

    val NAME_HINTS = listOf("elfa", "master", "elfbar", "innogate")
}
