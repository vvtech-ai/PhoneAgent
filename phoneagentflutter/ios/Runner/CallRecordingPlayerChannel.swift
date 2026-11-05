import AVFoundation
import Flutter
import UIKit

final class CallRecordingPlayerChannel: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var players: [String: Session] = [:]
  private var background: NSObjectProtocol?
  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = CallRecordingPlayerChannel()
    registrar.addMethodCallDelegate(instance, channel: FlutterMethodChannel(
      name: "phone_agent/call_recording_player", binaryMessenger: registrar.messenger()))
    FlutterEventChannel(name: "phone_agent/call_recording_player/events",
      binaryMessenger: registrar.messenger()).setStreamHandler(instance)
    instance.background = NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
    ) { [weak instance] _ in instance?.players.values.forEach { $0.pause() } }
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let id = args["playerId"] as? String else {
      result(FlutterError(code: "invalid", message: "Missing player", details: nil)); return
    }
    let generation = (args["generation"] as? NSNumber)?.intValue ?? 0
    if call.method == "stop" { players.removeValue(forKey: id)?.close(); result(nil); return }
    if call.method == "prepare" {
      players.removeValue(forKey: id)?.close()
      guard let source = args["source"] as? String else {
        result(FlutterError(code: "invalid", message: "Missing source", details: nil)); return
      }
      let remote = args["remote"] as? Bool ?? false
      guard let url = remote ? URL(string: source) : URL(fileURLWithPath: source) else {
        result(FlutterError(code: "invalid", message: "Invalid source", details: nil)); return
      }
      let session = Session(id: id, generation: generation) { [weak self] values in
        guard self?.players[id]?.generation == generation else { return }
        self?.sink?(values)
      }
      players[id] = session
      session.prepare(url: url, reply: result)
      return
    }
    guard let session = players[id], session.generation == generation else {
      result(FlutterError(code: "playback", message: "Recording unavailable", details: nil)); return
    }
    do {
      switch call.method {
      case "play": try session.play(rewind: true)
      case "resume": try session.play(rewind: false)
      case "pause": session.pause()
      default: result(FlutterMethodNotImplemented); return
      }
      result(nil)
    } catch { result(FlutterError(code: "playback", message: "Recording playback unavailable", details: nil)) }
  }
  deinit {
    if let background = background { NotificationCenter.default.removeObserver(background) }
    players.values.forEach { $0.close() }
  }

  private final class Session {
    let generation: Int
    private let id: String
    private let receive: ([String: Any]) -> Void
    private var player: AVPlayer?
    private var status: NSKeyValueObservation?
    private var progress: Any?
    private var completed: NSObjectProtocol?
    private var failed: NSObjectProtocol?
    private var timeout: DispatchWorkItem?
    private var reply: FlutterResult?
    private var closed = false, playing = false
    init(id: String, generation: Int, receive: @escaping ([String: Any]) -> Void) {
      self.id = id; self.generation = generation; self.receive = receive
    }
    private func emit(_ type: String, _ values: [String: Any] = [:]) {
      guard !closed else { return }
      receive(values.merging(["playerId": id, "generation": generation, "type": type]) { _, new in new })
    }
    func prepare(url: URL, reply: @escaping FlutterResult) {
      self.reply = reply
      let expiry = DispatchWorkItem { [weak self] in self?.finishPrepare(error: true); self?.close() }
      timeout = expiry
      DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: expiry)
      let asset = AVURLAsset(url: url)
      asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self] in
        DispatchQueue.main.async {
          guard let self = self, !self.closed else { return }
          let item = AVPlayerItem(asset: asset)
          if let track = asset.tracks(withMediaType: .audio).first {
            let meter = RecordingWaveformTap { [weak self] levels in
              guard self?.playing == true else { return }
              self?.emit("waveform", ["levels": levels])
            }
            item.audioMix = meter.mix(track: track)
          }
          let player = AVPlayer(playerItem: item)
          self.player = player
          self.status = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
              if item.status == .readyToPlay { self?.finishPrepare(error: false) }
              else if item.status == .failed { self?.finishPrepare(error: true); self?.emit("failed") }
            }
          }
          self.progress = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 5), queue: .main) {
            [weak self] time in
            guard let self = self, self.playing, time.seconds.isFinite else { return }
            self.emit("position", ["positionMillis": Int(time.seconds * 1000)])
          }
          self.completed = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
            object: item, queue: .main) { [weak self] _ in self?.playing = false; self?.emit("completed") }
          self.failed = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item, queue: .main) { [weak self] _ in self?.playing = false; self?.emit("failed") }
        }
      }
    }
    private func finishPrepare(error: Bool) {
      guard !closed, let reply = reply else { return }
      self.reply = nil
      timeout?.cancel(); timeout = nil
      let seconds = player?.currentItem?.duration.seconds ?? 0
      reply(error ? FlutterError(code: "prepare", message: "Recording unavailable", details: nil)
        : (seconds.isFinite && seconds > 0 ? Int(seconds * 1000) : 0))
    }
    func play(rewind: Bool) throws {
      guard !closed, let player = player else { return }
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
      playing = true
      if rewind {
        player.seek(to: .zero) { [weak self] _ in
          if self?.playing == true && self?.closed == false { self?.player?.play() }
        }
      } else { player.play() }
    }
    func pause() { playing = false; player?.pause(); emit("paused") }
    func close() {
      guard !closed else { return }
      reply?(FlutterError(code: "cancelled", message: "Recording preparation cancelled", details: nil))
      reply = nil; closed = true; playing = false
      timeout?.cancel(); timeout = nil
      status?.invalidate(); status = nil
      if let progress = progress { player?.removeTimeObserver(progress) }
      progress = nil
      for observer in [completed, failed].compactMap({ $0 }) { NotificationCenter.default.removeObserver(observer) }
      completed = nil; failed = nil
      player?.pause(); player?.replaceCurrentItem(with: nil); player = nil
    }
  }
}
