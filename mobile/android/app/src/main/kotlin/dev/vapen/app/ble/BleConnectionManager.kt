package dev.vapen.app.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import dev.vapen.app.bridge.TrackingConnectionState
import dev.vapen.app.protocol.Advertisement
import dev.vapen.app.protocol.DeviceInfo
import dev.vapen.app.protocol.DeviceMessage
import dev.vapen.app.protocol.ElfbarMasterProtocol
import dev.vapen.app.protocol.SimulatedProtocol
import dev.vapen.app.protocol.VapeProtocol
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.min

typealias MessageHandler = suspend (DeviceMessage) -> Unit

class BleConnectionManager(
    private val context: Context,
    private val onState: (TrackingConnectionState, String?) -> Unit,
    private val onMessage: MessageHandler,
) {
    private val scope = CoroutineScope(Dispatchers.IO)
    private val queue = GattOperationQueue()
    private var gatt: BluetoothGatt? = null
    private var profile: BleProfile? = null
    private var protocol: VapeProtocol = ElfbarMasterProtocol()
    private var session: AndroidGattSession? = null
    private var reconnectJob: Job? = null
    private var backoffMs = 1_000L
    private val targetAddress = AtomicReference<String?>(null)
    private var simulation = false

    fun setSimulation(enabled: Boolean) {
        simulation = enabled
        protocol = if (enabled) SimulatedProtocol() else ElfbarMasterProtocol()
    }

    fun setTargetAddress(address: String?) {
        targetAddress.set(address)
    }

    @SuppressLint("MissingPermission")
    fun connect() {
        if (simulation) {
            onState(TrackingConnectionState.LIVE, null)
            startSimulationFeed()
            return
        }
        val address = targetAddress.get()
        if (address == null) {
            onState(TrackingConnectionState.WAITING, "Kein Gerät gekoppelt")
            return
        }
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled) {
            onState(TrackingConnectionState.DISCONNECTED, "Bluetooth aus")
            return
        }
        val device = adapter.getRemoteDevice(address)
        onState(TrackingConnectionState.CONNECTING, null)
        gatt?.close()
        gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(context, true, callback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(context, true, callback)
        }
        session = AndroidGattSession({ gatt }, queue)
    }

    @SuppressLint("MissingPermission")
    fun disconnect() {
        reconnectJob?.cancel()
        gatt?.close()
        gatt = null
        onState(TrackingConnectionState.DISCONNECTED, null)
    }

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                backoffMs = 1_000
                onState(TrackingConnectionState.DISCOVERING, null)
                gatt.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                onState(TrackingConnectionState.DISCONNECTED, if (status == 133) "InnoGate schließen?" else null)
                scheduleReconnect()
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) return
            profile = BleProfileDetector.detect(gatt)
            if (profile == null) {
                onState(TrackingConnectionState.DISCONNECTED, "Unbekanntes GATT-Profil")
                return
            }
            scope.launch {
                onState(TrackingConnectionState.INITIALIZING, null)
                val sess = session ?: return@launch
                try {
                    protocol.initialize(sess)
                    profile?.let { p ->
                        sess.setNotify(p.serviceUuid, p.rxUuid, true)
                    }
                    protocol.requestStatus(sess)
                    protocol.requestHistory(sess, null)
                    onState(TrackingConnectionState.LIVE, null)
                } catch (e: Exception) {
                    onState(TrackingConnectionState.DISCONNECTED, e.message)
                }
            }
        }

        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
            queue.completeRead(status == BluetoothGatt.GATT_SUCCESS, value)
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) {
            queue.completeRead(status == BluetoothGatt.GATT_SUCCESS, characteristic.value)
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            queue.completeWrite(status == BluetoothGatt.GATT_SUCCESS)
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: android.bluetooth.BluetoothGattDescriptor, status: Int) {
            queue.completeNotify(status == BluetoothGatt.GATT_SUCCESS)
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            queue.completeMtu(if (status == BluetoothGatt.GATT_SUCCESS) mtu else 23)
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            scope.launch {
                val messages = protocol.decode(characteristic.uuid, value, System.currentTimeMillis())
                messages.forEach { onMessage(it) }
            }
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            onCharacteristicChanged(gatt, characteristic, characteristic.value ?: byteArrayOf())
        }
    }

    private fun scheduleReconnect() {
        reconnectJob?.cancel()
        reconnectJob = scope.launch {
            delay(backoffMs)
            backoffMs = min(backoffMs * 2, 60_000)
            connect()
        }
    }

    private fun startSimulationFeed() {
        val sim = protocol as? SimulatedProtocol ?: return
        reconnectJob?.cancel()
        reconnectJob = scope.launch {
            while (true) {
                delay(25_000)
                onMessage(sim.nextSimulatedPuff())
                onMessage(sim.nextSimulatedStatus())
            }
        }
    }

    fun hardwareId(): String {
        val address = targetAddress.get() ?: "sim"
        return protocol.hardwareId(DeviceInfo(serialNumber = null, bleMac = address))
    }

    fun matchesScan(name: String?, address: String, rssi: Int): Boolean {
        return protocol.matches(Advertisement(name, address, rssi, null, emptyList()))
    }
}
