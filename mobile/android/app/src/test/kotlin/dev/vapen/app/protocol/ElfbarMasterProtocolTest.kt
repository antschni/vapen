package dev.vapen.app.protocol

import dev.vapen.app.ble.BleConstants
import dev.vapen.app.ble.BleProfile
import dev.vapen.app.ble.GattSession
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.util.TimeZone
import java.util.UUID

class ElfbarMasterProtocolTest {
    private val profile = BleProfile(
        name = "innogate_cig",
        serviceUuid = BleConstants.CIG_SERVICE,
        txUuid = BleConstants.CIG_WRITE,
        rxUuid = BleConstants.CIG_NOTIFY,
    )
    private val berlin = TimeZone.getTimeZone("Europe/Berlin")
    private val now = Instant.parse("2026-10-04T18:00:00Z")

    /** Device seconds as the firmware stores them: local wall clock encoded as if it were UTC. */
    private fun deviceSeconds(local: String): Long = LocalDateTime.parse(local).toEpochSecond(ZoneOffset.UTC)

    private class Record(val seconds: Long, val durationMs: Int)

    private class FakeElfa(var linkResult: Int = 0) : GattSession {
        lateinit var protocol: ElfbarMasterProtocol
        val requests = mutableListOf<CigFrame>()
        val records = mutableListOf<Record>()
        var battery = 64
        var liquid = 35
        var today = 12

        override suspend fun read(service: UUID, characteristic: UUID): ByteArray? = null
        override suspend fun setNotify(service: UUID, characteristic: UUID, enabled: Boolean) {}
        override suspend fun requestMtu(mtu: Int): Int = 247

        override suspend fun write(service: UUID, characteristic: UUID, value: ByteArray, withResponse: Boolean) {
            val request = InnogateFrameCodec.decode(value)!!
            requests += request
            val payload = when (request.command) {
                BleConstants.CMD_FIRST_LINK_INFO -> byteArrayOf(linkResult.toByte())
                BleConstants.CMD_READ_ACTIVE_STATE -> byteArrayOf(1)
                BleConstants.CMD_READ_FIRMWARE_VERSION -> "V1.0.7".toByteArray()
                BleConstants.CMD_SET_TIME -> byteArrayOf(0)
                BleConstants.CMD_READ_SOC -> byteArrayOf(battery.toByte())
                BleConstants.CMD_READ_FUEL -> byteArrayOf(liquid.toByte())
                BleConstants.CMD_READ_LOCK_STATE -> byteArrayOf(0)
                BleConstants.CMD_READ_DAY_PUFF -> byteArrayOf(1, (today ushr 8).toByte(), today.toByte())
                BleConstants.CMD_READ_PUFF_RECORDS -> puffPage(request.payload)
                else -> return
            }
            val response = InnogateFrameCodec.encode(request.seq, request.command or 0x80, payload)
            protocol.onNotification(BleConstants.CIG_NOTIFY, response, 0)
        }

        private fun puffPage(request: ByteArray): ByteArray {
            val offset = ((request[0].toInt() and 0xFF) shl 8) or (request[1].toInt() and 0xFF)
            val count = ((request[2].toInt() and 0xFF) shl 8) or (request[3].toInt() and 0xFF)
            val page = records.drop(offset).take(count)
            val out = ByteArray(2 + page.size * 8)
            out[0] = (page.size ushr 8).toByte()
            out[1] = page.size.toByte()
            page.forEachIndexed { i, r ->
                val base = 2 + i * 8
                val tens = r.durationMs / 10
                out[base] = 120
                out[base + 1] = tens.toByte()
                out[base + 2] = (tens ushr 8).toByte()
                out[base + 3] = 8
                for (b in 0..3) out[base + 4 + b] = (r.seconds ushr (8 * b)).toByte()
            }
            return out
        }
    }

    private fun setup(device: FakeElfa = FakeElfa(), store: HistoryCursorStore = InMemoryHistoryCursorStore()) =
        ElfbarMasterProtocol(
            identity = { ClientIdentity("Pixel von Anton", "a1b2c3d4e5f60718") },
            cursorStore = store,
            clock = { now.toEpochMilli() },
            timeZone = { berlin },
        ).also {
            device.protocol = it
            it.bindDevice("AA:BB:CC:DD:EE:FF")
        }

    @Test
    fun initialize_runsInnoGateHandshakeInOrder() = runTest {
        val device = FakeElfa()
        val protocol = setup(device)

        val messages = protocol.initialize(device, profile)

        assertEquals(
            listOf(
                BleConstants.CMD_FIRST_LINK_INFO,
                BleConstants.CMD_READ_ACTIVE_STATE,
                BleConstants.CMD_READ_FIRMWARE_VERSION,
                BleConstants.CMD_SET_TIME,
            ),
            device.requests.map { it.command },
        )
        assertTrue(messages.isEmpty())

        val link = device.requests[0].payload
        assertEquals(BleConstants.IDENTIFIER_TYPE_ANDROID, link[0].toInt())
        val nameLen = link[1].toInt()
        assertEquals("Pixel von Anton", String(link, 2, nameLen, Charsets.UTF_8))
        val idLen = link[2 + nameLen].toInt()
        assertEquals("a1b2c3d4e5f60718", String(link, 3 + nameLen, idLen, Charsets.UTF_8))

        assertEquals("20261004200000", String(device.requests[3].payload, Charsets.US_ASCII))
        assertEquals(device.requests.indices.map { it and 0x0F }, device.requests.map { it.seq })
    }

