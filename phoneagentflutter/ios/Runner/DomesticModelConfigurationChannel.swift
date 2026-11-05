import Flutter
import Foundation

/// Reads only the app's private deployment resource; no network or SDK action.
final class DomesticModelConfigurationChannel: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.vvtech.phone_agent/domestic_model_configuration",
      binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(DomesticModelConfigurationChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "read" else { result(FlutterMethodNotImplemented); return }
    guard let arguments = call.arguments as? [String: Any],
          let provider = arguments["provider"] as? String,
          ["QWEN", "DOUBAO"].contains(provider),
          let url = Bundle.main.url(forResource: "domestic-model-configuration", withExtension: "json") else {
      result(nil); return
    }
    do {
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 16385
      guard size <= 16384 else { result(nil); return }
      let data = try Data(contentsOf: url)
      guard data.count <= 16384,
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            root["version"] as? Int == 1, root["platform"] as? String == "ios",
            let models = root["models"] as? [String: Any],
            let model = models[provider] as? [String: Any] else {
        result(nil); return
      }
      result(model)
    } catch {
      result(nil)
    }
  }
}
