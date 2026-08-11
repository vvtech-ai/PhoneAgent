package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.viewmodel.replaceChineseDigits
import org.junit.Assert.assertEquals
import org.junit.Test

class ReservationAsrTranscriptNormalizerTest {
    @Test
    fun splitsMergedPhoneAndPartySizeForDisplayAndSubmission() {
        assertEquals(
            "帮我订今晚7点海底捞，预留手机号13800008887，7个人",
            normalizeReservationAsrTranscript("帮我订今晚7点海底捞，预留手机号138000088877个人")
        )
    }

    @Test
    fun keepsPlainPhoneFollowedByPersonUnitUnchangedWhenPartySizeIsMissing() {
        val input = "帮我订今晚7点海底捞，预留手机号13800008887个人到"

        assertEquals(input, normalizeReservationAsrTranscript(input))
    }

    @Test
    fun keepsAlreadySeparatedPhoneAndPartySizeUnchanged() {
        val input = "帮我订今晚7点海底捞，预留手机号13800008887，7个人"

        assertEquals(input, normalizeReservationAsrTranscript(input))
    }

    @Test
    fun restoresSeparatorAfterSecondDigitNormalizationPass() {
        val input = "帮我订今晚7点海底捞，用张三的手机号13800008888，7个人，要包房。"

        assertEquals(
            input,
            normalizeReservationAsrTranscript(replaceChineseDigits(input))
        )
    }

    @Test
    fun splitsSpokenPhoneAndPartySizeAfterDigitNormalization() {
        assertEquals(
            "帮我订今晚7点海底捞，用张三的手机号13800008888，7个人，要包房。",
            normalizeReservationAsrTranscript(
                replaceChineseDigits("帮我订今晚七点海底捞，用张三的手机号幺三八零零零零八八八八，七个人，要包房。")
            )
        )
    }
}
