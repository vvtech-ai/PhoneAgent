import Flutter
import Foundation
import UIKit
import Darwin

/// Installed metadata only. This plugin has no OTA or permission capability.
final class AppInfoChannel: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.vvtech.phone_agent/app_info", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(AppInfoChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "read" || call.method == "readC1" || call.method == "readEnvironment" else { result(FlutterMethodNotImplemented); return }
    guard let identifier = Bundle.main.bundleIdentifier,
          let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
          let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
          let code = Int(build), !identifier.isEmpty, !version.isEmpty, code >= 0 else {
      result(FlutterError(code: "APP_INFO_UNAVAILABLE", message: "Installed app metadata unavailable", details: nil)); return
    }
    if call.method == "read" {
      result(["packageName": identifier, "versionName": version, "versionCode": code])
    } else {
      var metadata: [String: Any] = ["appVersionName": version, "appVersionCode": code,
        "sdkVersionName": "1.0.0", "osName": "iOS",
        "osVersion": UIDevice.current.systemVersion,
        "deviceBrand": "Apple", "deviceModel": UIDevice.current.model,
        "deviceManufacturer": "Apple", "networkType": "UNKNOWN", "platform": "APP"]
      if call.method == "readEnvironment" { metadata["deviceHardwareModel"] = hardwareModel() }
      result(metadata)
    }
  }

  private func hardwareModel() -> String {
    var system = utsname()
    guard uname(&system) == 0 else { return "" }
    let capacity = MemoryLayout.size(ofValue: system.machine)
    return withUnsafePointer(to: &system.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: capacity) { String(cString: $0) }
    }
  }
}
