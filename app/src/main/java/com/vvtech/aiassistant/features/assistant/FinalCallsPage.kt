package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_calls.AssistantCallsDialSheet
import com.vvtech.aiassistant.features.assistant_calls.AssistantCallsDialSheetCallbacks
import com.vvtech.aiassistant.features.assistant_calls.AssistantCallsDialSheetState
import com.vvtech.aiassistant.features.assistant_calls.AssistantDialPad

@Composable
internal fun FinalCallsDialSheetV2(
    state: AssistantCallsDialSheetState,
    callbacks: AssistantCallsDialSheetCallbacks
) {
    AssistantCallsDialSheet(
        state = state,
        callbacks = callbacks
    )
}

@Composable
internal fun FinalDialPadV2(onDigit: (String) -> Unit) {
    AssistantDialPad(onDigit = onDigit)
}
