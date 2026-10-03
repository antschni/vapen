package dev.vapen.app

import android.app.Application
import dev.vapen.app.data.VapenDatabase

class VapenApplication : Application() {
    lateinit var database: VapenDatabase
        private set

    override fun onCreate() {
        super.onCreate()
        database = VapenDatabase.get(this)
    }
}
