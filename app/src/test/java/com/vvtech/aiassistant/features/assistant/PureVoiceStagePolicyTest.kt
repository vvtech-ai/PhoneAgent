package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.ToolCardInfo
import org.junit.Assert.assertEquals
import org.junit.Test

class PureVoiceStagePolicyTest {
    @Test
    fun showOptionsKeepsNarratedTextWhenItIsTheOnlyOptionMessage() {
        val toolCard = ToolCardInfo(
            id = "show-options-1",
            toolName = "showOptions",
            methodLabel = "showOptions()",
            result = "Observe: 展示 3 个选项",
            status = "completed",
        )
        val generic = ClarificationStep(
            role = VoiceRole.Assistant,
            text = "搜到的结果\n1. 科教城店",
            status = "",
            toolCards = listOf(toolCard),
        )

        val displayed = pureVoiceSanitizeStepForDisplay(generic, VoiceLanguage.Chinese)

        assertEquals(generic.text, displayed.text)
        assertEquals(listOf(toolCard), displayed.toolCards)
    }

    @Test
    fun showOptionsDropsGenericTextOnlyWhenTheSameOptionsAreAlreadyVisible() {
        val toolCard = ToolCardInfo(
            id = "show-options-2",
            toolName = "showOptions",
            methodLabel = "showOptions()",
            result = "Observe: 展示 3 个选项",
            status = "completed",
        )
        val displayed = pureVoiceDisplaySteps(
            listOf(
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "选哪家华莱士\n1. 科教城店 (859m | 18144489075)\n2. 凤岗二店 (1.6km | 020-38104524)",
                    status = "",
                    toolCards = listOf(toolCard),
                ),
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "搜到的结果\n1. 科教城店 (859m | 尾号 9075)\n2. 凤岗二店 (1.6km | 020-38104524)",
                    status = "",
                ),
            ),
        )

        assertEquals(1, displayed.size)
        assertEquals("选哪家华莱士", displayed.single().text.lineSequence().first())
        assertEquals(listOf(toolCard), displayed.single().toolCards)
    }
}
