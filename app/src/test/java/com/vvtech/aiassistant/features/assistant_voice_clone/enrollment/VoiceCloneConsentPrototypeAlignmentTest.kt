package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCloneConsentPrototypeAlignmentTest {

    @Test
    fun `consent copy matches the demo and requirement baseline`() {
        assertEquals(
            "只有完成身份认证的用户，才能使用声音克隆服务。",
            VOICE_CLONE_AUTH_DESCRIPTION
        )
        assertEquals(
            "完成身份认证后，进入声音克隆并生成你的声音。",
            VOICE_CLONE_AFTER_AUTH_DESCRIPTION
        )
        assertEquals(
            "未经授权，AI 不应使用你的声音进行通话。",
            VOICE_CLONE_UNAUTHORIZED_DESCRIPTION
        )
        assertEquals(
            "后续通话完善声音需单独开启授权。",
            VOICE_CLONE_FOLLOW_UP_DESCRIPTION
        )
        assertEquals(
            "我确认由本人申请使用本人声音，并同意进行身份认证",
            VOICE_CLONE_CONSENT_DESCRIPTION
        )
    }

    @Test
    fun `consent layout uses the compact demo controls`() {
        val source = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/" +
                "VoiceCloneConsentStep.kt"
        ).readText(Charsets.UTF_8)
        val agreement = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/" +
                "VoiceCloneAgreementRow.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(source.contains("Modifier.padding(horizontal = 10.dp)"))
        assertTrue(agreement.contains(".toggleable("))
        assertTrue(agreement.contains(".size(18.dp)"))
        assertTrue(source.contains(".height(48.dp)"))
        assertTrue(source.contains("fontSize = 16.sp"))
        assertFalse(source.contains("Demo 模式"))
    }

    @Test
    fun `voice clone flow uses the compact demo title bar without a close action`() {
        val chrome = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/" +
                "VoiceCloneFlowTopBar.kt"
        ).readText(Charsets.UTF_8)
        val page = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalVoiceClonePage.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(chrome.contains("fontSize = 22.sp"))
        assertTrue(page.contains("VoiceCloneFlowTopBar("))
        assertFalse(page.contains("onClose: () -> Unit"))
    }

    @Test
    fun `completion step removes follow up voice improvement consent`() {
        val completion = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/" +
                "VoiceCloneDoneStep.kt"
        ).readText(Charsets.UTF_8)
        val titlePolicy = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/" +
                "VoiceCloneStepTitlePolicy.kt"
        ).readText(Charsets.UTF_8)
        val agreement = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/" +
                "VoiceCloneAgreementRow.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(titlePolicy.contains("\"3/3 完成\""))
        assertTrue(completion.contains("声音克隆已完成，可用于 Agent 通话。"))
        assertFalse(completion.contains("后续本人通话可用于完善声音的自然度和稳定性"))
        assertFalse(completion.contains("后续允许使用本人声音完善克隆音色表现"))
        assertFalse(completion.contains("VoiceCloneAgreementRow("))
        assertTrue(agreement.contains(".toggleable("))
        assertTrue(completion.contains("onStartUsing: (Boolean) -> Unit"))
        assertTrue(completion.contains("onStartUsing(false)"))
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(File(path), File("android/app/$path")).first { it.exists() }
        }
    }
}
