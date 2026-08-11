package com.vvtech.aiassistant.features.assistant_status

import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import org.junit.Assert.assertEquals
import org.junit.Test

class AssistantLocalizedStatusTextProviderTest {
    private var language = VoiceLanguage.Chinese
    private val provider = AssistantLocalizedStatusTextProvider { language }

    @Test
    fun returnsChineseTaskAndVoiceStatuses() {
        language = VoiceLanguage.Chinese

        assertEquals("任务信息已经整理好了，确认后继续", provider.taskReadyStatus())
        assertEquals("补充细节", provider.detailLabel())
        assertEquals("预留信息", provider.contactLabel())
        assertEquals("正在听你说...", provider.listeningStatus())
        assertEquals("已暂停，点击继续说话", provider.pausedTapToContinueStatus())
        assertEquals("没听到声音，请再试一次", provider.noValidSpeechStatus())
    }

    @Test
    fun returnsEnglishAndJapaneseTaskLabels() {
        language = VoiceLanguage.English
        assertEquals("Task details are ready. Please confirm to continue.", provider.taskReadyStatus())
        assertEquals("Extra details", provider.detailLabel())
        assertEquals("Booking contact", provider.contactLabel())

        language = VoiceLanguage.Japanese
        assertEquals("依頼内容を整理しました。確認して続けてください。", provider.taskReadyStatus())
        assertEquals("追加条件", provider.detailLabel())
        assertEquals("予約者情報", provider.contactLabel())
    }

    @Test
    fun filtersStatusHintByCurrentLanguage() {
        language = VoiceLanguage.English
        assertEquals("fallback", provider.statusHintOrFallback("正在确认细节", "fallback"))
        assertEquals("Connecting", provider.statusHintOrFallback(" Connecting ", "fallback"))
        assertEquals("fallback", provider.statusHintOrFallback("   ", "fallback"))

        language = VoiceLanguage.Japanese
        assertEquals("fallback", provider.statusHintOrFallback("正在确认细节", "fallback"))
        assertEquals("音声を開始しています", provider.statusHintOrFallback("音声を開始しています", "fallback"))

        language = VoiceLanguage.Chinese
        assertEquals("正在确认细节", provider.statusHintOrFallback("正在确认细节", "fallback"))
    }

    @Test
    fun returnsSelectionConfirmationTexts() {
        language = VoiceLanguage.English
        assertEquals("Confirming Demo...", provider.confirmingSelectionOptionStatus("Demo"))
        assertEquals("Failed to confirm this option", provider.selectionOptionConfirmFailureError())
        assertEquals("Confirmation failed. Please try again.", provider.selectionOptionConfirmFailureStatus())

        language = VoiceLanguage.Japanese
        assertEquals("候補 を確認しています...", provider.confirmingSelectionOptionStatus("候補"))
        assertEquals("候補の確認に失敗しました", provider.selectionOptionConfirmFailureError())
        assertEquals("確認に失敗しました。もう一度お試しください。", provider.selectionOptionConfirmFailureStatus())

        language = VoiceLanguage.Chinese
        assertEquals("正在确认包间...", provider.confirmingSelectionOptionStatus("包间"))
        assertEquals("选项确认失败", provider.selectionOptionConfirmFailureError())
        assertEquals("确认失败，请再试一次", provider.selectionOptionConfirmFailureStatus())
    }

    @Test
    fun returnsConfirmingDetailsForGeneralAndStructuredScenes() {
        language = VoiceLanguage.English
        assertEquals("AI is replying", provider.confirmingDetailsStatus("GENERAL"))
        assertEquals("Confirming details", provider.confirmingDetailsStatus("HOTEL_BOOKING"))

        language = VoiceLanguage.Japanese
        assertEquals("AI が返答しています", provider.confirmingDetailsStatus("GENERAL"))
        assertEquals("内容を確認しています", provider.confirmingDetailsStatus("RESTAURANT"))

        language = VoiceLanguage.Chinese
        assertEquals("AI在回复", provider.confirmingDetailsStatus("GENERAL"))
        assertEquals("AI在确认细节", provider.confirmingDetailsStatus("RESTAURANT"))
    }
}
