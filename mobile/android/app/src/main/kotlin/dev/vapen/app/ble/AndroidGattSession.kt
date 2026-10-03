package dev.vapen.app.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import java.util.UUID

class AndroidGattSession(
    private val gatt: () -> BluetoothGatt?,
    private val queue: GattOperationQueue,
) : GattSession {
    override suspend fun read(service: UUID, characteristic: UUID): ByteArray? {
        return queue.read {
            val g = gatt() ?: return@read
            val c = g.getService(service)?.getCharacteristic(characteristic) ?: return@read
            g.readCharacteristic(c)
        }
    }

    override suspend fun write(service: UUID, characteristic: UUID, value: ByteArray, withResponse: Boolean) {
        queue.write {
            val g = gatt() ?: return@write
            val c = g.getService(service)?.getCharacteristic(characteristic) ?: return@write
            c.writeType = if (withResponse) {
                BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            } else {
                BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            }
            c.value = value
            g.writeCharacteristic(c)
        }
    }

    override suspend fun setNotify(service: UUID, characteristic: UUID, enabled: Boolean) {
        queue.notify {
            val g = gatt() ?: return@notify
            val c = g.getService(service)?.getCharacteristic(characteristic) ?: return@notify
            g.setCharacteristicNotification(c, enabled)
            val descriptor = GattOperationQueue.cccdDescriptor(g, c) ?: return@notify
            descriptor.value = if (enabled) {
                android.bluetooth.BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            } else {
                android.bluetooth.BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
            }
            g.writeDescriptor(descriptor)
        }
    }

    override suspend fun requestMtu(mtu: Int): Int {
        return queue.mtu {
            gatt()?.requestMtu(mtu)
        }
    }
}
