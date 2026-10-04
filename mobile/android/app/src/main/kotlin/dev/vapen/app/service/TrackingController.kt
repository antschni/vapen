package dev.vapen.app.service

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
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
import dev.vapen.app.upload.UploadResult
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant

object TrackingController {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var flutterApi: TrackingFlutterApi? = null
    private var bleManager: BleConnectionManager? = null
    private var appContext: Context? = null

    @Volatile private var connectionState = TrackingConnectionState.IDLE
    @Volatile private var todayPuffCount = 0
    @Volatile private var batteryPercent: Int? = null
    @Volatile private var liquidPercent: Int? = null
    @Volatile private var isCharging: Boolean? = null
    @Volatile private var lastError: String? = null

    private var lastPersistedStatus: DeviceMessage.Status? = null
    private var flushJob: Job? = null
    @Volatile private var flushPending = false

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
            onMessage = { msg -> handleMessage(msg) },
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
        lastError = null
        requestFlush()
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
        requestFlush()
    }

    /** Foreground service / boot: reconnect BLE without toggling the tracking flag. */
    fun resumeBleIfConfigured() {
        if (!credentials.trackingEnabled) return
        if (credentials.pairedBleAddress == null) return
        bleManager?.connect()
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

    /** Called in device order from a single coroutine. */
    private suspend fun handleMessage(msg: DeviceMessage) {
        val hardwareId = credentials.get()?.hardwareId ?: bleManager?.hardwareId() ?: return
        when (msg) {
            is DeviceMessage.PuffStarted, is DeviceMessage.PuffDetected, is DeviceMessage.Unknown -> {}
            is DeviceMessage.PuffCompleted -> {
                persistPuff(hardwareId, msg.startedAt, msg.durationMs, msg.deviceIndex, msg.raw, source = "live")
                todayPuffCount++
                val puff = PuffInfo(
                    startedAtEpochMs = msg.startedAt.toEpochMilli(),
                    durationMs = msg.durationMs.toLong(),
                )
                onMain { flutterApi?.onPuff(puff) {} }
                publishState(credentials.trackingEnabled)
                requestFlush()
            }
            is DeviceMessage.HistoryPuff -> {
                persistPuff(hardwareId, msg.startedAt, msg.durationMs, msg.deviceIndex, msg.raw, source = "history")
                requestFlush()
            }
            is DeviceMessage.DailyPuffCount -> {
                todayPuffCount = msg.today
                publishState(credentials.trackingEnabled)
            }
            is DeviceMessage.Status -> {
                msg.battery?.let { batteryPercent = it }
                msg.liquid?.let { liquidPercent = it }
                msg.charging?.let { isCharging = it }
                if (shouldPersist(msg)) {
                    persistStatus(hardwareId, msg)
                    lastPersistedStatus = msg
                    requestFlush()
                }
                val status = StatusInfo(
                    batteryPercent = batteryPercent?.toLong(),
                    liquidPercent = liquidPercent?.toLong(),
                    isCharging = isCharging,
                    recordedAtEpochMs = msg.recordedAt.toEpochMilli(),
                )
                onMain { flutterApi?.onStatus(status) {} }
                publishState(credentials.trackingEnabled)
            }
            is DeviceMessage.DeviceAlert -> {
                alertText(msg.code)?.let {
                    lastError = it
                    publishState(credentials.trackingEnabled)
                }
            }
            is DeviceMessage.Warning -> {
                lastError = msg.message
                publishState(credentials.trackingEnabled)
            }
        }
    }

    private fun shouldPersist(status: DeviceMessage.Status): Boolean {
        val last = lastPersistedStatus ?: return true
        val changed = status.battery != last.battery ||
            status.liquid != last.liquid ||
            status.charging != last.charging ||
            status.childLock != last.childLock ||
            status.firmware != last.firmware
        val stale = status.recordedAt.epochSecond - last.recordedAt.epochSecond >= STATUS_HEARTBEAT_S
        return changed || stale
    }

    private fun alertText(code: Int): String? = when (code) {
        1 -> "Elfbar: Akku schwach"
        2 -> "Elfbar: Liquid fast leer"
        3 -> "Elfbar: überhitzt"
        4 -> "Elfbar: Kurzschluss am Pod"
        5 -> "Elfbar: Pod nicht erkannt"
        6 -> "Elfbar: Tageslimit erreicht"
        else -> null
    }

    /** Uploads everything pending; coalesces bursts (e.g. a history sync). */
    private fun requestFlush() {
        flushPending = true
        if (flushJob?.isActive == true) return
        flushJob = scope.launch {
            while (flushPending) {
                flushPending = false
                delay(FLUSH_DEBOUNCE_MS)
                repeat(MAX_FLUSH_BATCHES) {
                    val result = runCatching { uploader.flush() }.getOrNull() ?: return@launch
                    when (result) {
                        UploadResult.Success -> Unit
                        UploadResult.NothingToSend -> return@launch
                        else -> {
                            noteUploadFailure(result)
                            return@launch
                        }
                    }
                }
            }
            publishState(credentials.trackingEnabled)
        }
    }

    private fun noteUploadFailure(result: UploadResult) {
        lastError = when (result) {
            UploadResult.NoCredentials ->
                "Upload: kein Gerät-Token — unter Mehr → Geräte erneut koppeln."
            UploadResult.AuthError ->
                "Upload abgelehnt (Token ungültig). Gerät in der App erneut koppeln."
            UploadResult.ServerError -> "Upload: Server-Fehler — später erneut versuchen."
            is UploadResult.RateLimited -> "Upload: Rate-Limit — bitte kurz warten."
            is UploadResult.OtherError ->
                "Upload fehlgeschlagen (HTTP ${result.code}): ${result.body.take(120)}"
            else -> null
        }
        publishState(credentials.trackingEnabled)
    }

    private suspend fun persistPuff(
        hardwareId: String,
        startedAt: Instant,
        durationMs: Int,
        deviceIndex: Long?,
        raw: ByteArray,
        source: String,
    ) {
        val id = EventIdFactory.puffId(hardwareId, deviceIndex, startedAt)
        val payload = buildJsonObject {
            put("type", "puff")
            put("client_event_id", id)
            put("started_at", startedAt.toString())
            put("duration_ms", durationMs)
            put("source", source)
            put("raw", buildJsonObject { put("hex", raw.joinToString("") { "%02x".format(it) }) })
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
        scope.launch {
            val pending = runCatching { pendingCount() }.getOrDefault(0)
            val state = getState().copy(enabled = enabled, pendingUploads = pending.toLong())
            onMain { flutterApi?.onTrackingStateChanged(state) {} }
            appContext?.let { context ->
                if (enabled) onMain { VapenTrackingService.updateNotification(context, notificationText()) }
            }
        }
    }

    private fun notificationText(): String = when (connectionState) {
        TrackingConnectionState.LIVE -> buildString {
            append("Verbunden · heute $todayPuffCount Züge")
            batteryPercent?.let { append(" · Akku $it %") }
        }
        TrackingConnectionState.CONNECTING -> "Verbinde mit Elfbar…"
        TrackingConnectionState.DISCOVERING -> "Suche Dienste…"
        TrackingConnectionState.INITIALIZING -> "Kopplung mit Elfbar…"
        TrackingConnectionState.WAITING -> lastError ?: "Warte auf Gerät…"
        TrackingConnectionState.DISCONNECTED -> "Getrennt" + (lastError?.let { " — $it" } ?: "")
        TrackingConnectionState.IDLE -> "Tracking pausiert"
    }

    /** Pigeon/Flutter channels must only be called from the platform (main) thread. */
    private fun onMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post(block)
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

    private const val STATUS_HEARTBEAT_S = 15 * 60L
    private const val FLUSH_DEBOUNCE_MS = 500L
    private const val MAX_FLUSH_BATCHES = 50
}
