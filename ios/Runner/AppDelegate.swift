import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appIconChannelName = "league_hub/app_icon"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LeagueHubAppIcon") else {
      return
    }
    setupAppIconChannel(binaryMessenger: registrar.messenger())
  }

  private func setupAppIconChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: appIconChannelName,
      binaryMessenger: binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSupported":
        result(UIApplication.shared.supportsAlternateIcons)
      case "getCurrentIconName":
        result(UIApplication.shared.alternateIconName)
      case "setIcon":
        self.setAlternateIcon(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setAlternateIcon(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard UIApplication.shared.supportsAlternateIcons else {
      result(
        FlutterError(
          code: "unsupported",
          message: "Alternate icons are not supported on this device.",
          details: nil
        )
      )
      return
    }

    let args = call.arguments as? [String: Any]
    let requestedIconName = args?["iconName"] as? String
    let iconName = requestedIconName?.isEmpty == true ? nil : requestedIconName

    if UIApplication.shared.alternateIconName == iconName {
      result(nil)
      return
    }

    UIApplication.shared.setAlternateIconName(iconName) { error in
      if let error = error {
        result(
          FlutterError(
            code: "set_icon_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      } else {
        result(nil)
      }
    }
  }
}
