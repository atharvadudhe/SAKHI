import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Load API key from Info.plist (injected at build time via $(GOOGLE_MAPS_API_KEY))
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String,
       !apiKey.isEmpty,
       !apiKey.hasPrefix("$(") {
      GMSServices.provideAPIKey(apiKey)
    } else {
      NSLog("[SAKHI] WARNING: GOOGLE_MAPS_API_KEY not found in Info.plist")
    }

    // ── Camouflage icon MethodChannel ──
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.example.sakhi/icon",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] (call, result) in
        guard call.method == "setIcon" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let args = call.arguments as? [String: Any?]
        let iconName = args?["iconName"] as? String
        self?.setAlternateIcon(iconName, result: result)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setAlternateIcon(_ name: String?, result: @escaping FlutterResult) {
    guard UIApplication.shared.supportsAlternateIcons else {
      result(FlutterError(code: "UNSUPPORTED", message: "Alternate icons not supported", details: nil))
      return
    }
    UIApplication.shared.setAlternateIconName(name) { error in
      if let error = error {
        result(FlutterError(code: "ICON_ERROR", message: error.localizedDescription, details: nil))
      } else {
        result(nil)
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
