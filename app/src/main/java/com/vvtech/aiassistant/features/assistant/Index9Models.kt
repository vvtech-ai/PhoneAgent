package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.domain.task.ReceiptField

enum class AssistantStage {
    Idle,
    Clarifying,
    Recognized
}

enum class VoiceRole {
    Assistant,
    User
}

enum class TranscriptRole {
    Assistant,
    Remote,
    Note
}

enum class CallUiMode {
    Ai,
    Human
}

enum class StatusStyle {
    Success,
    Failure
}

data class SummaryData(
    val taskLabel: String = "任务",
    val task: String,
    val targetLabel: String,
    val target: String,
    val timeLabel: String,
    val time: String,
    val extraLabel: String,
    val extra: String,
    val contactLabel: String? = null,
    val contactValue: String? = null,
    val detailLabel: String? = null,
    val detailValue: String? = null
)

data class SelectionSheetOption(
    val itemId: String,
    val title: String,
    val phone: String,
    val meta: String,
    val actionId: String,
    val actionLabel: String
)

data class SelectionSheetData(
    val title: String,
    val subtitle: String,
    val targetLabel: String,
    val options: List<SelectionSheetOption>
)

data class ClarificationStep(
    val role: VoiceRole,
    val text: String,
    val status: String,
    val thinking: String? = null,
    val toolCalls: List<com.vvtech.aiassistant.core.model.ToolCallInfo>? = null,
    val toolCards: List<com.vvtech.aiassistant.core.model.ToolCardInfo> = emptyList(),
    val callConfirmSpec: CallSpecPayload? = null,
    val callResult: CallResultPayload? = null,
    val batchCallResult: BatchCallResultPayload? = null,
    val callStatusEvents: List<String> = emptyList(),
    val streaming: Boolean = false,
    val thinkingStartedAt: Long? = null,
    val thinkingDurationMs: Long? = null,
    val partialToolCalls: List<PartialToolCall> = emptyList(),
    val callConfirmIdentity: String? = null,
    /** Visible local action feedback, not a new semantic user turn. */
    val isUserActionEcho: Boolean = false
)

data class PartialToolCall(
    val id: String,
    val name: String,
    val argsPreview: String,
    val result: String? = null,
    val durationMs: Long? = null,
    val startedAt: Long = System.currentTimeMillis()
)

data class TranscriptLine(
    val role: TranscriptRole,
    val text: String
)

data class CallPageData(
    val name: String,
    val sub: String,
    val status: String,
    val transcript: List<TranscriptLine>,
    val callResult: CallResultPayload? = null,
    val callState: String = "",
) {
    val receiptFields: List<ReceiptField>
        get() = callResult?.receiptFields.orEmpty()
}

data class HistoryRecord(
    val title: String,
    val status: String,
    val style: StatusStyle,
    val meta: String,
    val occurredAtMillis: Long? = null,
    val phoneNumber: String = "",
    val dateText: String = "",
    val startTimeText: String = "",
    val endTimeText: String = "",
    val durationText: String = "",
    val resultText: String = "",
    val transcript: List<TranscriptLine> = emptyList(),
    val taskId: String = "",
    val callId: String = ""
)

enum class PersonalInfoGender {
    Mr,
    Ms
}

data class PersonalInfoEntry(
    val id: String,
    val name: String,
    val gender: PersonalInfoGender = PersonalInfoGender.Mr,
    val phone: String,
    val idCardNumber: String = "",
    val isDefault: Boolean = false
)

data class EffectiveTaskContact(
    val name: String = "",
    val gender: PersonalInfoGender = PersonalInfoGender.Mr,
    val phone: String = "",
    val idCardNumber: String = ""
) {
    fun isComplete(sceneType: String = ""): Boolean {
        return name.isNotBlank() &&
            phone.isNotBlank() &&
            (sceneType != "FLIGHT_BOOKING" || idCardNumber.isNotBlank())
    }
}

data class DetailSupplementQuestionData(
    val questionId: String,
    val prompt: String,
    val answerType: String = "boolean",
    val dependsOnQuestionId: String? = null,
    val dependsOnAnswer: String? = null
)

data class DetailSupplementPageData(
    val taskId: String,
    val sceneType: String,
    val title: String,
    val intro: String,
    val targetName: String,
    val questions: List<DetailSupplementQuestionData> = emptyList(),
    val loading: Boolean = false
)

data class VoiceCloneLocalSample(
    val scriptId: String,
    val text: String,
    val filePath: String,
    val durationMs: Long,
    val qualityWarnings: List<String> = emptyList(),
    val qualityBlocked: Boolean = false
)

data class VoiceContactCaptureUiState(
    val taskId: String? = null,
    val prompt: String = "",
    val contactName: String = "",
    val contactPhone: String = "",
    val eventId: Long = 0L,
    val completedContact: EffectiveTaskContact? = null
)

data class VoiceUiCommandUiState(
    val eventId: Long = 0L,
    val taskId: String? = null,
    val type: VoiceUiCommandType,
    val detailSummaryText: String = ""
)

enum class VoiceUiCommandType {
    ConfirmDefaultContact,
    CompleteDetailSupplement,
    ReturnHome
}

data class DeviceContactSelectionCandidateUi(
    val contactId: String? = null,
    val displayName: String,
    val phoneNumber: String,
    val label: String? = null
)

data class DeviceContactSelectionGroupUi(
    val name: String,
    val candidates: List<DeviceContactSelectionCandidateUi>
)

data class DeviceContactSelectionUiState(
    val pendingToolCallId: String,
    val reason: String? = null,
    val groups: List<DeviceContactSelectionGroupUi>,
    val preResolvedResults: List<Map<String, Any?>> = emptyList()
)
