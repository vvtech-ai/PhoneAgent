package com.vvtech.aiassistant.features.branding

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PhoneAgentBrandNameGuardTest {

    @Test
    fun `user visible brand surfaces use Phone Agent`() {
        val paths = listOf(
            "build.gradle",
            "src/main/res/values/strings.xml",
            "src/main/assets/index9/index.html",
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalHomeTopBar.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant/V88AuthPages.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant/V88GuideDialogs.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalChatBubblesV3.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant/SingleFlowConversationContent.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant_pure_voice/PureVoiceThreadList.kt"
        )

        paths.forEach { path ->
            val source = File(path).readText()
            assertTrue("$path should display Phone Agent", source.contains("Phone Agent"))
            assertFalse("$path must not display CHAKEN.AI", source.contains("CHAKEN.AI"))
        }
    }
}