    @Test
    fun initialize_failsWhenDeviceRejectsLink() = runTest {
        val device = FakeElfa(linkResult = 1)
        val protocol = setup(device)
        try {
            protocol.initialize(device, profile)
            fail("expected ProtocolException")
        } catch (e: ProtocolException) {
            assertTrue(e.message!!.contains("abgelehnt"))
        }
    }

    @Test
    fun requestStatus_readsBatteryLiquidAndTodayCount() = runTest {
        val device = FakeElfa()
        val protocol = setup(device)
        protocol.initialize(device, profile)

        val messages = protocol.requestStatus(device, profile)

        val status = messages.filterIsInstance<DeviceMessage.Status>().single()
        assertEquals(64, status.battery)
        assertEquals(35, status.liquid)
        assertEquals(false, status.childLock)
        assertEquals("V1.0.7", status.firmware)
        assertEquals(12, messages.filterIsInstance<DeviceMessage.DailyPuffCount>().single().today)
    }

    @Test
    fun syncHistory_pagesThroughRecordsAndResumesFromCursor() = runTest {
        val device = FakeElfa()
        val store = InMemoryHistoryCursorStore()
        val protocol = setup(device, store)
        val base = deviceSeconds("2026-10-04T08:00:00")
        repeat(13) { device.records += Record(base + it * 600L, 1500 + it * 10) }

        val first = protocol.syncHistory(device, profile)

        assertEquals(13, first.size)
        val firstPuff = first.first() as DeviceMessage.HistoryPuff
        assertEquals(Instant.parse("2026-10-04T06:00:00Z"), firstPuff.startedAt)
        assertEquals(1500, firstPuff.durationMs)
        assertEquals(base, firstPuff.deviceIndex)
        assertEquals(13, store.load("AA:BB:CC:DD:EE:FF").nextOffset)

        val second = protocol.syncHistory(device, profile)
        assertTrue(second.isEmpty())

        device.records += Record(deviceSeconds("2026-10-04T19:58:00"), 2340)
        val third = protocol.syncHistory(device, profile)
        val live = third.single() as DeviceMessage.PuffCompleted
        assertEquals(Instant.parse("2026-10-04T17:58:00Z"), live.startedAt)
        assertEquals(2340, live.durationMs)
    }

    @Test
    fun syncHistory_rescansWhenDeviceListWasCleared() = runTest {
        val device = FakeElfa()
        val protocol = setup(device)
        val base = deviceSeconds("2026-10-04T08:00:00")
        repeat(5) { device.records += Record(base + it * 60L, 1200) }
        assertEquals(5, protocol.syncHistory(device, profile).size)

        device.records.clear()
        device.records += Record(base + 3_600, 1800)
        device.records += Record(base + 3_660, 1900)

        val after = protocol.syncHistory(device, profile)
        assertEquals(listOf(1800, 1900), after.map { (it as DeviceMessage.HistoryPuff).durationMs })
    }

    @Test
    fun syncHistory_doesNotReemitAfterRescanOfUnchangedNewestFirstList() = runTest {
        val device = FakeElfa()
        val protocol = setup(device)
        val base = deviceSeconds("2026-10-04T08:00:00")
        repeat(25) { device.records += Record(base + (25 - it) * 60L, 1300) }
        assertEquals(25, protocol.syncHistory(device, profile).size)

        device.records.add(0, Record(base + 26 * 60L, 2100))
        val after = protocol.syncHistory(device, profile)
        assertEquals(listOf(2100), after.map { (it as DeviceMessage.HistoryPuff).durationMs })
    }

    @Test
    fun pushes_areDecoded() {
        val protocol = setup()
        fun push(command: Int, vararg payload: Int) = protocol.onNotification(
            BleConstants.CIG_NOTIFY,
            InnogateFrameCodec.encode(0, command, payload.map { it.toByte() }.toByteArray()),
            now.toEpochMilli(),
        )

        val detected = push(0x96, 23).single() as DeviceMessage.PuffDetected
        assertEquals(2300, detected.durationMs)
        assertEquals(81, (push(0x92, 81).single() as DeviceMessage.Status).battery)
        assertEquals(40, (push(0xC1, 1, 0, 40).single() as DeviceMessage.DailyPuffCount).today)
        assertEquals(2, (push(0x9E, 2).single() as DeviceMessage.DeviceAlert).code)
        assertTrue(push(0x93, 255).isEmpty())
        assertTrue(push(0x96, 0).isEmpty())
    }

    @Test
    fun notificationsOnOtherCharacteristicsAreIgnored() {
        val protocol = setup()
        val frame = InnogateFrameCodec.encode(0, 0x92, byteArrayOf(50))
        assertTrue(protocol.onNotification(BleConstants.OTA_NOTIFY, frame, 0).isEmpty())
    }
}
