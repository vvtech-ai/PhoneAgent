import Flutter
import AVFoundation
import Foundation

@objc(PhoneAgentRecordingProbeInspector)
final class RecordingProbeInspector: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "phone_agent/synthetic_recording_inspector", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(RecordingProbeInspector(), channel: channel)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "inspect", let args = call.arguments as? [String: Any], let path = args["m4aPath"] as? String else { result(FlutterMethodNotImplemented); return }
    DispatchQueue.global().async {
      do {
        let metrics = try Self.inspect(URL(fileURLWithPath: path))
        DispatchQueue.main.async { result(metrics) }
      } catch { DispatchQueue.main.async { result(FlutterError(code: "synthetic_inspection_failed", message: "Synthetic AAC inspection failed", details: nil)) } }
    }
  }
  private static func inspect(_ url: URL) throws -> [String: Any] {
    let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("domestic-recordings")
    guard url.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/"), url.lastPathComponent == "recording.m4a" else { throw failure() }
    let audio = try AVAudioFile(forReading: url)
    guard audio.fileFormat.streamDescription.pointee.mFormatID == kAudioFormatMPEG4AAC,
      audio.fileFormat.sampleRate == 16000, audio.fileFormat.channelCount == 1,
      audio.length > 0 && audio.length < 100000,
      let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: 4096),
      let samples = buffer.floatChannelData else { throw failure() }
    var frames = 0, silentCount = 0, toneCount = 0
    var silentEnergy = 0.0, toneEnergy = 0.0
    while audio.framePosition < audio.length {
      try audio.read(into: buffer)
      guard buffer.frameLength > 0 else { throw failure() }
      for index in 0..<Int(buffer.frameLength) {
        let value = Double(samples[0][index])
        if frames < 9600 { silentEnergy += value * value; silentCount += 1 }
        if frames >= 24000 { toneEnergy += value * value; toneCount += 1 }
        frames += 1
      }
    }
    guard silentCount > 0 && toneCount > 0 else { throw failure() }
    return ["codec": "audio/mp4a-latm", "sampleRate": 16000, "channels": 1,
      "durationSeconds": Double(audio.length) / 16000, "decodedFrames": frames,
      "silenceRms": sqrt(silentEnergy / Double(silentCount)), "toneRms": sqrt(toneEnergy / Double(toneCount))]
  }
  private static func failure() -> NSError { NSError(domain: "synthetic.recording.probe", code: 1) }
}
