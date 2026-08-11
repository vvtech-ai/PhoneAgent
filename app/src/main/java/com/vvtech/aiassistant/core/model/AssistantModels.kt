package com.vvtech.aiassistant.core.model

import com.vvtech.aiassistant.model.ApiResponse
import com.vvtech.aiassistant.model.UserContextPayload

data class AssistantSessionMeta(
    val taskId: String,
    val sceneType: String,
    val taskStatus: String,
    val title: String,
    val subtitle: String?,
    val waitingForUser: Boolean
)

data class AssistantActionChip(
    val actionId: String,
    val label: String,
    val kind: String
)

data class RestaurantCardPayload(
    val itemId: String,
    val name: String,
    val cuisine: String?,
    val area: String?,
    val address: String,
    val phone: String,
    val distanceMeters: Int?,
    val actions: List<AssistantActionChip> = emptyList()
)

data class HotelCardPayload(
    val itemId: String,
    val name: String,
    val city: String,
    val priceHint: String,
    val roomType: String,
    val address: String,
    val summary: String,
    val actions: List<AssistantActionChip> = emptyList()
)

data class CallConfirmCardPayload(
    val targetName: String,
    val phone: String?,
    val purpose: String,
    val summary: String,
    val actions: List<AssistantActionChip> = emptyList()
)

data class ResultSummaryPayload(
    val headline: String,
    val detail: String,
    val status: String,
    val actions: List<AssistantActionChip> = emptyList()
)

data class AssistantMessageItem(
    val messageId: String,
    val type: String,
    val role: String,
    val text: String?,
    val title: String?,
    val subtitle: String?,
    val statusText: String?,
    val actions: List<AssistantActionChip> = emptyList(),
    val restaurantCard: RestaurantCardPayload? = null,
    val hotelCard: HotelCardPayload? = null,
    val callConfirmCard: CallConfirmCardPayload? = null,
    val resultSummary: ResultSummaryPayload? = null,
    val createdAt: String? = null
)

data class AssistantSessionResponse(
    val session: AssistantSessionMeta,
    val messages: List<AssistantMessageItem>
)

data class ContactResolutionPayload(
    val contactName: String? = null,
    val phoneNumber: String? = null,
    val status: String? = null
)

data class StructuredAssistantSlotValue(
    val value: String? = null,
    val confidence: Double? = null
)

data class StructuredAssistantUnderstanding(
    val schemaVersion: String? = null,
    val scene: String? = null,
    val sceneConfidence: Double? = null,
    val slotUpdates: Map<String, StructuredAssistantSlotValue> = emptyMap(),
    val nextAction: String? = null,
    val speak: String? = null,
    val statusHint: String? = null,
    val complete: Boolean? = null
)

data class AssistantMessageRequest(
    val userId: String,
    val taskId: String? = null,
    val startFresh: Boolean? = null,
    val message: String? = null,
    val actionId: String? = null,
    val actionLabel: String? = null,
    val userContext: UserContextPayload? = null,
    val contactResolution: ContactResolutionPayload? = null,
    val structuredUnderstanding: StructuredAssistantUnderstanding? = null,
    val assistantResponseText: String? = null,
    val languageCode: String? = null
)

data class TextSessionStartRequest(
    val userId: String,
    val userContext: UserContextPayload? = null,
    val languageCode: String? = null
)

data class TextTurnRequest(
    val userId: String,
    val taskId: String? = null,
    val startFresh: Boolean? = null,
    val message: String? = null,
    val actionId: String? = null,
    val actionLabel: String? = null,
    val userContext: UserContextPayload? = null,
    val contactResolution: ContactResolutionPayload? = null,
    val languageCode: String? = null
)

typealias AssistantSessionApiResponse = ApiResponse<AssistantSessionResponse>

data class AssistantHistoryItem(
    val taskId: String,
    val sceneType: String,
    val taskStatus: String,
    val title: String? = null,
    val subtitle: String? = null,
    val resultHeadline: String? = null,
    val resultDetail: String? = null,
    val resultStatus: String? = null,
    val updatedAt: String? = null
)

data class AssistantSessionHistoryResponse(
    val tasks: List<AssistantHistoryItem> = emptyList()
)
