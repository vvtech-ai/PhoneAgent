import Flutter
import Foundation

/// Pure read; no authorization prompt, persistent cache or account data.
final class DeviceClockChannel: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "phone_agent/device_clock", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(DeviceClockChannel(), channel: channel)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "read" else { result(FlutterMethodNotImplemented); return }
    let now = Date()
    let zone = TimeZone.current
    result(["epochMillis": Int64(now.timeIntervalSince1970 * 1000),
            "offsetSeconds": zone.secondsFromGMT(for: now), "timezone": zone.identifier])
  }
}
