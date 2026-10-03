package dev.vapen.app.service

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import dev.vapen.app.ble.BleConnectionManager
import dev.vapen.app.bridge.PuffInfo
import dev.vapen.app.bridge.StatusInfo
import dev.vapen.app.bridge.TrackingConnectionState
import dev.vapen.app.bridge.TrackingFlutterApi
import dev.vapen.app.bridge.TrackingState
import dev.vapen.app.data.CredentialStore
import dev.vapen.app.data.NativeCredentials
import dev.vapen.app.data.PendingEvent
import dev.vapen.app.data.VapenDatabase
import dev.vapen.app.protocol.DeviceMessage
import dev.vapen.app.upload.EventIdFactory
import dev.vapen.app.upload.IngestUploader
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant

object TrackingController {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var flutterApi: TrackingFlutterApi? = null
    private var bleManager: BleConnectionManager? = null
    private var appContext: Context? = null

    private var connectionState = TrackingConnectionState.IDLE
    private var todayPuffCount = 0
    private var batteryPercent: Int? = null
    private var liquidPercent: Int? = null
    private var isCharging: Boolean? = null
    private var lastError: String? = null

    lateinit var credentials: CredentialStore
    lateinit var database: VapenDatabase
    lateinit var uploader: IngestUploader

    fun setFlutterApi(api: TrackingFlutterApi?) {
        flutterApi = api
        publishState(credentials.trackingEnabled)
    }

    fun init(context: Context) {
        if (appContext != null) return
        appContext = context.applicationContext
        credentials = CredentialStore(context)
        database = VapenDatabase.get(context)
        uploader = IngestUploader(credentials, database.pendingEvents(), database.deadEvents())
        bleManager = BleConnectionManager(
            context.applicationContext,
            onState = { state, err ->
                connectionState = state
                lastError = err
                publishState(credentials.trackingEnabled)
            },
            onMessage = { msg -> scope.launch { handleMessage(msg) } },
        ).also {
            it.setSimulation(credentials.simulationEnabled)
            it.setTargetAddress(credentials.pairedBleAddress)
        }
    }

    fun setNativeCredentials(creds: dev.vapen.app.bridge.NativeCredentials) {
        credentials.save(
            NativeCredentials(
                baseUrl = creds.baseUrl,
                deviceId = creds.deviceId,
                deviceToken = creds.deviceToken,
                hardwareId = creds.hardwareId,
            ),
        )
    }

    fun setPairedAddress(address: String?) {
        credentials.pairedBleAddress = address
        bleManager?.setTargetAddress(address)
    }

    fun clearCredentials() {
        stopTrackingInternal()
        credentials.clear()
    }

    fun startTracking(context: Context) {
        init(context)
        credentials.trackingEnabled = true
        bleManager?.setSimulation(credentials.simulationEnabled)
        context.startForegroundService(Intent(context, VapenTrackingService::class.java))
        bleManager?.connect()
        publishState(true)
        scope.launch { uploader.flush() }
    }

    fun stopTracking(context: Context) {
        credentials.trackingEnabled = false
        stopTrackingInternal()
        context.stopService(Intent(context, VapenTrackingService::class.java))
        publishState(false)
    }

    private fun stopTrackingInternal() {
        bleManager?.disconnect()
        connectionState = TrackingConnectionState.IDLE
    }

    fun getState(): TrackingState {
        return TrackingState(
            enabled = credentials.trackingEnabled,
            connectionState = connectionState,
            batteryPercent = batteryPercent?.toLong(),
            liquidPercent = liquidPercent?.toLong(),
            isCharging = isCharging,
            todayPuffCount = todayPuffCount.toLong(),
            pendingUploads = 0,
            lastError = lastError,
            simulationEnabled = credentials.simulationEnabled,
        )
    }

    suspend fun pendingCount(): Int = database.pendingEvents().count()

    fun setSimulationEnabled(enabled: Boolean) {
        credentials.simulationEnabled = enabled
        bleManager?.setSimulation(enabled)
        if (credentials.trackingEnabled) {
            bleManager?.disconnect()
            bleManager?.connect()
        }
        publishState(credentials.trackingEnabled)
    }

    private suspend fun handleMessage(msg: DeviceMessage) {
        val hardwareId = credentials.get()?.hardwareId ?: bleManager?.hardwareId() ?: return
        when (msg) {
            is DeviceMessage.PuffStarted -> sendPuffStarted(hardwareId, msg.at)
            is DeviceMessage.PuffCompleted -> {
                persistPuff(hardwareId, msg)
                todayPuffCount++
                flutterApi?.onPuff(
                    PuffInfo(
                        startedAtEpochMs = msg.startedAt.toEpochMilli(),
                        durationMs = msg.durationMs.toLong(),
                    ),
                ) {}
                publishState(credentials.trackingEnabled)
                uploader.flush()
            }
            is DeviceMessage.HistoryPuff -> persistPuff(
                hardwareId,
                DeviceMessage.PuffCompleted(msg.startedAt, msg.durationMs, msg.deviceIndex, msg.raw),
            )
            is DeviceMessage.Status -> {
                batteryPercent = msg.battery
                liquidPercent = msg.liquid
                isCharging = msg.charging
                persistStatus(hardwareId, msg)
                flutterApi?.onStatus(
                    StatusInfo(
                        batteryPercent = msg.battery?.toLong(),
                        liquidPercent = msg.liquid?.toLong(),
                        isCharging = msg.charging,
                        recordedAtEpochMs = msg.recordedAt.toEpochMilli(),
                    ),
                ) {}
                publishState(credentials.trackingEnabled)
                uploader.flush()
            }
            is DeviceMessage.Unknown -> {}
        }
    }

    private suspend fun sendPuffStarted(hardwareId: String, at: Instant) {
        // Transient — not buffered; best-effort direct POST would need okhttp here; skip for now.
    }

    private suspend fun persistPuff(hardwareId: String, puff: DeviceMessage.PuffCompleted) {
        val id = EventIdFactory.puffId(hardwareId, puff.deviceIndex, puff.startedAt)
        val payload = buildJsonObject {
            put("type", "puff")
            put("client_event_id", id)
            put("started_at", puff.startedAt.toString())
            put("duration_ms", puff.durationMs)
            put("source", if (puff.deviceIndex != null) "live" else "history")
            put("raw", buildJsonObject { put("hex", puff.raw.joinToString("") { "%02x".format(it) }) })
        }
        database.pendingEvents().insert(
            PendingEvent(id, "puff", payload.toString(), Instant.now().toEpochMilli()),
        )
    }

    private suspend fun persistStatus(hardwareId: String, status: DeviceMessage.Status) {
        val id = EventIdFactory.statusId(hardwareId, status.recordedAt)
        val payload = buildJsonObject {
            put("type", "status")
            put("client_event_id", id)
            put("recorded_at", status.recordedAt.toString())
            status.battery?.let { put("battery_percent", it) }
            status.charging?.let { put("is_charging", it) }
            status.liquid?.let { put("liquid_percent", it) }
            status.counterTotal?.let { put("puff_counter_total", it) }
            status.powerMode?.let { put("power_mode", it) }
            status.childLock?.let { put("child_lock", it) }
            status.firmware?.let { put("firmware_version", it) }
        }
        database.pendingEvents().insert(
            PendingEvent(id, "status", payload.toString(), Instant.now().toEpochMilli()),
        )
    }

    private fun publishState(enabled: Boolean) {
        flutterApi?.onTrackingStateChanged(getState().copy(enabled = enabled)) {}
    }

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun requestIgnoreBatteryOptimizations(context: Context) {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
