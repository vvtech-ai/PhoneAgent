package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.FinalTaskRecord
import com.vvtech.aiassistant.features.assistant.finalTaskCombinedText as legacyFinalTaskCombinedText
import com.vvtech.aiassistant.features.assistant.finalTaskKeyInfo as legacyFinalTaskKeyInfo
import com.vvtech.aiassistant.features.assistant.finalTaskSceneName as legacyFinalTaskSceneName
import com.vvtech.aiassistant.features.assistant.finalTaskSceneTarget as legacyFinalTaskSceneTarget
import com.vvtech.aiassistant.features.assistant.homeNotificationText as legacyHomeNotificationText
import com.vvtech.aiassistant.features.assistant.removeFinalTaskTimeExpressions as legacyRemoveFinalTaskTimeExpressions
import com.vvtech.aiassistant.features.assistant.toFinalTaskDisplayItem
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskDisplayTextPolicyTest {
    @Test
    fun buildsRestaurantDisplayText() {
        val combined = taskDisplayCombinedText("订餐任务 · 北海渔村", "明天18点 4位 包间 低消")
        val sceneName = taskDisplaySceneName("RESTAURANT_BOOKING", combined)
        val target = taskDisplaySceneTarget(sceneName, "订餐任务 · 北海渔村", "明天18点 4位 包间 低消", "")
        val keyInfo = taskDisplayKeyInfo(sceneName, "订餐任务 · 北海渔村", "明天18点 4位 包间 低消", "")
        val notification = taskDisplayHomeNotificationText(
            sceneName = sceneName,
            sceneTarget = target,
            keyInfo = keyInfo,
            statusKind = TaskDisplayTextStatusKind.Completed
        )

        assertEquals("订餐厅", sceneName)
        assertEquals("北海渔村", target)
        assertTrue(keyInfo.contains("包间"))
        assertTrue(keyInfo.contains("低消"))
        assertEquals("订餐厅已完成：北海渔村 · $keyInfo", notification)
    }

    @Test
    fun removesTimeExpressionsAndKeepsUsefulFacts() {
        assertEquals("4位 包间 低消", removeTaskDisplayTimeExpressions("明天18点 4位 包间 低消"))
        assertEquals(listOf("明天18点", "18点", "4位", "包间"), extractTaskDisplayFactSegments("明天18点 4位 包间", "订餐厅"))
        assertFalse(isUsefulTaskDisplayInfoSegment("任务已提交，等待进一步处理", ""))
        assertEquals("包间", compactTaskDisplayInfo("明天18点 包间"))
    }

    @Test
    fun legacyFinalTaskTextEntrypointsDelegateToTaskDisplayPolicy() {
        val title = "订餐任务 · 北海渔村"
        val detail = "明天18点 4位 包间 低消"
        val sceneName = taskDisplaySceneName("RESTAURANT_BOOKING", taskDisplayCombinedText(title, detail))
        val record = FinalTaskRecord(
            title = title,
            status = "COMPLETED",
            detail = detail,
            sceneType = "RESTAURANT_BOOKING"
        )
        val item = record.toFinalTaskDisplayItem()

        assertEquals(taskDisplayCombinedText(title, detail), legacyFinalTaskCombinedText(title, detail))
        assertEquals(sceneName, legacyFinalTaskSceneName("RESTAURANT_BOOKING", taskDisplayCombinedText(title, detail)))
        assertEquals(
            taskDisplaySceneTarget(sceneName, title, detail, ""),
            legacyFinalTaskSceneTarget(sceneName, title, detail, "")
        )
        assertEquals(taskDisplayKeyInfo(sceneName, title, detail, ""), legacyFinalTaskKeyInfo(sceneName, title, detail, ""))
        assertEquals(removeTaskDisplayTimeExpressions(detail), legacyRemoveFinalTaskTimeExpressions(detail))
        assertEquals(taskDisplayHomeNotificationText(item.sceneName, item.sceneTarget, item.keyInfo, TaskDisplayTextStatusKind.Completed), legacyHomeNotificationText(item))
    }

    @Test
    fun legacyTextPolicyKeepsOnlyCompatibilityBridgeForDisplayText() {
        val legacy = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalTaskTextPolicy.kt"
        ).readText()
        val policy = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskDisplayTextPolicy.kt"
        ).readText()

        assertTrue(legacy.contains("taskDisplaySceneName(sceneType, text)"))
        assertTrue(legacy.contains("taskDisplayHomeNotificationText("))
        assertFalse(legacy.contains("normalizedScene in setOf"))
        assertFalse(legacy.contains("Regex(\"\"\"([\\\\u4e00-\\\\u9fa5A-Za-z0-9·-]"))
        assertTrue(policy.contains("normalizedScene in setOf"))
        assertTrue(policy.contains("TaskDisplayTextStatusKind"))
    }

    private fun sourceFile(path: String): File {
        return listOf(
            File(path),
            File("android/app/$path")
        ).first { it.exists() }
    }
}
