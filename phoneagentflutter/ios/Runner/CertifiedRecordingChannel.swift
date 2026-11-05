import Flutter
import Foundation
import CryptoKit
import Security

/// Private encrypted file boundary; account and recording semantics are Dart-owned.
final class CertifiedRecordingChannel: NSObject, FlutterPlugin {
  private static let queue = DispatchQueue(label: "phone_agent.certified_recording")
  private let limit = 11 * 1024 * 1024
  private enum StorageError: Error { case corrupt, unavailable }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "phone_agent/certified_recording",
                                       binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(CertifiedRecordingChannel(), channel: channel)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard ["read", "replace", "clear"].contains(call.method) else {
      result(FlutterMethodNotImplemented); return
    }
    guard let args = call.arguments as? [String: Any], let slot = args["slot"] as? String,
          slot.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else {
      result(FlutterError(code: "recording_unavailable", message: "Invalid recording slot", details: nil)); return
    }
    let payload = (args["payload"] as? FlutterStandardTypedData)?.data
    Self.queue.async {
      do {
        let url = try self.file(slot)
        switch call.method {
        case "read":
          guard FileManager.default.fileExists(atPath: url.path) else {
            DispatchQueue.main.async { result(nil) }; return
          }
          let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
          guard size > 28 && size <= self.limit else { throw StorageError.corrupt }
          let encrypted = try Data(contentsOf: url)
          let key = try self.key(create: false)
          let plain: Data
          do {
            plain = try AES.GCM.open(AES.GCM.SealedBox(combined: encrypted), using: key,
                                     authenticating: Data(slot.utf8))
          } catch { throw StorageError.corrupt }
          DispatchQueue.main.async { result(FlutterStandardTypedData(bytes: plain)) }
        case "replace":
          guard let plain = payload, !plain.isEmpty, plain.count <= self.limit - 64 else {
            throw StorageError.unavailable
          }
          let box = try AES.GCM.seal(plain, using: self.key(create: true),
                                     authenticating: Data(slot.utf8))
          guard let combined = box.combined else { throw StorageError.unavailable }
          try combined.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
          DispatchQueue.main.async { result(nil) }
        default:
          if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
          DispatchQueue.main.async { result(nil) }
        }
      } catch {
        let code = (error as? StorageError) == .corrupt ? "recording_corrupt" : "recording_unavailable"
        DispatchQueue.main.async {
          result(FlutterError(code: code, message: "Private recording storage unavailable", details: nil))
        }
      }
    }
  }
  private func file(_ slot: String) throws -> URL {
    let support = try FileManager.default.url(for: .applicationSupportDirectory,
      in: .userDomainMask, appropriateFor: nil, create: true)
    var directory = support.appendingPathComponent("flutter_certified_recording_v1", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try directory.setResourceValues(values)
    return directory.appendingPathComponent(slot + ".bin")
  }
  private func key(create: Bool) throws -> SymmetricKey {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "phone_agent.certified_recording.v1",
      kSecAttrAccount as String: "encryption-key",
      kSecAttrSynchronizable as String: false]
    var lookup = query
    lookup[kSecReturnData as String] = true
    lookup[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(lookup as CFDictionary, &item)
    if status == errSecSuccess, let data = item as? Data, data.count == 32 {
      return SymmetricKey(data: data)
    }
    guard status == errSecItemNotFound else { throw StorageError.unavailable }
    guard create else { throw StorageError.corrupt }
    let key = SymmetricKey(size: .bits256)
    var insertion = query
    insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    insertion[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
    let added = SecItemAdd(insertion as CFDictionary, nil)
    if added == errSecDuplicateItem { return try self.key(create: false) }
    guard added == errSecSuccess else { throw StorageError.unavailable }
    return key
  }
}
