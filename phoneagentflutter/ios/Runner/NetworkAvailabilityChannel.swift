import Flutter
import Network

/// Bounded OS samples and subscribed path events, not proof of backend reachability.
final class NetworkAvailabilityChannel: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var samples: [UUID: Sample] = [:]
  private var watchMonitor: NWPathMonitor?
  private var watchToken: UUID?

  private final class Sample {
    let monitor = NWPathMonitor()
    let result: FlutterResult
    var timeout: DispatchWorkItem?
    init(_ result: @escaping FlutterResult) { self.result = result }
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = NetworkAvailabilityChannel()
    let channel = FlutterMethodChannel(name: "phone_agent/network_availability",
                                      binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: channel)
    let events = FlutterEventChannel(name: "phone_agent/network_availability_events",
                                     binaryMessenger: registrar.messenger())
    events.setStreamHandler(plugin)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "read" else { result(FlutterMethodNotImplemented); return }
    let id = UUID()
    let sample = Sample(result)
    samples[id] = sample
    // currentPath before the first callback is not evidence of being offline.
    sample.monitor.pathUpdateHandler = { [weak self] path in
      let value: String
      switch path.status {
      case .satisfied: value = "available"
      case .unsatisfied: value = "unavailable"
      case .requiresConnection: value = "unknown"
      @unknown default: value = "unknown"
      }
      DispatchQueue.main.async { self?.finish(id, value) }
    }
    let timeout = DispatchWorkItem { [weak self] in self?.finish(id, "unknown") }
    sample.timeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: timeout)
    sample.monitor.start(queue: DispatchQueue(label: "phone_agent.network_sample"))
  }

  private func finish(_ id: UUID, _ value: String) {
    guard let sample = samples.removeValue(forKey: id) else { return }
    sample.timeout?.cancel()
    sample.monitor.pathUpdateHandler = nil
    sample.monitor.cancel()
    sample.result(value)
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    stopWatch()
    for id in Array(samples.keys) { finish(id, "unknown") }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stopWatch()
    let token = UUID()
    let monitor = NWPathMonitor()
    watchToken = token
    watchMonitor = monitor
    monitor.pathUpdateHandler = { [weak self] path in
      let value: String
      switch path.status {
      case .satisfied: value = "available"
      case .unsatisfied: value = "unavailable"
      case .requiresConnection: value = "unknown"
      @unknown default: value = "unknown"
      }
      DispatchQueue.main.async { [weak self] in
        guard self?.watchToken == token else { return }
        events(value)
      }
    }
    monitor.start(queue: DispatchQueue(label: "phone_agent.network_watch"))
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopWatch()
    return nil
  }

  private func stopWatch() {
    watchToken = nil
    watchMonitor?.pathUpdateHandler = nil
    watchMonitor?.cancel()
    watchMonitor = nil
  }

  deinit {
    watchMonitor?.pathUpdateHandler = nil
    watchMonitor?.cancel()
    for sample in samples.values {
      sample.timeout?.cancel()
      sample.monitor.pathUpdateHandler = nil
      sample.monitor.cancel()
    }
  }
}
