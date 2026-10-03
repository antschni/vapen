package dev.vapen.app.ble

import java.util.UUID

/** Abstraction over Android GATT for protocol tests and future BLE implementation. */
interface GattSession {
    suspend fun read(service: UUID, characteristic: UUID): ByteArray?
    suspend fun write(service: UUID, characteristic: UUID, value: ByteArray, withResponse: Boolean)
    suspend fun setNotify(service: UUID, characteristic: UUID, enabled: Boolean)
    suspend fun requestMtu(mtu: Int): Int
}

class FakeGattSession : GattSession {
    override suspend fun read(service: UUID, characteristic: UUID): ByteArray? = null
    override suspend fun write(service: UUID, characteristic: UUID, value: ByteArray, withResponse: Boolean) {}
    override suspend fun setNotify(service: UUID, characteristic: UUID, enabled: Boolean) {}
    override suspend fun requestMtu(mtu: Int): Int = mtu
}
