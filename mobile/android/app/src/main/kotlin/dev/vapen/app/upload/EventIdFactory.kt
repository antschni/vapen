package dev.vapen.app.upload

import java.nio.charset.StandardCharsets
import java.time.Instant
import java.util.UUID

/**
 * Deterministic client_event_id (UUIDv5). Namespace and rules documented in docs/elfbar-protocol.md.
 */
object EventIdFactory {
    private val NAMESPACE = UUID.fromString("6ba7b810-9dad-11d1-80b4-00c04fd430c8")

    fun puffId(hardwareId: String, deviceIndex: Long?, startedAt: Instant): String {
        val name = if (deviceIndex != null) {
            "$hardwareId:puff:$deviceIndex"
        } else {
            val ms = (startedAt.toEpochMilli() / 100) * 100
            "$hardwareId:puff:$ms"
        }
        return uuidV5(NAMESPACE, name).toString()
    }

    fun statusId(hardwareId: String, recordedAt: Instant): String {
        val minute = recordedAt.epochSecond / 60
        return uuidV5(NAMESPACE, "$hardwareId:status:$minute").toString()
    }

    fun puffStartedId(hardwareId: String, occurredAt: Instant): String {
        val second = occurredAt.epochSecond
        return uuidV5(NAMESPACE, "$hardwareId:puff_started:$second").toString()
    }

    private fun uuidV5(namespace: UUID, name: String): UUID {
        val nsBytes = ByteArray(16)
        val msb = namespace.mostSignificantBits
        val lsb = namespace.leastSignificantBits
        for (i in 0..7) nsBytes[i] = ((msb ushr (8 * (7 - i))) and 0xff).toByte()
        for (i in 8..15) nsBytes[i] = ((lsb ushr (8 * (15 - i))) and 0xff).toByte()
        val sha1 = java.security.MessageDigest.getInstance("SHA-1")
        sha1.update(nsBytes)
        sha1.update(name.toByteArray(StandardCharsets.UTF_8))
        val hash = sha1.digest()
        hash[6] = ((hash[6].toInt() and 0x0f) or 0x50).toByte()
        hash[8] = ((hash[8].toInt() and 0x3f) or 0x80).toByte()
        var msbOut = 0L
        var lsbOut = 0L
        for (i in 0..7) msbOut = (msbOut shl 8) or (hash[i].toLong() and 0xff)
        for (i in 8..15) lsbOut = (lsbOut shl 8) or (hash[i].toLong() and 0xff)
        return UUID(msbOut, lsbOut)
    }
}
