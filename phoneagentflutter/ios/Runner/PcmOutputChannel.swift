import AVFoundation
import Flutter
import UIKit

/// Ordinary play waits for dataPlayedBack; translation enqueue has bounded admission.
final class PcmOutputChannel: NSObject, FlutterPlugin {
  private var current: Output?
  private var observers: [NSObjectProtocol] = []

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PcmOutputChannel()
    let channel = FlutterMethodChannel(name: "phone_agent/pcm_output", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.observe()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let id = args["outputId"] as? String, !id.isEmpty, id.count <= 128 else {
      result(failure("output_invalid")); return
    }
    switch call.method {
    case "start": start(id, args["sampleRate"] as? Int ?? 0, args["communication"] as? Bool ?? false,
                        args["duplex"] as? Bool ?? false, args["callAudioId"] as? String,
                        args["queuedTranslation"] as? Bool ?? false, result)
    case "play": play(id, (args["bytes"] as? FlutterStandardTypedData)?.data, result)
    case "enqueue": play(id, (args["bytes"] as? FlutterStandardTypedData)?.data, result, enqueue: true)
    case "drain": drain(id, result)
    case "statistics": statistics(id, result)
    case "enabled": enabled(id, args["enabled"] as? Bool ?? false, result)
    case "route": route(id, args["select"] as? String, result)
    case "stop":
      guard let output = current, output.id == id else { result(true); return }
      result(release(output) ? true : failure("output_stop_failed", details: output.failureDetails))
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func start(_ id: String, _ rate: Int, _ communication: Bool, _ duplex: Bool, _ callAudioId: String?, _ queuedTranslation: Bool, _ result: @escaping FlutterResult) {
    guard (UIApplication.shared.applicationState == .active || TranslationCallAudioOwner.matches(callAudioId)),
      (callAudioId == nil || (duplex && communication && TranslationCallAudioOwner.matches(callAudioId))) else {
      result(failure("output_interrupted")); return
    }
    guard !queuedTranslation || communication else { result(failure("output_invalid")); return }
    guard current == nil else { result(failure("output_busy")); return }
    guard (8000...48000).contains(rate),
          let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
              sampleRate: Double(rate), channels: 1, interleaved: false) else {
      result(failure("output_invalid")); return
    }
    let session = AVAudioSession.sharedInstance()
    let output = Output(id, rate, format, session)
    output.callAudioId = callAudioId
    output.queuedTranslation = queuedTranslation
    current = output
    var phase = "category"
    do {
      if duplex {
        output.duplex = true
        phase = "duplexAcquire"
        output.engine = try PcmDuplexSession.acquire("output:\(id)")
        output.routes = PcmCommunicationRoute(session)
      } else if communication {
        output.routes = PcmCommunicationRoute(session)
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
      } else { try session.setCategory(.playback, mode: .default, options: []) }
      phase = "activation"
      if !duplex { try session.setActive(true) }
      phase = "route"
      try output.routes?.select("earpiece")
      phase = "attach"
      output.engine.attach(output.player)
      output.attached = true
      phase = "connect"
      output.engine.connect(output.player, to: output.engine.mainMixerNode, format: format)
      phase = "engineStart"
      if !output.engine.isRunning { try output.engine.start() }
      phase = "playerPlay"
      output.player.play()
      result(true)
    } catch {
      let details = failureDetails(error, phase: phase, output: output)
      _ = release(output)
      result(failure("output_start_failed", details: details))
    }
  }

  private func play(_ id: String, _ data: Data?, _ result: @escaping FlutterResult, enqueue: Bool = false) {
    guard let output = current, output.id == id, !output.stopped, output.enabled else {
      result(failure("output_interrupted")); return
    }
    guard !enqueue || output.queuedTranslation else { result(failure("output_invalid")); return }
    guard let data = data, !data.isEmpty, data.count % 2 == 0,
          output.pendingBytes + data.count <= output.rate * 4 else {
      result(failure("output_capacity")); return
    }
    let frames = AVAudioFrameCount(data.count / 2)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: output.format, frameCapacity: frames),
          let samples = buffer.floatChannelData?[0] else {
      result(failure("output_play_failed")); return
    }
    buffer.frameLength = frames
    for i in 0..<Int(frames) {
      let bits = UInt16(data[i * 2]) | UInt16(data[i * 2 + 1]) << 8
      samples[i] = Float(Int16(bitPattern: bits)) / 32768.0
    }
    let token = UUID()
    output.pendingBytes += data.count
    let now = Int(ProcessInfo.processInfo.systemUptime * 1000)
    if let last = output.lastEnqueueMs { output.maxEnqueueGapMs = max(output.maxEnqueueGapMs, now - last) }
    output.lastEnqueueMs = now
    output.enqueuedBuffers += 1
    output.maxQueuedBytes = max(output.maxQueuedBytes, output.pendingBytes)
    output.pending[token] = (data.count, enqueue ? nil : result)
    output.player.scheduleBuffer(buffer, at: nil, options: [],
        completionCallbackType: .dataPlayedBack) { [weak self, weak output] _ in
      DispatchQueue.main.async {
        guard let self = self, let output = output,
              self.current === output, !output.stopped,
              let completed = output.pending.removeValue(forKey: token) else { return }
        output.pendingBytes -= completed.0
        output.playedBuffers += 1
        if output.pendingBytes == 0 { output.emptyTransitions += 1 }
        completed.1?(true)
        output.admission.played(pendingBytes: output.pendingBytes)
      }
    }
    if enqueue {
      output.admission.enqueue(pendingBytes: output.pendingBytes, highWater: output.rate,
                               completion: queuedCompletion(result))
    }
    // A missing hardware callback is a failure, never synthetic consumption.
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self, weak output] in
      guard let self = self, let output = output,
            self.current === output, output.pending[token] != nil else { return }
      _ = self.release(output, reason: output.queuedTranslation ? "output_stalled" : "output_interrupted")
    }
  }

  private func queuedCompletion(_ result: @escaping FlutterResult) -> (String?) -> Void {
    return { reason in
      if let reason = reason { result(FlutterError(code: reason, message: "PCM output unavailable", details: nil)) }
      else { result(true) }
    }
  }

  private func drain(_ id: String, _ result: @escaping FlutterResult) {
    guard let output = current, output.id == id, !output.stopped,
          output.queuedTranslation else { result(failure("output_interrupted")); return }
    output.admission.drain(pendingBytes: output.pendingBytes, completion: queuedCompletion(result))
  }

  private func statistics(_ id: String, _ result: @escaping FlutterResult) {
    guard let output = current, output.id == id, !output.stopped else {
      result(failure("output_interrupted")); return
    }
    result(["outputPlatform": 2, "outputQueuedMs": output.pendingBytes * 500 / output.rate,
      "outputMaxQueuedMs": output.maxQueuedBytes * 500 / output.rate,
      "outputEmptyTransitions": output.emptyTransitions,
      "outputMaxEnqueueGapMs": output.maxEnqueueGapMs,
      "outputEnqueuedBuffers": output.enqueuedBuffers, "outputPlayedBuffers": output.playedBuffers])
  }

  private func cancelPending(_ output: Output, _ code: String) {
    let pending = Array(output.pending.values)
    output.pending.removeAll()
    output.pendingBytes = 0
    for item in pending { item.1?(failure(code)) }
    output.admission.cancel(code)
  }

  private func enabled(_ id: String, _ enabled: Bool, _ result: @escaping FlutterResult) {
    guard let output = current, output.id == id, !output.stopped, output.routes != nil else {
      result(failure("output_interrupted")); return
    }
    output.enabled = false
    cancelPending(output, "output_interrupted")
    output.player.stop() // Discard queued buffers, not a pause-and-replay backlog.
    if enabled { output.player.play() }
    output.enabled = enabled
    result(true)
  }

  private func route(_ id: String, _ select: String?, _ result: @escaping FlutterResult) {
    guard let output = current, output.id == id, !output.stopped, let routes = output.routes else {
      result(failure("output_interrupted")); return
    }
    do {
      if let select = select { try routes.select(select) }
      result(try routes.snapshot())
    } catch { result(failure("output_route_failed")) }
  }

  private func release(_ output: Output, reason: String = "output_interrupted") -> Bool {
    output.stopped = true // stop also fires callbacks; invalidate them first.
    cancelPending(output, reason)
    if !output.released {
      output.player.stop()
      // A voice-processing duplex graph can abort when its live player is
      // detached. Stop the graph first; keep capture's tap/ownership intact.
      // A format replacement restarts this same engine in start().
      output.engine.stop()
      if output.attached {
        output.engine.disconnectNodeOutput(output.player)
        output.engine.detach(output.player)
        output.attached = false
      }
      output.released = true
    }
    do {
      let session = AVAudioSession.sharedInstance()
      if output.duplex {
        try PcmDuplexSession.release("output:\(output.id)")
      } else {
        try output.routes?.stop()
        try session.setActive(false, options: [.notifyOthersOnDeactivation])
        try session.setCategory(output.oldCategory, mode: output.oldMode, options: output.oldOptions)
      }
      if current === output { current = nil }
      return true
    } catch {
      output.failureDetails = failureDetails(error, phase: "release", output: output)
      return false // Keep ownership so an explicit stop can retry.
    }
  }

  private func observe() {
    let center = NotificationCenter.default
    for name in [UIApplication.didEnterBackgroundNotification,
                 AVAudioSession.mediaServicesWereLostNotification,
                 TranslationCallAudioOwner.lost] {
      observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        guard let self = self, let output = self.current else { return }
        if name == TranslationCallAudioOwner.lost && output.callAudioId == nil { return }
        if name == UIApplication.didEnterBackgroundNotification && TranslationCallAudioOwner.matches(output.callAudioId) { return }
        _ = self.release(output)
      })
    }
    observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
        object: nil, queue: .main) { [weak self] note in
      guard let self = self, let output = self.current,
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            type == AVAudioSession.InterruptionType.began.rawValue else { return }
      _ = self.release(output)
    })
    observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
        object: nil, queue: .main) { [weak self] note in
      guard let self = self, let output = self.current,
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
      if let routes = output.routes {
        do { _ = try routes.snapshot() } catch { _ = self.release(output) }
      } else { _ = self.release(output) }
    })
  }

  private func failureDetails(_ error: Error, phase: String, output: Output) -> [String: Any] {
    let native = error as NSError
    let session = AVAudioSession.sharedInstance()
    let domain: String
    switch native.domain {
    case NSOSStatusErrorDomain: domain = "osStatus"
    case "AVAudioSessionErrorDomain": domain = "audioSession"
    case NSCocoaErrorDomain: domain = "cocoa"
    default: domain = "other"
    }
    let ports = session.currentRoute.outputs.map(\.portType)
    let route = ports.isEmpty ? "none" : ports.contains(.builtInSpeaker) ? "speaker" :
      ports.contains(.builtInReceiver) ? "receiver" :
      ports.contains(where: { [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains($0) }) ? "bluetooth" :
      ports.contains(where: { [.headphones, .lineOut, .usbAudio].contains($0) }) ? "wired" : "other"
    return ["phase": phase, "domain": domain, "code": native.code,
            "appState": UIApplication.shared.applicationState.rawValue,
            "route": route, "engineRunning": output.engine.isRunning,
            "outputPresent": current === output, "outputId": output.id]
  }

  private func failure(_ code: String, details: [String: Any]? = nil) -> FlutterError {
    FlutterError(code: code, message: "PCM output unavailable", details: details)
  }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
    if let output = current { _ = release(output) }
  }

  private final class Output {
    let id: String
    var callAudioId: String?
    let rate: Int
    let format: AVAudioFormat
    var engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    let oldCategory: AVAudioSession.Category
    let oldMode: AVAudioSession.Mode
    let oldOptions: AVAudioSession.CategoryOptions
    var pending: [UUID: (Int, FlutterResult?)] = [:]
    let admission = PcmTranslationAdmission()
    var queuedTranslation = false
    var maxQueuedBytes = 0, maxEnqueueGapMs = 0, enqueuedBuffers = 0
    var playedBuffers = 0, emptyTransitions = 0
    var lastEnqueueMs: Int?
    var pendingBytes = 0
    var stopped = false, released = false, attached = false
    var enabled = true
    var failureDetails: [String: Any]?
    var duplex = false
    var routes: PcmCommunicationRoute?
    init(_ id: String, _ rate: Int, _ format: AVAudioFormat, _ session: AVAudioSession) {
      self.id = id
      self.rate = rate
      self.format = format
      oldCategory = session.category
      oldMode = session.mode
      oldOptions = session.categoryOptions
    }
  }
}

