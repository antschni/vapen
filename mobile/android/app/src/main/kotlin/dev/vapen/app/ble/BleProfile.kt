package dev.vapen.app.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import java.util.UUID

data class BleProfile(
    val name: String,
    val serviceUuid: UUID,
    /** Phone → device (commands). */
    val txUuid: UUID,
    /** Device → phone (notifications); subscribe to all listed characteristics. */
    val rxUuids: List<UUID>,
    /** Optional InnoGate-style pairing trigger (`[0x01, 0x00]` write). */
    val armPairUuid: UUID? = null,
) {
    val rxUuid: UUID get() = rxUuids.first()
}

object BleProfileDetector {
    /**
     * ELFA MASTER / InnoGate lab captures use vendor `fff0` with notify on `fff2` and writes on `fff1`.
     * Prefer that profile over Nordic UART when both services are present.
     */
    fun detect(gatt: BluetoothGatt): BleProfile? {
        val services = gatt.services ?: return null
        val vendor = services.find { it.uuid == BleConstants.VENDOR_FFF0 }
        if (vendor != null) {
            profileFromVendorService(vendor)?.let { return it }
        }
        val nus = services.find { it.uuid == BleConstants.NUS_SERVICE }
        if (nus != null) {
            return BleProfile(
                name = "nordic_uart",
                serviceUuid = BleConstants.NUS_SERVICE,
                txUuid = BleConstants.NUS_TX,
                rxUuids = listOf(BleConstants.NUS_RX),
            )
        }
        return discoverGenericUart(services)
    }

    private fun profileFromVendorService(service: android.bluetooth.BluetoothGattService): BleProfile? {
        val fff1 = service.getCharacteristic(BleConstants.VENDOR_FFF1)
        val fff2 = service.getCharacteristic(BleConstants.VENDOR_FFF2)
        val tx = when {
            fff1?.isWritable() == true -> BleConstants.VENDOR_FFF1
            fff2?.isWritable() == true -> BleConstants.VENDOR_FFF2
            else -> service.characteristics.firstOrNull { it.isWritable() }?.uuid ?: return null
        }
        val notifyCandidates = listOf(
            BleConstants.VENDOR_FFF2,
            BleConstants.VENDOR_FFF1,
            BleConstants.VENDOR_FFF4,
            BleConstants.VENDOR_FFF5,
            BleConstants.VENDOR_FFF3,
        )
        val rx = notifyCandidates.mapNotNull { uuid ->
            service.getCharacteristic(uuid)?.takeIf { it.isNotifiable() }?.uuid
        }.distinct()
        val rxFinal = if (rx.isNotEmpty()) {
            rx
        } else {
            service.characteristics.filter { it.isNotifiable() }.map { it.uuid }.ifEmpty { return null }
        }
        val armPairUuid = service.getCharacteristic(BleConstants.VENDOR_FFF4)?.takeIf { it.isWritable() }?.uuid
        return BleProfile(
            name = "vendor_fff0",
            serviceUuid = BleConstants.VENDOR_FFF0,
            txUuid = tx,
            rxUuids = rxFinal,
            armPairUuid = armPairUuid,
        )
    }

    private fun discoverGenericUart(services: List<android.bluetooth.BluetoothGattService>): BleProfile? {
        for (service in services) {
            if (service.uuid.toString().startsWith("0000")) continue
            var write: UUID? = null
            val notify = mutableListOf<UUID>()
            for (c in service.characteristics) {
                if (c.isWritable() && write == null) write = c.uuid
                if (c.isNotifiable()) notify.add(c.uuid)
            }
            if (write != null && notify.isNotEmpty()) {
                return BleProfile("discovered", service.uuid, write, notify)
            }
        }
        return null
    }

    private fun BluetoothGattCharacteristic.isWritable(): Boolean {
        val p = properties
        return (p and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) ||
            (p and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0)
    }

    private fun BluetoothGattCharacteristic.isNotifiable(): Boolean {
        val p = properties
        return (p and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) ||
            (p and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0)
    }
}
