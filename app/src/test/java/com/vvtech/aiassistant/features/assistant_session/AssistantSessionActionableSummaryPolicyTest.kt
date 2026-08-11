package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantActionChip
import com.vvtech.aiassistant.core.model.AssistantMessageItem
import com.vvtech.aiassistant.core.model.AssistantSessionMeta
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.CallConfirmCardPayload
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Test

class AssistantSessionActionableSummaryPolicyTest {
    @Test
    fun mapsChineseCallConfirmCardWithSupplementFields() {
        val primary = AssistantActionChip("confirm", "确认拨打", "primary")
        val result = AssistantSessionActionableSummaryPolicy.resolve(
            session = session(
                title = "",
                sceneType = "FOOD_ORDERING",
                card = callCard(
                    targetName = "北海渔村",
                    phone = "13800138000",
                    purpose = "预订包间",
                    summary = "我会帮你联系商家确认包间",
                    actions = listOf(primary)
                )
            ),
            context = context(
                language = VoiceLanguage.Chinese,
                contactTaskId = "task-1",
                contactValue = "张三",
                detailTaskId = "task-1",
                detailValue = "靠窗包间"
            )
        )

        requireNotNull(result)
        assertEquals("订餐任务", result.summary.task)
        assertEquals("对象", result.summary.targetLabel)
        assertEquals("北海渔村", result.summary.target)
        assertEquals("电话", result.summary.timeLabel)
        assertEquals("13800138000", result.summary.time)
        assertEquals("重点", result.summary.extraLabel)
        assertEquals("预订包间", result.summary.extra)
        assertEquals("预订人", result.summary.contactLabel)
        assertEquals("张三", result.summary.contactValue)
        assertEquals("补充细节", result.summary.detailLabel)
        assertEquals("靠窗包间", result.summary.detailValue)
        assertEquals("确认拨打", result.confirmLabel)
        assertEquals(primary, result.primaryAction)
        assertEquals("北海渔村", result.callPageSeed.name)
        assertEquals("13800138000", result.callPageSeed.sub)
        assertEquals("准备发起电话", result.callPageSeed.status)
        assertEquals(TranscriptRole.Note, result.callPageSeed.transcript[0].role)
        assertEquals("通话重点：预订包间", result.callPageSeed.transcript[0].text)
        assertEquals(TranscriptRole.Assistant, result.callPageSeed.transcript[1].role)
        assertEquals("我会帮你联系商家确认包间", result.callPageSeed.transcript[1].text)
    }

    @Test
    fun mapsEnglishBookingFallbacksWithoutMatchingSupplement() {
        val result = AssistantSessionActionableSummaryPolicy.resolve(
            session = session(
                title = "Hotel booking",
                sceneType = "HOTEL_BOOKING",
                card = callCard(
                    targetName = "",
                    phone = null,
                    purpose = "",
                    summary = "I will call the hotel."
                )
            ),
            context = context(
                language = VoiceLanguage.English,
                contactTaskId = "other-task",
                contactValue = "Alice",
                detailTaskId = "other-task",
                detailValue = "quiet room"
            )
        )

        requireNotNull(result)
        assertEquals("Hotel booking", result.summary.task)
        assertEquals("Target", result.summary.targetLabel)
        assertEquals("Pending target", result.summary.target)
        assertEquals("Phone", result.summary.timeLabel)
        assertEquals("Pending", result.summary.time)
        assertEquals("Details", result.summary.extraLabel)
        assertEquals("I will call the hotel.", result.summary.extra)
        assertNull(result.summary.contactLabel)
        assertNull(result.summary.contactValue)
        assertEquals("确认并发起", result.confirmLabel)
        assertEquals("Hotel booking", result.callPageSeed.name)
        assertEquals("订酒店", result.callPageSeed.sub)
        assertEquals("Ready to call", result.callPageSeed.status)
        assertEquals(1, result.callPageSeed.transcript.size)
        assertEquals("I will call the hotel.", result.callPageSeed.transcript.single().text)
    }

