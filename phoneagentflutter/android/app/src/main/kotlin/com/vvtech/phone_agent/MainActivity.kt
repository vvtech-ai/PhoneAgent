package com.vvtech.phone_agent

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.vvtech.phone_agent.ota.UpdateInstallChannel
import android.content.Intent
import com.vvtech.phone_agent.diagnostics.NativeCrashApplication
import com.vvtech.phone_agent.diagnostics.NativeCrashChannel

class MainActivity : FlutterActivity() {
    private var commercePayment: CommercePaymentChannel? = null
    private var nativeCrash: NativeCrashChannel? = null
    private var translationCallAudio: TranslationCallAudioChannel? = null
    private var pcmOutput: PcmOutputChannel? = null
    private var pcmCapture: PcmCaptureChannel? = null
    private var contacts: ContactsChannel? = null
    private var systemDialer: SystemDialerChannel? = null
    private var callLog: CallLogChannel? = null
    private var appInfo: AppInfoChannel? = null
    private var legalDocuments: LegalDocumentChannel? = null
    private var permissionChannel: PermissionChannel? = null
    private var translationLocation: TranslationLocationChannel? = null
    private var certifiedRecording: CertifiedRecordingChannel? = null
    private var identityCapture: IdentityCaptureChannel? = null
    private var updateInstall: UpdateInstallChannel? = null
    private var recordingExport: RecordingExportChannel? = null
    private var callRecordingPlayer: CallRecordingPlayerChannel? = null
    private var recordingDestination: RecordingDestinationChannel? = null
    private var taskFiles: TaskFileChannel? = null
    private var taskVoicePreferences: TaskVoicePreferenceChannel? = null
    private var networkAvailability: NetworkAvailabilityChannel? = null
    private var agentLocation: AgentLocationChannel? = null
    private var deviceClock: DeviceClockChannel? = null
    private var trustedCaller: TrustedCallerChannel? = null
    private var sipRoute: SipRouteChannel? = null
    private var domesticModels: DomesticModelConfigurationChannel? = null
    private var domesticRecording: DomesticRecordingChannel? = null
    private var legacySession: LegacySessionChannel? = null
    private var legacyPreferences: LegacyPreferencesChannel? = null
    private var legacyCertifiedRecording: LegacyCertifiedRecordingChannel? = null
    private var legacyCallRecords: LegacyCallRecordsChannel? = null
    private var legacyRatingDraft: LegacyRatingDraftChannel? = null
    private var legacyTranslationArchive: LegacyTranslationArchiveChannel? = null
    private var legacyCallAdmission: LegacyCallAdmissionChannel? = null
    private var legacyConfirmationBilling: LegacyConfirmationBillingChannel? = null

