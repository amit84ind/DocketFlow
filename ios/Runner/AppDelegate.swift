import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pendingSharedText: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let methodChannel = FlutterMethodChannel(name: "com.docketflow/settings",
                                                binaryMessenger: controller.binaryMessenger)

      methodChannel.setMethodCallHandler({
        [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        guard let self = self else { return }
        switch call.method {
        case "isNotificationServiceEnabled":
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
              let enabled = (settings.authorizationStatus == .authorized)
              result(enabled)
            }
          }
        case "openNotificationSettings":
          if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
              UIApplication.shared.open(url, options: [:], completionHandler: nil)
              result(true)
            } else {
              result(FlutterError(code: "UNAVAILABLE", message: "Cannot open iOS settings", details: nil))
            }
          } else {
            result(FlutterError(code: "UNAVAILABLE", message: "Invalid settings URL", details: nil))
          }
        case "getPendingSharedText":
          let text = self.pendingSharedText
          self.pendingSharedText = nil
          result(text)
        default:
          result(FlutterMethodNotImplemented)
        }
      })
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
