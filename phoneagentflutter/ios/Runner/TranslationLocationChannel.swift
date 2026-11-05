import Flutter
import CoreLocation
import UIKit

/// Only system permission, one location and reverse geocoding. No business cache.
final class TranslationLocationChannel: NSObject, FlutterPlugin, CLLocationManagerDelegate {
  private var pending: FlutterResult?
  private var requestId: String?
  private var manager: CLLocationManager?
  private var geocoder: CLGeocoder?
  private var timeout: DispatchWorkItem?
  private var locating = false
  private var geocoding = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "phone_agent/translation_location",
                                       binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(TranslationLocationChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "locate":
      guard pending == nil else {
        result(FlutterError(code: "location_busy", message: "Location request active", details: nil)); return
      }
      guard let id = args?["requestId"] as? String, !id.isEmpty else {
        result(FlutterError(code: "invalid", message: "Missing request id", details: nil)); return
      }
      pending = result
      requestId = id
      let location = CLLocationManager()
      manager = location
      location.delegate = self
      location.desiredAccuracy = kCLLocationAccuracyKilometer
      armTimeout(90)
      switch location.authorizationStatus {
      case .authorizedAlways, .authorizedWhenInUse: locate(location)
      case .notDetermined: location.requestWhenInUseAuthorization()
      case .denied, .restricted: finish("blocked")
      @unknown default: finish("unavailable")
      }
    case "cancel":
      if args?["requestId"] as? String == requestId { finish("failed") }
      result(nil)
    case "openSettings":
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(FlutterError(code: "settings_failed", message: "Settings unavailable", details: nil)); return
      }
      UIApplication.shared.open(url) { opened in
        if opened { result(nil) }
        else { result(FlutterError(code: "settings_failed", message: "Settings unavailable", details: nil)) }
      }
    default: result(FlutterMethodNotImplemented)
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard manager === self.manager, pending != nil else { return }
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse: locate(manager)
    case .denied, .restricted: finish("blocked")
    default: break
    }
  }

  private func locate(_ manager: CLLocationManager) {
    guard !locating, !geocoding, pending != nil else { return }
    locating = true
    armTimeout(30)
    manager.requestLocation()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard manager === self.manager, pending != nil, !geocoding,
          let id = requestId, let location = locations.last else { return }
    let point = location.coordinate
    guard CLLocationCoordinate2DIsValid(point), point.latitude.isFinite,
          point.longitude.isFinite, !(point.latitude == 0 && point.longitude == 0),
          location.horizontalAccuracy >= 0 else { finish("failed"); return }
    geocoding = true
    manager.stopUpdatingLocation()
    let coder = CLGeocoder()
    geocoder = coder
    coder.reverseGeocodeLocation(location) { [weak self] places, _ in
      DispatchQueue.main.async {
        guard let self = self, self.requestId == id else { return }
        let iso = places?.first?.isoCountryCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let iso = iso, iso.range(of: "^[A-Z]{2}$", options: .regularExpression) != nil {
          self.finish("resolved", iso: iso)
        } else { self.finish("failed") }
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard manager === self.manager, pending != nil, !geocoding else { return }
    finish(manager.authorizationStatus == .denied ? "blocked" : "failed")
  }

  private func armTimeout(_ seconds: Double) {
    timeout?.cancel()
    let id = requestId
    let task = DispatchWorkItem { [weak self] in
      guard let self = self, self.requestId == id else { return }
      self.finish("failed")
    }
    timeout = task
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: task)
  }

  private func finish(_ status: String, iso: String? = nil) {
    let callback = pending
    pending = nil
    requestId = nil
    timeout?.cancel()
    timeout = nil
    manager?.stopUpdatingLocation()
    manager?.delegate = nil
    manager = nil
    geocoder?.cancelGeocode()
    geocoder = nil
    locating = false
    geocoding = false
    var response: [String: Any] = ["status": status]
    if let iso = iso { response["countryIso"] = iso }
    callback?(response)
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) { finish("failed") }
}
