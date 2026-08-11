package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.SummaryData
import com.vvtech.aiassistant.core.model.DetailSupplementPromptResponse
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSessionDetailSupplementPolicyTest {
    @Test
    fun shouldEnterDetailSupplementOnlyForSupportedUnfinishedActionableScenes() {
        assertTrue(
            AssistantSessionDetailSupplementPolicy.shouldEnterDetailSupplement(
                sceneType = "FOOD_ORDERING",
                taskId = "task-1",
                hasActionable = true,
                completedTaskId = null
            )
        )

        assertFalse(
            AssistantSessionDetailSupplementPolicy.shouldEnterDetailSupplement(
                sceneType = "GENERAL",
                taskId = "task-1",
                hasActionable = true,
                completedTaskId = null
            )
        )
        assertFalse(
            AssistantSessionDetailSupplementPolicy.shouldEnterDetailSupplement(
                sceneType = "FOOD_ORDERING",
                taskId = "task-1",
                hasActionable = false,
                completedTaskId = null
            )
        )
        assertFalse(
            AssistantSessionDetailSupplementPolicy.shouldEnterDetailSupplement(
                sceneType = "FOOD_ORDERING",
                taskId = "task-1",
                hasActionable = true,
                completedTaskId = "task-1"
            )
        )
    }

    @Test
    fun selectionContinuationOnlyForSupportedMatchingSceneWithoutActionOrSelection() {
        assertTrue(
            AssistantSessionDetailSupplementPolicy.shouldForceSelectionDetailSupplement(
                sceneType = "HOTEL_BOOKING",
                hasActionable = false,
                hasSelectionSheet = false,
                selectionContinuationSceneType = "HOTEL_BOOKING"
            )
        )

        assertFalse(
            AssistantSessionDetailSupplementPolicy.shouldForceSelectionDetailSupplement(
                sceneType = "GENERAL",
                hasActionable = false,
                hasSelectionSheet = false,
                selectionContinuationSceneType = "GENERAL"
            )
        )
        assertFalse(
            AssistantSessionDetailSupplementPolicy.shouldForceSelectionDetailSupplement(
                sceneType = "HOTEL_BOOKING",
                hasActionable = true,
                hasSelectionSheet = false,
                selectionContinuationSceneType = "HOTEL_BOOKING"
            )
        )
        assertFalse(
            AssistantSessionDetailSupplementPolicy.shouldForceSelectionDetailSupplement(
                sceneType = "HOTEL_BOOKING",
                hasActionable = false,
                hasSelectionSheet = true,
                selectionContinuationSceneType = "HOTEL_BOOKING"
            )
        )
        assertFalse(
            AssistantSessionDetailSupplementPolicy.shouldForceSelectionDetailSupplement(
                sceneType = "HOTEL_BOOKING",
                hasActionable = false,
                hasSelectionSheet = false,
                selectionContinuationSceneType = "FOOD_ORDERING"
            )
        )
    }

    @Test
    fun decorateSummaryOnlyOverridesMatchingTaskSupplements() {
        val summary = summary(contactLabel = "联系人", contactValue = "旧联系人", detailLabel = "细节", detailValue = "旧细节")

        val updated = AssistantSessionDetailSupplementPolicy.decorateSummaryWithSupplement(
            taskId = "task-1",
            summary = summary,
            contactTaskId = "task-1",
            contactValue = "张三",
            detailTaskId = "task-1",
            detailValue = "要包间",
            contactLabel = "预订人",
            detailLabel = "补充细节"
        )

        assertEquals("预订人", updated.contactLabel)
        assertEquals("张三", updated.contactValue)
        assertEquals("补充细节", updated.detailLabel)
        assertEquals("要包间", updated.detailValue)

        val unchanged = AssistantSessionDetailSupplementPolicy.decorateSummaryWithSupplement(
            taskId = "task-2",
            summary = summary,
            contactTaskId = "task-1",
            contactValue = "张三",
            detailTaskId = "task-1",
            detailValue = "要包间",
            contactLabel = "预订人",
            detailLabel = "补充细节"
        )

        assertEquals(summary, unchanged)
    }

    @Test
    fun localizedPromptResponseKeepsChineseAndLocalizesOtherLanguages() {
        val chinese = DetailSupplementPromptResponse(
            sceneType = "FOOD_ORDERING",
            title = "补充细节",
            intro = "原始中文",
            questions = emptyList()
        )

        assertEquals(
            chinese,
            AssistantSessionDetailSupplementPolicy.localizedPromptResponse(
                language = VoiceLanguage.Chinese,
                sceneType = "FOOD_ORDERING",
                title = "补充细节",
                promptResponse = chinese
            )
        )

        val english = AssistantSessionDetailSupplementPolicy.localizedPromptResponse(
            language = VoiceLanguage.English,
            sceneType = "HOTEL_BOOKING",
            title = "Extra details",
            promptResponse = chinese
        )

        assertEquals("Extra details", english.title)
        assertEquals("Confirm the booking contact first, then add hotel preferences or skip them.", english.intro)
        assertEquals(listOf("nonSmoking", "quietHighFloor", "parking"), english.questions.map { it.questionId })
    }

    @Test
    fun sessionMapperDelegatesDetailSupplementPurePolicy() {
        val mapper = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_session/SessionMapper.kt")
            .readText(Charsets.UTF_8)
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionDetailSupplementHandler.kt")
                .readText(Charsets.UTF_8)
        val policy =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionDetailSupplementPolicy.kt")
                .readText(Charsets.UTF_8)

        assertTrue(mapper.contains("AssistantSessionDetailSupplementPolicy.shouldEnterDetailSupplement"))
        assertTrue(mapper.contains("AssistantSessionDetailSupplementPolicy.shouldForceSelectionDetailSupplement"))
        assertTrue(mapper.contains("AssistantSessionDetailSupplementPolicy.decorateSummaryWithSupplement"))
        assertTrue(handler.contains("AssistantSessionDetailSupplementPolicy.localizedPromptResponse"))
        assertTrue(handler.contains("AssistantSessionDetailSupplementPolicy.detailIntro"))
        assertFalse(mapper.contains("sceneType !in setOf(\"FOOD_ORDERING\", \"HOTEL_BOOKING\", \"FLIGHT_BOOKING\")"))
        assertFalse(mapper.contains("selectionContinuation.sceneType == session.session.sceneType"))
        assertFalse(mapper.contains("summary.copy(\n            contactLabel"))
        assertFalse(mapper.contains("private fun localizedDetailQuestions"))

        assertTrue(policy.contains("fun shouldEnterDetailSupplement"))
        assertTrue(policy.contains("fun shouldForceSelectionDetailSupplement"))
        assertTrue(policy.contains("fun decorateSummaryWithSupplement"))
        assertTrue(policy.contains("fun localizedPromptResponse"))
        assertTrue(policy.contains("fun localizedDetailQuestions"))
    }

    private fun summary(
        contactLabel: String? = null,
        contactValue: String? = null,
        detailLabel: String? = null,
        detailValue: String? = null
    ): SummaryData {
        return SummaryData(
            task = "订餐",
            targetLabel = "对象",
            target = "北海渔村",
            timeLabel = "电话",
            time = "待确认",
            extraLabel = "重点",
            extra = "包间",
            contactLabel = contactLabel,
            contactValue = contactValue,
            detailLabel = detailLabel,
            detailValue = detailValue
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
