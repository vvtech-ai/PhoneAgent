package com.vvtech.aiassistant.features.assistant_home

import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfigPolicy
import com.vvtech.aiassistant.features.assistant_home.domain.HomeEntryAction
import com.vvtech.aiassistant.features.assistant_home.domain.HomeSloganRotationPolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeConfigPolicyTest {
    @Test
    fun minimumVersionUsesNumericSegments() {
        assertTrue(HomeConfigPolicy.isVersionSupported("1.10.0", "1.9.9"))
        assertTrue(HomeConfigPolicy.isVersionSupported("1.0.31-local", "1.0.31"))
        assertFalse(HomeConfigPolicy.isVersionSupported("1.0.30", "1.0.31"))
        assertFalse(HomeConfigPolicy.isVersionSupported("bad", "1.0.31"))
    }

    @Test
    fun sloganRotationAdvancesOnceAndNewVersionStartsFirst() {
        assertEquals(HomeSloganRotationPolicy.Result(1, 0),
            HomeSloganRotationPolicy.next("v1", "v1", 1, 2))
        assertEquals(HomeSloganRotationPolicy.Result(0, 1),
            HomeSloganRotationPolicy.next("v1", "v2", 1, 2))
        assertEquals(HomeSloganRotationPolicy.Result(0, 1),
            HomeSloganRotationPolicy.next("v2", "v2", 0, 2))
    }

    @Test
    fun entryDispatcherMapsSkillTranslationGenericAndDisabled() {
        val events = mutableListOf<String>()
        val dispatcher = HomeCardEntryDispatcher(
            clearInitialSkill = { events += "clear" },
            armInitialSkill = { skillId, opening -> events += "arm:$skillId:$opening" }
        )
        dispatcher.dispatch(card(true, HomeEntryAction.OpenSkill("restaurant_booking", "欢迎")),
            { events += "voice:$it"; true }, { events += "translation" })
        dispatcher.dispatch(card(true, HomeEntryAction.OpenTranslation),
            { events += "voice:$it"; true }, { events += "translation" })
        dispatcher.dispatch(card(true, HomeEntryAction.OpenGenericTask),
            { events += "voice:$it"; true }, { events += "translation" })
        dispatcher.dispatch(card(false, HomeEntryAction.OpenSkill("ignored")),
            { events += "voice:$it"; true }, { events += "translation" })

        assertEquals(
            listOf(
                "arm:restaurant_booking:欢迎",
                "voice:restaurant_booking",
                "clear",
                "translation",
                "clear",
                "voice:null"
            ),
            events
        )
    }

    @Test
    fun entryDispatcherBlocksEveryHomeActionBeforeSideEffectsWhenOffline() {
        val events = mutableListOf<String>()
        val dispatcher = HomeCardEntryDispatcher(
            clearInitialSkill = { events += "clear" },
            armInitialSkill = { skillId, _ -> events += "arm:$skillId" }
        )
        val actions = listOf(
            HomeEntryAction.OpenSkill("restaurant_booking"),
            HomeEntryAction.OpenTranslation,
            HomeEntryAction.OpenGenericTask
        )

        val handled = actions.map { action ->
            dispatcher.dispatch(
                card = card(true, action),
                onQuickVoiceEntry = { events += "voice"; true },
                onOpenTranslateDial = { events += "translation" },
                onBlockOffline = {
                    events += "offline"
                    true
                }
            )
        }

        assertEquals(listOf(false, false, false), handled)
        assertEquals(listOf("offline", "offline", "offline"), events)
    }

    private fun card(enabled: Boolean, action: HomeEntryAction) = AssistantHomeCardUi(
        id = "card",
        title = "标题",
        subtitle = "副标题",
        imageUrl = null,
        enabled = enabled,
        statusLabel = null,
        action = action
    )
}
