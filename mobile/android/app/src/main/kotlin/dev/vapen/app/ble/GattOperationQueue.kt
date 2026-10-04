package dev.vapen.app.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import java.util.UUID

/** Serializes GATT operations; Android allows only one outstanding operation per connection. */
class GattOperationQueue {
    private val mutex = Mutex()

    @Volatile private var pendingRead: CompletableDeferred<ByteArray?>? = null
    @Volatile private var pendingWrite: CompletableDeferred<Boolean>? = null
    @Volatile private var pendingNotify: CompletableDeferred<Boolean>? = null
    @Volatile private var pendingMtu: CompletableDeferred<Int>? = null

    suspend fun read(block: () -> Boolean): ByteArray? = mutex.withLock {
        val deferred = CompletableDeferred<ByteArray?>()
        pendingRead = deferred
        try {
            if (!block()) return@withLock null
            withTimeoutOrNull(TIMEOUT_MS) { deferred.await() }
        } finally {
            pendingRead = null
        }
    }

    suspend fun write(block: () -> Boolean): Boolean = mutex.withLock {
        val deferred = CompletableDeferred<Boolean>()
        pendingWrite = deferred
        try {
            if (!block()) return@withLock false
            withTimeoutOrNull(TIMEOUT_MS) { deferred.await() } ?: false
        } finally {
            pendingWrite = null
        }
    }

    suspend fun notify(block: () -> Boolean): Boolean = mutex.withLock {
        val deferred = CompletableDeferred<Boolean>()
        pendingNotify = deferred
        try {
            if (!block()) return@withLock false
            withTimeoutOrNull(TIMEOUT_MS) { deferred.await() } ?: false
        } finally {
            pendingNotify = null
        }
    }

    suspend fun mtu(block: () -> Boolean): Int = mutex.withLock {
        val deferred = CompletableDeferred<Int>()
        pendingMtu = deferred
        try {
            if (!block()) return@withLock DEFAULT_MTU
            withTimeoutOrNull(TIMEOUT_MS) { deferred.await() } ?: DEFAULT_MTU
        } finally {
            pendingMtu = null
        }
    }

    fun completeRead(success: Boolean, data: ByteArray?) {
        pendingRead?.complete(if (success) data else null)
    }

    fun completeWrite(success: Boolean) {
        pendingWrite?.complete(success)
    }

    fun completeNotify(success: Boolean) {
        pendingNotify?.complete(success)
    }

    fun completeMtu(mtu: Int) {
        pendingMtu?.complete(mtu)
    }

    /** Fails whatever is in flight, e.g. after the link dropped. */
    fun failAll() {
        pendingRead?.complete(null)
        pendingWrite?.complete(false)
        pendingNotify?.complete(false)
        pendingMtu?.complete(DEFAULT_MTU)
    }

    companion object {
        private const val TIMEOUT_MS = 10_000L
        private const val DEFAULT_MTU = 23

        fun cccdDescriptor(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic): BluetoothGattDescriptor? {
            return characteristic.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
        }
    }
}
