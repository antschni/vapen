package dev.vapen.app.ble

import java.util.UUID

/** ELFA MASTER / InnoGate GATT layout and command codes — see docs/elfbar-protocol.md. */
object BleConstants {
    val CIG_SERVICE: UUID = UUID.fromString("00010203-0405-0607-0809-0a0b0c0dff00")
    val CIG_WRITE: UUID = UUID.fromString("00010203-0405-0607-0809-0a0b0c0dff01")
    val CIG_NOTIFY: UUID = UUID.fromString("00010203-0405-0607-0809-0a0b0c0dff02")

    /** Firmware/theme update channel. Vapen never writes to it. */
    val OTA_SERVICE: UUID = UUID.fromString("00010203-0405-0607-0809-0a0b0c0da100")
    val OTA_NOTIFY: UUID = UUID.fromString("00010203-0405-0607-0809-0a0b0c0da102")

    const val MTU_REQUEST = 517

    const val CMD_READ_IDENTIFIER = 0x05
    const val CMD_READ_FIRMWARE_VERSION = 0x06
    const val CMD_SET_TIME = 0x07
    const val CMD_READ_ACTIVE_STATE = 0x0A
    const val CMD_READ_LOCK_STATE = 0x0B
    const val CMD_READ_SOC = 0x12
    const val CMD_READ_FUEL = 0x13
    const val CMD_READ_SUCTION_TIME = 0x16
    const val CMD_FIRST_LINK_INFO = 0x2A
    const val CMD_READ_PUFF_RECORDS = 0x33
    const val CMD_READ_DAY_PUFF = 0x41

    /** Unsolicited device alert (low battery, low liquid, overheat, …). */
    const val PUSH_DEVICE_REPORT = 0x9E

    const val RESPONSE_FLAG = 0x80

    const val IDENTIFIER_TYPE_ANDROID = 0x02

    val NAME_HINTS = listOf("elfa", "master", "elfbar", "innogate")
}
