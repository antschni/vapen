package dev.vapen.app.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "pending_events")
data class PendingEvent(
    @PrimaryKey val clientEventId: String,
    val type: String,
    val payloadJson: String,
    val createdAtEpochMs: Long,
    val attempts: Int = 0,
    val lastError: String? = null,
)

@Entity(tableName = "dead_events")
data class DeadEvent(
    @PrimaryKey val clientEventId: String,
    val type: String,
    val payloadJson: String,
    val reason: String,
    val createdAtEpochMs: Long,
)
