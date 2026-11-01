package dev.vapen.app.upload

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dev.vapen.app.data.CredentialStore
import dev.vapen.app.data.VapenDatabase
import java.util.concurrent.TimeUnit

class UploadWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val db = VapenDatabase.get(applicationContext)
        val uploader = IngestUploader(
            CredentialStore(applicationContext),
            db.pendingEvents(),
            db.deadEvents(),
        )
        repeat(MAX_BATCHES) {
            // Network exceptions must retry; an uncaught throw would mark the work as failed for good.
            val result = runCatching { uploader.flush() }.getOrElse { return Result.retry() }
            when (result) {
                is UploadResult.Success -> Unit
                is UploadResult.NothingToSend -> return Result.success()
                is UploadResult.AuthError, is UploadResult.NoCredentials -> return Result.failure()
                else -> return Result.retry()
            }
        }
        return Result.success()
    }

    companion object {
        private const val UNIQUE_NAME = "vapen_upload"
        private const val MAX_BATCHES = 50

        /** Uploads pending events once a network is available, retrying with backoff. */
        fun enqueue(context: Context) {
            val request = OneTimeWorkRequestBuilder<UploadWorker>()
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build(),
                )
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                UNIQUE_NAME,
                ExistingWorkPolicy.KEEP,
                request,
            )
        }
    }
}
