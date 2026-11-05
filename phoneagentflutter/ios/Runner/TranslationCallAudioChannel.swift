import Flutter
import AVFoundation
import UIKit

enum TranslationCallAudioOwner {
  static var id: String?
  static var captureStarted = false
  static let lost = Notification.Name("PhoneAgentTranslationCallAudioLost")
  static func matches(_ token: String?) -> Bool {
    token != nil && token == id && captureStarted
  }
  static func reserved(_ token: String?) -> Bool { token != nil && token == id }
  static func invalidate() {
    guard id != nil else { return }
    id = nil
    captureStarted = false
    NotificationCenter.default.post(name: lost, object: nil)
  }
}

final class TranslationCallAudioChannel: NSObject, FlutterPlugin {
  private var owned: String?
  private var observers: [NSObjectProtocol] = []
  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = TranslationCallAudioChannel()
    let channel = FlutterMethodChannel(name: "phone_agent/translation_call_audio", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: channel)
    let center = NotificationCenter.default
    plugin.observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
      object: nil, queue: .main) { note in
      guard let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
        type == AVAudioSession.InterruptionType.began.rawValue else { return }
      TranslationCallAudioOwner.invalidate()
    })
    plugin.observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereLostNotification,
      object: nil, queue: .main) { _ in TranslationCallAudioOwner.invalidate() })
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let id = args["callAudioId"] as? String,
      id.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil else {
      result(failure()); return
    }
    switch call.method {
    case "acquire":
      guard UIApplication.shared.applicationState == .active else {
        result(failure("call_audio_background")); return
      }
      guard AVAudioSession.sharedInstance().recordPermission == .granted else {
        result(failure("call_audio_permission")); return
      }
      guard owned == nil, TranslationCallAudioOwner.id == nil else {
        result(failure("call_audio_busy")); return
      }
      owned = id
      TranslationCallAudioOwner.id = id
      result(true)
    case "release":
      if owned == id {
        if TranslationCallAudioOwner.id == id { TranslationCallAudioOwner.invalidate() }
        owned = nil
      }
      result(true)
    default: result(FlutterMethodNotImplemented)
    }
  }
  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    if owned != nil && owned == TranslationCallAudioOwner.id { TranslationCallAudioOwner.invalidate() }
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    owned = nil
  }
  deinit { observers.forEach(NotificationCenter.default.removeObserver) }
  private func failure(_ code: String = "call_audio_unavailable") -> FlutterError {
    FlutterError(code: code, message: "Foreground microphone admission required", details: nil)
  }
}
