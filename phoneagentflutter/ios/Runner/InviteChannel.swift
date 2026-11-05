import Flutter
import UIKit
import Photos

final class InviteChannel: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var initial: String?
  private var sink: FlutterEventSink?
  private var saving = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = InviteChannel()
    let methods = FlutterMethodChannel(name: "phone_agent/invite", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    registrar.addApplicationDelegate(instance)
    FlutterEventChannel(name: "phone_agent/invite_links", binaryMessenger: registrar.messenger())
      .setStreamHandler(instance)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialLink":
      let value = initial; initial = nil; result(value)
    case "savePoster":
      guard !saving else { result(FlutterError(code: "BUSY", message: "保存进行中", details: nil)); return }
      guard let typed = call.arguments as? FlutterStandardTypedData,
            typed.data.count <= 10 * 1024 * 1024,
            let image = UIImage(data: typed.data) else {
        result(FlutterError(code: "INVALID_IMAGE", message: "图片无效", details: nil)); return
      }
      saving = true
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
        guard status == .authorized || status == .limited else {
          DispatchQueue.main.async {
            self?.saving = false
            result(FlutterError(code: "PERMISSION_DENIED", message: "请允许保存图片后重试", details: nil))
          }
          return
        }
        PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, _ in
          DispatchQueue.main.async {
            self?.saving = false
            if success { result(true) }
            else { result(FlutterError(code: "SAVE_FAILED", message: "图片保存失败", details: nil)) }
          }
        }
      }
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func receive(_ url: URL) -> Bool {
    guard url.absoluteString.count <= 4096 else { return false }
    let schemes = ["phoneagent", "phoneagent-test"]
    let hosts = ["chaken.ai", "www.chaken.ai", "agent.vvtech.tech", "chakenai-dev.vvtech.tech",
                 "chakenai-test.vvtech.tech", "ioslink.chaken.ai", "phoneagent-ioslink.vvtech.tech"]
    guard schemes.contains(url.scheme ?? "") ||
        (url.scheme == "https" && hosts.contains(url.host ?? "")) else { return false }
    if let sink = sink { sink(url.absoluteString) } else { initial = url.absoluteString }
    return true
  }
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any]) -> Bool {
    if let url = launchOptions[UIApplication.LaunchOptionsKey.url] as? URL { _ = receive(url) }
    return true
  }
  func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    receive(url)
  }
  func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                   restorationHandler: @escaping ([Any]) -> Void) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else { return false }
    return receive(url)
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events; return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }
}
