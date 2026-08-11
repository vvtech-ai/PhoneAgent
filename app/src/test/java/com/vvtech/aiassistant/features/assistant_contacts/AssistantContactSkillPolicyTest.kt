package com.vvtech.aiassistant.features.assistant_contacts

import com.vvtech.aiassistant.features.assistant_home.AssistantHomeCardUi
import com.vvtech.aiassistant.features.assistant_home.domain.HomeEntryAction
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantContactSkillPolicyTest {
    @Test
    fun keepsOnlyEnabledContactSkillsInHomeOrder() {
        val options = buildAssistantContactSkillOptions(
            listOf(
                card(
                    id = "restaurant",
                    title = "订餐厅",
                    enabled = true,
                    action = HomeEntryAction.OpenSkill(
                        skillId = "restaurant_booking",
                        opening = "想订哪家餐厅？"
                    )
                ),
                card(
                    id = "apology",
                    title = "道歉",
                    enabled = false,
                    statusLabel = "即将提供",
                    action = HomeEntryAction.OpenSkill("apology")
                ),
                card(
                    id = "translation",
                    title = "实时翻译",
                    enabled = true,
                    action = HomeEntryAction.OpenTranslation
                ),
                card(
                    id = "blank",
                    title = "空 Skill",
                    enabled = true,
                    action = HomeEntryAction.OpenSkill(" ")
                )
            )
        )

        assertEquals(listOf("restaurant"), options.map { it.id })
        assertEquals("restaurant_booking", options[0].skillId)
        assertEquals("想订哪家餐厅？", options[0].opening)
        assertTrue(options[0].enabled)
    }

    @Test
    fun dispatchesOnlyEnabledSkillOption() {
        val events = mutableListOf<String>()
        val disabled = option(enabled = false)
        val enabled = option(enabled = true)
        val armInitialSkill: (String, String?) -> Unit = { skillId, opening ->
            events += "arm:$skillId:$opening"
        }
        val onSkillSelected: (String) -> Unit = { skillId ->
            events += "select:$skillId"
        }

        assertFalse(dispatchAssistantContactSkillOption(disabled, armInitialSkill, onSkillSelected))
        assertTrue(events.isEmpty())
        assertTrue(dispatchAssistantContactSkillOption(enabled, armInitialSkill, onSkillSelected))
        assertEquals(
            listOf(
                "arm:restaurant_booking:想订哪家餐厅？",
                "select:restaurant_booking"
            ),
            events
        )
    }

    private fun option(enabled: Boolean) = AssistantContactSkillOption(
        id = "restaurant",
        title = "订餐厅",
        subtitle = "帮你询位、预订包房",
        enabled = enabled,
        statusLabel = if (enabled) null else "即将提供",
        skillId = "restaurant_booking",
        opening = "想订哪家餐厅？"
    )

    private fun card(
        id: String,
        title: String,
        enabled: Boolean,
        statusLabel: String? = null,
        action: HomeEntryAction
    ) = AssistantHomeCardUi(
        id = id,
        title = title,
        subtitle = "$title 的说明",
        imageUrl = null,
        enabled = enabled,
        statusLabel = statusLabel,
        action = action
    )
}
