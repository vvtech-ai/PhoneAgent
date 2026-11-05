import AVFoundation
import Flutter
import Foundation

final class DomesticRecordingChannel: NSObject, FlutterPlugin {
  private let worker = DispatchQueue(label: "phoneagent.domestic.recording")
  private var busy = false
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "phone_agent/domestic_recording", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(DomesticRecordingChannel(), channel: channel)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      let root = try Self.privateRoot()
      if call.method == "directory" { result(root.path); return }
      guard call.method == "encode" else { result(FlutterMethodNotImplemented); return }
      guard !busy, let args = call.arguments as? [String: Any],
            let inputPath = args["pcmPath"] as? String, let outputPath = args["m4aPath"] as? String else {
        throw Self.failure()
      }
      let input = URL(fileURLWithPath: inputPath).resolvingSymlinksInPath()
      // Resolve the existing parent, not the not-yet-created M4A. On device,
      // Foundation can represent existing/nonexistent file URLs differently.
      let candidate = URL(fileURLWithPath: outputPath)
      let outputParent = candidate.deletingLastPathComponent().resolvingSymlinksInPath()
      let output = outputParent.appendingPathComponent(candidate.lastPathComponent)
      let prefix = root.resolvingSymlinksInPath().path + "/"
      guard input.path.hasPrefix(prefix),
            String(input.path.dropFirst(prefix.count)).range(of: "^translation-recordings/[a-f0-9]{64}/[a-f0-9]{64}/mix\\.pcm16$", options: .regularExpression) != nil,
            input.deletingLastPathComponent().resolvingSymlinksInPath().path == outputParent.path,
            output.lastPathComponent == "recording.m4a", !FileManager.default.fileExists(atPath: output.path) else {
        throw Self.failure()
      }
      busy = true
      worker.async {
        let success: Bool
        do { try Self.encode(input, output); success = true } catch { success = false }
        DispatchQueue.main.async {
          self.busy = false
          if success { result(nil) }
          else { result(FlutterError(code: "recording_encode_failed", message: "录音编码失败", details: nil)) }
        }
      }
    } catch {
      result(FlutterError(code: "recording_encode_unavailable", message: "录音编码不可用", details: nil))
    }
  }
  private static func privateRoot() throws -> URL {
    let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    var root = base.appendingPathComponent("domestic-recordings", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try root.setResourceValues(values)
    return root
  }
  private static func failure() -> NSError { NSError(domain: "phoneagent.recording", code: 1) }
  private static func encode(_ input: URL, _ output: URL) throws {
    let attributes = try FileManager.default.attributesOfItem(atPath: input.path)
    guard let size = (attributes[.size] as? NSNumber)?.intValue, size > 0,
          size <= 300 * 1024 * 1024, size % 2 == 0 else { throw failure() }
    let part = output.deletingLastPathComponent().appendingPathComponent("recording.encoding.m4a")
    guard !FileManager.default.fileExists(atPath: part.path) else { throw failure() }
    defer { try? FileManager.default.removeItem(at: part) }
    try autoreleasepool { try encodeFrames(input, part, size) }
    let encoded = try FileManager.default.attributesOfItem(atPath: part.path)
    guard let bytes = (encoded[.size] as? NSNumber)?.intValue, bytes > 0,
          bytes <= 300 * 1024 * 1024 else { throw failure() }
    try FileManager.default.moveItem(at: part, to: output)
    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: output.path)
  }
  private static func encodeFrames(_ input: URL, _ output: URL, _ size: Int) throws {
    let source = try FileHandle(forReadingFrom: input)
    defer { source.closeFile() }
    let audio = try AVAudioFile(forWriting: output, settings: [
      AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 16000,
      AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 48000])
    var remaining = size
    while remaining > 0 {
      try autoreleasepool {
        let data = source.readData(ofLength: min(8192, remaining))
        guard !data.isEmpty, data.count % 2 == 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: AVAudioFrameCount(data.count / 2)),
              let samples = buffer.floatChannelData else { throw failure() }
        buffer.frameLength = AVAudioFrameCount(data.count / 2)
        for index in 0..<(data.count / 2) {
          let raw = UInt16(data[index * 2]) | UInt16(data[index * 2 + 1]) << 8
          samples[0][index] = Float(Int16(bitPattern: raw)) / 32768
        }
        try audio.write(from: buffer)
        remaining -= data.count
      }
    }
  }
}
