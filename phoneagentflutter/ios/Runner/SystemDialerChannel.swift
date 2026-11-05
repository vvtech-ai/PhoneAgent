import Flutter
import UIKit

/// Only hands a validated number to the system phone UI; never an Agent call.
final class SystemDialerChannel: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.vvtech.phone_agent/system_dialer",
      binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SystemDialerChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "open" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
      let number = args["number"] as? String,
      number.range(of: "^\\+?[0-9*#]+$", options: .regularExpression)
        == number.startIndex..<number.endIndex,
      let encodedNumber = number.addingPercentEncoding(
        withAllowedCharacters: CharacterSet(charactersIn: "0123456789+*")),
      let url = URL(string: "tel:\(encodedNumber)") else {
      result("invalid")
      return
    }
    guard UIApplication.shared.canOpenURL(url) else {
      result("unsupported")
      return
    }
    UIApplication.shared.open(url, options: [:]) { opened in
      result(opened ? "opened" : "failed")
    }
  }
}
