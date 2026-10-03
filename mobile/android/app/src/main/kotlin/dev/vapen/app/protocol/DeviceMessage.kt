package dev.vapen.app.protocol

import java.time.Instant
import java.util.UUID

sealed interface DeviceMessage {
    data class PuffStarted(val at: Instant) : DeviceMessage
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
    data class Unknown(val characteristic: UUID, val raw: ByteArray) : DeviceMessage
}
