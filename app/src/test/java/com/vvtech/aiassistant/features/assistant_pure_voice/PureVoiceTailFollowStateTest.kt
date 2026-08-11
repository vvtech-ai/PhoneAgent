package com.vvtech.aiassistant.features.assistant_pure_voice

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PureVoiceTailFollowStateTest {

    @Test
    fun layoutGrowthKeepsTailFollowingWhenUserDidNotScroll() {
        val state = PureVoiceTailFollowState()
            .onListSnapshot(isScrollInProgress = false, canScrollForward = false)
            .onListSnapshot(isScrollInProgress = false, canScrollForward = true)

        assertTrue(state.followingTail)
    }

    @Test
    fun userScrollAwayDisablesTailFollowing() {
        val state = PureVoiceTailFollowState()
            .onListSnapshot(isScrollInProgress = true, canScrollForward = true)

        assertFalse(state.followingTail)
    }

    @Test
    fun reachingTailAgainEnablesTailFollowing() {
        val state = PureVoiceTailFollowState(followingTail = false)
            .onListSnapshot(isScrollInProgress = true, canScrollForward = false)

        assertTrue(state.followingTail)
    }
}
