package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalPage
import org.junit.Assert.assertEquals
import org.junit.Test

class AssistantCallNavigationActionsTest {
    @Test
    fun normalCallBackNavigatesToConfiguredCallsPage() {
        val recorder = CallNavigationRecorder()

        navigateBackFromAssistantNormalCall(
            state = AssistantNormalCallNavigationState(
                pureVoiceMode = false,
                normalCallReturnPage = FinalPage.Calls.name
            ),
            callbacks = recorder.callbacks
        )

        assertEquals(listOf("page:Calls"), recorder.events)
    }

    @Test
    fun normalCallHangupSyncsCallsTabBeforeNavigatingToCalls() {
        val recorder = CallNavigationRecorder()

        navigateAfterAssistantNormalCallHangup(
            state = AssistantNormalCallNavigationState(
                pureVoiceMode = false,
                normalCallReturnPage = FinalPage.Calls.name
            ),
            callbacks = recorder.callbacks
        )

        assertEquals(listOf("tab:Calls", "page:Calls"), recorder.events)
    }

    @Test
    fun normalCallHangupSyncsContactsTabBeforeNavigatingToContactDetail() {
        val recorder = CallNavigationRecorder()

        navigateAfterAssistantNormalCallHangup(
            state = AssistantNormalCallNavigationState(
                pureVoiceMode = false,
                normalCallReturnPage = FinalPage.ContactDetail.name
            ),
            callbacks = recorder.callbacks
        )

        assertEquals(listOf("tab:Contacts", "page:ContactDetail"), recorder.events)
    }

    @Test
    fun normalCallInvalidReturnPageFallsBackToCalls() {
        val recorder = CallNavigationRecorder()

        navigateAfterAssistantNormalCallHangup(
            state = AssistantNormalCallNavigationState(
                pureVoiceMode = false,
                normalCallReturnPage = "not-a-page"
            ),
            callbacks = recorder.callbacks
        )

        assertEquals(FinalPage.Calls, assistantNormalCallReturnTarget(
            AssistantNormalCallNavigationState(
                pureVoiceMode = false,
                normalCallReturnPage = "not-a-page"
            )
        ))
        assertEquals(listOf("tab:Calls", "page:Calls"), recorder.events)
    }
}

private class CallNavigationRecorder {
    val events = mutableListOf<String>()

    val callbacks = AssistantNormalCallNavigationCallbacks(
        onPageChange = { page ->
            events += "page:${page.name}"
        },
        onMainTabChange = { tab ->
            events += "tab:${tab.name}"
        }
    )
}
