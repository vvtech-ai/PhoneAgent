package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantMessageItem
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.VoiceRole

internal object AssistantSessionDialogueStepPolicy {
    fun mapClarificationSteps(
        messages: List<AssistantMessageItem>,
        hideInternalSync: Boolean = false
    ): List<ClarificationStep> {
        val steps = mutableListOf<ClarificationStep>()
        var conversationStarted = false
        messages.forEach { message ->
            when (message.type) {
                "user_text" -> {
                    val text = message.text.orEmpty().trim()
                    if (text.isNotBlank()) {
                        if (hideInternalSync && isStructuredSupplementSyncText(text)) {
                            return@forEach
                        }
                        conversationStarted = true
                        steps += ClarificationStep(VoiceRole.User, text, "")
                    }
                }

                "assistant_text" -> if (conversationStarted) {
                    extractVisibleAssistantDialogueText(message)?.let {
                        steps += ClarificationStep(VoiceRole.Assistant, it, "")
                    }
                }

                "restaurant_card",
                "hotel_card",
                "task_status",
                "assistant_suggestion",
                "action_chip_group",
                "call_confirm_card",
                "result_summary" -> Unit
            }
        }
        return steps
    }

    fun extractVisibleAssistantDialogueText(message: AssistantMessageItem): String? {
        if (message.type != "assistant_text") return null
        return normalizeAssistantDialogueText(message.text).takeIf { it.isNotBlank() }
    }

    fun normalizeAssistantDialogueText(text: String?): String {
        val trimmed = text.orEmpty().trim()
        if (trimmed.isBlank()) return ""
        return AssistantDialogueMetaPrefixRegex.replace(trimmed, "").trim()
    }

    fun resolveLatestBackendAssistantPrompt(
        currentSteps: List<ClarificationStep>,
        backendSteps: List<ClarificationStep>
    ): String? {
        val latestBackendAssistant = backendSteps
            .asReversed()
            .firstOrNull { it.role == VoiceRole.Assistant }
            ?.text
            ?.trim()
            .orEmpty()
        if (latestBackendAssistant.isBlank()) return null
        val latestVisibleAssistant = currentSteps
            .asReversed()
            .firstOrNull { it.role == VoiceRole.Assistant }
            ?.text
            ?.trim()
            .orEmpty()
        if (
            latestBackendAssistant == latestVisibleAssistant &&
            currentSteps.lastOrNull()?.role == VoiceRole.User
        ) {
            return latestBackendAssistant
        }
        return latestBackendAssistant.takeIf { it != latestVisibleAssistant }
    }

    fun removeTrailingAssistantPrompt(
        steps: List<ClarificationStep>,
        prompt: String?
    ): List<ClarificationStep> {
        val normalizedPrompt = prompt?.trim().orEmpty()
        if (normalizedPrompt.isBlank() || steps.isEmpty()) return steps
        val lastStep = steps.last()
        if (lastStep.role != VoiceRole.Assistant) return steps
        return if (lastStep.text.trim() == normalizedPrompt) steps.dropLast(1) else steps
    }

    fun appendClarificationStepIfMissing(
        steps: MutableList<ClarificationStep>,
        role: VoiceRole,
        text: String
    ) {
        val normalized = text.trim()
        if (normalized.isBlank()) return
        val last = steps.lastOrNull()
        if (last != null && last.role == role && last.text == normalized) return
        steps += ClarificationStep(
            role = role,
            text = normalized,
            status = ""
        )
    }

    private fun isStructuredSupplementSyncText(text: String): Boolean {
        val normalized = text.trim()
        return normalized.contains("本次预订请预留信息") ||
            normalized.contains("本次订位请预留信息") ||
            normalized.contains("补充细节：")
    }
}

private val AssistantDialogueMetaPrefixRegex = Regex(
    pattern = "^(我(?:先)?(?:记下|记住)了?你的(?:条件|需求))[，。、“”\\s:：;；,、]*"
)
