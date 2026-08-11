package com.vvtech.aiassistant.features.assistant_pure_voice.input

import android.view.View
import android.view.ViewTreeObserver
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

internal data class PureVoiceImeSnapshot(
    val visible: Boolean,
    val bottomInsetPx: Int
)

@Composable
internal fun rememberPureVoiceImeSnapshot(): PureVoiceImeSnapshot {
    val view = LocalView.current
    var snapshot by remember(view) { mutableStateOf(readPureVoiceImeSnapshot(view)) }

    DisposableEffect(view) {
        val listener = ViewTreeObserver.OnGlobalLayoutListener {
            val next = readPureVoiceImeSnapshot(view)
            if (next != snapshot) snapshot = next
        }
        view.viewTreeObserver.addOnGlobalLayoutListener(listener)
        snapshot = readPureVoiceImeSnapshot(view)
        onDispose {
            if (view.viewTreeObserver.isAlive) {
                view.viewTreeObserver.removeOnGlobalLayoutListener(listener)
            }
        }
    }
    return snapshot
}

private fun readPureVoiceImeSnapshot(view: View): PureVoiceImeSnapshot {
    val insets = ViewCompat.getRootWindowInsets(view)
    val imeType = WindowInsetsCompat.Type.ime()
    val visible = insets?.isVisible(imeType) == true
    val bottom = if (visible) insets?.getInsets(imeType)?.bottom ?: 0 else 0
    return PureVoiceImeSnapshot(visible = visible, bottomInsetPx = bottom)
}
