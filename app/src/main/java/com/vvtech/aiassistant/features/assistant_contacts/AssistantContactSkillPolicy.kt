package com.vvtech.aiassistant.features.assistant_contacts

import com.vvtech.aiassistant.features.assistant_home.AssistantHomeCardUi
import com.vvtech.aiassistant.features.assistant_home.domain.HomeEntryAction

internal data class AssistantContactSkillOption(
    val id: String,
    val title: String,
    val subtitle: String,
    val enabled: Boolean,
    val statusLabel: String?,
    val skillId: String,
    val opening: String?
)

internal fun buildAssistantContactSkillOptions(
    cards: List<AssistantHomeCardUi>
): List<AssistantContactSkillOption> = cards.mapNotNull { card ->
    if (!card.enabled) return@mapNotNull null
    val action = card.action as? HomeEntryAction.OpenSkill ?: return@mapNotNull null
    val skillId = action.skillId.trim()
    if (skillId.isEmpty()) return@mapNotNull null
    AssistantContactSkillOption(
        id = card.id,
        title = card.title,
        subtitle = card.subtitle,
        enabled = card.enabled,
        statusLabel = card.statusLabel,
        skillId = skillId,
        opening = action.opening
    )
}

internal fun dispatchAssistantContactSkillOption(
    option: AssistantContactSkillOption,
    armInitialSkill: (String, String?) -> Unit,
    onSkillSelected: (String) -> Unit
): Boolean {
    if (!option.enabled) return false
    armInitialSkill(option.skillId, option.opening)
    onSkillSelected(option.skillId)
    return true
}
