import Flutter
import Foundation
import CryptoKit
import Security

/// Sandbox-only value storage. No client-supplied paths or legacy Keychain reads.
final class LocalStorageChannel: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "phone_agent.local_storage")
  private let manager = FileManager.default
  private let keyService = "phone_agent.local_storage.v1"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "phone_agent/local_storage",
                                       binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(LocalStorageChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    queue.async {
      do {
        let value = try self.perform(call)
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "local_storage_unavailable",
                              message: "Private storage unavailable", details: nil))
        }
      }
    }
  }

  private func directory() throws -> URL {
    let support = try manager.url(for: .applicationSupportDirectory,
      in: .userDomainMask, appropriateFor: nil, create: true)
    var root = support.appendingPathComponent("local-storage-v1", isDirectory: true)
    try manager.createDirectory(at: root, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    try manager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                              ofItemAtPath: root.path)
    var flags = URLResourceValues()
    flags.isExcludedFromBackup = true
    try root.setResourceValues(flags)
    guard try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true,
          try manager.attributesOfItem(atPath: root.path)[.protectionKey] as? FileProtectionType
            == .completeUntilFirstUserAuthentication else { throw StorageError.protection }
    return root
  }

  private func perform(_ call: FlutterMethodCall) throws -> Any? {
    let root = try directory()
    let marker = root.appendingPathComponent("installation")
    if call.method == "installed" {
      do {
        guard try String(contentsOf: marker, encoding: .utf8) == "v1" else {
          throw StorageError.format
        }
        return true
      } catch let error as CocoaError where error.code == .fileReadNoSuchFile { return false }
    }
    if call.method == "markInstalled" {
      try save(Data("v1".utf8), to: marker)
      return nil
    }
    guard let args = call.arguments as? [String: Any],
          let key = args["key"] as? String, !key.isEmpty, key.utf8.count <= 4096,
          let kind = args["kind"] as? String,
          kind == "preference" || kind == "encrypted" else { throw StorageError.format }
    let binding = Data("\(kind)|\(key)".utf8)
    let name = SHA256.hash(data: binding).map { String(format: "%02x", $0) }.joined()
    let url = root.appendingPathComponent("\(kind)-\(name)")
    switch call.method {
    case "read":
      let stored: Data
      do { stored = try Data(contentsOf: url) }
      catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
      let data: Data
      if kind == "encrypted" {
        let secret = try encryptionKey(create: false)
        data = try AES.GCM.open(AES.GCM.SealedBox(combined: stored),
                                using: secret, authenticating: binding)
      } else { data = stored }
      guard let text = String(data: data, encoding: .utf8) else { throw StorageError.format }
      return text
    case "write":
      guard let value = args["value"] as? String else { throw StorageError.format }
      let data = Data(value.utf8)
      if kind == "encrypted" {
        // Never replace a missing key when ciphertext already exists.
        let existing = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
          .contains { $0.lastPathComponent.hasPrefix("encrypted-") }
        let secret = try encryptionKey(create: !existing)
        guard let sealed = try AES.GCM.seal(data, using: secret, authenticating: binding).combined
          else { throw StorageError.format }
        try save(sealed, to: url)
      } else { try save(data, to: url) }
      return nil
    case "delete":
      do { try manager.removeItem(at: url) }
      catch let error as CocoaError where error.code == .fileNoSuchFile { }
      return nil
    default: throw StorageError.format
    }
  }

  private func save(_ data: Data, to url: URL) throws {
    try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    try manager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                              ofItemAtPath: url.path)
  }

  private func encryptionKey(create: Bool) throws -> SymmetricKey {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keyService, kSecAttrAccount as String: "encryption-key",
      kSecAttrSynchronizable as String: false]
    var read = query
    read[kSecReturnData as String] = true
    read[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(read as CFDictionary, &result)
    if status == errSecSuccess {
      guard let data = result as? Data, data.count == 32 else { throw StorageError.format }
      return SymmetricKey(data: data)
    }
    guard status == errSecItemNotFound, create else { throw StorageError.key }
    let key = SymmetricKey(size: .bits256)
    var add = query
    add[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
    add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw StorageError.key }
    return key
  }
  private enum StorageError: Error { case format, protection, key }
}
