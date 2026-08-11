package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue

internal class AssistantHomeComposerState(
    private val openState: MutableState<Boolean>,
    private val modeNameState: MutableState<String>
) {
    var isOpen: Boolean by openState
    var modeName: String by modeNameState

    fun show() {
        isOpen = true
    }

    fun close() {
        isOpen = false
    }

    fun updateModeName(value: String) {
        modeName = value
    }
}

@Composable
internal fun rememberAssistantHomeComposerState(
    defaultModeName: String
): AssistantHomeComposerState {
    val openState = rememberSaveable { mutableStateOf(false) }
    val modeNameState = rememberSaveable { mutableStateOf(defaultModeName) }
    return remember(openState, modeNameState) {
        AssistantHomeComposerState(
            openState = openState,
            modeNameState = modeNameState
        )
    }
}
