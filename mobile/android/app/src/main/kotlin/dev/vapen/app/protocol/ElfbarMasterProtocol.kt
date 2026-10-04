package dev.vapen.app.protocol

import dev.vapen.app.ble.BleConstants
import dev.vapen.app.ble.BleProfile
import dev.vapen.app.ble.GattSession
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import java.security.MessageDigest
import java.time.Instant
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.TimeZone
import java.util.UUID

/** Phone identity sent with FIRST_LINK_INFO; the device remembers it to skip re-confirmation. */
data class ClientIdentity(val name: String, val id: String)

/**
 * ELFA MASTER over the InnoGate "CIG" channel. Protocol reference: docs/elfbar-protocol.md.
 *
 * One request is in flight at a time; the response is the notification whose command is
 * `request | 0x80`. Every other notification is an unsolicited push.
 */
class ElfbarMasterProtocol(
    private val identity: () -> ClientIdentity = { ClientIdentity("Vapen", "vapen") },
    private val cursorStore: HistoryCursorStore = InMemoryHistoryCursorStore(),
    private val clock: () -> Long = System::currentTimeMillis,
    private val timeZone: () -> TimeZone = TimeZone::getDefault,
) : VapeProtocol {
    override val model: String = "elfbar_master"

    private class Pending(val responseCommand: Int, val deferred: CompletableDeferred<CigFrame>)

    private val requestMutex = Mutex()
    private val syncMutex = Mutex()
    private var seq = 0

    @Volatile
    private var pending: Pending? = null

    @Volatile
    private var deviceKey = "default"
    private var mtu = DEFAULT_MTU

    @Volatile private var battery: Int? = null
    @Volatile private var liquid: Int? = null
    @Volatile private var childLock: Boolean? = null
    @Volatile private var firmware: String? = null

    override fun matches(advertisement: Advertisement): Boolean {
        val name = advertisement.name?.lowercase() ?: return false
        return BleConstants.NAME_HINTS.any { name.contains(it) }
    }

    override fun bindDevice(deviceKey: String) {
        if (deviceKey != this.deviceKey) {
            battery = null
            liquid = null
            childLock = null
            firmware = null
        }
        this.deviceKey = deviceKey
    }

    override suspend fun initialize(session: GattSession, profile: BleProfile): List<DeviceMessage> {
        mtu = runCatching { session.requestMtu(BleConstants.MTU_REQUEST) }.getOrDefault(DEFAULT_MTU)
        session.setNotify(profile.serviceUuid, profile.rxUuid, true)
        profile.otaNotify?.let { (service, characteristic) ->
            runCatching { session.setNotify(service, characteristic, true) }
        }

        val cursor = cursorStore.load(deviceKey)
        val link = transact(
            session,
            profile,
            BleConstants.CMD_FIRST_LINK_INFO,
            firstLinkPayload(identity()),
            timeoutMs = if (cursor.linked) RECONNECT_LINK_TIMEOUT_MS else FIRST_LINK_TIMEOUT_MS,
        )
        val linkResult = link.u8(0)
        if (linkResult != 0) {
            throw ProtocolException(
                "Elfbar hat die Verbindung abgelehnt (Code ${linkResult ?: "-"}). " +
                    "InnoGate schließen und Kopplung am Gerät bestätigen.",
            )
        }
        if (!cursor.linked) cursorStore.save(deviceKey, cursor.copy(linked = true))

        val messages = mutableListOf<DeviceMessage>()
        val active = transactOrNull(session, profile, BleConstants.CMD_READ_ACTIVE_STATE)?.u8(0)
        if (active == 0) {
            messages += DeviceMessage.Warning("Elfbar ist nicht aktiviert — einmalig in der InnoGate-App aktivieren.")
        }
        transactOrNull(session, profile, BleConstants.CMD_READ_FIRMWARE_VERSION)?.let { frame ->
            firmware = frame.payload.toString(Charsets.US_ASCII).trim { it <= ' ' }.ifEmpty { null }
        }
        val timeSet = transactOrNull(
            session,
            profile,
            BleConstants.CMD_SET_TIME,
            deviceClockString().toByteArray(Charsets.US_ASCII),
        )?.u8(0) == 0
        if (!timeSet) {
            messages += DeviceMessage.Warning("Uhrzeit der Elfbar konnte nicht gesetzt werden — Zeitstempel evtl. ungenau.")
        }
        return messages
    }

    override fun onNotification(characteristic: UUID, value: ByteArray, receivedAtMillis: Long): List<DeviceMessage> {
        if (characteristic != BleConstants.CIG_NOTIFY) return emptyList()
        val frame = InnogateFrameCodec.decode(value) ?: return listOf(DeviceMessage.Unknown(characteristic, value))
        val waiting = pending
        if (waiting != null && frame.command == waiting.responseCommand && waiting.deferred.complete(frame)) {
            return emptyList()
        }
        return decodePush(frame, Instant.ofEpochMilli(receivedAtMillis), characteristic, value)
    }

    override suspend fun requestStatus(session: GattSession, profile: BleProfile): List<DeviceMessage> {
        transactOrNull(session, profile, BleConstants.CMD_READ_SOC, byteArrayOf(UNIT_PERCENT))
            ?.u8(0)?.takeIf { it in 0..100 }?.let { battery = it }
        transactOrNull(session, profile, BleConstants.CMD_READ_FUEL, byteArrayOf(UNIT_PERCENT))
            ?.u8(0)?.takeIf { it in 0..100 }?.let { liquid = it }
        transactOrNull(session, profile, BleConstants.CMD_READ_LOCK_STATE)
            ?.u8(0)?.let { childLock = it == 1 }
        val now = Instant.ofEpochMilli(clock())
        val today = transactOrNull(session, profile, BleConstants.CMD_READ_DAY_PUFF, byteArrayOf(1))
            ?.let { parseTodayPuffs(it.payload) }
        return listOfNotNull(statusSnapshot(now), today?.let { DeviceMessage.DailyPuffCount(it, now) })
    }

    override suspend fun syncHistory(session: GattSession, profile: BleProfile): List<DeviceMessage> = syncMutex.withLock {
        val key = deviceKey
        val cursor = cursorStore.load(key)
        val pageSize = ((mtu - ATT_OVERHEAD - InnogateFrameCodec.HEADER_SIZE - 2) / PUFF_RECORD_SIZE)
            .coerceIn(1, MAX_PAGE_SIZE)

        var offset = cursor.nextOffset
        var rescan = false
        if (offset > 0) {
            val probe = readPuffPage(session, profile, offset - 1, 1) ?: return@withLock emptyList()
            if (probe.records.firstOrNull()?.deviceSeconds != cursor.tailDeviceSeconds) {
                offset = 0
                rescan = true
            }
        }

        val nowMs = clock()
        val out = mutableListOf<DeviceMessage>()
        var tail = cursor.tailDeviceSeconds
        var newest = cursor.newestDeviceSeconds
        var pages = 0
        while (pages < MAX_PAGES) {
            val page = readPuffPage(session, profile, offset, pageSize) ?: break
            pages++
            if (page.records.isEmpty()) break
            var newInPage = 0
            for (record in page.records) {
                if (!rescan || record.deviceSeconds > cursor.newestDeviceSeconds) {
                    toMessage(record, nowMs)?.let {
                        out += it
                        newInPage++
                    }
                }
                newest = maxOf(newest, record.deviceSeconds)
            }
            offset += page.records.size
            tail = page.records.last().deviceSeconds
            if (page.claimed < pageSize || page.records.size < page.claimed) break
            val newestFirst = page.records.first().deviceSeconds > page.records.last().deviceSeconds
            if (rescan && newestFirst && newInPage == 0) break
        }
        cursorStore.save(key, cursor.copy(nextOffset = offset, tailDeviceSeconds = tail, newestDeviceSeconds = newest))
        out
    }

    override fun hardwareId(info: DeviceInfo): String {
        val source = info.serialNumber?.lowercase() ?: info.bleMac.lowercase()
        val digest = MessageDigest.getInstance("SHA-256").digest(source.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }

    private suspend fun transact(
        session: GattSession,
        profile: BleProfile,
        command: Int,
        payload: ByteArray = byteArrayOf(),
        timeoutMs: Long = DEFAULT_TIMEOUT_MS,
    ): CigFrame = requestMutex.withLock {
        val frameSeq = seq
        seq = (seq + 1) and 0x0F
        val waiting = Pending(command or BleConstants.RESPONSE_FLAG, CompletableDeferred())
        pending = waiting
        try {
            session.write(
                profile.serviceUuid,
                profile.txUuid,
                InnogateFrameCodec.encode(frameSeq, command, payload),
                withResponse = true,
            )
            withTimeoutOrNull(timeoutMs) { waiting.deferred.await() }
                ?: throw ProtocolException("Keine Antwort der Elfbar auf Befehl 0x%02X".format(command))
        } finally {
            pending = null
        }
    }

    private suspend fun transactOrNull(
        session: GattSession,
        profile: BleProfile,
        command: Int,
        payload: ByteArray = byteArrayOf(),
    ): CigFrame? = try {
        transact(session, profile, command, payload)
    } catch (e: ProtocolException) {
        null
    } catch (e: java.io.IOException) {
        null
    }

    private suspend fun readPuffPage(session: GattSession, profile: BleProfile, offset: Int, count: Int): PuffPage? {
        val request = byteArrayOf(
            (offset ushr 8).toByte(),
            offset.toByte(),
            (count ushr 8).toByte(),
            count.toByte(),
        )
        val frame = transactOrNull(session, profile, BleConstants.CMD_READ_PUFF_RECORDS, request) ?: return null
        return parsePuffPage(frame.payload)
    }

    private fun decodePush(frame: CigFrame, at: Instant, characteristic: UUID, raw: ByteArray): List<DeviceMessage> {
        return when (frame.command) {
            BleConstants.CMD_READ_SOC or BleConstants.RESPONSE_FLAG -> {
                frame.u8(0)?.takeIf { it in 0..100 }?.let { battery = it } ?: return emptyList()
                listOf(statusSnapshot(at))
            }
            BleConstants.CMD_READ_FUEL or BleConstants.RESPONSE_FLAG -> {
                frame.u8(0)?.takeIf { it in 0..100 }?.let { liquid = it } ?: return emptyList()
                listOf(statusSnapshot(at))
            }
            BleConstants.CMD_READ_LOCK_STATE or BleConstants.RESPONSE_FLAG -> {
                childLock = frame.u8(0)?.let { it == 1 } ?: return emptyList()
                listOf(statusSnapshot(at))
            }
            BleConstants.CMD_READ_SUCTION_TIME or BleConstants.RESPONSE_FLAG -> {
                val tenths = frame.u8(0) ?: return emptyList()
                if (tenths == 0) emptyList() else listOf(DeviceMessage.PuffDetected(at, tenths * 100))
            }
            BleConstants.CMD_READ_DAY_PUFF or BleConstants.RESPONSE_FLAG -> {
                parseTodayPuffs(frame.payload)?.let { listOf(DeviceMessage.DailyPuffCount(it, at)) } ?: emptyList()
            }
            BleConstants.PUSH_DEVICE_REPORT -> {
                frame.u8(0)?.let { listOf(DeviceMessage.DeviceAlert(it, at)) } ?: emptyList()
            }
            else -> listOf(DeviceMessage.Unknown(characteristic, raw))
        }
    }

    private fun statusSnapshot(at: Instant) = DeviceMessage.Status(
        battery = battery,
        charging = null,
        liquid = liquid,
        counterTotal = null,
        powerMode = null,
        childLock = childLock,
        firmware = firmware,
        recordedAt = at,
    )

    private fun toMessage(record: PuffRecord, nowMs: Long): DeviceMessage? {
        if (record.durationMs !in 1..MAX_PUFF_MS) return null
        val startMs = deviceSecondsToEpochMs(record.deviceSeconds)
            ?.takeIf { it in MIN_PLAUSIBLE_MS..(nowMs + CLOCK_SKEW_MS) }
            ?: (nowMs - record.durationMs)
        val startedAt = Instant.ofEpochMilli(startMs)
        return if (nowMs - startMs <= LIVE_WINDOW_MS) {
            DeviceMessage.PuffCompleted(startedAt, record.durationMs, record.deviceSeconds, record.raw)
        } else {
            DeviceMessage.HistoryPuff(startedAt, record.durationMs, record.deviceSeconds, record.raw)
        }
    }

    /** The device counts local wall-clock seconds as if they were UTC. */
    private fun deviceSecondsToEpochMs(deviceSeconds: Long): Long? {
        if (deviceSeconds <= 0) return null
        val local = deviceSeconds * 1000
        val tz = timeZone()
        return local - tz.getOffset(local - tz.getOffset(local))
    }

    private fun deviceClockString(): String {
        val now = ZonedDateTime.ofInstant(Instant.ofEpochMilli(clock()), timeZone().toZoneId())
        return now.format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"))
    }

    companion object {
        private const val DEFAULT_MTU = 23
        private const val ATT_OVERHEAD = 3
        private const val PUFF_RECORD_SIZE = 8
        private const val MAX_PAGE_SIZE = 10
        private const val MAX_PAGES = 400
        private const val UNIT_PERCENT: Byte = 0
        private const val DEFAULT_TIMEOUT_MS = 5_000L
        private const val FIRST_LINK_TIMEOUT_MS = 60_000L
        private const val RECONNECT_LINK_TIMEOUT_MS = 10_000L
        private const val MAX_PUFF_MS = 60_000
        private const val LIVE_WINDOW_MS = 10 * 60_000L
        private const val CLOCK_SKEW_MS = 24 * 3_600_000L
        private const val MIN_PLAUSIBLE_MS = 1_672_531_200_000L // 2023-01-01T00:00:00Z
        private const val MAX_NAME_BYTES = 32

        internal fun firstLinkPayload(identity: ClientIdentity): ByteArray {
            val name = utf8Truncated(identity.name.ifBlank { "Vapen" }, MAX_NAME_BYTES)
            val id = utf8Truncated(identity.id.ifBlank { "vapen" }, 64)
            return byteArrayOf(BleConstants.IDENTIFIER_TYPE_ANDROID.toByte(), name.size.toByte()) +
                name + byteArrayOf(id.size.toByte()) + id
        }

        private fun utf8Truncated(value: String, maxBytes: Int): ByteArray {
            var end = value.length
            while (end > 0) {
                val bytes = value.substring(0, end).toByteArray(Charsets.UTF_8)
                if (bytes.size <= maxBytes) return bytes
                end--
            }
            return byteArrayOf()
        }

        /** Response payload of READ_DAY_PUFF: `[days][u16 BE per day…]`, today first. */
        internal fun parseTodayPuffs(payload: ByteArray): Int? {
            val days = payload.getOrNull(0)?.toInt()?.and(0xFF) ?: return null
            if (days < 1 || payload.size < 3) return null
            return ((payload[1].toInt() and 0xFF) shl 8) or (payload[2].toInt() and 0xFF)
        }

        /**
         * Response payload of READ_PUFF_RECORDS: `[count u16 BE]` then `count` records of 8 bytes:
         * `[power ×0.1 W][duration u16 LE ×10 ms][resistance ×0.1 Ω][device seconds u32 LE]`.
         */
        internal fun parsePuffPage(payload: ByteArray): PuffPage? {
            if (payload.size < 2) return null
            val claimed = ((payload[0].toInt() and 0xFF) shl 8) or (payload[1].toInt() and 0xFF)
            val records = mutableListOf<PuffRecord>()
            for (i in 0 until claimed) {
                val base = 2 + i * PUFF_RECORD_SIZE
                if (base + PUFF_RECORD_SIZE > payload.size) break
                val duration = ((payload[base + 1].toInt() and 0xFF) or ((payload[base + 2].toInt() and 0xFF) shl 8)) * 10
                val seconds = (payload[base + 4].toLong() and 0xFF) or
                    ((payload[base + 5].toLong() and 0xFF) shl 8) or
                    ((payload[base + 6].toLong() and 0xFF) shl 16) or
                    ((payload[base + 7].toLong() and 0xFF) shl 24)
                records += PuffRecord(
                    deviceSeconds = seconds,
                    durationMs = duration,
                    powerWatts = (payload[base].toInt() and 0xFF) / 10.0,
                    resistanceOhm = (payload[base + 3].toInt() and 0xFF) / 10.0,
                    raw = payload.copyOfRange(base, base + PUFF_RECORD_SIZE),
                )
            }
            return PuffPage(claimed, records)
        }
    }
}

internal class PuffRecord(
    val deviceSeconds: Long,
    val durationMs: Int,
    val powerWatts: Double,
    val resistanceOhm: Double,
    val raw: ByteArray,
)

internal class PuffPage(val claimed: Int, val records: List<PuffRecord>)
