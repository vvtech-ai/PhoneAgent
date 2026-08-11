package com.vvtech.aiassistant.features.assistant_agent

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.After
import org.junit.Test

class AgentInitialSkillLaunchStoreTest {
    @After
    fun clearStore() {
        AgentInitialSkillLaunchStore.clear()
    }

    @Test
    fun initialSkillIsConsumedOnlyOnce() {
        AgentInitialSkillLaunchStore.arm(
            "restaurant_booking",
            opening = "想订哪家餐厅？",
            now = 100L
        )
        AgentInitialSkillLaunchStore.bindToSession("session-1", now = 150L)

        assertEquals("想订哪家餐厅？", AgentInitialSkillLaunchStore.peekOpening(now = 160L))
        AgentInitialSkillLaunchStore.rememberOpening("想订哪家餐厅？", now = 170L)
        val launch = AgentInitialSkillLaunchStore.takeLaunch("session-1", now = 200L)
        assertEquals("restaurant_booking", launch?.skillId)
        assertEquals("想订哪家餐厅？", launch?.opening)
        assertNull(AgentInitialSkillLaunchStore.takeLaunch("session-1", now = 201L))
    }

    @Test
    fun genericWelcomeIsRetainedUntilTheFirstBoundTurn() {
        AgentInitialSkillLaunchStore.rememberOpening("请说出你的需求。", now = 100L)
        AgentInitialSkillLaunchStore.bindToSession("session-1", now = 150L)

        val launch = AgentInitialSkillLaunchStore.takeLaunch("session-1", now = 200L)

        assertNull(launch?.skillId)
        assertEquals("请说出你的需求。", launch?.opening)
    }

    @Test
    fun presentedOpeningCanBeReadForOcrWithoutConsumingTheFirstTurnFallback() {
        AgentInitialSkillLaunchStore.arm(
            "restaurant_booking",
            opening = "想订哪家餐厅？",
            now = 100L,
        )
        AgentInitialSkillLaunchStore.rememberOpening("想订哪家餐厅？", now = 120L)
        AgentInitialSkillLaunchStore.bindToSession("session-1", now = 150L)

        assertEquals(
            "想订哪家餐厅？",
            AgentInitialSkillLaunchStore.peekPresentedOpeningForSession("session-1", now = 160L),
        )
        assertNull(
            AgentInitialSkillLaunchStore.peekPresentedOpeningForSession("session-2", now = 160L),
        )
        assertEquals(
            "想订哪家餐厅？",
            AgentInitialSkillLaunchStore.takeLaunch("session-1", now = 170L)?.opening,
        )
    }

    @Test
    fun configuredOpeningIsNotCarriedUntilItWasPresented() {
        AgentInitialSkillLaunchStore.arm(
            "restaurant_booking",
            opening = "想订哪家餐厅？",
            now = 100L
        )
        AgentInitialSkillLaunchStore.bindToSession("session-1", now = 150L)

        val launch = AgentInitialSkillLaunchStore.takeLaunch("session-1", now = 200L)

        assertEquals("restaurant_booking", launch?.skillId)
        assertNull(launch?.opening)
    }

    @Test
    fun expiredInitialSkillIsDiscarded() {
        AgentInitialSkillLaunchStore.arm("restaurant_booking", now = 100L)
        AgentInitialSkillLaunchStore.bindToSession("session-1", now = 200L)

        assertNull(AgentInitialSkillLaunchStore.take("session-1", now = 300_101L))
    }

    @Test
    fun initialSkillCannotLeakIntoAnotherSession() {
        AgentInitialSkillLaunchStore.arm("restaurant_booking", now = 100L)
        AgentInitialSkillLaunchStore.bindToSession("session-1", now = 150L)

        assertNull(AgentInitialSkillLaunchStore.take("session-2", now = 200L))
        assertNull(AgentInitialSkillLaunchStore.take("session-1", now = 201L))
    }
}
