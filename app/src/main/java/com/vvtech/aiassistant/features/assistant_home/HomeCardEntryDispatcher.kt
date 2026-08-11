package com.vvtech.aiassistant.features.assistant_home

import com.vvtech.aiassistant.features.assistant_home.domain.HomeEntryAction
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

internal class HomeCardEntryDispatcher(
    private val clearInitialSkill: () -> Unit,
    private val armInitialSkill: (String, String?) -> Unit
) {
    fun dispatch(
        card: AssistantHomeCardUi,
        onQuickVoiceEntry: (String?) -> Boolean,
        onOpenTranslateDial: () -> Unit,
        onBlockOffline: () -> Boolean = { false }
    ): Boolean {
        val actionName = when (card.action) {
            is HomeEntryAction.OpenSkill -> "open_skill"
            HomeEntryAction.OpenTranslation -> "open_translation"
            HomeEntryAction.OpenGenericTask -> "open_generic_task"
            HomeEntryAction.None -> "none"
        }
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.APP,
                eventType = "HOME_ENTRY_DISPATCH_REQUESTED",
                attributes = mapOf("cardId" to card.id, "action" to actionName)
            )
        )
        if (!card.enabled) {
            RuntimeStateLogger.warn(
                RuntimeStateLogEvent(
                    domain = RuntimeStateLogDomain.APP,
                    eventType = "HOME_ENTRY_DISPATCH_BLOCKED",
                    result = "blocked",
                    reason = "card_disabled",
                    attributes = mapOf("cardId" to card.id, "action" to actionName)
                )
            )
            return false
        }
        if (onBlockOffline()) {
            RuntimeStateLogger.warn(
                RuntimeStateLogEvent(
                    domain = RuntimeStateLogDomain.APP,
                    eventType = "HOME_ENTRY_DISPATCH_BLOCKED",
                    result = "blocked",
                    reason = "offline",
                    attributes = mapOf("cardId" to card.id, "action" to actionName)
                )
            )
            return false
        }
        val handled = when (val action = card.action) {
            is HomeEntryAction.OpenSkill -> {
                armInitialSkill(action.skillId, action.opening)
                onQuickVoiceEntry(action.skillId).also { opened ->
                    if (!opened) clearInitialSkill()
                }
            }
            HomeEntryAction.OpenTranslation -> {
                clearInitialSkill()
                onOpenTranslateDial()
                true
            }
            HomeEntryAction.OpenGenericTask -> {
                clearInitialSkill()
                onQuickVoiceEntry(null)
            }
            HomeEntryAction.None -> false
        }
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.APP,
                eventType = "HOME_ENTRY_DISPATCH_COMPLETED",
                result = if (handled) "handled" else "not_handled",
                attributes = mapOf("cardId" to card.id, "action" to actionName)
            )
        )
        return handled
    }
}
