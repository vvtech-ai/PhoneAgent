#!/usr/bin/env python3
"""Execute the production iOS channel with deterministic OS/Flutter boundaries.

Host Swift runner: no GPS, system permission changes, network, or phone data.
Only CoreLocation and Flutter are substituted; all channel state and decisions
are executed from ios/Runner/AgentLocationChannel.swift without rewriting it.
"""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FLUTTER = '''
@_exported import Foundation
public typealias FlutterResult = (Any?) -> Void
public protocol FlutterPlugin {}
public class FlutterMethodCall {
  public let method: String
  public let arguments: Any?
  public init(_ method: String, _ arguments: Any?) { self.method = method; self.arguments = arguments }
}
public class FlutterError {
  public init(code: String, message: String?, details: Any?) {}
}
public class FlutterPluginRegistrar {
  public func messenger() -> Any { NSObject() }
  public func addMethodCallDelegate(_ delegate: Any, channel: FlutterMethodChannel) {}
}
public class FlutterMethodChannel {
  public init(name: String, binaryMessenger: Any) {}
}
public let FlutterMethodNotImplemented = NSObject()
'''
CORE_LOCATION = '''
import Foundation
public typealias CLLocationAccuracy = Double
public let kCLLocationAccuracyBest = -1.0
public let kCLLocationAccuracyHundredMeters = 100.0
public enum CLAuthorizationStatus { case notDetermined, restricted, denied, authorizedAlways, authorizedWhenInUse }
public enum CLAccuracyAuthorization { case fullAccuracy, reducedAccuracy }
public struct CLLocationCoordinate2D {
  public let latitude: Double
  public let longitude: Double
  public init(latitude: Double, longitude: Double) { self.latitude = latitude; self.longitude = longitude }
}
public func CLLocationCoordinate2DIsValid(_ p: CLLocationCoordinate2D) -> Bool {
  p.latitude.isFinite && p.longitude.isFinite && abs(p.latitude) <= 90 && abs(p.longitude) <= 180
}
public class CLLocation {
  public let coordinate: CLLocationCoordinate2D
  public let horizontalAccuracy: Double
  public let timestamp: Date
  public init(coordinate: CLLocationCoordinate2D, altitude: Double, horizontalAccuracy: Double,
              verticalAccuracy: Double, timestamp: Date) {
    self.coordinate = coordinate; self.horizontalAccuracy = horizontalAccuracy; self.timestamp = timestamp
  }
}
public protocol CLLocationManagerDelegate: AnyObject {
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
}
public class CLLocationManager: NSObject {
  public static var created = [CLLocationManager]()
  public static var seed: CLLocation?
  public static var status = CLAuthorizationStatus.authorizedWhenInUse
  public weak var delegate: CLLocationManagerDelegate?
  public var authorizationStatus = CLLocationManager.status
  public var accuracyAuthorization = CLAccuracyAuthorization.fullAccuracy
  public var desiredAccuracy = kCLLocationAccuracyBest
  public var location: CLLocation? = CLLocationManager.seed
  public var requests = 0
  public override init() { super.init(); Self.created.append(self) }
  public func requestLocation() { requests += 1 }
  public func stopUpdatingLocation() {}
}
public let kCLErrorDomain = "kCLErrorDomain"
public struct CLError {
  public enum Code: Int { case locationUnknown = 0, denied = 1, network = 2 }
}
public class CLPlacemark {
  public var administrativeArea: String?; public var locality: String?; public var subLocality: String?
  public var thoroughfare: String?; public var subThoroughfare: String?
}
public class CLGeocoder {
  public static var created = [CLGeocoder]()
  public var completion: (([CLPlacemark]?, Error?) -> Void)?
  public init() { Self.created.append(self) }
  public func reverseGeocodeLocation(_ location: CLLocation, completionHandler: @escaping ([CLPlacemark]?, Error?) -> Void) {
    completion = completionHandler
  }
  public func cancelGeocode() {}
}
'''
TESTS = '''
import Foundation
import Flutter
import CoreLocation

@main struct AgentLocationTests {
  static var failures = 0
  static var checks = 0
  static func check(_ value: Bool, _ message: String) {
    checks += 1
    if !value { failures += 1; print("FAIL: " + message) }
  }
  static func point(_ age: Double = 10, _ accuracy: Double = 50, _ lat: Double = 1, _ lng: Double = 2) -> CLLocation {
    CLLocation(coordinate: .init(latitude: lat, longitude: lng), altitude: 0,
      horizontalAccuracy: accuracy, verticalAccuracy: 0, timestamp: Date().addingTimeInterval(-age))
  }
  static func reset(_ seed: CLLocation? = nil) {
    CLLocationManager.created = []; CLLocationManager.seed = seed
    CLLocationManager.status = .authorizedWhenInUse; CLGeocoder.created = []
  }
  static func error(_ code: CLError.Code) -> NSError { NSError(domain: kCLErrorDomain, code: code.rawValue) }
  static func flush(_ seconds: Double = 0.05) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
  static func read(_ channel: AgentLocationChannel, _ id: String, _ callback: @escaping FlutterResult) {
    channel.handle(FlutterMethodCall("read", ["requestId": id]), result: callback)
  }
  static func coordinate(_ result: Any?) -> Bool {
    let data = result as? [String: Any]
    return data?["lat"] as? Double == 1 && data?["lng"] as? Double == 2
  }
  static func main() {
    reset(point(180))
    do {
      let channel = AgentLocationChannel(); var values = [Any?]()
      read(channel, "fallback") { values.append($0) }
      let manager = CLLocationManager.created.last!
      channel.locationManager(manager, didFailWithError: error(.network)); flush()
      check(values.count == 1 && coordinate(values.first ?? nil), "network failure returns trusted system cache")
    }
    for seed in [point(301), point(10, 3001), point(10, -1), point(10, 50, 0, 0), point(-60)] {
      reset(seed)
      let channel = AgentLocationChannel(); var values = [Any?]()
      read(channel, "untrusted") { values.append($0) }
      channel.locationManager(CLLocationManager.created.last!, didFailWithError: error(.network)); flush()
      check(values.count == 1 && values[0] == nil, "untrusted cache is rejected")
    }
    reset(point(180))
    do {
      let channel = AgentLocationChannel(); var values = [Any?]()
      read(channel, "deadline") { values.append($0) }
      flush(9.2)
      check(values.count == 1 && coordinate(values.first ?? nil), "deadline returns trusted cache within budget")
    }
    reset()
    do {
      let channel = AgentLocationChannel(); var values = [Any?]()
      read(channel, "retry") { values.append($0) }
      let manager = CLLocationManager.created.last!
      channel.locationManager(manager, didFailWithError: error(.locationUnknown)); flush(0.9)
      check(values.isEmpty && manager.requests == 2, "temporary unknown location retries without ending request")
      channel.locationManager(manager, didUpdateLocations: [point()])
      CLGeocoder.created.last?.completion?(nil, error(.network)); flush()
      check(values.count == 1 && coordinate(values.first ?? nil), "geocoder failure preserves acquired coordinates")
    }
    reset()
    do {
      let channel = AgentLocationChannel(); var values = [Any?]()
      read(channel, "approximate") { values.append($0) }
      let manager = CLLocationManager.created.last!; manager.accuracyAuthorization = .reducedAccuracy
      channel.locationManager(manager, didUpdateLocations: [point(10, 2000)])
      CLGeocoder.created.last?.completion?(nil, nil); flush()
      check(values.count == 1 && coordinate(values.first ?? nil), "approximate authorized sample can locate nearby")
    }
    reset()
    do {
      let channel = AgentLocationChannel(); var values = [Any?]()
      read(channel, "invalid-current") { values.append($0) }
      let manager = CLLocationManager.created.last!
      channel.locationManager(manager, didUpdateLocations: [point(301)])
      flush(0.9)
      check(values.isEmpty && manager.requests == 2 && CLGeocoder.created.isEmpty,
        "stale current sample is not accepted and acquisition retries")
      channel.handle(FlutterMethodCall("cancel", ["requestId": "invalid-current"]), result: { _ in })
    }
    reset()
    do {
      let channel = AgentLocationChannel(); var first = [Any?](); var second = [Any?]()
      read(channel, "first") { first.append($0) }
      let manager = CLLocationManager.created.last!
      channel.locationManager(manager, didUpdateLocations: [point()])
      let oldGeocode = CLGeocoder.created.last?.completion
      channel.handle(FlutterMethodCall("cancel", ["requestId": "first"]), result: { _ in })
      check(first.count == 1 && first[0] == nil, "cancel never returns cached or in-flight coordinates")
      read(channel, "second") { second.append($0) }
      oldGeocode?(nil, nil); flush()
      check(second.isEmpty, "late geocode does not complete next request")
      let current = CLLocationManager.created.last!
      channel.locationManager(current, didFailWithError: error(.network)); flush()
      check(second.count == 1 && coordinate(second.first ?? nil), "trusted native observation survives subsequent real failure")
    }
    reset()
    do {
      let channel = AgentLocationChannel(); var first = [Any?](); var second = [Any?]()
      read(channel, "old-acquisition") { first.append($0) }
      let oldManager = CLLocationManager.created.last!
      channel.handle(FlutterMethodCall("cancel", ["requestId": "old-acquisition"]), result: { _ in })
      read(channel, "new-acquisition") { second.append($0) }
      channel.locationManager(oldManager, didUpdateLocations: [point()])
      CLGeocoder.created.last?.completion?(nil, nil); flush()
      check(second.isEmpty && CLGeocoder.created.isEmpty, "late native sample cannot affect next acquisition")
      channel.locationManager(oldManager, didFailWithError: error(.network)); flush()
      check(second.isEmpty, "late native error cannot terminate next acquisition")
      channel.handle(FlutterMethodCall("cancel", ["requestId": "new-acquisition"]), result: { _ in })
    }
    for status in [CLAuthorizationStatus.notDetermined, .denied, .restricted] {
      reset(point()); CLLocationManager.status = status
      let channel = AgentLocationChannel(); var values = [Any?]()
      read(channel, "permission") { values.append($0) }
      check(values.count == 1 && values[0] == nil, "ungranted permission never returns cache")
    }
    reset(point())
    do {
      let channel = AgentLocationChannel(); var values = [Any?]()
      read(channel, "revoked") { values.append($0) }
      let manager = CLLocationManager.created.last!; manager.authorizationStatus = .denied
      channel.locationManager(manager, didFailWithError: error(.denied)); flush()
      check(values.count == 1 && values[0] == nil, "revoked permission never falls back")
    }
    print("AgentLocationChannel: \\(checks) checks, \\(failures) failures")
    exit(failures == 0 ? 0 : 1)
  }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix='agent-location-test-') as folder:
        directory = Path(folder)
        for name, source in [('Flutter', FLUTTER), ('CoreLocation', CORE_LOCATION)]:
            path = directory / f'{name}.swift'
            path.write_text(source)
            subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-emit-library',
                            '-emit-module', '-module-name', name, str(path),
                            '-o', str(directory / f'lib{name}.dylib')], cwd=directory, check=True)
        test = directory / 'Tests.swift'
        test.write_text(TESTS)
        binary = directory / 'tests'
        subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-I', folder, '-L', folder,
                        '-lFlutter', '-lCoreLocation', str(ROOT / 'ios/Runner/AgentLocationChannel.swift'),
                        str(test), '-o', str(binary)], check=True)
        environment = dict(os.environ, DYLD_LIBRARY_PATH=folder)
        subprocess.run([str(binary)], env=environment, check=True)


if __name__ == '__main__':
    main()
