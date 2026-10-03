package dev.vapen.app.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface PendingEventDao {
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(event: PendingEvent)

    @Query("SELECT * FROM pending_events ORDER BY createdAtEpochMs ASC LIMIT :limit")
    suspend fun oldest(limit: Int): List<PendingEvent>

    @Query("DELETE FROM pending_events WHERE clientEventId IN (:ids)")
    suspend fun deleteByIds(ids: List<String>)

    @Query("SELECT COUNT(*) FROM pending_events")
    suspend fun count(): Int

}

@Dao
interface DeadEventDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(event: DeadEvent)

    @Query("SELECT COUNT(*) FROM dead_events")
    suspend fun count(): Int
}
