import Flutter
import Foundation

/// Platform-only protection/backup policy; encryption and archive rules are Dart.
final class DiagnosticDirectoryChannel: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "phone_agent/diagnostic_directory",
                                       binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(DiagnosticDirectoryChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "directory" else {
      result(FlutterMethodNotImplemented); return
    }
    DispatchQueue.global(qos: .utility).async {
      do {
        let support = try FileManager.default.url(for: .applicationSupportDirectory,
          in: .userDomainMask, appropriateFor: nil, create: true)
        var directory = support.appendingPathComponent("diagnostics-v2", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
          attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        try FileManager.default.setAttributes(
          [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
          ofItemAtPath: directory.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        let actual = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        let protected = attributes[.protectionKey] as? FileProtectionType
        let payload: [String: Any] = ["path": directory.path,
          "excludedFromBackup": actual.isExcludedFromBackup == true,
          "protectedUntilFirstUnlock": protected == .completeUntilFirstUserAuthentication]
        DispatchQueue.main.async { result(payload) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "diagnostic_storage_unavailable",
            message: "Private diagnostic directory unavailable", details: nil))
        }
      }
    }
  }
}
