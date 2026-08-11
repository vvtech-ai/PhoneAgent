package com.vvtech.aiassistant.features.assistant_contacts

import org.junit.Assert.assertEquals
import org.junit.Test

class AssistantContactSkillOpeningPolicyTest {
    @Test
    fun buildsRestaurantOpeningWithSelectedContactName() {
        assertEquals(
            "想订海棠餐厅？告诉我时间和人数就行，有其他要求也可以一起说。",
            buildAssistantContactSkillOpening(
                skillId = "restaurant_booking",
                contactName = " 海棠餐厅 ",
                fallbackOpening = "想订哪家餐厅？"
            )
        )
    }

    @Test
    fun buildsMeetingOpeningWithSelectedContactName() {
        assertEquals(
            "要通知张三几点在哪开会？我来帮你打电话通知。",
            buildAssistantContactSkillOpening(
                skillId = "meeting_notification",
                contactName = "张三",
                fallbackOpening = "要通知谁？"
            )
        )
    }

    @Test
    fun buildsEventOpeningWithoutRepeatingInvitee() {
        assertEquals(
            "要邀约什么活动？跟我说下主题、时间地点，还有以谁的名义打。",
            buildAssistantContactSkillOpening(
                skillId = "business_event_invitation",
                contactName = "张三",
                fallbackOpening = "要邀约什么活动、邀请谁？"
            )
        )
    }

    @Test
    fun fallsBackForUnknownSkillOrBlankContactName() {
        assertEquals(
            "原始开场白",
            buildAssistantContactSkillOpening(
                skillId = "other_skill",
                contactName = "张三",
                fallbackOpening = "原始开场白"
            )
        )
        assertEquals(
            "想订哪家餐厅？",
            buildAssistantContactSkillOpening(
                skillId = "restaurant_booking",
                contactName = " ",
                fallbackOpening = "想订哪家餐厅？"
            )
        )
    }
}