/// Only selects output routing; no input node/tap or microphone capture.
private final class PcmCommunicationRoute {
  private let session: AVAudioSession
  private var selected = "earpiece"
  init(_ session: AVAudioSession) { self.session = session }
  private var bluetooth: AVAudioSessionPortDescription? {
    session.availableInputs?.first { $0.portType == .bluetoothHFP || $0.portType == .bluetoothLE }
  }
  func select(_ value: String) throws {
    switch value {
    case "speaker":
      try session.setPreferredInput(nil)
      try session.overrideOutputAudioPort(.speaker)
    case "earpiece":
      try session.overrideOutputAudioPort(.none)
      try session.setPreferredInput(session.availableInputs?.first { $0.portType == .builtInMic })
    case "bluetooth":
      guard let input = bluetooth else { throw NSError(domain: "PCMRoute", code: 1) }
      try session.overrideOutputAudioPort(.none)
      try session.setPreferredInput(input)
    default: throw NSError(domain: "PCMRoute", code: 2)
    }
    selected = value
  }
  func snapshot() throws -> [String: Any] {
    let available = bluetooth != nil
    if selected == "bluetooth" && !available { try select("earpiece") }
    let ports = session.currentRoute.outputs.map(\.portType)
    let actual = ports.contains(.builtInSpeaker) ? "speaker" :
      (ports.contains(.bluetoothHFP) || ports.contains(.bluetoothLE) || ports.contains(.bluetoothA2DP) ? "bluetooth" : "earpiece")
    return ["selected": actual, "bluetooth": available]
  }
  func stop() throws {
    try session.overrideOutputAudioPort(.none)
    try session.setPreferredInput(nil)
  }
}

// BEGIN PCM_TRANSLATION_ADMISSION: pure callback rules, tested without audio hardware.
final class PcmTranslationAdmission {
  typealias Completion = (String?) -> Void
  private var admissions: [(Int, Completion)] = []
  private var drains: [Completion] = []
  func enqueue(pendingBytes: Int, highWater: Int, completion: @escaping Completion) {
    if pendingBytes <= highWater { completion(nil) }
    else { admissions.append((highWater, completion)) }
  }
  func drain(pendingBytes: Int, completion: @escaping Completion) {
    if pendingBytes == 0 { completion(nil) }
    else { drains.append(completion) }
  }
  func played(pendingBytes: Int) {
    let ready = admissions.filter { pendingBytes <= $0.0 }
    admissions.removeAll { pendingBytes <= $0.0 }
    let drained = pendingBytes == 0 ? drains : []
    if pendingBytes == 0 { drains.removeAll() }
    for waiter in ready { waiter.1(nil) }
    for waiter in drained { waiter(nil) }
  }
  func cancel(_ reason: String) {
    let waiting = admissions.map { $0.1 } + drains
    admissions.removeAll(); drains.removeAll()
    for waiter in waiting { waiter(reason) }
  }
}
// END PCM_TRANSLATION_ADMISSION
