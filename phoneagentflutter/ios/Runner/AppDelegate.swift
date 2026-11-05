import Flutter
import UIKit
import PhoneAgentIdentityCapture
import PhoneAgentTrustedCaller
import PhoneAgentCrashDiagnostics

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    PACrashPlugin.start()
    if let crashRegistrar = registrar(forPlugin: "PhoneAgentCrashDiagnostics") {
      PACrashPlugin.register(with: crashRegistrar)
    }
    GeneratedPluginRegistrant.register(with: self)
    if let localRegistrar = registrar(forPlugin: "LocalStorageChannel") {
      LocalStorageChannel.register(with: localRegistrar)
    }
    if let commerceRegistrar = registrar(forPlugin: "PhoneAgentCommercePayment") {
      CommercePaymentChannel.register(with: commerceRegistrar)
    }
    if let recordingRegistrar = registrar(forPlugin: "PhoneAgentCallRecordingPlayer") {
      CallRecordingPlayerChannel.register(with: recordingRegistrar)
    }
    if let trustedRegistrar = registrar(forPlugin: "PhoneAgentTrustedCaller") {
      TrustedCallerPlugin.register(with: trustedRegistrar, host: window?.rootViewController)
    }
    if let paragraphRegistrar = registrar(forPlugin: "PhoneAgentNativeParagraph") {
      NativeParagraphChannel.register(with: paragraphRegistrar)
    }
    if let appInfoRegistrar = registrar(forPlugin: "PhoneAgentAppInfo") {
      AppInfoChannel.register(with: appInfoRegistrar)
    }
    if let updateRegistrar = registrar(forPlugin: "PhoneAgentIosUpdate") {
      IosUpdateChannel.register(with: updateRegistrar)
    }
    if let legalRegistrar = registrar(forPlugin: "PhoneAgentLegalDocuments") {
      LegalDocumentChannel.register(with: legalRegistrar, host: window?.rootViewController)
    }
    if let inviteRegistrar = registrar(forPlugin: "PhoneAgentInvite") {
      InviteChannel.register(with: inviteRegistrar)
    }
    if let diagnosticRegistrar = registrar(forPlugin: "PhoneAgentDiagnosticDirectory") {
      DiagnosticDirectoryChannel.register(with: diagnosticRegistrar)
    }
    if let callAudioRegistrar = registrar(forPlugin: "PhoneAgentTranslationCallAudio") {
      TranslationCallAudioChannel.register(with: callAudioRegistrar)
    }
    if let outputRegistrar = registrar(forPlugin: "PhoneAgentPcmOutput") {
      PcmOutputChannel.register(with: outputRegistrar)
    }
    if let pcmRegistrar = registrar(forPlugin: "PhoneAgentPcmCapture") {
      PcmCaptureChannel.register(with: pcmRegistrar)
    }
    if let modelRegistrar = registrar(forPlugin: "PhoneAgentDomesticModels") {
      DomesticModelConfigurationChannel.register(with: modelRegistrar)
    }
    if let recordingRegistrar = registrar(forPlugin: "PhoneAgentDomesticRecording") {
      DomesticRecordingChannel.register(with: recordingRegistrar)
    }
    if let sipRouteRegistrar = registrar(forPlugin: "PhoneAgentSipRoute") {
      SipRouteChannel.register(with: sipRouteRegistrar)
    }
    if let clockRegistrar = registrar(forPlugin: "PhoneAgentDeviceClock") {
      DeviceClockChannel.register(with: clockRegistrar)
    }
    if let agentLocationRegistrar = registrar(forPlugin: "PhoneAgentAgentLocation") {
      AgentLocationChannel.register(with: agentLocationRegistrar)
    }
    if let networkRegistrar = registrar(forPlugin: "PhoneAgentNetworkAvailability") {
      NetworkAvailabilityChannel.register(with: networkRegistrar)
    }
    if let contactsRegistrar = registrar(forPlugin: "PhoneAgentContacts") {
      ContactsChannel.register(with: contactsRegistrar)
    }
    if let dialerRegistrar = registrar(forPlugin: "PhoneAgentSystemDialer") {
      SystemDialerChannel.register(with: dialerRegistrar)
    }
    if let permissionRegistrar = registrar(forPlugin: "PhoneAgentPermissions") {
      PermissionChannel.register(with: permissionRegistrar)
    }
    if let locationRegistrar = registrar(forPlugin: "PhoneAgentTranslationLocation") {
      TranslationLocationChannel.register(with: locationRegistrar)
    }
    if let recordingRegistrar = registrar(forPlugin: "PhoneAgentCertifiedRecording") {
      CertifiedRecordingChannel.register(with: recordingRegistrar)
    }
    if let exportRegistrar = registrar(forPlugin: "PhoneAgentRecordingExport") {
      RecordingExportChannel.register(with: exportRegistrar, host: window?.rootViewController)
    }
    if let taskFileRegistrar = registrar(forPlugin: "PhoneAgentTaskFiles") {
      TaskFileChannel.register(with: taskFileRegistrar, host: window?.rootViewController)
    }
    if let identityRegistrar = registrar(forPlugin: "PhoneAgentIdentityCapture") {
      IdentityCapturePlugin.register(with: identityRegistrar, host: window?.rootViewController)
    }
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    TrustedCallerPlugin.installNotificationRelay()
    if #available(iOS 16.1, *) {
      TrustedCallerPlugin.setActivityReportObserver { report in
        DispatchQueue.main.async {
          TrustedIdentityActivityManager.shared.receive(report as? [String: Any])
        }
      }
    }
    return launched
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    if #available(iOS 16.1, *) { TrustedIdentityActivityManager.shared.resume() }
  }

  override func application(
    _ app: UIApplication, open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if TrustedCallerPlugin.handleTrustedIdentityURL(url) { return true }
    return super.application(app, open: url, options: options)
  }
}
