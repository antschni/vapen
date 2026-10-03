package dev.vapen.app.upload

import dev.vapen.app.data.CredentialStore
import dev.vapen.app.data.DeadEvent
import dev.vapen.app.data.DeadEventDao
import dev.vapen.app.data.PendingEvent
import dev.vapen.app.data.PendingEventDao
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.time.Instant

class IngestUploader(
    private val credentials: CredentialStore,
    private val pendingDao: PendingEventDao,
    private val deadDao: DeadEventDao,
    private val client: OkHttpClient = OkHttpClient(),
) {
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun flush(maxBatch: Int = 100): UploadResult = withContext(Dispatchers.IO) {
        val creds = credentials.get() ?: return@withContext UploadResult.NoCredentials
        val batch = pendingDao.oldest(maxBatch)
        if (batch.isEmpty()) return@withContext UploadResult.NothingToSend

        val events = buildJsonArray {
            batch.forEach { row ->
                add(json.parseToJsonElement(row.payloadJson))
            }
        }
        val body = buildJsonObject {
            put("device_id", creds.deviceId)
            put("sent_at", Instant.now().toString())
            put("events", events)
        }
        val url = "${creds.baseUrl.trimEnd('/')}/api/v1/ingest"
        val request = Request.Builder()
            .url(url)
            .addHeader("Authorization", "Bearer ${creds.deviceToken}")
            .addHeader("Content-Type", "application/json")
            .post(body.toString().toRequestBody("application/json".toMediaType()))
            .build()

        val response = client.newCall(request).execute()
        val responseBody = response.body?.string() ?: ""
        when (response.code) {
            200 -> {
                val parsed = json.parseToJsonElement(responseBody).jsonObject
                handleSuccess(batch, parsed)
                UploadResult.Success
            }
            401, 403 -> UploadResult.AuthError
            429 -> {
                val retry = response.header("Retry-After")?.toLongOrNull()
                UploadResult.RateLimited(retry)
            }
            in 500..599 -> UploadResult.ServerError
            else -> UploadResult.OtherError(response.code, responseBody)
        }
    }

    private suspend fun handleSuccess(batch: List<PendingEvent>, parsed: JsonObject) {
        val rejected = parsed["rejected"] as? JsonArray ?: JsonArray(emptyList())
        val rejectedIds = rejected.mapNotNull {
            it.jsonObject["client_event_id"]?.jsonPrimitive?.content
        }.toSet()
        val acceptedCount = parsed["accepted"]?.jsonPrimitive?.content?.toIntOrNull() ?: 0
        val duplicateCount = parsed["duplicates"]?.jsonPrimitive?.content?.toIntOrNull() ?: 0
        val toRemove = batch.take(acceptedCount + duplicateCount).map { it.clientEventId }
        if (toRemove.isNotEmpty()) {
            pendingDao.deleteByIds(toRemove)
        }
        rejected.forEach { element ->
            val obj = element.jsonObject
            val id = obj["client_event_id"]?.jsonPrimitive?.content ?: return@forEach
            val message = obj["message"]?.jsonPrimitive?.content ?: "rejected"
            val row = batch.find { it.clientEventId == id }
            if (row != null) {
                deadDao.insert(
                    DeadEvent(
                        clientEventId = id,
                        type = row.type,
                        payloadJson = row.payloadJson,
                        reason = message,
                        createdAtEpochMs = row.createdAtEpochMs,
                    ),
                )
                pendingDao.deleteByIds(listOf(id))
            }
        }
        val total = pendingDao.count()
        if (total > 100_000) {
            val excess = pendingDao.oldest(total - 100_000)
            pendingDao.deleteByIds(excess.map { it.clientEventId })
        }
    }
}

sealed class UploadResult {
    data object Success : UploadResult()
    data object NothingToSend : UploadResult()
    data object NoCredentials : UploadResult()
    data object AuthError : UploadResult()
    data object ServerError : UploadResult()
    data class RateLimited(val retryAfterSeconds: Long?) : UploadResult()
    data class OtherError(val code: Int, val body: String) : UploadResult()
}
