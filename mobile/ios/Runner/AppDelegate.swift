import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UploadScheduler.register { IngestUploader(credentials: CredentialStore(), store: .shared) }
    // Recreates the restorable BLE central right away, also when iOS relaunches the app in the
    // background for a Bluetooth event (state restoration).
    TrackingController.shared.resumeBleIfConfigured()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VapenNativePlugin") {
      VapenNativePlugin.register(with: registrar)
    }
  }
}
