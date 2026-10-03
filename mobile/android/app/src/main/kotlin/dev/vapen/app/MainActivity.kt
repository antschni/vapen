package dev.vapen.app

import android.content.Intent
import android.os.Build
import dev.vapen.app.bridge.TrackingFlutterApi
import dev.vapen.app.bridge.TrackingHostApi
import dev.vapen.app.bridge.TrackingHostApiImpl
import dev.vapen.app.companion.CompanionDeviceHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var hostApi: TrackingHostApiImpl? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val flutterApi = TrackingFlutterApi(flutterEngine.dartExecutor.binaryMessenger)
        hostApi = TrackingHostApiImpl(this, flutterApi).also { impl ->
            TrackingHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, impl)
            impl.attachEngine()
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        hostApi?.detachEngine()
        hostApi = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == CompanionDeviceHelper.REQUEST_CODE) {
            CompanionDeviceHelper.handleActivityResult(resultCode, data)
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
