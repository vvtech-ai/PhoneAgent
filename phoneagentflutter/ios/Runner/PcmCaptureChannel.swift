import Flutter
import AVFoundation
import UIKit

/// Hardware-only pull adapter. Permission requests and ASR belong to Dart.
final class PcmCaptureChannel: NSObject, FlutterPlugin {
  private var current: Capture?
  private var observers: [NSObjectProtocol] = []
  private var closed = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = PcmCaptureChannel()
    let channel = FlutterMethodChannel(name: "phone_agent/pcm_capture", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: channel)
    plugin.observeInterruptions()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard !closed, let args = call.arguments as? [String: Any],
          let id = args["captureId"] as? String, !id.isEmpty, id.count <= 128 else {
      result(failure("capture_failed")); return
    }
    switch call.method {
    case "start": start(id, args["duplex"] as? Bool ?? false, args["callAudioId"] as? String,
                        args["speechInput"] as? Bool ?? false,
                        args["deferDelivery"] as? Bool ?? false, result)
    case "resumePreparedCall":
      guard let capture = current, capture.id == id, capture.duplex,
        TranslationCallAudioOwner.matches(capture.callAudioId),
        capture.engine?.isRunning == true, capture.resumeDelivery() else {
        result(failure("capture_interrupted")); return
      }
      result(true)
    case "speaker":
      guard let capture = current, capture.id == id, capture.duplex else {
        result(failure("capture_interrupted")); return
      }
      do {
        try AVAudioSession.sharedInstance().overrideOutputAudioPort(args["enabled"] as? Bool == true ? .speaker : .none)
        result(true)
      } catch { result(failure("capture_route_failed")) }
    case "read":
      guard let capture = current, capture.id == id else { result(nil); return }
      guard !capture.reading else { result(failure("capture_busy")); return }
      capture.reading = true
      read(capture, deadline: ProcessInfo.processInfo.systemUptime + 5, result: result)
    case "stop":
      guard let capture = current, capture.id == id else { result(true); return }
      result(stop(capture) ? true : failure("capture_stop_failed"))
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func start(_ id: String, _ duplex: Bool, _ callAudioId: String?, _ speechInput: Bool,
                     _ deferDelivery: Bool,
                     _ result: @escaping FlutterResult) {
    guard current == nil else { result(failure("capture_busy")); return }
    guard UIApplication.shared.applicationState == .active else {
      result(failure("capture_interrupted")); return
    }
    if callAudioId != nil && (!duplex || !TranslationCallAudioOwner.reserved(callAudioId)) {
      result(failure("capture_interrupted")); return
    }
    let session = AVAudioSession.sharedInstance()
    guard session.recordPermission == .granted else { result(failure("permission_denied")); return }
    let capture = Capture(id: id, session: session)
    if deferDelivery {
      guard duplex, TranslationCallAudioOwner.reserved(callAudioId) else {
        result(failure("capture_interrupted")); return
      }
      capture.deferDelivery()
    }
    capture.callAudioId = callAudioId
    current = capture // Retain even on failure until shutdown is confirmed.
    do {
      let engine: AVAudioEngine
      if duplex {
        capture.duplex = true
        engine = try PcmDuplexSession.acquire("capture:\(id)")
      } else {
        // Conversation speech uses the system voice-processing path to reduce
        // far-field speech; file/clone capture retains measurement and duplex
        // already owns its separate voiceChat session.
        try session.setCategory(.playAndRecord, mode: speechInput ? .voiceChat : .measurement,
                                options: [.defaultToSpeaker, .allowBluetooth])
        capture.sessionConfigured = true
        try session.setPreferredSampleRate(16000)
        try session.setActive(true)
        engine = AVAudioEngine()
      }
      capture.engine = engine
      let input = engine.inputNode
      if speechInput && !duplex {
        try input.setVoiceProcessingEnabled(true)
      }
      let format = input.outputFormat(forBus: 0)
      guard format.sampleRate > 0, format.channelCount > 0,
            let output = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true),
            let converter = AVAudioConverter(from: format, to: output) else {
        throw CaptureError.unavailable
      }
      input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak capture] buffer, _ in
        capture?.convert(buffer, converter: converter, format: output)
      }
      capture.hasTap = true
      engine.prepare()
      try engine.start()
      if TranslationCallAudioOwner.reserved(callAudioId) { TranslationCallAudioOwner.captureStarted = true }
      result(true)
    } catch {
      _ = stop(capture)
      result(failure("capture_failed"))
    }
  }

  private func read(_ capture: Capture, deadline: TimeInterval, result: @escaping FlutterResult) {
    guard current === capture else { capture.reading = false; result(nil); return }
    let sample = capture.take()
    if let error = sample.error {
      capture.reading = false; result(failure(error)); return
    }
    if sample.stopped { capture.reading = false; result(nil); return }
    if let bytes = sample.bytes {
      capture.reading = false; result(FlutterStandardTypedData(bytes: bytes)); return
    }
    if ProcessInfo.processInfo.systemUptime >= deadline {
      capture.reading = false; result(failure("capture_read_failed")); return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
      guard let self = self else { capture.reading = false; result(nil); return }
      self.read(capture, deadline: deadline, result: result)
    }
  }

  @discardableResult private func stop(_ capture: Capture) -> Bool {
    capture.invalidate()
    if let engine = capture.engine {
      if capture.hasTap { engine.inputNode.removeTap(onBus: 0); capture.hasTap = false }
      if !capture.duplex { engine.stop() }
      capture.engine = nil
    }
    do {
      if capture.duplex { try PcmDuplexSession.release("capture:\(capture.id)") }
      if capture.sessionConfigured {
        let session = AVAudioSession.sharedInstance()
        try session.setActive(false, options: .notifyOthersOnDeactivation)
        try session.setCategory(capture.oldCategory, mode: capture.oldMode, options: capture.oldOptions)
        try session.setPreferredSampleRate(capture.oldSampleRate)
        capture.sessionConfigured = false
      }
      if current === capture { current = nil }
      if TranslationCallAudioOwner.reserved(capture.callAudioId) { TranslationCallAudioOwner.captureStarted = false }
      return true
    } catch {
      // Do not claim audio ownership is free if session shutdown failed.
      return false
    }
  }

  private func observeInterruptions() {
    let center = NotificationCenter.default
    for name in [UIApplication.willResignActiveNotification,
                 AVAudioSession.interruptionNotification,
                 AVAudioSession.mediaServicesWereLostNotification,
                 TranslationCallAudioOwner.lost] {
      observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
        guard let self = self, let capture = self.current else { return }
        if name == TranslationCallAudioOwner.lost && capture.callAudioId == nil { return }
        if name == AVAudioSession.interruptionNotification {
          guard let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            type == AVAudioSession.InterruptionType.began.rawValue else { return }
        }
        if name == UIApplication.willResignActiveNotification && TranslationCallAudioOwner.matches(capture.callAudioId) { return }
        self.stop(capture) // Never auto-resume after interruption.
      })
    }
    observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                       object: nil, queue: .main) { [weak self] note in
      guard let self = self, let capture = self.current,
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
      self.stop(capture)
    })
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    closed = true
    if let capture = current { stop(capture) }
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
  }

  deinit { observers.forEach(NotificationCenter.default.removeObserver) }
  private func failure(_ code: String) -> FlutterError {
    FlutterError(code: code, message: "Microphone capture unavailable", details: nil)
  }
  private enum CaptureError: Error { case unavailable }

  private final class Capture {
    let id: String
    let oldCategory: AVAudioSession.Category
    let oldMode: AVAudioSession.Mode
    let oldOptions: AVAudioSession.CategoryOptions
    let oldSampleRate: Double
    var engine: AVAudioEngine?
    var reading = false, hasTap = false, sessionConfigured = false
    var duplex = false
    var callAudioId: String?
    private let lock = NSLock()
    private var buffer = Data()
    private var stopped = false
    private var delivering = true
    private var error: String?

    init(id: String, session: AVAudioSession) {
      self.id = id
      oldCategory = session.category; oldMode = session.mode
      oldOptions = session.categoryOptions; oldSampleRate = session.preferredSampleRate
    }

    func convert(_ input: AVAudioPCMBuffer, converter: AVAudioConverter, format: AVAudioFormat) {
      lock.lock()
      defer { lock.unlock() }
      guard !stopped, delivering, error == nil, input.frameLength > 0 else { return }
      let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * 16000 / input.format.sampleRate)) + 32
      guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
        error = "capture_read_failed"; return
      }
      var supplied = false
      var conversionError: NSError?
      let status = converter.convert(to: output, error: &conversionError) { _, state in
        if supplied { state.pointee = .noDataNow; return nil }
        supplied = true; state.pointee = .haveData; return input
      }
      guard status != .error, conversionError == nil else { error = "capture_read_failed"; return }
      let audio = output.audioBufferList.pointee.mBuffers
      guard output.frameLength > 0, let data = audio.mData else { return }
      let count = Int(output.frameLength) * 2
      guard count <= Int(audio.mDataByteSize), buffer.count + count <= 32000 else {
        error = "capture_overflow"; buffer.removeAll(); return
      }
      buffer.append(data.assumingMemoryBound(to: UInt8.self), count: count)
    }

    func take() -> (bytes: Data?, stopped: Bool, error: String?) {
      lock.lock()
      defer { lock.unlock() }
      guard !stopped, error == nil, !buffer.isEmpty else { return (nil, stopped, error) }
      let size = min(640, buffer.count)
      let frame = Data(buffer.prefix(size))
      buffer.removeFirst(size)
      return (frame, false, nil)
    }

    func invalidate() {
      lock.lock()
      stopped = true; buffer.removeAll()
      lock.unlock()
    }

    func deferDelivery() {
      lock.lock()
      delivering = false; buffer.removeAll()
      lock.unlock()
    }

    func resumeDelivery() -> Bool {
      lock.lock()
      defer { lock.unlock() }
      guard !stopped, error == nil else { return false }
      buffer.removeAll(); delivering = true
      return true
    }
  }
}

