package com.vvtech.aiassistant.features.assistant

import org.junit.Assert.assertEquals
import org.junit.Test

class TranslationCallUiTextTest {

    @Test
    fun subtitleRoleLabelsShouldUseReadableChineseText() {
        assertEquals("你说", translationSubtitleRoleLabel("caller"))
        assertEquals("对方说", translationSubtitleRoleLabel("callee"))
        assertEquals("--", translationSubtitleRoleLabel(null))
    }

    @Test
    fun translationCallMessagesShouldLocalizeKnownEnglishSipStatus() {
        assertEquals(
            "对方正在响铃，等待接听。",
            localizedTranslationCallMessage("Remote side is ringing. Waiting for answer.")
        )
        assertEquals("等待接听", localizedTranslationCallState("RINGING"))
        assertEquals("识别语言中", localizedTranslationSessionState("LANGUAGE_DETECTING"))
    }
}