    private var invite: InviteChannel? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        invite?.receive(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        commercePayment?.close()
        commercePayment = CommercePaymentChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        super.configureFlutterEngine(flutterEngine)
        legalDocuments?.close()
        legalDocuments = LegalDocumentChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        invite?.close()
        invite = InviteChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        nativeCrash?.close()
        nativeCrash = NativeCrashChannel(application as NativeCrashApplication, flutterEngine.dartExecutor.binaryMessenger)
        legacySession?.close()
        legacySession = LegacySessionChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        legacyPreferences?.close()
        legacyPreferences = LegacyPreferencesChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        legacyCertifiedRecording?.close()
        legacyCertifiedRecording = LegacyCertifiedRecordingChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        legacyCallRecords?.close()
        legacyCallRecords = LegacyCallRecordsChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        legacyRatingDraft?.close()
        legacyRatingDraft = LegacyRatingDraftChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        legacyTranslationArchive?.close()
        legacyTranslationArchive = LegacyTranslationArchiveChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        legacyCallAdmission?.close()
        legacyCallAdmission = LegacyCallAdmissionChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        legacyConfirmationBilling?.close()
        legacyConfirmationBilling = LegacyConfirmationBillingChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        pcmOutput?.close()
        translationCallAudio?.close()
        translationCallAudio = TranslationCallAudioChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        pcmOutput = PcmOutputChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        pcmCapture?.close()
        pcmCapture = PcmCaptureChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        deviceClock?.close()
        deviceClock = DeviceClockChannel(flutterEngine.dartExecutor.binaryMessenger)
        trustedCaller?.close()
        trustedCaller = TrustedCallerChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        sipRoute?.close()
        sipRoute = SipRouteChannel(flutterEngine.dartExecutor.binaryMessenger)
        domesticModels?.close()
        domesticModels = DomesticModelConfigurationChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        domesticRecording?.close()
        domesticRecording = DomesticRecordingChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        agentLocation?.close()
        agentLocation = AgentLocationChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        networkAvailability?.close()
        networkAvailability = NetworkAvailabilityChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        contacts?.close()
        contacts = ContactsChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        systemDialer?.close()
        systemDialer = SystemDialerChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        callLog?.close()
        callLog = CallLogChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        appInfo?.close()
        appInfo = AppInfoChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        permissionChannel?.close()
        permissionChannel = PermissionChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        translationLocation?.close()
        translationLocation = TranslationLocationChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        certifiedRecording?.close()
        certifiedRecording = CertifiedRecordingChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        identityCapture?.close()
        identityCapture = IdentityCaptureChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        updateInstall?.close()
        updateInstall = UpdateInstallChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        recordingExport?.close()
        recordingExport = RecordingExportChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        callRecordingPlayer?.close()
        callRecordingPlayer = CallRecordingPlayerChannel(flutterEngine.dartExecutor.binaryMessenger)
        recordingDestination?.close()
        recordingDestination = RecordingDestinationChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        taskFiles?.close()
        taskFiles = TaskFileChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        taskVoicePreferences?.close()
        taskVoicePreferences = TaskVoicePreferenceChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (invite?.onActivityResult(requestCode, resultCode, data) != true &&
            taskFiles?.onActivityResult(requestCode, resultCode, data) != true &&
            recordingExport?.onActivityResult(requestCode, resultCode, data) != true &&
            recordingDestination?.onActivityResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (permissionChannel?.onPermissionResult(requestCode) != true &&
            translationLocation?.onPermissionResult(requestCode) != true &&
            contacts?.onPermissionResult(requestCode) != true) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        commercePayment?.close()
        commercePayment = null
        translationCallAudio?.close()
        translationCallAudio = null
        invite?.close()
        invite = null
        nativeCrash?.close()
        nativeCrash = null
        legacySession?.close()
        legacySession = null
        legacyPreferences?.close()
        legacyPreferences = null
        legacyCertifiedRecording?.close()
        legacyCertifiedRecording = null
        legacyCallRecords?.close()
        legacyCallRecords = null
        legacyRatingDraft?.close()
        legacyRatingDraft = null
        legacyTranslationArchive?.close()
        legacyTranslationArchive = null
        legacyCallAdmission?.close()
        legacyCallAdmission = null
        legacyConfirmationBilling?.close()
        legacyConfirmationBilling = null
        pcmOutput?.close()
        pcmOutput = null
        pcmCapture?.close()
        pcmCapture = null
        deviceClock?.close()
        deviceClock = null
        trustedCaller?.close()
        trustedCaller = null
        sipRoute?.close()
        sipRoute = null
        domesticModels?.close()
        domesticModels = null
        domesticRecording?.close()
        domesticRecording = null
        agentLocation?.close()
        agentLocation = null
        networkAvailability?.close()
        networkAvailability = null
        contacts?.close()
        contacts = null
        systemDialer?.close()
        systemDialer = null
        callLog?.close()
        callLog = null
        appInfo?.close()
        appInfo = null
        legalDocuments?.close()
        legalDocuments = null
        permissionChannel?.close()
        permissionChannel = null
        translationLocation?.close()
        translationLocation = null
        certifiedRecording?.close()
        certifiedRecording = null
        identityCapture?.close()
        identityCapture = null
        updateInstall?.close()
        updateInstall = null
        recordingExport?.close()
        recordingExport = null
        callRecordingPlayer?.close()
        callRecordingPlayer = null
        recordingDestination?.close()
        recordingDestination = null
        taskFiles?.close()
        taskFiles = null
        taskVoicePreferences?.close()
        taskVoicePreferences = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onPause() {
        callRecordingPlayer?.setForeground(false)
        translationCallAudio?.setForeground(false)
        pcmOutput?.setForeground(false)
        pcmCapture?.setForeground(false)
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        translationCallAudio?.setForeground(true)
        pcmOutput?.setForeground(true)
        pcmCapture?.setForeground(true)
    }
}
