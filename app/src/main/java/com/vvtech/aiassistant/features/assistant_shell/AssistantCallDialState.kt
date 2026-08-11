package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant_calls.AssistantDialerStateHolder

internal data class DialReturnDestination(
    val mainTab: FinalMainTab,
    val page: FinalPage
)

internal class AssistantCallDialState(
    val dialer: AssistantDialerStateHolder = AssistantDialerStateHolder(),
    private val showCallsDialSheetState: MutableState<Boolean>,
    private val returnMainTabNameState: MutableState<String> = mutableStateOf(FinalMainTab.Home.name),
    private val returnPageNameState: MutableState<String> = mutableStateOf(FinalPage.Home.name),
    private val normalCallReturnPageState: MutableState<String>,
    private val normalCallMutedState: MutableState<Boolean>,
    private val normalCallSpeakerState: MutableState<Boolean>,
    private val normalCallSecondsState: MutableState<Int>
) {
    var showCallsDialSheet: Boolean by showCallsDialSheetState
    var normalCallReturnPage: String by normalCallReturnPageState
    var normalCallMuted: Boolean by normalCallMutedState
    var normalCallSpeaker: Boolean by normalCallSpeakerState
    var normalCallSeconds: Int by normalCallSecondsState
    val returnDestination: DialReturnDestination
        get() = DialReturnDestination(
            mainTab = runCatching {
                FinalMainTab.valueOf(returnMainTabNameState.value)
            }.getOrDefault(FinalMainTab.Home),
            page = runCatching {
                FinalPage.valueOf(returnPageNameState.value)
            }.getOrDefault(FinalPage.Home)
        )

    fun openDialSheet() {
        showCallsDialSheet = true
    }

    fun hideDialSheet() {
        showCallsDialSheet = false
    }

    fun captureReturnDestination(mainTab: FinalMainTab, page: FinalPage) {
        returnMainTabNameState.value = mainTab.name
        returnPageNameState.value = page.name
    }

}

@Composable
internal fun rememberAssistantCallDialState(
    normalCallReturnPageDefault: String,
    dialer: AssistantDialerStateHolder
): AssistantCallDialState {
    val showCallsDialSheetState = rememberSaveable { mutableStateOf(false) }
    val returnMainTabNameState = rememberSaveable { mutableStateOf(FinalMainTab.Home.name) }
    val returnPageNameState = rememberSaveable { mutableStateOf(FinalPage.Home.name) }
    val normalCallReturnPageState = rememberSaveable { mutableStateOf(normalCallReturnPageDefault) }
    val normalCallMutedState = rememberSaveable { mutableStateOf(false) }
    val normalCallSpeakerState = rememberSaveable { mutableStateOf(true) }
    val normalCallSecondsState = rememberSaveable { mutableStateOf(0) }
    return remember(
        showCallsDialSheetState,
        dialer,
        returnMainTabNameState,
        returnPageNameState,
        normalCallReturnPageState,
        normalCallMutedState,
        normalCallSpeakerState,
        normalCallSecondsState
    ) {
        AssistantCallDialState(
            dialer = dialer,
            showCallsDialSheetState = showCallsDialSheetState,
            returnMainTabNameState = returnMainTabNameState,
            returnPageNameState = returnPageNameState,
            normalCallReturnPageState = normalCallReturnPageState,
            normalCallMutedState = normalCallMutedState,
            normalCallSpeakerState = normalCallSpeakerState,
            normalCallSecondsState = normalCallSecondsState
        )
    }
}
