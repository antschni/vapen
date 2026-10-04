package dev.vapen.app.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import dev.vapen.app.bridge.ExplorerDirection
import dev.vapen.app.bridge.ExplorerEvent
import dev.vapen.app.bridge.ExplorerScanFilter
import dev.vapen.app.bridge.TrackingFlutterApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File
import java.time.Instant

class BleExplorerManager(
    private val context: Context,
    private val flutterApi: TrackingFlutterApi?,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val log = mutableListOf<JSONObject>()
    private var gatt: BluetoothGatt? = null
    private var scanning = false

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            handleScanResult(result, activeFilter)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach { handleScanResult(it, activeFilter) }
        }

        override fun onScanFailed(errorCode: Int) {
            scanning = false
            emit(ExplorerDirection.SCAN, note = "scan failed error=$errorCode")
        }
    }

    private var activeFilter = ExplorerScanFilter()

    @SuppressLint("MissingPermission")
    fun startScan(filter: ExplorerScanFilter) {
        activeFilter = filter
        BlePermissions.missingScanMessage(context)?.let { msg ->
            emit(ExplorerDirection.SCAN, note = msg)
            return
        }
        val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
        if (adapter == null || !adapter.isEnabled) {
            emit(ExplorerDirection.SCAN, note = "Bluetooth ist aus — bitte einschalten.")
            return
        }
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            emit(ExplorerDirection.SCAN, note = "BLE-Scanner nicht verfügbar.")
            return
        }
        if (scanning) {
            scanner.stopScan(scanCallback)
        }
        scanning = true
        emit(ExplorerDirection.SCAN, note = "scan start")
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        scanner.startScan(null, settings, scanCallback)
    }

    @SuppressLint("MissingPermission")
    fun stopScan() {
        val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
        adapter?.bluetoothLeScanner?.stopScan(scanCallback)
        scanning = false
        emit(ExplorerDirection.SCAN, note = "scan stop")
    }

    private fun handleScanResult(result: ScanResult, filter: ExplorerScanFilter) {
        val name = result.scanRecord?.deviceName?.takeIf { it.isNotEmpty() }
            ?: result.device.name
        val rssi = result.rssi
        if (filter.minRssi != null && rssi < filter.minRssi!!) return
        if (filter.nameContains != null && name?.contains(filter.nameContains!!, true) != true) return
        val md = result.scanRecord?.manufacturerSpecificData?.let { sparse ->
            if (sparse.size() == 0) "" else {
                val first = sparse.valueAt(0)
                first.joinToString("") { "%02x".format(it) }
            }
        } ?: ""
        emit(
            ExplorerDirection.SCAN,
            hex = md,
            note = "${result.device.address} rssi=$rssi name=${name ?: "?"}",
        )
    }

    @SuppressLint("MissingPermission")
    fun connect(address: String) {
        BlePermissions.missingConnectMessage(context)?.let { msg ->
            emit(ExplorerDirection.CONNECT, note = msg)
            return
        }
        val device = BluetoothAdapter.getDefaultAdapter().getRemoteDevice(address)
        emit(ExplorerDirection.CONNECT, note = address)
        gatt?.close()
        gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(context, false, explorerCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(context, false, explorerCallback)
        }
    }

    @SuppressLint("MissingPermission")
    fun disconnect() {
        gatt?.close()
        gatt = null
        emit(ExplorerDirection.DISCONNECT, note = "")
    }

    @SuppressLint("MissingPermission")
    fun write(serviceUuid: String, charUuid: String, hex: String, withResponse: Boolean) {
        val g = gatt ?: return
        val service = g.getService(java.util.UUID.fromString(serviceUuid)) ?: return
        val char = service.getCharacteristic(java.util.UUID.fromString(charUuid)) ?: return
        val bytes = hex.replace(" ", "").chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        char.writeType = if (withResponse) {
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        } else {
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        }
        char.value = bytes
        g.writeCharacteristic(char)
        emit(ExplorerDirection.WRITE, serviceUuid, charUuid, hex, "withResponse=$withResponse")
    }

    fun addMarker(note: String) {
        emit(ExplorerDirection.MARKER, hex = "", note = note)
    }

    fun exportLog(): String {
        val dir = File(context.cacheDir, "explorer")
        dir.mkdirs()
        val file = File(dir, "ble-explorer-${Instant.now().epochSecond}.jsonl")
        file.writeText(log.joinToString("\n") { it.toString() })
        return file.absolutePath
    }

    private val explorerCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> gatt.discoverServices()
                BluetoothProfile.STATE_DISCONNECTED ->
                    emit(ExplorerDirection.DISCONNECT, note = "status=$status")
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                emit(ExplorerDirection.READ, note = "service discovery failed status=$status")
                return
            }
            gatt.services?.forEach { service ->
                service.characteristics.forEach { char ->
                    val props = char.properties
                    if (props and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) {
                        gatt.setCharacteristicNotification(char, true)
                    }
                    emit(
                        ExplorerDirection.READ,
                        service.uuid.toString(),
                        char.uuid.toString(),
                        "",
                        "props=$props",
                    )
                }
            }
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            emit(
                ExplorerDirection.NOTIFY,
                characteristic.service.uuid.toString(),
                characteristic.uuid.toString(),
                value.joinToString("") { "%02x".format(it) },
            )
        }
    }

    private fun emit(
        direction: ExplorerDirection,
        serviceUuid: String? = null,
        charUuid: String? = null,
        hex: String = "",
        note: String? = null,
    ) {
        val entry = JSONObject()
            .put("ts", Instant.now().toString())
            .put("direction", direction.name)
            .put("service_uuid", serviceUuid)
            .put("char_uuid", charUuid)
            .put("hex", hex)
            .put("note", note)
        log.add(entry)
        val event = ExplorerEvent(
            epochMs = System.currentTimeMillis(),
            direction = direction,
            serviceUuid = serviceUuid,
            charUuid = charUuid,
            hex = hex,
            note = note,
        )
        scope.launch {
            flutterApi?.onExplorerEvent(event) {}
        }
    }
}
