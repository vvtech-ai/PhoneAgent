package com.vvtech.aiassistant.features.assistant_singleflow

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.EffectiveTaskContact
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.PersonalInfoEntry
import com.vvtech.aiassistant.features.assistant.SelectionSheetOption
import com.vvtech.aiassistant.features.assistant.SummaryData
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoicePrecheckUiState
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrHostCallbacks
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames

internal data class SingleFlowNativeDemoScreenArgs(
    val onBack: (() -> Unit)? = null,
    val onStop: (() -> Unit)? = null,
    val initialCommand: String? = null,
    val startInVoice: Boolean = false,
    val resumeListeningOnly: Boolean = false,
    val entryKey: Long = 0L,
    val onSubmitTask: ((String) -> Unit)? = null,
    val assistantState: Index9AssistantUiState? = null,
    val onSelectSelectionOption: ((SelectionSheetOption) -> Unit)? = null,
    val onConfirmTask: (() -> Unit)? = null,
    val onSubmitSceneSupplement: ((String) -> Unit)? = null,
    val onStartVoiceInteraction: (() -> Unit)? = null,
    val onStartNewVoiceTaskEntry: (() -> Unit)? = null,
    val onToggleVoiceInput: (() -> Unit)? = null,
    val onPauseTtsPlayback: (() -> Unit)? = null,
    val onSpeakVoicePrompt: ((String) -> Unit)? = null,
    val onBeginVoiceContactReentry: ((String) -> Unit)? = null,
    val onBeginVoiceDefaultContactConfirmation: ((String) -> Unit)? = null,
    val onBeginVoiceDetailSupplementPrompt: ((String) -> Unit)? = null,
    val onBeginVoiceSummaryConfirmation: ((SummaryData) -> Unit)? = null,
    val onVoiceContactCaptured: ((EffectiveTaskContact) -> Unit)? = null,
    val savedContacts: List<PersonalInfoEntry> = emptyList(),
    val onCompleteDetailSupplement: ((EffectiveTaskContact, String) -> Unit)? = null,
    val bottomOverlayInset: Dp = 0.dp,
    val pureVoiceMode: Boolean = false,
    val pureVoicePrecheck: PureVoicePrecheckUiState? = null,
    val pureVoiceOcrHostCallbacks: PureVoiceOcrHostCallbacks? = null,
    val voiceLanguage: VoiceLanguage = VoiceLanguage.Chinese,
    val activeCallModelTitle: String = AssistantCallModelDisplayNames.Qwen,
    val onOpenCallModelSheet: (() -> Unit)? = null,
    val onStopVoiceInteraction: (() -> Unit)? = null,
    val onManualPressVoiceInteraction: (() -> Unit)? = null,
    val onManualCancelVoiceInteraction: (() -> Unit)? = null,
    val onManualTooShortVoiceInteraction: (() -> Unit)? = null,
    val onNewTask: (() -> Unit)? = null,
    val onGoHome: (() -> Unit)? = null
)
