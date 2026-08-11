package com.vvtech.aiassistant.features.assistant_home

import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.ComposerMode
import com.vvtech.aiassistant.features.assistant.FinalTaskStatusKind
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames
import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfigSource
import com.vvtech.aiassistant.features.assistant_home.domain.HomeEntryAction

internal data class AssistantHomeComposerState(
    val assistantFocused: Boolean,
    val composerOpen: Boolean,
    val composerMode: ComposerMode,
    val textDraft: String,
    val pureVoiceMode: Boolean = false,
    val apiAsrPartialText: String? = null,
    val apiTtsPlaying: Boolean = false
)

internal data class AssistantHomeTaskState(
    val voiceRecording: Boolean,
    val taskStarted: Boolean,
    val taskUserText: String,
    val aiThinking: Boolean,
    val aiReplyVisible: Boolean,
    val taskStatus: String = "INIT",
    val clarificationSteps: List<ClarificationStep> = emptyList(),
    val processingTurn: Boolean = false
)

internal data class AssistantHomeAgentSheetState(
    val questions: AskQuestionsPayload? = null,
    val options: OptionsPayload? = null,
    val documentRequest: DocumentImportRequestPayload? = null,
    val documentImporting: Boolean = false
)

internal data class AssistantHomeNotificationState(
    val visible: Boolean = false,
    val text: String = "",
    val extra: String = "",
    val statusKind: FinalTaskStatusKind = FinalTaskStatusKind.Completed
)

internal data class AssistantHomePageVisibility(
    val showComposer: Boolean,
    val showQuickCards: Boolean
)

internal data class AssistantHomeConfigUiState(
    val configVersion: String = "builtin-1",
    val slogan: AssistantHomeSloganUi = AssistantHomeSloganUi("给我一个任务", "我来帮你打电话"),
    val cards: List<AssistantHomeCardUi> = emptyList(),
    val source: HomeConfigSource = HomeConfigSource.Default,
    val loading: Boolean = false,
    val warning: String? = null
)

internal data class AssistantHomeSloganUi(val line1: String, val line2: String)

internal data class AssistantHomeCardUi(
    val id: String,
    val title: String,
    val subtitle: String,
    val imageUrl: String?,
    val enabled: Boolean,
    val statusLabel: String?,
    val action: HomeEntryAction
)

internal data class AssistantHomeShellCallbacks(
    val onQuickVoiceEntry: (String?) -> Boolean = { false },
    val onOpenTranslateDial: () -> Unit = {},
    val onBlockOffline: () -> Boolean = { false },
    val onComposerOpen: () -> Unit = {},
    val activeCallModelTitle: String = AssistantCallModelDisplayNames.Qwen,
    val onOpenCallModelSheet: () -> Unit = {}
)

internal data class AssistantHomeComposerCallbacks(
    val onModeChange: (ComposerMode) -> Unit = {},
    val onStartVoice: () -> Unit,
    val onStopVoice: () -> Unit,
    val onInterruptTts: () -> Unit = {},
    val onTextDraftChange: (String) -> Unit,
    val onSendText: () -> Unit,
    val onStopTask: () -> Unit
)

internal data class AssistantHomeAgentCallbacks(
    val onAnswerSubmit: ((Map<String, Any>) -> Unit)? = null,
    val onOptionSelect: ((String) -> Unit)? = null,
    val onDocumentSelect: (() -> Unit)? = null,
    val onDocumentCancel: (() -> Unit)? = null,
    val onSheetDismiss: (() -> Unit)? = null,
    val onReplayTts: ((String) -> Unit)? = null
)

internal data class AssistantHomeNotificationCallbacks(
    val onClick: () -> Unit = {},
    val onDismiss: () -> Unit = {}
)

internal data class AssistantHomePageCallbacks(
    val shell: AssistantHomeShellCallbacks,
    val composer: AssistantHomeComposerCallbacks,
    val agent: AssistantHomeAgentCallbacks = AssistantHomeAgentCallbacks(),
    val notification: AssistantHomeNotificationCallbacks = AssistantHomeNotificationCallbacks()
)
