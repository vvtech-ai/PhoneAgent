package com.vvtech.aiassistant.features.assistant_pure_voice.ocr

import android.app.Application
import android.net.Uri
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.PureVoiceState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoiceConversationStepProjector
import com.vvtech.aiassistant.features.assistant_pure_voice.buildPureVoiceThreadRenderState
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class PureVoiceOcrAnchorStepCountTest {

    @Test
    fun anchorExcludesATrailingInvisibleAssistantPlaceholder() {
        val steps = listOf(
            ClarificationStep(
                role = VoiceRole.User,
                text = "先前消息",
                status = "",
            ),
            ClarificationStep(
                role = VoiceRole.Assistant,
                text = "",
                status = "",
            ),
        )

        assertEquals(1, pureVoiceOcrAnchorStepCount(steps))
    }

    @Test
    fun historicalSourceBoundaryMapsToTheMergedDisplayBoundary() {
        val source = listOf(
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

        val projection = PureVoiceConversationStepProjector.projectWithBoundaries(source)

        assertEquals(3, projection.steps.size)
        assertEquals(2, projection.displayBoundaryFor(3))
        assertEquals("继续", projection.steps[2].text)
    }

    @Test
    fun imageRemainsAfterOpeningAndBeforeTheLaterUserMessage() {
        val stepsAtSelection = listOf(
            ClarificationStep(
                role = VoiceRole.Assistant,
                text = "想订哪家餐厅？告诉我时间和人数就行。",
                status = "",
            )
        )
        val attachment = PureVoiceOcrAttachment(
            attachmentId = "ocr-1",
            imageUri = Uri.parse("content://ocr/image-1"),
            anchorStepCount = pureVoiceOcrAnchorStepCount(stepsAtSelection),
            createdOrdinal = 0,
            status = PureVoiceOcrStatus.Success,
        )

        val historySynchronizedAttachment = PureVoiceOcrStateReducer.upsertCommitted(
            state = PureVoiceOcrUiState(attachments = listOf(attachment)),
            attachment = attachment.copy(anchorStepCount = 1),
        ).attachments.single()
        val afterUserMessage = buildPureVoiceThreadRenderState(
            voiceLanguage = VoiceLanguage.Chinese,
            state = PureVoiceState.Standby,
            processingTurn = false,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            status = "",
            clarificationSteps = stepsAtSelection +
                ClarificationStep(VoiceRole.User, "这是张三的号码", ""),
            error = null,
            precheck = null,
            callPageData = null,
            showCallPage = false,
            ocrAttachments = listOf(historySynchronizedAttachment),
        )

        assertEquals(1, attachment.anchorStepCount)
        assertEquals(1, historySynchronizedAttachment.anchorStepCount)
        assertEquals(1, afterUserMessage.ocrAttachments.single().anchorStepCount)
        assertEquals(
            listOf("想订哪家餐厅？告诉我时间和人数就行。", "这是张三的号码"),
            afterUserMessage.displayClarificationSteps.map { it.text },
        )
        assertEquals(
            attachment.attachmentId,
            PureVoiceOcrDisplayOrdering.byAnchor(
                afterUserMessage.ocrAttachments,
                afterUserMessage.displayClarificationSteps.size,
            ).getValue(1).single().attachmentId,
        )
    }
}
