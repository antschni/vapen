package dev.vapen.app.protocol

import java.time.Instant
import java.util.UUID

sealed interface DeviceMessage {
    data class PuffStarted(val at: Instant) : DeviceMessage

    /** Device signalled a finished puff; the exact record arrives via the next history sync. */
    data class PuffDetected(val at: Instant, val durationMs: Int) : DeviceMessage

    data class PuffCompleted(
        val startedAt: Instant,
        val durationMs: Int,
        val deviceIndex: Long?,
        val raw: ByteArray,
    ) : DeviceMessage
    data class HistoryPuff(
        val startedAt: Instant,
        val durationMs: Int,
        val deviceIndex: Long?,
        val raw: ByteArray,
    ) : DeviceMessage
    data class DailyPuffCount(val today: Int, val at: Instant) : DeviceMessage
    data class Status(
        val battery: Int?,
        val charging: Boolean?,
        val liquid: Int?,
        val counterTotal: Long?,
        val powerMode: String?,
        val childLock: Boolean?,
        val firmware: String?,
        val recordedAt: Instant,
    ) : DeviceMessage
    data class DeviceAlert(val code: Int, val at: Instant) : DeviceMessage
    data class Warning(val message: String) : DeviceMessage
    data class Unknown(val characteristic: UUID, val raw: ByteArray) : DeviceMessage
}

class ProtocolException(message: String) : Exception(message)