    @Test
    fun mapsJapaneseBookingFallbacks() {
        val result = AssistantSessionActionableSummaryPolicy.resolve(
            session = session(
                title = "",
                sceneType = "FOOD_ORDERING",
                card = callCard(
                    targetName = "",
                    phone = "",
                    purpose = "個室を予約する",
                    summary = "レストランに電話します。"
                )
            ),
            context = context(language = VoiceLanguage.Japanese)
        )

        requireNotNull(result)
        assertEquals("订餐任务", result.summary.task)
        assertEquals("対象", result.summary.targetLabel)
        assertEquals("対象未確認", result.summary.target)
        assertEquals("電話", result.summary.timeLabel)
        assertEquals("未確認", result.summary.time)
        assertEquals("要点", result.summary.extraLabel)
        assertEquals("発信準備完了", result.callPageSeed.status)
        assertEquals("通話の要点：個室を予約する", result.callPageSeed.transcript.first().text)
    }

    @Test
    fun returnsNullWithoutCallConfirmCard() {
        assertNull(
            AssistantSessionActionableSummaryPolicy.resolve(
                session = session(card = null),
                context = context(language = VoiceLanguage.Chinese)
            )
        )
    }

    @Test
    fun sessionMapperDelegatesActionableSummaryPolicy() {
        val mapper = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_session/SessionMapper.kt")
            .readText(Charsets.UTF_8)
        val policy =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionActionableSummaryPolicy.kt")
                .readText(Charsets.UTF_8)

        assertTrue(mapper.contains("AssistantSessionActionableSummaryPolicy.resolve"))
        assertTrue(mapper.contains("AssistantSessionActionableSummaryPolicy.BuildContext"))
        assertFalse(mapper.contains("val localizeBookingScene"))
        assertFalse(mapper.contains("Call focus:"))
        assertTrue(policy.contains("fun resolve("))
        assertTrue(policy.contains("private fun readyToCallStatus"))
    }

    private fun session(
        taskId: String = "task-1",
        title: String = "订餐",
        sceneType: String = "FOOD_ORDERING",
        taskStatus: String = "RUNNING",
        card: CallConfirmCardPayload?
    ): AssistantSessionResponse {
        return AssistantSessionResponse(
            session = AssistantSessionMeta(
                taskId = taskId,
                sceneType = sceneType,
                taskStatus = taskStatus,
                title = title,
                subtitle = null,
                waitingForUser = false
            ),
            messages = listOfNotNull(
                card?.let {
                    AssistantMessageItem(
                        messageId = "message-1",
                        type = "CALL_CONFIRM",
                        role = "assistant",
                        text = null,
                        title = null,
                        subtitle = null,
                        statusText = null,
                        callConfirmCard = it
                    )
                }
            )
        )
    }

    private fun callCard(
        targetName: String = "北海渔村",
        phone: String? = "13800138000",
        purpose: String = "预订包间",
        summary: String = "我会帮你联系商家确认包间",
        actions: List<AssistantActionChip> = emptyList()
    ): CallConfirmCardPayload {
        return CallConfirmCardPayload(
            targetName = targetName,
            phone = phone,
            purpose = purpose,
            summary = summary,
            actions = actions
        )
    }

    private fun context(
        language: VoiceLanguage,
        contactTaskId: String? = null,
        contactValue: String? = null,
        detailTaskId: String? = null,
        detailValue: String? = null
    ): AssistantSessionActionableSummaryPolicy.BuildContext {
        return AssistantSessionActionableSummaryPolicy.BuildContext(
            language = language,
            contactTaskId = contactTaskId,
            contactValue = contactValue,
            detailTaskId = detailTaskId,
            detailValue = detailValue,
            contactLabel = "预订人",
            detailLabel = "补充细节",
            defaultConfirmLabel = "确认并发起"
        )
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
