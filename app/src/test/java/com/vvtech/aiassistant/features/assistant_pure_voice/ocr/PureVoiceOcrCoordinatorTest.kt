package com.vvtech.aiassistant.features.assistant_pure_voice.ocr

import android.app.Application
import android.net.Uri
import com.vvtech.aiassistant.model.OcrAttachmentContextPayload
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class PureVoiceOcrCoordinatorTest {
    @Test
    fun modelContextIsPublishedOnlyAfterCloudCommitSucceeds() {
        val contexts = mutableListOf<List<OcrAttachmentContextPayload>>()
        var committedInput: PureVoiceOcrCommitInput? = null
        val coordinator = coordinator(
            contexts = contexts,
            commit = { input ->
                assertTrue(contexts.isEmpty())
                committedInput = input
                PureVoiceOcrCommitResult(
                    attachmentId = input.attachmentId,
                    anchorStepCount = input.anchorStepCount,
                    createdOrdinal = input.createdOrdinal,
                    fields = listOf(PureVoiceOcrField("server:0", "姓名", "张三")),
                    segments = listOf("姓名：张三"),
                    fullText = "姓名：张三",
                )
            },
        )

        coordinator.selectImage(Uri.parse("content://ocr/image-1"), 2, "session-1")

        assertEquals(PureVoiceOcrStatus.Success, coordinator.state.value.attachments.single().status)
        assertEquals(2, committedInput?.anchorStepCount)
        assertEquals("欢迎使用图片识别", committedInput?.initialOpening)
        assertEquals("姓名 张三", committedInput?.rawText)
        assertEquals("姓名：张三", coordinator.state.value.attachments.single().fullText)
        assertEquals(1, contexts.single().size)
        assertEquals("姓名：张三", contexts.single().single().fullText)
    }

    @Test
    fun cloudCommitFailureNeverPublishesRecognizedTextAsModelContext() {
        val contexts = mutableListOf<List<OcrAttachmentContextPayload>>()
        val coordinator = coordinator(
            contexts = contexts,
            commit = { throw IllegalStateException("cloud unavailable") },
        )

        coordinator.selectImage(Uri.parse("content://ocr/image-1"), 1, "session-1")

        val attachment = coordinator.state.value.attachments.single()
        assertEquals(PureVoiceOcrStatus.Failed, attachment.status)
        assertEquals(PureVoiceOcrFailure.CloudCommitFailed, attachment.failure)
        assertTrue(contexts.single().isEmpty())
    }

    @Test
    fun aiRefinementFailureUsesItsOwnFailureStateWithoutRawTextFallback() {
        val contexts = mutableListOf<List<OcrAttachmentContextPayload>>()
        val coordinator = coordinator(
            contexts = contexts,
            commit = {
                throw PureVoiceOcrCommitException(PureVoiceOcrFailure.AiRefinementFailed)
            },
        )

        coordinator.selectImage(Uri.parse("content://ocr/image-1"), 1, "session-1")

        val attachment = coordinator.state.value.attachments.single()
        assertEquals(PureVoiceOcrStatus.Failed, attachment.status)
        assertEquals(PureVoiceOcrFailure.AiRefinementFailed, attachment.failure)
        assertTrue(attachment.fullText.isEmpty())
        assertTrue(contexts.single().isEmpty())
    }

    private fun coordinator(
        contexts: MutableList<List<OcrAttachmentContextPayload>>,
        commit: suspend (PureVoiceOcrCommitInput) -> PureVoiceOcrCommitResult,
    ) = PureVoiceOcrCoordinator(
        scope = CoroutineScope(Dispatchers.Unconfined),
        processor = object : PureVoiceOcrProcessor {
            override suspend fun recognize(imageUri: Uri) = PureVoiceOcrRecognition(
                rawSegments = listOf("姓名 张三"),
                rawText = "姓名 张三",
            )
        },
        hostCallbacks = {
            PureVoiceOcrHostCallbacks(
                onContextChanged = contexts::add,
                ensureSessionId = { "session-1" },
                pendingInitialOpening = { "欢迎使用图片识别" },
                commitAttachment = commit,
                loadHistoryImage = { Uri.EMPTY },
            )
        },
    )
}
