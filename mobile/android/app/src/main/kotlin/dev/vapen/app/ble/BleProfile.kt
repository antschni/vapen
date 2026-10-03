package dev.vapen.app.ble

import android.bluetooth.BluetoothGatt
import java.util.UUID

data class BleProfile(
    val name: String,
    val serviceUuid: UUID,
    val txUuid: UUID,
    val rxUuid: UUID,
)

object BleProfileDetector {
    fun detect(gatt: BluetoothGatt): BleProfile? {
        val services = gatt.services ?: return null
        for (service in services) {
            val uuid = service.uuid
            when (uuid) {
                BleConstants.NUS_SERVICE -> {
                    return BleProfile("nordic_uart", BleConstants.NUS_SERVICE, BleConstants.NUS_TX, BleConstants.NUS_RX)
                }
                BleConstants.VENDOR_FFF0 -> {
                    return BleProfile("vendor_fff0", BleConstants.VENDOR_FFF0, BleConstants.VENDOR_FFF1, BleConstants.VENDOR_FFF2)
                }
            }
        }
        // First custom 128-bit service with write + notify chars
        for (service in services) {
            if (service.uuid.toString().startsWith("0000")) continue
            var write: UUID? = null
            var notify: UUID? = null
            for (c in service.characteristics) {
                val props = c.properties
                if (props and android.bluetooth.BluetoothGattCharacteristic.PROPERTY_WRITE != 0 ||
                    props and android.bluetooth.BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0
                ) {
                    write = c.uuid
                }
                if (props and android.bluetooth.BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) {
                    notify = c.uuid
                }
            }
            if (write != null && notify != null) {
                return BleProfile("discovered", service.uuid, write, notify)
            }
        }
        return null
    }
}
