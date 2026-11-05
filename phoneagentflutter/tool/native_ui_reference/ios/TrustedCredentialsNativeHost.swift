import UIKit

/// Synthetic fixed-view host: no SDK, account, push, call, or avatar URL.
@main
final class TrustedCredentialsNativeHost: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.overrideUserInterfaceStyle = .dark
    window.rootViewController = ReferenceMenu()
    window.makeKeyAndVisible()
    self.window = window
    return true
  }
}

private final class ReferenceMenu: UIViewController {
  private var shown = false
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 16
    let label = UILabel()
    label.text = "原生凭据独立演练：未调用SDK"
    stack.addArrangedSubview(label)
    for phase in ["pending", "failed", "verified", "uncertified"] {
      let button = UIButton(type: .system)
      button.setTitle("查看合成状态 \(phase)", for: .normal)
      button.addAction(UIAction { [weak self] _ in self?.show(phase) }, for: .touchUpInside)
      stack.addArrangedSubview(button)
    }
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
    ])
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if !shown { shown = true; show("verified") }
  }
  private func show(_ phase: String) {
    let identity: NSDictionary = [
      "signStaus": phase == "verified" ? "1" : phase == "failed" ? "0" : "pending",
      "showType": phase == "uncertified" ? "6" : "0",
      "name": "合成姓名", "deptZh": "合成部门", "position": "合成职位",
      "commonName": "合成企业", "phoneno": "12025550100",
      "serialNumber": "synthetic-serial", "organizationName": "合成颁发机构",
      "callTime": "合成日期", "createTime": "合成日期"
    ]
    present(AITrustedIdentityCredentialsViewController(identity: identity), animated: false)
  }
}
