package dev.vapen.app.ble

import android.bluetooth.BluetoothGatt
import java.util.UUID

data class BleProfile(
    val name: String,
    val serviceUuid: UUID,
    /** Phone → device (framed commands, write with response). */
    val txUuid: UUID,
    /** Device → phone (responses and pushes, notify). */
    val rxUuid: UUID,
    /** Notify characteristic InnoGate subscribes to as well; optional. */
    val otaNotify: Pair<UUID, UUID>? = null,
)

object BleProfileDetector {
    fun detect(gatt: BluetoothGatt): BleProfile? {
        val services = gatt.services ?: return null
        val cig = services.find { it.uuid == BleConstants.CIG_SERVICE } ?: return null
        if (cig.getCharacteristic(BleConstants.CIG_WRITE) == null) return null
        if (cig.getCharacteristic(BleConstants.CIG_NOTIFY) == null) return null
        val ota = services.find { it.uuid == BleConstants.OTA_SERVICE }
            ?.getCharacteristic(BleConstants.OTA_NOTIFY)
            ?.let { BleConstants.OTA_SERVICE to BleConstants.OTA_NOTIFY }
        return BleProfile(
            name = "innogate_cig",
            serviceUuid = BleConstants.CIG_SERVICE,
            txUuid = BleConstants.CIG_WRITE,
            rxUuid = BleConstants.CIG_NOTIFY,
            otaNotify = ota,
        )
    }
}
