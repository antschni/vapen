package dev.vapen.app.upload

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import dev.vapen.app.data.CredentialStore
import dev.vapen.app.data.VapenDatabase

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
        return when (val result = uploader.flush()) {
            is UploadResult.Success,
            is UploadResult.NothingToSend,
            -> Result.success()
            is UploadResult.RateLimited -> Result.retry()
            is UploadResult.ServerError -> Result.retry()
            is UploadResult.AuthError -> Result.failure()
            else -> Result.retry()
        }
    }
}
