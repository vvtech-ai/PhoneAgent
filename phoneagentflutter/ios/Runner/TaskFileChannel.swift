import Flutter
import UIKit

final class TaskFileChannel: NSObject, FlutterPlugin, UIDocumentPickerDelegate, UIDocumentInteractionControllerDelegate {
  private weak var host: UIViewController?
  private let queue = DispatchQueue(label: "phone_agent.task_files")
  private var pending: Operation?
  private var saved = Set<URL>()
  private var preview: UIDocumentInteractionController?
  private var previewURL: URL?
  private var previewHost: UIViewController?
  private final class Operation {
    let id: String
    var reply: FlutterResult?
    var folder: URL?
    weak var picker: UIDocumentPickerViewController?
    private let lock = NSLock()
    private var stopped = false
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func cancel() { lock.lock(); stopped = true; lock.unlock() }
    init(_ id: String, _ reply: @escaping FlutterResult) { self.id = id; self.reply = reply }
  }
  static func register(with registrar: FlutterPluginRegistrar) { register(with: registrar, host: nil) }
  static func register(with registrar: FlutterPluginRegistrar, host: UIViewController?) {
    let instance = TaskFileChannel()
    instance.host = host
    let channel = FlutterMethodChannel(name: "phone_agent/task_files", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "save": save(call, result)
    case "cancel":
      if let args = call.arguments as? [String: Any], let operation = pending, args["id"] as? String == operation.id {
        operation.cancel()
        operation.picker?.dismiss(animated: true)
        // The worker owns cleanup until it reaches the main queue.
        if operation.folder != nil { finish(operation, nil) }
      }
      result(nil)
    case "exists":
      guard let args = call.arguments as? [String: Any], let raw = args["location"] as? String,
            let url = URL(string: raw), saved.contains(url) else { result(false); return }
      let scoped = url.startAccessingSecurityScopedResource()
      let exists = FileManager.default.fileExists(atPath: url.path)
      if scoped { url.stopAccessingSecurityScopedResource() }
      result(exists)
    case "open":
      guard let args = call.arguments as? [String: Any], let raw = args["location"] as? String,
            let url = URL(string: raw), saved.contains(url), let host = host,
            host.presentedViewController == nil else { fail(result); return }
      _ = url.startAccessingSecurityScopedResource()
      let document = UIDocumentInteractionController(url: url)
      document.delegate = self
      preview = document
      previewURL = url
      previewHost = host
      if document.presentPreview(animated: true) { result(nil) }
      else { clearPreview(); fail(result) }
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func save(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let docx = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    guard pending == nil, let args = call.arguments as? [String: Any], let id = args["id"] as? String,
          id.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil,
          let name = args["name"] as? String, !name.isEmpty, name.count <= 180,
          name.range(of: "[/\\\\\\x00-\\x1f]", options: .regularExpression) == nil,
          let mime = args["mime"] as? String,
          (mime == "text/csv" && name.lowercased().hasSuffix(".csv") || mime == docx && name.lowercased().hasSuffix(".docx") ||
           mime == "application/pdf" && name.lowercased().hasSuffix(".pdf") ||
           mime == "application/ofd" && name.lowercased().hasSuffix(".ofd") ||
           mime == "application/xml" && name.lowercased().hasSuffix(".xml")),
          let bytes = args["bytes"] as? FlutterStandardTypedData, !bytes.data.isEmpty,
          bytes.data.count <= 20 * 1024 * 1024 else { fail(result); return }
    let operation = Operation(id, result)
    pending = operation
    queue.async {
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent("task-export-\(UUID().uuidString)", isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false,
          attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let file = folder.appendingPathComponent(name)
        try bytes.data.write(to: file, options: .atomic)
        DispatchQueue.main.async {
          operation.folder = folder
          guard self.pending === operation, !operation.cancelled, let host = self.host,
                host.presentedViewController == nil else { self.finish(operation, nil, failed: !operation.cancelled); return }
          let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
          picker.delegate = self
          operation.picker = picker
          host.present(picker, animated: true)
        }
      } catch {
        try? FileManager.default.removeItem(at: folder)
        DispatchQueue.main.async { self.finish(operation, nil, failed: !operation.cancelled) }
      }
    }
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    if let operation = pending, operation.picker === controller { finish(operation, nil) }
  }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    if let operation = pending, operation.picker === controller {
      let url = operation.cancelled ? nil : urls.first
      if let url = url { saved.insert(url) }
      finish(operation, url?.absoluteString, failed: !operation.cancelled && url == nil)
    }
  }
  func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
    // Retain the guarded host for the lifetime of the system preview.
    return previewHost ?? UIViewController()
  }
  func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) { clearPreview() }
  private func clearPreview() { previewURL?.stopAccessingSecurityScopedResource(); previewURL = nil; preview = nil; previewHost = nil }
  private func finish(_ operation: Operation, _ location: String?, failed: Bool = false) {
    if pending === operation { pending = nil }
    if let folder = operation.folder { try? FileManager.default.removeItem(at: folder) }
    let reply = operation.reply
    operation.reply = nil
    if let reply = reply { if failed { fail(reply) } else { reply(location) } }
  }
  private func fail(_ reply: FlutterResult) {
    reply(FlutterError(code: "task_file_failed", message: "Task file unavailable", details: nil))
  }
}
