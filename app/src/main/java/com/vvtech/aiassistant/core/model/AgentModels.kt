package com.vvtech.aiassistant.core.model

import com.vvtech.aiassistant.model.ApiResponse
import com.vvtech.aiassistant.model.UserContextPayload
import com.vvtech.aiassistant.domain.task.ReceiptField

data class SelectedContactTaskContext(
    val source: String,
    val name: String,
    val phone: String
) {
    companion object {
        const val ContactDetailSource = "CONTACT_DETAIL"

        fun contactDetail(name: String, phone: String): SelectedContactTaskContext =
            SelectedContactTaskContext(
                source = ContactDetailSource,
                name = name.trim(),
                phone = phone.trim()
            )
    }
}

data class AgentChatRequest(
    val sessionId: String,
    val message: String? = null,
    val actionId: String? = null,
    val actionPayload: Map<String, Any>? = null,
    val userContext: UserContextPayload? = null,
    val pendingToolCallId: String? = null,
    val channel: String? = null,
    val userId: String? = null,
    val initialSkillId: String? = null,
    val initialOpening: String? = null,
    val commandId: String,
    val idempotencyKey: String,
    val traceId: String,
    val supersedesCommandId: String? = null,
    val selectedContact: SelectedContactTaskContext? = null,
)

data class AgentConversationInterruptRequest(
    val userId: String,
    val reason: String? = null
)

data class AgentConversationInterruptResponse(
    val sessionId: String,
    val status: String,
    val updatedAt: String? = null
)

data class AgentChatResponse(
    val sessionId: String,
    val type: String,
    val text: String?,
    val thinking: String? = null,
    val toolCalls: List<ToolCallInfo>? = null,
    val options: OptionsPayload? = null,
    val questions: AskQuestionsPayload? = null,
    val permissionRequest: PermissionRequestPayload? = null,
    val documentImportRequest: DocumentImportRequestPayload? = null,
    val callSpec: CallSpecPayload? = null,
    val callResult: CallResultPayload? = null,
    val batchCallResult: BatchCallResultPayload? = null,
    val pendingToolCallId: String? = null,
    val lookupContactPhone: String? = null,
    val lookupDeviceContactsByNames: LookupDeviceContactsByNamesPayload? = null
)

data class LookupDeviceContactsByNamesPayload(
    val names: List<String>,
    val reason: String? = null
)

data class DeviceContactCandidate(
    val contactId: String? = null,
    val displayName: String,
    val phoneNumber: String,
    val label: String? = null
)

data class DeviceContactLookupItem(
    val name: String,
    val status: String,
    val phoneNumber: String? = null,
    val displayName: String? = null,
    val label: String? = null,
    val contactId: String? = null,
    val candidates: List<DeviceContactCandidate>? = null
)

data class AskQuestionsPayload(
    val title: String?,
    val items: List<AskQuestionItem>
)

data class AskQuestionItem(
    val id: String,
    val prompt: String,
    val answerType: String,
    val choices: List<String>? = null,
    val multi: Boolean? = null,
    val required: Boolean? = true,
    val hint: String? = null,
    val defaultValue: String? = null,
    val validatorPattern: String? = null
)

data class ToolCallInfo(
    val name: String,
    val args: String,
    val result: String
)

data class ToolCardInfo(
    val id: String = "",
    val toolName: String = "",
    val methodLabel: String,
    val body: String = "",
    val result: String = "",
    val status: String = ""
)

data class OptionsPayload(
    val title: String,
    val items: List<OptionItem>
)

data class OptionItem(
    val id: String,
    val label: String,
    val detail: String? = null,
    val tags: List<String>? = null,
    val phone: String? = null,
    val address: String? = null,
    val distanceMeters: Int? = null
)

data class PermissionRequestPayload(
    val permissionKey: String,
    val androidPermission: String? = null,
    val reason: String? = null,
    val statusBeforeRequest: String? = null
)

data class DocumentImportRequestPayload(
    val title: String? = null,
    val reason: String? = null,
    val acceptedTypes: List<String>? = null,
    val acceptedMimeTypes: List<String>? = null,
    val maxBytes: Long? = null
)

data class DocumentParseResult(
    val status: String,
    val fileName: String? = null,
    val mimeType: String? = null,
    val charCount: Int = 0,
    val truncated: Boolean = false,
    val content: String? = null,
    val message: String? = null
)

data class CallSpecPayload(
    val phoneNumber: String,
    val scene: String,
    val targetName: String,
    val primaryGoal: String,
    val summaryLines: List<String>,
    val negotiationRules: List<String>? = null,
    val boundaries: List<String>? = null
)

data class CallResultPayload(
    val status: String,
    val headline: String,
    val detail: String,
    val metadata: Map<String, String>? = null,
    val receiptFields: List<ReceiptField> = emptyList(),
)

data class BatchCallResultPayload(
    val status: String,
    val headline: String,
    val items: List<BatchCallItemResultPayload>,
    val batchId: String? = null,
)

data class BatchCallItemResultPayload(
    val itemId: String,
    val targetName: String,
    val phoneNumber: String,
    val status: String,
    val headline: String,
    val detail: String,
    val attemptCount: Int,
    val recalled: Boolean,
    val abnormal: Boolean,
    val transcript: String? = null
)

typealias AgentChatApiResponse = ApiResponse<AgentChatResponse>
typealias AgentConversationInterruptApiResponse = ApiResponse<AgentConversationInterruptResponse>
typealias DocumentParseApiResponse = ApiResponse<DocumentParseResult>
