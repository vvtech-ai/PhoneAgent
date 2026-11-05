import Flutter
import CoreLocation

/// Already-authorized foreground location only. No prompts or persisted coordinates.
final class AgentLocationChannel: NSObject, FlutterPlugin, CLLocationManagerDelegate {
  private var pending: FlutterResult?
  private var requestId: String?
  private var manager: CLLocationManager?
  private var coder: CLGeocoder?
  private var timeout: DispatchWorkItem?
  private var retry: DispatchWorkItem?
  private var retries = 0
  private var sample: CLLocation?
  private var latestLocation: CLLocation?
  private var bestObserved: CLLocation?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "phone_agent/agent_location", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(AgentLocationChannel(), channel: channel)
  }

  private func authorized(_ source: CLLocationManager) -> Bool {
    source.authorizationStatus == .authorizedAlways || source.authorizationStatus == .authorizedWhenInUse
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "read":
      guard pending == nil else { result(FlutterError(code: "busy", message: "Sample pending", details: nil)); return }
      guard let id = args?["requestId"] as? String, !id.isEmpty else {
        result(FlutterError(code: "invalid", message: "Missing request id", details: nil)); return
      }
      // Keep trusted samples separately. A fresh manager isolates delayed OS
      // callbacks from an earlier canceled acquisition.
      let source = CLLocationManager()
      manager = source
      guard authorized(source) else {
        latestLocation = nil
        NSLog("[AgentLocation] unavailable: permission")
        result(nil); return
      }
      pending = result
      requestId = id
      retries = 0
      bestObserved = nil
      source.delegate = self
      source.desiredAccuracy = kCLLocationAccuracyHundredMeters
      let deadline = DispatchWorkItem { [weak self] in
        guard self?.requestId == id else { return }
        if self?.sample != nil { self?.finish() }
        else { self?.finishWithFallback("timeout") }
      }
      timeout = deadline
      DispatchQueue.main.asyncAfter(deadline: .now() + 9, execute: deadline)
      NSLog("[AgentLocation] acquisition started")
      source.requestLocation()
    case "cancel":
      if args?["requestId"] as? String == requestId { finish(includeSample: false) }
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func valid(_ value: CLLocation, age: TimeInterval, accuracy: CLLocationAccuracy) -> Bool {
    let point = value.coordinate
    let elapsed = -value.timestamp.timeIntervalSinceNow
    return CLLocationCoordinate2DIsValid(point) && point.latitude.isFinite && point.longitude.isFinite &&
      !(point.latitude == 0 && point.longitude == 0) && elapsed >= -30 && elapsed <= age &&
      value.horizontalAccuracy >= 0 && value.horizontalAccuracy <= accuracy
  }

  private func better(_ candidates: [CLLocation?]) -> CLLocation? {
    candidates.compactMap { $0 }.filter { valid($0, age: 300, accuracy: 3000) }.min {
      max(0, -$0.timestamp.timeIntervalSinceNow) * 10000 + $0.horizontalAccuracy <
        max(0, -$1.timestamp.timeIntervalSinceNow) * 10000 + $1.horizontalAccuracy
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard manager === self.manager, pending != nil, sample == nil, let id = requestId else { return }
    guard authorized(manager) else {
      latestLocation = nil
      finish(includeSample: false); return
    }
    bestObserved = better([bestObserved] + locations.map { Optional($0) })
    let accuracy: CLLocationAccuracy = manager.accuracyAuthorization == .reducedAccuracy ? 3000 : 1500
    guard let location = locations.reversed().first(where: { valid($0, age: 120, accuracy: accuracy) }) else {
      retryOrFallback("invalid_sample"); return
    }
    sample = location
    latestLocation = location
    retry?.cancel()
    retry = nil
    manager.stopUpdatingLocation()
    NSLog("[AgentLocation] acquired current sample")
    let geocoder = CLGeocoder()
    coder = geocoder
    geocoder.reverseGeocodeLocation(location) { [weak self] places, _ in
      DispatchQueue.main.async {
        guard let self = self, self.requestId == id else { return }
        let place = places?.first
        let address = [place?.administrativeArea, place?.locality, place?.subLocality, place?.thoroughfare, place?.subThoroughfare]
          .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        self.finish(address)
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard manager === self.manager, pending != nil, sample == nil else { return }
    let native = error as NSError
    NSLog("[AgentLocation] native failure code=%ld", native.code)
    if !authorized(manager) || (native.domain == kCLErrorDomain && native.code == CLError.Code.denied.rawValue) {
      latestLocation = nil
      finish(includeSample: false)
    } else if native.domain == kCLErrorDomain && native.code == CLError.Code.locationUnknown.rawValue {
      retryOrFallback("location_unknown")
    } else {
      finishWithFallback("native_error")
    }
  }

  private func retryOrFallback(_ reason: String) {
    guard retry == nil, let id = requestId, let source = manager else { return }
    guard retries < 2 else { finishWithFallback(reason); return }
    retries += 1
    let work = DispatchWorkItem { [weak self] in
      guard let self = self, self.requestId == id, self.sample == nil else { return }
      self.retry = nil
      guard self.authorized(source) else {
        self.latestLocation = nil
        self.finish(includeSample: false); return
      }
      source.requestLocation()
    }
    retry = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
  }

  private func finishWithFallback(_ reason: String) {
    guard pending != nil, let source = manager, authorized(source) else {
      latestLocation = nil
      finish(includeSample: false); return
    }
    sample = better([bestObserved, latestLocation, source.location])
    if let value = sample { latestLocation = value }
    NSLog("[AgentLocation] fallback reason=%@ available=%@", reason, sample == nil ? "no" : "yes")
    // Nearby search needs coordinates; reverse geocoding must not extend the deadline.
    finish()
  }

  private func finish(_ address: String = "", includeSample: Bool = true) {
    let callback = pending
    let point = includeSample && manager.map(authorized) == true ? sample?.coordinate : nil
    pending = nil
    requestId = nil
    sample = nil
    bestObserved = nil
    timeout?.cancel()
    timeout = nil
    retry?.cancel()
    retry = nil
    manager?.stopUpdatingLocation()
    manager?.delegate = nil
    manager = nil
    coder?.cancelGeocode()
    coder = nil
    if let point = point { callback?(["lat": point.latitude, "lng": point.longitude, "address": address]) }
    else { callback?(nil) }
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    finish(includeSample: false)
    manager = nil
    latestLocation = nil
  }
}