/// Main-thread shared ownership for full-duplex PCM only. Ordinary ASR/TTS keep
/// their existing independent sessions. Playback format changes retain capture.
enum PcmDuplexSession {
  private static var engine: AVAudioEngine?
  private static var owners = Set<String>()
  private static var oldCategory = AVAudioSession.Category.ambient
  private static var oldMode = AVAudioSession.Mode.default
  private static var oldOptions = AVAudioSession.CategoryOptions()
  private static var oldRate = 0.0

  static func acquire(_ owner: String) throws -> AVAudioEngine {
    if let engine = engine {
      owners.insert(owner)
      return engine
    }
    guard owner.hasPrefix("capture:"), AVAudioSession.sharedInstance().recordPermission == .granted else {
      throw NSError(domain: "PcmDuplex", code: 1)
    }
    let session = AVAudioSession.sharedInstance()
    oldCategory = session.category; oldMode = session.mode
    oldOptions = session.categoryOptions; oldRate = session.preferredSampleRate
    // Retain ownership before configuration so failed setup remains releasable.
    let next = AVAudioEngine()
    engine = next; owners.insert(owner)
    try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
    try session.setPreferredSampleRate(16000)
    try session.setActive(true)
    try session.overrideOutputAudioPort(.none)
    try next.inputNode.setVoiceProcessingEnabled(true)
    return next
  }

  static func release(_ owner: String) throws {
    guard owners.contains(owner) else { return }
    if owners.count > 1 { owners.remove(owner); return }
    engine?.stop()
    let session = AVAudioSession.sharedInstance()
    try session.setActive(false, options: .notifyOthersOnDeactivation)
    try session.setCategory(oldCategory, mode: oldMode, options: oldOptions)
    try session.setPreferredSampleRate(oldRate)
    owners.remove(owner); engine = nil
  }
}
