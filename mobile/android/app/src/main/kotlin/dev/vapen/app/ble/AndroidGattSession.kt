package dev.vapen.app.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import java.io.IOException
import java.util.UUID

class AndroidGattSession(
    private val gatt: () -> BluetoothGatt?,
    private val queue: GattOperationQueue,
) : GattSession {
    override suspend fun read(service: UUID, characteristic: UUID): ByteArray? {
        return queue.read {
            val g = gatt() ?: return@read false
            val c = g.getService(service)?.getCharacteristic(characteristic) ?: return@read false
            g.readCharacteristic(c)
        }
    }

    override suspend fun write(service: UUID, characteristic: UUID, value: ByteArray, withResponse: Boolean) {
        val ok = queue.write {
            val g = gatt() ?: return@write false
            val c = g.getService(service)?.getCharacteristic(characteristic) ?: return@write false
            c.writeType = if (withResponse) {
                BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            } else {
                BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            }
            c.value = value
            g.writeCharacteristic(c)
        }
        if (!ok) throw IOException("Schreiben auf $characteristic fehlgeschlagen")
    }

    override suspend fun setNotify(service: UUID, characteristic: UUID, enabled: Boolean) {
        val ok = queue.notify {
            val g = gatt() ?: return@notify false
            val c = g.getService(service)?.getCharacteristic(characteristic) ?: return@notify false
            if (!g.setCharacteristicNotification(c, enabled)) return@notify false
            val descriptor = GattOperationQueue.cccdDescriptor(g, c) ?: return@notify false
            val indicate = c.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY == 0 &&
                c.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
            descriptor.value = when {
                !enabled -> android.bluetooth.BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
                indicate -> android.bluetooth.BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                else -> android.bluetooth.BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            }
            g.writeDescriptor(descriptor)
        }
        if (!ok) throw IOException("Notifications auf $characteristic konnten nicht aktiviert werden")
    }

    override suspend fun requestMtu(mtu: Int): Int {
        return queue.mtu {
            gatt()?.requestMtu(mtu) ?: false
        }
    }
}
