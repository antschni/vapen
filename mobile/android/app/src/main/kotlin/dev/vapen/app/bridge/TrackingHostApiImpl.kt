package dev.vapen.app.bridge

import android.app.Activity
import android.os.Build
import dev.vapen.app.ble.BleExplorerManager
import dev.vapen.app.companion.CompanionDeviceHelper
import dev.vapen.app.service.TrackingController
import kotlinx.coroutines.runBlocking

class TrackingHostApiImpl(
    private val activity: Activity,
    private val flutterApi: TrackingFlutterApi,
) : TrackingHostApi {
    private val explorer = BleExplorerManager(activity.applicationContext, flutterApi)

    init {
        TrackingController.init(activity.applicationContext)
    }

    fun attachEngine() {
        TrackingController.setFlutterApi(flutterApi)
    }

    fun detachEngine() {
        TrackingController.setFlutterApi(null)
    }

    override fun setCredentials(credentials: NativeCredentials) {
        TrackingController.setNativeCredentials(credentials)
    }

    override fun clearCredentials() {
        TrackingController.clearCredentials()
    }

    override fun associateDevice(callback: (Result<PairingResult>) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            var replied = false
            fun replyOnce(result: Result<PairingResult>) {
                if (replied) return
                replied = true
                callback(result)
            }
            CompanionDeviceHelper.associate(activity) { address ->
                if (address != null) {
                    TrackingController.setPairedAddress(address)
                    replyOnce(Result.success(PairingResult(success = true, address = address, errorMessage = null)))
                } else {
                    replyOnce(
                        Result.success(
                            PairingResult(
                                success = false,
                                address = null,
                                errorMessage = "Kopplung abgebrochen",
                            ),
                        ),
                    )
                }
            }
        } else {
            callback(
                Result.success(
                    PairingResult(
                        success = false,
                        address = null,
                        errorMessage = "Companion Device Manager benötigt Android 8+",
                    ),
                ),
            )
        }
    }

    override fun startTracking() {
        TrackingController.startTracking(activity.applicationContext)
    }

    override fun stopTracking() {
        TrackingController.stopTracking(activity.applicationContext)
    }

    override fun getTrackingState(): TrackingState {
        return runBlocking {
            TrackingController.getState().copy(pendingUploads = TrackingController.pendingCount().toLong())
        }
    }

    override fun getPendingEventCount(): Long {
        return runBlocking { TrackingController.pendingCount().toLong() }
    }

    override fun isIgnoringBatteryOptimizations(): Boolean {
        return TrackingController.isIgnoringBatteryOptimizations(activity)
    }

    override fun requestIgnoreBatteryOptimizations() {
        TrackingController.requestIgnoreBatteryOptimizations(activity)
    }

    override fun setSimulationEnabled(enabled: Boolean) {
        TrackingController.setSimulationEnabled(enabled)
    }

    override fun explorerStartScan(filter: ExplorerScanFilter) {
        explorer.startScan(filter)
    }

    override fun explorerStopScan() {
        explorer.stopScan()
    }

    override fun explorerConnect(address: String) {
        explorer.connect(address)
    }

    override fun explorerDisconnect() {
        explorer.disconnect()
    }

    override fun explorerWrite(serviceUuid: String, charUuid: String, hex: String, withResponse: Boolean) {
        explorer.write(serviceUuid, charUuid, hex, withResponse)
    }

    override fun explorerAddMarker(note: String) {
        explorer.addMarker(note)
    }

    override fun explorerExportLog(): String = explorer.exportLog()
}
