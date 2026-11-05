import Flutter
import UIKit

/// Opens a distribution link only; never downloads or installs application files.
final class IosUpdateChannel: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.vvtech.phone_agent/ios_update", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(IosUpdateChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "open" else { result(FlutterMethodNotImplemented); return }
    guard let raw = call.arguments as? String, let url = URL(string: raw),
          ["https", "itms-apps"].contains(url.scheme?.lowercased() ?? ""),
          !(url.host ?? "").isEmpty, url.user == nil, url.password == nil,
          url.fragment == nil, url.pathExtension.lowercased() != "apk" else {
      result(FlutterError(code: "INVALID_UPDATE_LINK", message: "Invalid update link", details: nil))
      return
    }
    UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
  }
}
