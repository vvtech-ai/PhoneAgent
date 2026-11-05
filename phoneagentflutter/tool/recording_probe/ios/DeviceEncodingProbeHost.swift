import UIKit
import Flutter
import AVFoundation
import CryptoKit
import Darwin

@main final class RecordingDeviceProbeHost: UIResponder, UIApplicationDelegate {
  let runId = UUID().uuidString
  var window: UIWindow?
  let encoder = DomesticRecordingChannel()
  func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let w = UIWindow(frame: UIScreen.main.bounds)
    let vc = UIViewController(); vc.view.backgroundColor = .white
    w.rootViewController = vc; w.makeKeyAndVisible(); window = w
    DispatchQueue.main.async { self.run() }
    return true
  }
  func report(_ value: [String: Any]) {
    let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    var value = value; value["runId"] = runId
    try? JSONSerialization.data(withJSONObject: value).write(to: root.appendingPathComponent("encoding-probe-report.json"))
  }
  func checkRejections(input: URL, output: URL, root: URL, metrics: [String: Any]) {
    let cases = [
      ["pcmPath":input.path,"m4aPath":output.path], // Existing output.
      ["pcmPath":input.path,"m4aPath":output.deletingLastPathComponent().appendingPathComponent("other.m4a").path],
      ["pcmPath":input.path,"m4aPath":root.appendingPathComponent("recording.m4a").path],
      ["pcmPath":root.appendingPathComponent("mix.pcm16").path,"m4aPath":output.path],
    ]
    func next(_ index: Int) {
      if index == cases.count { var result = metrics; result["invalidPathsRejected"] = cases.count; report(result); return }
      encoder.handle(FlutterMethodCall(methodName:"encode",arguments:cases[index])) { result in
        guard let error = result as? FlutterError, error.code == "recording_encode_unavailable" else { self.report(["success":false,"stage":"path_rejection"]); return }
        next(index+1)
      }
    }
    next(0)
  }
  func run() {
    encoder.handle(FlutterMethodCall(methodName: "directory", arguments: nil)) { root in
      guard let path = root as? String else { self.report(["success": false,"stage":"directory"]); return }
      do {
        func hash(_ s: String) -> String { SHA256.hash(data: Data(s.utf8)).map { String(format:"%02x",$0) }.joined() }
        let dir = URL(fileURLWithPath: path).appendingPathComponent("translation-recordings/\(hash("synthetic-device"))/\(hash(UUID().uuidString))")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let canonical = realpath(dir.path, nil) else { throw NSError(domain:"probe",code:1) }
        let folder = String(cString: canonical); free(canonical)
        let input = URL(fileURLWithPath: folder+"/mix.pcm16"), output = URL(fileURLWithPath: folder+"/recording.m4a")
        var pcm = Data()
        for i in 0..<32000 {
          let value: Int16 = i < 16000 ? 0 : Int16(sin(Double(i) * 2 * .pi * 440 / 16000) * 11000)
          pcm.append(UInt8(truncatingIfNeeded: value));pcm.append(UInt8(truncatingIfNeeded:value >> 8))
        }
        try pcm.write(to: input)
        self.encoder.handle(FlutterMethodCall(methodName:"encode",arguments:["pcmPath":input.path,"m4aPath":output.path])) { result in
          if let error = result as? FlutterError { self.report(["success":false,"stage":"encode","platformCode":error.code]); return }
          do {
            let audio = try AVAudioFile(forReading: output)
            guard audio.fileFormat.sampleRate == 16000, audio.fileFormat.channelCount == 1,
                  audio.fileFormat.streamDescription.pointee.mFormatID == kAudioFormatMPEG4AAC,
                  audio.length == 32000,
                  let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: 32000) else { throw NSError(domain:"probe",code:2) }
            try audio.read(into: buffer)
            guard buffer.frameLength == 32000 else { throw NSError(domain:"probe",code:3) }
            let metrics: [String: Any] = ["success":true,"sampleRate":audio.fileFormat.sampleRate,"channels":audio.fileFormat.channelCount,"frames":audio.length,
              "encodedBytes":try FileManager.default.attributesOfItem(atPath:output.path)[.size] ?? 0]
            self.checkRejections(input: input, output: output, root: URL(fileURLWithPath: path), metrics: metrics)
          } catch { self.report(["success":false,"stage":"decode"]) }
        }
      } catch { self.report(["success":false,"stage":"fixture"]) }
    }
  }
}
