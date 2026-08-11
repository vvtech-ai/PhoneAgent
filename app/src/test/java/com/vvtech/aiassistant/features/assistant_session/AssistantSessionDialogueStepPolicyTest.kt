package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantMessageItem
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.viewmodel.mapClarificationSteps
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AssistantSessionDialogueStepPolicyTest {
    @Test
    fun mapsBackendMessagesAfterUserConversationStarted() {
        val steps = AssistantSessionDialogueStepPolicy.mapClarificationSteps(
            listOf(
                message("assistant_text", "这句不应展示"),
                message("restaurant_card"),
                message("user_text", "给我订北海渔村"),
                message("assistant_text", "我先记下了你的需求：确认包间信息"),
                message("call_confirm_card")
            )
        )

        assertEquals(
            listOf(
                ClarificationStep(VoiceRole.User, "给我订北海渔村", ""),
                ClarificationStep(VoiceRole.Assistant, "确认包间信息", "")
            ),
            steps
        )
    }

    @Test
    fun hidesInternalSupplementSyncOnlyWhenRequested() {
        val messages = listOf(
            message("user_text", "本次预订请预留信息：Alex，联系电话13800138000。"),
            message("assistant_text", "Please confirm the booking contact.")
        )

        assertEquals(
            emptyList<ClarificationStep>(),
            AssistantSessionDialogueStepPolicy.mapClarificationSteps(messages, hideInternalSync = true)
        )
        assertEquals(
            listOf(
                ClarificationStep(
                    VoiceRole.User,
                    "本次预订请预留信息：Alex，联系电话13800138000。",
                    ""
                ),
                ClarificationStep(VoiceRole.Assistant, "Please confirm the booking contact.", "")
            ),
            AssistantSessionDialogueStepPolicy.mapClarificationSteps(messages, hideInternalSync = false)
        )
    }

    @Test
    fun extractsOnlyAssistantTextAndRemovesMetaPrefix() {
        assertEquals(
            "今晚六点两个人",
            AssistantSessionDialogueStepPolicy.extractVisibleAssistantDialogueText(
                message("assistant_text", "我先记下了你的需求：今晚六点两个人")
            )
        )
        assertNull(
            AssistantSessionDialogueStepPolicy.extractVisibleAssistantDialogueText(
                message("user_text", "我先记下了你的需求：今晚六点两个人")
            )
        )
    }

    @Test
    fun resolvesLatestBackendAssistantPromptForReplayGate() {
        val current = listOf(
            ClarificationStep(VoiceRole.Assistant, "请选择一家餐厅", ""),
            ClarificationStep(VoiceRole.User, "第一家", "")
        )
        val sameBackend = listOf(ClarificationStep(VoiceRole.Assistant, "请选择一家餐厅", ""))
        val newBackend = listOf(ClarificationStep(VoiceRole.Assistant, "请补充预订人信息", ""))

        assertEquals(
            "请选择一家餐厅",
            AssistantSessionDialogueStepPolicy.resolveLatestBackendAssistantPrompt(current, sameBackend)
        )
        assertEquals(
            "请补充预订人信息",
            AssistantSessionDialogueStepPolicy.resolveLatestBackendAssistantPrompt(current, newBackend)
        )
        assertNull(
            AssistantSessionDialogueStepPolicy.resolveLatestBackendAssistantPrompt(
                listOf(ClarificationStep(VoiceRole.Assistant, "请选择一家餐厅", "")),
                sameBackend
            )
        )
    }

    @Test
    fun removesOnlyMatchingTrailingAssistantPrompt() {
        val steps = listOf(
            ClarificationStep(VoiceRole.User, "第一家", ""),
            ClarificationStep(VoiceRole.Assistant, "请补充预订人信息", "")
        )

        assertEquals(
            listOf(ClarificationStep(VoiceRole.User, "第一家", "")),
            AssistantSessionDialogueStepPolicy.removeTrailingAssistantPrompt(steps, "请补充预订人信息")
        )
        assertEquals(
            steps,
            AssistantSessionDialogueStepPolicy.removeTrailingAssistantPrompt(steps, "请选择一家餐厅")
        )
    }

    @Test
    fun appendStepHelperTrimsBlankAndDeduplicatesTail() {
        val steps = mutableListOf(ClarificationStep(VoiceRole.User, "第一家", ""))

        AssistantSessionDialogueStepPolicy.appendClarificationStepIfMissing(steps, VoiceRole.User, " 第一家 ")
        AssistantSessionDialogueStepPolicy.appendClarificationStepIfMissing(steps, VoiceRole.Assistant, " ")
        AssistantSessionDialogueStepPolicy.appendClarificationStepIfMissing(steps, VoiceRole.Assistant, "请补充预订人信息")

        assertEquals(
            listOf(
                ClarificationStep(VoiceRole.User, "第一家", ""),
                ClarificationStep(VoiceRole.Assistant, "请补充预订人信息", "")
            ),
            steps
        )
    }

    @Test
    fun legacyViewModelHelperDelegatesToSessionPolicy() {
        val messages = listOf(
            message("user_text", "补充细节：要包间。"),
            message("assistant_text", "我记下了你的条件：还需要联系人")
        )

        assertEquals(
            AssistantSessionDialogueStepPolicy.mapClarificationSteps(messages, hideInternalSync = true),
            mapClarificationSteps(messages, hideInternalSync = true)
        )
    }

    private fun message(
        type: String,
        text: String? = null
    ): AssistantMessageItem = AssistantMessageItem(
        messageId = type + "-1",
        type = type,
        role = if (type == "user_text") "user" else "assistant",
        text = text,
        title = null,
        subtitle = null,
        statusText = null,
        restaurantCard = null,
        hotelCard = null
    )
}
