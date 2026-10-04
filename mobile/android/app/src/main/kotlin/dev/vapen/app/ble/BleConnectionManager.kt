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
import android.provider.Settings
import dev.vapen.app.bridge.TrackingConnectionState
import dev.vapen.app.protocol.Advertisement
import dev.vapen.app.protocol.ClientIdentity
import dev.vapen.app.protocol.DeviceInfo
import dev.vapen.app.protocol.DeviceMessage
import dev.vapen.app.protocol.ElfbarMasterProtocol
import dev.vapen.app.protocol.SharedPrefsHistoryCursorStore
import dev.vapen.app.protocol.SimulatedProtocol
import dev.vapen.app.protocol.VapeProtocol
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.min

typealias MessageHandler = suspend (DeviceMessage) -> Unit

class BleConnectionManager(
    private val context: Context,
    private val onState: (TrackingConnectionState, String?) -> Unit,
    private val onMessage: MessageHandler,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val queue = GattOperationQueue()
    private val cursorStore = SharedPrefsHistoryCursorStore(context)
    private val messages = Channel<DeviceMessage>(Channel.UNLIMITED)

    @Volatile private var gatt: BluetoothGatt? = null
    @Volatile private var protocol: VapeProtocol = createDeviceProtocol()
    private var session: AndroidGattSession? = null
    private var reconnectJob: Job? = null
    private var connectTimeoutJob: Job? = null
    private var linkJob: Job? = null
    @Volatile private var syncRequests: Channel<Unit>? = null
    private var backoffMs = 1_000L
    private val targetAddress = AtomicReference<String?>(null)
    private var simulation = false

    init {
        scope.launch {
            for (message in messages) {
                runCatching { onMessage(message) }
            }
        }
    }

    fun setSimulation(enabled: Boolean) {
        simulation = enabled
        protocol = if (enabled) SimulatedProtocol() else createDeviceProtocol()
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
            onState(TrackingConnectionState.WAITING, "Kein Gerät gekoppelt — unter Geräte erneut koppeln.")
            return
        }
        BlePermissions.missingConnectMessage(context)?.let { msg ->
            onState(TrackingConnectionState.DISCONNECTED, msg)
            return
        }
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled) {
            onState(TrackingConnectionState.DISCONNECTED, "Bluetooth aus")
            return
        }
        val device = adapter.getRemoteDevice(address)
        reconnectJob?.cancel()
        stopLinkJobs()
        protocol.bindDevice(address.uppercase())
        onState(TrackingConnectionState.CONNECTING, null)
        gatt?.close()
        gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(context, false, callback)
        }
        session = AndroidGattSession({ gatt }, queue)
        armWatchdog(
            CONNECT_TIMEOUT_MS,
            "Verbindungstimeout — Elfbar nah ans Telefon, Bildschirm an, InnoGate geschlossen?",
        )
    }

    @SuppressLint("MissingPermission")
    fun disconnect() {
        reconnectJob?.cancel()
        connectTimeoutJob?.cancel()
        stopLinkJobs()
        gatt?.close()
        gatt = null
        queue.failAll()
        onState(TrackingConnectionState.DISCONNECTED, null)
    }

    /** Aborts the current attempt if it does not reach LIVE in time (connect, discovery or handshake can hang). */
    private fun armWatchdog(timeoutMs: Long, message: String) {
        connectTimeoutJob?.cancel()
        connectTimeoutJob = scope.launch {
            delay(timeoutMs)
            failAndReconnect(message)
        }
    }

    @SuppressLint("MissingPermission")
    private fun failAndReconnect(message: String?, reconnect: Boolean = true) {
        connectTimeoutJob?.cancel()
        stopLinkJobs()
        gatt?.close()
        gatt = null
        queue.failAll()
        onState(TrackingConnectionState.DISCONNECTED, message)
        if (reconnect) scheduleReconnect()
    }

    private fun stopLinkJobs() {
        linkJob?.cancel()
        linkJob = null
        syncRequests?.close()
        syncRequests = null
    }

    private fun emit(list: List<DeviceMessage>) {
        list.forEach { messages.trySend(it) }
    }

    /** Runs for the lifetime of one established link: initial sync, puff-triggered syncs, periodic polling. */
    private fun startLinkJobs(sess: AndroidGattSession, p: BleProfile, link: BluetoothGatt) {
        stopLinkJobs()
        val requests = Channel<Unit>(Channel.CONFLATED)
        syncRequests = requests
        linkJob = scope.launch {
            launch {
                emit(runCatching { protocol.requestStatus(sess, p) }.getOrDefault(emptyList()))
                emit(runCatching { protocol.syncHistory(sess, p) }.getOrDefault(emptyList()))
                for (request in requests) {
                    delay(PUFF_SYNC_DELAY_MS)
                    var found = syncPuffs(sess, p)
                    if (!found && isActive) {
                        delay(PUFF_SYNC_RETRY_MS)
                        found = syncPuffs(sess, p)
                    }
                    emit(runCatching { protocol.requestStatus(sess, p) }.getOrDefault(emptyList()))
                }
            }
            launch {
                var tick = 0
                while (isActive && gatt === link) {
                    delay(STATUS_POLL_MS)
                    emit(runCatching { protocol.requestStatus(sess, p) }.getOrDefault(emptyList()))
                    if (++tick % HISTORY_POLL_EVERY_N_STATUS == 0) syncRequests?.trySend(Unit)
                }
            }
        }
    }

    private suspend fun syncPuffs(sess: AndroidGattSession, p: BleProfile): Boolean {
        val result = runCatching { protocol.syncHistory(sess, p) }.getOrDefault(emptyList())
        emit(result)
        return result.any { it is DeviceMessage.PuffCompleted || it is DeviceMessage.HistoryPuff }
    }

    private val callback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (gatt !== this@BleConnectionManager.gatt) return
            if (newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
                if (!gatt.discoverServices()) {
                    failAndReconnect("Dienstsuche konnte nicht gestartet werden.")
                    return
                }
                armWatchdog(DISCOVERY_TIMEOUT_MS, "Dienstsuche hängt — Elfbar wach halten (Display an).")
                onState(TrackingConnectionState.DISCOVERING, null)
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) {
                failAndReconnect(disconnectHint(status))
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (gatt !== this@BleConnectionManager.gatt) return
            if (status != BluetoothGatt.GATT_SUCCESS) {
                failAndReconnect("Dienstsuche fehlgeschlagen (status=$status)")
                return
            }
            val p = BleProfileDetector.detect(gatt)
            if (p == null) {
                val uuids = gatt.services.orEmpty().joinToString { it.uuid.toString() }
                failAndReconnect("Kein ELFA-MASTER-Dienst gefunden: $uuids", reconnect = false)
                return
            }
            armWatchdog(
                HANDSHAKE_TIMEOUT_MS,
                "Elfbar antwortet nicht — InnoGate schließen und Kopplung am Gerät bestätigen.",
            )
            onState(TrackingConnectionState.INITIALIZING, null)
            scope.launch {
                val sess = session ?: return@launch
                try {
                    val initial = protocol.initialize(sess, p)
                    if (gatt !== this@BleConnectionManager.gatt) return@launch
                    connectTimeoutJob?.cancel()
                    backoffMs = 1_000
                    onState(TrackingConnectionState.LIVE, null)
                    emit(initial)
                    startLinkJobs(sess, p, gatt)
                } catch (e: Exception) {
                    if (gatt !== this@BleConnectionManager.gatt) return@launch
                    failAndReconnect(e.message ?: "Initialisierung fehlgeschlagen (${e::class.simpleName})")
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
            if (gatt !== this@BleConnectionManager.gatt) return
            val decoded = protocol.onNotification(characteristic.uuid, value, System.currentTimeMillis())
            if (decoded.any { it is DeviceMessage.PuffDetected }) syncRequests?.trySend(Unit)
            emit(decoded)
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

    private fun createDeviceProtocol(): VapeProtocol = ElfbarMasterProtocol(
        identity = ::clientIdentity,
        cursorStore = cursorStore,
    )

    private fun clientIdentity(): ClientIdentity {
        val resolver = context.contentResolver
        val name = Settings.Global.getString(resolver, "device_name")?.takeIf { it.isNotBlank() }
            ?: Build.BRAND?.takeIf { it.isNotBlank() }
            ?: "Android"
        val id = Settings.Secure.getString(resolver, Settings.Secure.ANDROID_ID)?.takeIf { it.isNotBlank() }
            ?: "vapen"
        return ClientIdentity(name, id)
    }

    private fun disconnectHint(status: Int): String? = when (status) {
        0 -> null
        133 -> "GATT-Fehler 133 — Gerät in Reichweite halten, InnoGate schließen, Bluetooth neu starten."
        8 -> "Verbindung beendet — Elfbar wach halten (Display an)."
        19 -> "Gerät hat die Verbindung getrennt — InnoGate geschlossen?"
        else -> "BLE getrennt (status=$status)"
    }

    companion object {
        private const val CONNECT_TIMEOUT_MS = 25_000L
        private const val DISCOVERY_TIMEOUT_MS = 20_000L
        /** FIRST_LINK_INFO may wait up to 60 s for on-device confirmation. */
        private const val HANDSHAKE_TIMEOUT_MS = 90_000L
        private const val STATUS_POLL_MS = 60_000L
        private const val HISTORY_POLL_EVERY_N_STATUS = 5
        private const val PUFF_SYNC_DELAY_MS = 1_500L
        private const val PUFF_SYNC_RETRY_MS = 4_000L
    }
}
