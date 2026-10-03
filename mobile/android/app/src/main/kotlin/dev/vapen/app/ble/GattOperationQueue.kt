package dev.vapen.app.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeout
import java.util.UUID

class GattOperationQueue {
    private val mutex = Mutex()
    private var pendingRead: CompletableDeferred<ByteArray?>? = null
    private var pendingWrite: CompletableDeferred<Boolean>? = null
    private var pendingNotify: CompletableDeferred<Boolean>? = null
    private var pendingMtu: CompletableDeferred<Int>? = null

    suspend fun read(block: () -> Unit): ByteArray? = mutex.withLock {
        val deferred = CompletableDeferred<ByteArray?>()
        pendingRead = deferred
        block()
        withTimeout(15_000) { deferred.await() }
    }

    suspend fun write(block: () -> Unit): Boolean = mutex.withLock {
        val deferred = CompletableDeferred<Boolean>()
        pendingWrite = deferred
        block()
        withTimeout(15_000) { deferred.await() }
    }

    suspend fun notify(block: () -> Unit): Boolean = mutex.withLock {
        val deferred = CompletableDeferred<Boolean>()
        pendingNotify = deferred
        block()
        withTimeout(15_000) { deferred.await() }
    }

    suspend fun mtu(block: () -> Unit): Int = mutex.withLock {
        val deferred = CompletableDeferred<Int>()
        pendingMtu = deferred
        block()
        withTimeout(15_000) { deferred.await() }
    }

    fun completeRead(success: Boolean, data: ByteArray?) {
        pendingRead?.complete(if (success) data else null)
        pendingRead = null
    }

    fun completeWrite(success: Boolean) {
        pendingWrite?.complete(success)
        pendingWrite = null
    }

    fun completeNotify(success: Boolean) {
        pendingNotify?.complete(success)
        pendingNotify = null
    }

    fun completeMtu(mtu: Int) {
        pendingMtu?.complete(mtu)
        pendingMtu = null
    }

    companion object {
        fun cccdDescriptor(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic): BluetoothGattDescriptor? {
            return characteristic.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
        }
    }
}
