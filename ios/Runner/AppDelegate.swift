import Flutter
import UIKit
import UserNotifications

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
      case "setBadgeCount":
        self.setBadgeCount(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setBadgeCount(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let count = args["count"] as? Int,
      count >= 0
    else {
      result(
        FlutterError(
          code: "invalid_badge_count",
          message: "Badge count must be a non-negative integer.",
          details: nil
        )
      )
      return
    }

    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(count) { error in
        DispatchQueue.main.async {
          if let error = error {
            result(
              FlutterError(
                code: "set_badge_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          } else {
            result(nil)
          }
        }
      }
    } else {
      UIApplication.shared.applicationIconBadgeNumber = count
      result(nil)
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
