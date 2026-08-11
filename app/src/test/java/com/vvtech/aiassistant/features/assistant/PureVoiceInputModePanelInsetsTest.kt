package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class PureVoiceInputModePanelInsetsTest {

    @Test
    fun inputDockUsesFixedSlotAndRootWindowImeObserver() {
        val dock = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_pure_voice/input/PureVoiceInputDock.kt"
        ).readText()
        val observer = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_pure_voice/input/PureVoiceImeObserver.kt"
        ).readText()
        val bridge = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant/PureVoiceInputModePanel.kt"
        ).readText()

        assertTrue(dock.contains(".height(88.dp)"))
        assertTrue(dock.contains(".padding(bottom = dockBottomPadding)"))
        assertTrue(dock.contains("if (machine.imeVisible) 12.dp else 0.dp"))
        assertTrue(dock.contains("if (machine.imeVisible) 0.dp else 28.dp"))
        assertTrue(dock.contains("Crossfade(targetState = renderedMode"))
        assertTrue(!dock.contains("WindowInsets.isImeVisible"))
        assertTrue(observer.contains("WindowInsetsCompat.Type.ime()"))
        assertTrue(observer.contains("removeOnGlobalLayoutListener"))
        assertTrue(bridge.contains("PureVoiceInputDock("))
        assertTrue(!bridge.contains("BasicTextField"))
    }

    @Test
    fun mainActivityResizesForIme() {
        val manifest = File("src/main/AndroidManifest.xml").readText()
        assertTrue(manifest.contains("android:windowSoftInputMode=\"adjustResize\""))
    }
}
