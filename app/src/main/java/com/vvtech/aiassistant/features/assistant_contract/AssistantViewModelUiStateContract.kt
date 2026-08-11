package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.LookupDeviceContactsByNamesPayload
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultConfirmLabel
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultIdleExample
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultIdleStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultRetryLabel
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem

enum class AgentContactInputSource(val wireValue: String) {
    UNKNOWN("unknown"),
    TYPED("typed"),
    ASR("asr")
}

data class Index9AssistantUiState(
    val stage: AssistantStage = AssistantStage.Idle,
    val status: String = DefaultIdleStatus,
    val clarificationSteps: List<ClarificationStep> = emptyList(),
    /** Immutable conversation ledger. Legacy UI fields below are projections only. */
    val timelineItems: List<ConversationTimelineItem> = emptyList(),
    val liveUserTranscript: String? = null,
    val liveAssistantTranscript: String? = null,
    val selectionSheet: SelectionSheetData? = null,
    val summary: SummaryData? = null,
    val detailSupplement: DetailSupplementPageData? = null,
    val confirmLabel: String = DefaultConfirmLabel,
    val retryLabel: String = DefaultRetryLabel,
    val exampleText: String = DefaultIdleExample,
    val historyRecords: List<HistoryRecord> = emptyList(),
    val historyLoading: Boolean = false,
    val historyError: String? = null,
    val loading: Boolean = false,
    val voiceConnecting: Boolean = false,
    val voiceActive: Boolean = false,
    val voiceManuallyPaused: Boolean = false,
    val voiceBackgroundPaused: Boolean = false,
    val listening: Boolean = false,
    val processingTurn: Boolean = false,
    /** True while a local prompt is actively playing through the unified TTS bridge. */
    val localTtsSpeaking: Boolean = false,
    val error: String? = null,
    val taskId: String? = null,
    val sceneType: String = "GENERAL",
    val taskStatus: String = "INIT",
    /** Whether the user may append a new turn; independent from receipt terminal state. */
    val conversationContinuable: Boolean = true,
    /** Whether a pending tool prompt may be resumed after restoration. */
    val pendingToolRestorable: Boolean = false,
    /** Status of the latest execution/receipt, never a reason to remove history. */
    val executionStatus: String = "INIT",
    val unresolvedTaskErrorStatus: String? = null,
    val taskErrorRecoveryInProgress: Boolean = false,
    val callUiMode: CallUiMode = CallUiMode.Ai,
    val currentCallId: String? = null,
    val handoffInFlight: Boolean = false,
    val callMonitorState: CallMonitorPlaybackState = CallMonitorPlaybackState.Off,
    val callMonitorAudioRouteState: CallMonitorAudioRouteState = CallMonitorAudioRouteState(),
    val humanMicrophoneMuted: Boolean = false,
    val callPageData: CallPageData = CallPageData(
        name = "AI 助理",
        sub = "实时外呼",
        status = "等待发起",
        transcript = emptyList()
    ),
    val showAiCallPage: Boolean = false,
    val agentOptions: OptionsPayload? = null,
    val agentQuestions: AskQuestionsPayload? = null,
    val agentPermissionRequest: PermissionRequestPayload? = null,
    val agentDocumentRequest: DocumentImportRequestPayload? = null,
    val agentDocumentImporting: Boolean = false,
    val agentPendingToolCallId: String? = null,
    val agentCallSpec: CallSpecPayload? = null,
    val agentCallResult: CallResultPayload? = null,
    val agentLookupContactPhone: String? = null,
    val agentLookupContactInFlight: Boolean = false,
    val agentLookupDeviceContactsRequest: LookupDeviceContactsByNamesPayload? = null,
    val agentLookupDeviceContactsInFlight: Boolean = false,
    val agentContactInputSource: AgentContactInputSource = AgentContactInputSource.UNKNOWN,
    val agentDeviceContactSelection: DeviceContactSelectionUiState? = null,
    val identityInitOverlayVisible: Boolean = false,
    val voiceContactCapture: VoiceContactCaptureUiState? = null,
    val voiceUiCommand: VoiceUiCommandUiState? = null,
    /** True after manual push-to-talk release while ASR is completing the current utterance. */
    val manualAsrFinalizing: Boolean = false,
    val apiAsrListening: Boolean = false,
    val apiAsrPartialText: String? = null,
    val apiTtsPlaying: Boolean = false,
    val locationAvailable: Boolean = false,
    val locationDisplayText: String = ""
)
