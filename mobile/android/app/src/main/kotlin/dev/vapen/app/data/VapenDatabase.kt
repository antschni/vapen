package dev.vapen.app.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [PendingEvent::class, DeadEvent::class],
    version = 1,
    exportSchema = false,
)
abstract class VapenDatabase : RoomDatabase() {
    abstract fun pendingEvents(): PendingEventDao
    abstract fun deadEvents(): DeadEventDao

    companion object {
        @Volatile
        private var instance: VapenDatabase? = null

        fun get(context: Context): VapenDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    VapenDatabase::class.java,
                    "vapen.db",
                ).build().also { instance = it }
            }
    }
}
