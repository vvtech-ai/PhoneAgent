import Flutter
import UIKit
import CryptoKit

final class RecordingExportChannel: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private weak var host: UIViewController?
  private let queue = DispatchQueue(label: "phone_agent.history_export")
  private var pending: Operation?
  private enum ExportError: Error { case unavailable }
  private final class Operation {
    let id: String
    var reply: FlutterResult?
    var staging: URL?
    weak var picker: UIDocumentPickerViewController?
    private let lock = NSLock()
    private var stopped = false
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func cancel() { lock.lock(); stopped = true; lock.unlock() }
    init(_ id: String, _ reply: @escaping FlutterResult) { self.id = id; self.reply = reply }
  }
  static func register(with registrar: FlutterPluginRegistrar) {
    register(with: registrar, host: nil)
  }
  static func register(with registrar: FlutterPluginRegistrar, host: UIViewController?) {
    let instance = RecordingExportChannel()
    instance.host = host
    let channel = FlutterMethodChannel(name: "phone_agent/history_recordings", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  private func root() throws -> URL {
    let cache = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true)
    let url = cache.appendingPathComponent("phoneagent-history-recordings", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    return url.resolvingSymlinksInPath()
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "root":
      do { result(try root().path) } catch { fail(result) }
    case "cancel":
      if let args = call.arguments as? [String: Any], let operation = pending,
         args["id"] as? String == operation.id {
        operation.cancel()
        operation.picker?.dismiss(animated: true)
        finish(operation, false)
      }
      result(nil)
    case "save": save(call, result)
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func save(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard pending == nil, let args = call.arguments as? [String: Any],
          let id = args["id"] as? String, id.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil,
          let path = args["path"] as? String, let size = args["size"] as? NSNumber, size.int64Value >= 0,
          let hash = args["sha256"] as? String,
          hash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { fail(result); return }
    let rawName = (args["name"] as? String ?? "recording.m4a")
      .replacingOccurrences(of: "[/\\\\\\x00-\\x1f]", with: "_", options: .regularExpression)
    let name = rawName.isEmpty || rawName == "." || rawName == ".." ? "recording.m4a" : String(rawName.prefix(180))
    let operation = Operation(id, result)
    pending = operation
    queue.async {
      var staging: URL?
      do {
        let source = URL(fileURLWithPath: path).standardizedFileURL
        let resolved = source.resolvingSymlinksInPath()
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard source == resolved, resolved.deletingLastPathComponent() == (try self.root()),
              values.isRegularFile == true, values.isSymbolicLink != true,
              values.fileSize == size.intValue,
              source.lastPathComponent.range(of: "^[a-f0-9]{64}\\.m4a$", options: .regularExpression) != nil else {
          throw ExportError.unavailable
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("history-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false,
          attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        staging = folder
        let destination = folder.appendingPathComponent(name)
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else { throw ExportError.unavailable }
        let input = try FileHandle(forReadingFrom: source)
        defer { input.closeFile() }
        let output = try FileHandle(forWritingTo: destination)
        defer { output.closeFile() }
        var digest = SHA256(), copied: Int64 = 0
        while true {
          guard !operation.cancelled else { throw ExportError.unavailable }
          let bytes = try input.read(upToCount: 64 * 1024) ?? Data()
          if bytes.isEmpty { break }
          copied += Int64(bytes.count)
          guard copied <= size.int64Value else { throw ExportError.unavailable }
          digest.update(data: bytes)
          try output.write(contentsOf: bytes)
        }
        try output.synchronize()
        guard copied == size.int64Value,
              digest.finalize().map({ String(format: "%02x", $0) }).joined() == hash else { throw ExportError.unavailable }
        DispatchQueue.main.async {
          operation.staging = folder
          guard self.pending === operation, let host = self.host,
                host.presentedViewController == nil else { self.finish(operation, nil); return }
          let picker = UIDocumentPickerViewController(forExporting: [destination], asCopy: true)
          picker.delegate = self
          operation.picker = picker
          host.present(picker, animated: true)
        }
      } catch {
        if let staging = staging { try? FileManager.default.removeItem(at: staging) }
        DispatchQueue.main.async { self.finish(operation, nil) }
      }
    }
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    if let operation = pending, operation.picker === controller { finish(operation, false) }
  }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    if let operation = pending, operation.picker === controller { finish(operation, !urls.isEmpty) }
  }
  private func finish(_ operation: Operation, _ success: Bool?) {
    if pending === operation { pending = nil }
    if let folder = operation.staging { try? FileManager.default.removeItem(at: folder) }
    let reply = operation.reply
    operation.reply = nil
    if let reply = reply { if let success = success { reply(success) } else { fail(reply) } }
  }
  private func fail(_ reply: FlutterResult) {
    reply(FlutterError(code: "recording_export_failed", message: "Recording export unavailable", details: nil))
  }
}
