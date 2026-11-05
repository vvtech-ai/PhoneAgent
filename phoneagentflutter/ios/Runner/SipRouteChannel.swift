import Darwin
import Flutter
import Foundation

/// Connect a UDP descriptor only to select its route; no datagram is sent.
final class SipRouteChannel: NSObject, FlutterPlugin {
  private let worker = DispatchQueue(label: "phoneagent.sip.route")
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "phone_agent/sip_route", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SipRouteChannel(), channel: channel)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "resolve" else { result(FlutterMethodNotImplemented); return }
    guard let args = call.arguments as? [String: Any], let host = args["host"] as? String,
          host.count <= 253, host.range(of: "^[A-Za-z0-9.:-]+$", options: .regularExpression) != nil,
          let port = args["port"] as? Int, (1...65535).contains(port) else {
      result(FlutterError(code: "sip_route_unavailable", message: "SIP网络不可用", details: nil)); return
    }
    worker.async {
      let route = Self.resolve(host, port)
      DispatchQueue.main.async {
        if let route = route { result(route) }
        else { result(FlutterError(code: "sip_route_unavailable", message: "SIP网络不可用", details: nil)) }
      }
    }
  }
  private static func resolve(_ host: String, _ port: Int) -> [String: String]? {
    var hints = addrinfo()
    hints.ai_family = AF_UNSPEC
    hints.ai_socktype = SOCK_DGRAM
    hints.ai_protocol = IPPROTO_UDP
    var head: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo(host, String(port), &hints, &head) == 0, let first = head else { return nil }
    defer { freeaddrinfo(first) }
    var cursor: UnsafeMutablePointer<addrinfo>? = first
    while let item = cursor {
      let address = item.pointee
      cursor = address.ai_next
      guard address.ai_family == AF_INET || address.ai_family == AF_INET6 else { continue }
      let descriptor = socket(address.ai_family, SOCK_DGRAM, IPPROTO_UDP)
      guard descriptor >= 0 else { continue }
      defer { Darwin.close(descriptor) }
      guard Darwin.connect(descriptor, address.ai_addr, address.ai_addrlen) == 0 else { continue }
      var local = sockaddr_storage()
      var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
      let localHost: String? = withUnsafeMutablePointer(to: &local) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
          guard getsockname(descriptor, socketAddress, &length) == 0 else { return nil }
          return numericHost(socketAddress, length)
        }
      }
      if let localHost = localHost, let peerHost = numericHost(address.ai_addr, address.ai_addrlen),
         localHost != "0.0.0.0", localHost != "::" {
        return ["localAddress": localHost, "peerAddress": peerHost]
      }
    }
    return nil
  }
  private static func numericHost(_ address: UnsafePointer<sockaddr>?, _ length: socklen_t) -> String? {
    var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    guard getnameinfo(address, length, &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 else { return nil }
    return String(cString: buffer)
  }
}
