package com.vvtech.aiassistant.features.assistant_singleflow

import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.ui.unit.Dp
import com.vvtech.aiassistant.features.assistant.DetailSupplementPageData
import com.vvtech.aiassistant.features.assistant.DetailSupplementQuestionData
import com.vvtech.aiassistant.features.assistant.EffectiveTaskContact
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.PersonalInfoEntry
import com.vvtech.aiassistant.features.assistant.SelectionSheetOption
import com.vvtech.aiassistant.features.assistant.SfInputMode
import com.vvtech.aiassistant.features.assistant.SfRestaurantOption
import com.vvtech.aiassistant.features.assistant.SfThreadItem
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoicePrecheckUiState
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrBinding

internal data class SingleFlowNativeMainContentState(
    val stage: Int,
    val entryKey: Long,
    val pureVoiceMode: Boolean,
    val realFlowEnabled: Boolean,
    val assistantState: Index9AssistantUiState?,
    val inputMode: SfInputMode,
    val voiceLanguage: VoiceLanguage,
    val activeCallModelTitle: String,
    val pureVoicePrecheck: PureVoicePrecheckUiState?,
    val pureVoiceOcrBinding: PureVoiceOcrBinding,
    val listening: Boolean,
    val mockAiSpeaking: Boolean,
    val showMockRestaurantOptions: Boolean,
    val restaurants: List<SfRestaurantOption>,
    val listState: LazyListState,
    val composerReserve: Dp,
    val threadItems: List<SfThreadItem>,
    val savedContacts: List<PersonalInfoEntry>,
    val supplementContact: EffectiveTaskContact?,
    val preferredSavedContact: PersonalInfoEntry?,
    val manualContactMode: Boolean,
    val contactInputError: String?,
    val voiceContactPromptTaskId: String?,
    val selectedDetailQuestionIds: List<String>,
    val closeTaskAction: (() -> Unit)?
)

internal data class SingleFlowNativeInputState(val textInput: String, val bottomOverlayInset: Dp)

internal data class SingleFlowNativeCallOverlayState(
    val visible: Boolean,
    val name: String,
    val subTitle: String,
    val status: String,
    val seconds: Int,
    val transcripts: List<String>,
    val listState: LazyListState,
    val muted: Boolean,
    val speaker: Boolean
)

internal data class SingleFlowNativeReceiptState(
    val showOverlay: Boolean,
    val restaurantName: String,
    val time: String,
    val partySize: String,
    val showHint: Boolean
)

internal data class SingleFlowNativeContentCallbacks(
    val onAdvanceMockStep: () -> Unit,
    val onPureVoiceSelectionOption: (SelectionSheetOption) -> Unit,
    val onConfirmTask: (() -> Unit)?,
    val onPureVoiceButtonTap: () -> Unit,
    val onPureVoiceStop: () -> Unit,
    val onPureVoiceCancel: () -> Unit,
    val onPureVoiceTooShort: () -> Unit,
    val onSelectMockRestaurant: (SfRestaurantOption) -> Unit,
    val onAgentOptionSelect: (Int) -> Unit,
    val onRealSelectionOptionSelected: (SelectionSheetOption) -> Unit,
    val onConfirmSavedContact: (PersonalInfoEntry) -> Unit,
    val onManualContact: () -> Unit,
    val onToggleQuestion: (DetailSupplementQuestionData) -> Unit,
    val onConfirmDetails: (DetailSupplementPageData, List<String>) -> Unit,
    val onSkipDetails: () -> Unit,
    val onConfirmSummary: () -> Unit,
    val onMockCtaClick: () -> Unit,
    val onTextInputChange: (String) -> Unit,
    val onSubmitText: () -> Unit,
    val onVoiceButtonTap: () -> Unit,
    val onPauseTtsPlayback: (() -> Unit)?,
    val onStopVoiceInteraction: (() -> Unit)?,
    val onInputModeChange: (SfInputMode) -> Unit,
    val onOpenCallModelSheet: () -> Unit,
    val onStopClick: () -> Unit,
    val onComposerHeightChanged: (Int) -> Unit,
    val onToggleMuted: () -> Unit,
    val onToggleSpeaker: () -> Unit,
    val onEndCall: () -> Unit,
    val onDismissReceipt: () -> Unit,
    val onDoNotShowReceiptAgain: () -> Unit,
    val onAutoDismissReceiptHint: () -> Unit
)
