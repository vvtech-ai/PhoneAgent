package com.vvtech.aiassistant.features.assistant_home

import androidx.compose.ui.graphics.Color
import com.vvtech.aiassistant.features.assistant_home.domain.HomeEntryAction
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AssistantHomeQuickTaskStyleTest {
    @Test
    fun translationDialEntryUsesPrototypePurpleWithoutDependingOnBackendTitle() {
        val renamedTranslationCard = card(
            title = "后台可调整的任意名称",
            action = HomeEntryAction.OpenTranslation
        )
        val sameTitleSkillCard = card(
            title = renamedTranslationCard.title,
            action = HomeEntryAction.OpenSkill("another_skill")
        )

        assertEquals(Color(0xFF6C5CE7), assistantHomeCardStatusDotColor(renamedTranslationCard))
        assertNull(assistantHomeCardStatusDotColor(sameTitleSkillCard))
    }

    private fun card(
        title: String,
        action: HomeEntryAction
    ) = AssistantHomeCardUi(
        id = "card",
        title = title,
        subtitle = "副标题",
        imageUrl = null,
        enabled = true,
        statusLabel = null,
        action = action
    )
}
