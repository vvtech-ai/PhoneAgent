import Flutter
import Contacts
import CoreLocation
import AVFoundation

/// Authorization boundary only: no recording, contact fetch, or location read.
final class PermissionChannel: NSObject, FlutterPlugin, CLLocationManagerDelegate {
  private var pending: FlutterResult?
  private var pendingKey: String?
  private var location: CLLocationManager?
  private let contacts = CNContactStore()

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "phone_agent/permissions",
                                       binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(PermissionChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "locationStatus" {
      switch locationManager().authorizationStatus {
      case .authorizedAlways, .authorizedWhenInUse: result("granted")
      case .notDetermined: result("denied")
      case .denied, .restricted: result("blocked")
      @unknown default: result("unavailable")
      }
      return
    }
    guard call.method == "resolve" else { result(FlutterMethodNotImplemented); return }
    guard let args = call.arguments as? [String: Any],
          let key = args["permission"] as? String,
          ["contacts", "microphone", "location"].contains(key) else {
      result("unavailable"); return
    }
    if granted(key) { result("granted"); return }
    if blocked(key) { result("blocked"); return }
    guard args["request"] as? Bool == true else { result("denied"); return }
    guard pending == nil else {
      result(FlutterError(code: "permission_busy", message: "Permission request active", details: nil))
      return
    }
    pending = result
    pendingKey = key
    switch key {
    case "contacts":
      guard CNContactStore.authorizationStatus(for: .contacts) == .notDetermined else {
        finish("blocked"); return
      }
      contacts.requestAccess(for: .contacts) { [weak self] allowed, error in
        DispatchQueue.main.async {
          guard let self = self else { return }
          if !allowed && CNContactStore.authorizationStatus(for: .contacts) == .notDetermined && error != nil {
            self.fail()
          } else {
            self.finish(self.granted("contacts") ? "granted" : "blocked")
          }
        }
      }
    case "microphone":
      AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
        DispatchQueue.main.async { self?.finish(allowed ? "granted" : "blocked") }
      }
    case "location":
      let manager = locationManager()
      guard manager.authorizationStatus == .notDetermined else {
        finish("blocked"); return
      }
      manager.requestWhenInUseAuthorization()
    default:
      finish("unavailable")
    }
  }

  private func locationManager() -> CLLocationManager {
    if let location = location { return location }
    let manager = CLLocationManager()
    manager.delegate = self
    location = manager
    return manager
  }

  private func granted(_ key: String) -> Bool {
    switch key {
    case "contacts":
      let status = CNContactStore.authorizationStatus(for: .contacts)
      // iOS18 limited contacts is usable; raw value keeps Xcode15 compatibility.
      return status == .authorized || status.rawValue == 4
    case "microphone":
      return AVAudioSession.sharedInstance().recordPermission == .granted
    case "location":
      let status = locationManager().authorizationStatus
      return status == .authorizedWhenInUse || status == .authorizedAlways
    default: return false
    }
  }

  private func blocked(_ key: String) -> Bool {
    switch key {
    case "contacts":
      let status = CNContactStore.authorizationStatus(for: .contacts)
      return status == .denied || status == .restricted
    case "microphone":
      return AVAudioSession.sharedInstance().recordPermission == .denied
    case "location":
      let status = locationManager().authorizationStatus
      return status == .denied || status == .restricted
    default: return false
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard pendingKey == "location", manager.authorizationStatus != .notDetermined else { return }
    finish(granted("location") ? "granted" : "blocked")
  }

  private func finish(_ status: String) {
    let callback = pending
    pending = nil
    pendingKey = nil
    callback?(status)
  }

  private func fail() {
    let callback = pending
    pending = nil
    pendingKey = nil
    callback?(FlutterError(code: "permission_failed", message: "Permission request unavailable", details: nil))
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    location?.delegate = nil
    location = nil
    fail()
  }
}
