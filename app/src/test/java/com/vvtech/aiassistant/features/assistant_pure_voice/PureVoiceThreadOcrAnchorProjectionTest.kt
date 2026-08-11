package com.vvtech.aiassistant.features.assistant_pure_voice

import android.app.Application
import android.net.Uri
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.PureVoiceState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrAttachment
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrStatus
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class PureVoiceThreadOcrAnchorProjectionTest {
    @Test
    fun historicalSourceAnchorStaysBetweenTheSameDisplayedTurnsAfterMerge() {
        val sourceSteps = listOf(
            ClarificationStep(VoiceRole.User, "帮我确认", ""),
            ClarificationStep(
                role = VoiceRole.Assistant,
                text = "",
                status = "",
                callConfirmSpec = CallSpecPayload(
                    phoneNumber = "13800138000",
                    scene = "restaurant_booking",
                    targetName = "星河店",
                    primaryGoal = "预订四人位",
                    summaryLines = emptyList(),
                ),
            ),
            ClarificationStep(VoiceRole.Assistant, "请确认下面的信息。", ""),
            ClarificationStep(VoiceRole.User, "继续", ""),
        )
        val attachment = PureVoiceOcrAttachment(
            attachmentId = "ocr-1",
            imageUri = Uri.parse("content://ocr/image-1"),
            anchorStepCount = 3,
            createdOrdinal = 1,
            status = PureVoiceOcrStatus.Success,
        )

        val renderState = buildPureVoiceThreadRenderState(
            voiceLanguage = VoiceLanguage.Chinese,
            state = PureVoiceState.Standby,
            processingTurn = false,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            status = "",
            clarificationSteps = sourceSteps,
            error = null,
            precheck = null,
            callPageData = null,
            showCallPage = false,
            ocrAttachments = listOf(attachment),
        )

        assertEquals(3, renderState.displayClarificationSteps.size)
        assertEquals(2, renderState.ocrAttachments.single().anchorStepCount)
        assertEquals("继续", renderState.displayClarificationSteps[2].text)
    }
}
