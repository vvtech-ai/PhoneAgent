package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantActionChip
import com.vvtech.aiassistant.core.model.AssistantMessageItem
import com.vvtech.aiassistant.core.model.AssistantSessionMeta
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.HotelCardPayload
import com.vvtech.aiassistant.core.model.RestaurantCardPayload
import com.vvtech.aiassistant.core.model.ResultSummaryPayload
import com.vvtech.aiassistant.features.assistant.SelectionSheetData
import com.vvtech.aiassistant.features.assistant.SelectionSheetOption
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSessionSelectionSheetPolicyTest {
    @Test
    fun signatureKeepsOptionOrderAndItemActionShape() {
        assertEquals(
            "item-1#action-a|item-2#action-b",
            AssistantSessionSelectionSheetPolicy.signature(selectionSheet())
        )
    }

    @Test
    fun suppressionOnlyMatchesNonBlankTaskAndSameSignature() {
        val sheet = selectionSheet()
        val signature = AssistantSessionSelectionSheetPolicy.signature(sheet)

        assertTrue(
            AssistantSessionSelectionSheetPolicy.shouldSuppressSelectionSheet(
                taskId = " task-1 ",
                sheet = sheet,
                consumedTaskId = "task-1",
                consumedSignature = signature
            )
        )
        assertFalse(
            AssistantSessionSelectionSheetPolicy.shouldSuppressSelectionSheet(
                taskId = " ",
                sheet = sheet,
                consumedTaskId = "task-1",
                consumedSignature = signature
            )
        )
        assertFalse(
            AssistantSessionSelectionSheetPolicy.shouldSuppressSelectionSheet(
                taskId = "task-2",
                sheet = sheet,
                consumedTaskId = "task-1",
                consumedSignature = signature
            )
        )
        assertFalse(
            AssistantSessionSelectionSheetPolicy.shouldSuppressSelectionSheet(
                taskId = "task-1",
                sheet = sheet,
                consumedTaskId = "task-1",
                consumedSignature = "changed"
            )
        )
    }

    @Test
    fun clearConsumedSelectionSheetOnlyForBlankOrChangedTask() {
        assertTrue(
            AssistantSessionSelectionSheetPolicy.shouldClearConsumedSelectionSheet(
                taskId = " ",
                consumedTaskId = "task-1"
            )
        )
        assertTrue(
            AssistantSessionSelectionSheetPolicy.shouldClearConsumedSelectionSheet(
                taskId = "task-2",
                consumedTaskId = "task-1"
            )
        )
        assertFalse(
            AssistantSessionSelectionSheetPolicy.shouldClearConsumedSelectionSheet(
                taskId = " task-1 ",
                consumedTaskId = "task-1"
            )
        )
        assertFalse(
            AssistantSessionSelectionSheetPolicy.shouldClearConsumedSelectionSheet(
                taskId = "task-1",
                consumedTaskId = null
            )
        )
    }

    @Test
    fun buildsRestaurantSelectionSheetWithLocalizedLabels() {
        val sheet = AssistantSessionSelectionSheetPolicy.resolveSelectionSheetFromSession(
            session(
                sceneType = "FOOD_ORDERING",
                messages = listOf(
                    message(
                        type = "restaurant_card",
                        restaurantCard = RestaurantCardPayload(
                            itemId = "r1",
                            name = "Bistro 1",
                            cuisine = "western",
                            area = "downtown",
                            address = "1 Main St",
                            phone = "123456",
                            distanceMeters = 300,
                            actions = listOf(AssistantActionChip("food.select:r1", "Choose this one", "primary"))
                        )
                    )
                )
            ),
            VoiceLanguage.English
        )

        assertEquals("Choose a restaurant", sheet?.title)
        assertEquals("restaurant", sheet?.targetLabel)
        assertEquals("western · downtown\n1 Main St", sheet?.options?.single()?.meta)
        assertEquals("food.select:r1", sheet?.options?.single()?.actionId)
        assertFalse(sheet?.subtitle.orEmpty().contains("请选择"))
    }

    @Test
    fun buildsHotelSelectionSheetWithLocalizedLabels() {
        val sheet = AssistantSessionSelectionSheetPolicy.resolveSelectionSheetFromSession(
            session(
                sceneType = "HOTEL_BOOKING",
                messages = listOf(
                    message(
                        type = "hotel_card",
                        hotelCard = HotelCardPayload(
                            itemId = "h1",
                            name = "Hotel 1",
                            city = "Tokyo",
                            priceHint = "12000",
                            roomType = "double",
                            address = "2 Main St",
                            summary = "quiet",
                            actions = listOf(AssistantActionChip("hotel.select:h1", "これを選ぶ", "primary"))
                        )
                    )
                )
            ),
            VoiceLanguage.Japanese
        )

        assertEquals("ホテルを選択", sheet?.title)
        assertEquals("ホテル", sheet?.targetLabel)
        assertEquals("Tokyo · double · 12000\n2 Main St", sheet?.options?.single()?.meta)
        assertFalse(sheet?.subtitle.orEmpty().contains("请选择"))
    }

    @Test
    fun resolvesVoiceSelectionByTitleAndOrdinal() {
        val sheet = selectionSheet()

        assertEquals("item-1", AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption("the first", sheet)?.itemId)
        assertEquals("item-1", AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption("one", sheet)?.itemId)
        assertEquals("item-2", AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption("second", sheet)?.itemId)
        assertEquals("item-2", AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption("item-2", sheet)?.itemId)
        assertEquals("item-1", AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption("一番目", sheet)?.itemId)
        assertEquals("item-2", AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption("二番", sheet)?.itemId)
        assertNull(AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption("", sheet))
        assertNull(AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption("number 9", sheet))
    }

    @Test
    fun ignoresCardsBeforeTerminalBoundaryAndUnsupportedScenes() {
        val sheet = AssistantSessionSelectionSheetPolicy.resolveSelectionSheetFromSession(
            session(
                sceneType = "FOOD_ORDERING",
                messages = listOf(
                    message(
                        type = "restaurant_card",
                        restaurantCard = RestaurantCardPayload(
                            itemId = "old",
                            name = "Old Bistro",
                            cuisine = "western",
                            area = "downtown",
                            address = "1 Main St",
                            phone = "123456",
                            distanceMeters = 300,
                            actions = listOf(AssistantActionChip("food.select:old", "Choose", "primary"))
                        ),
                        hasResultSummary = true
                    ),
                    message(
                        type = "restaurant_card",
                        restaurantCard = RestaurantCardPayload(
                            itemId = "new",
                            name = "New Bistro",
                            cuisine = "western",
                            area = "downtown",
                            address = "2 Main St",
                            phone = "654321",
                            distanceMeters = 500,
                            actions = listOf(AssistantActionChip("food.select:new", "Choose", "primary"))
                        )
                    )
                )
            )
        )

        assertEquals("new", sheet?.options?.single()?.itemId)
        assertNull(
            AssistantSessionSelectionSheetPolicy.resolveSelectionSheetFromSession(
                session(sceneType = "GENERAL", messages = emptyList())
            )
        )
    }

    @Test
    fun selectionSuppressionDelegatesToSessionPolicyAndDeletesOldHelper() {
        val mapper = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_session/SessionMapper.kt")
            .readText(Charsets.UTF_8)
        val voiceApplyHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionVoiceApplyHandler.kt")
                .readText(Charsets.UTF_8)
        val actionHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_actions/AssistantUserDecisionActionHandler.kt")
                .readText(Charsets.UTF_8)
        val viewModel = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt")
            .readText(Charsets.UTF_8)
        val facade = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_facade/AssistantViewModelTaskSessionFacades.kt"
        ).readText(Charsets.UTF_8)
        val oldPureFunctions =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/Index9PureFunctions.kt")
                .readText(Charsets.UTF_8)

        assertTrue(mapper.contains("AssistantSessionSelectionSheetPolicy.signature"))
        assertTrue(mapper.contains("AssistantSessionSelectionSheetPolicy.shouldSuppressSelectionSheet"))
        assertTrue(mapper.contains("AssistantSessionSelectionSheetPolicy.shouldClearConsumedSelectionSheet"))
        assertTrue(mapper.contains("AssistantSessionSelectionSheetPolicy.resolveSelectionSheetFromSession"))
        assertFalse(mapper.contains("AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption"))
        assertTrue(voiceApplyHandler.contains("AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption"))
        assertTrue(actionHandler.contains("AssistantSessionSelectionSheetPolicy::signature"))
        assertFalse(viewModel.contains("AssistantSessionSelectionSheetPolicy.signature"))
        assertTrue(facade.contains("AssistantSessionSelectionSheetPolicy.signature"))
        assertFalse(oldPureFunctions.contains("fun selectionSheetSignature"))
        assertFalse(mapper.contains("val sheet = resolveSelectionSheetFromSession"))
        assertTrue(oldPureFunctions.contains("AssistantSessionSelectionSheetPolicy.resolveSelectionSheetFromSession"))
        assertTrue(oldPureFunctions.contains("AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption"))
    }

    private fun session(
        sceneType: String,
        messages: List<AssistantMessageItem>
    ): AssistantSessionResponse = AssistantSessionResponse(
        session = AssistantSessionMeta(
            taskId = "task-1",
            sceneType = sceneType,
            taskStatus = "WAITING_EXTERNAL_RESULT",
            title = "",
            subtitle = null,
            waitingForUser = true
        ),
        messages = messages
    )

    private fun message(
        type: String,
        restaurantCard: RestaurantCardPayload? = null,
        hotelCard: HotelCardPayload? = null,
        hasResultSummary: Boolean = false
    ): AssistantMessageItem = AssistantMessageItem(
        messageId = type + "-1",
        type = type,
        role = "assistant",
        text = null,
        title = null,
        subtitle = null,
        statusText = null,
        resultSummary = if (hasResultSummary) {
            ResultSummaryPayload(headline = "done", detail = "", status = "COMPLETED")
        } else {
            null
        },
        restaurantCard = restaurantCard,
        hotelCard = hotelCard
    )

    private fun selectionSheet(): SelectionSheetData {
        return SelectionSheetData(
            title = "选择候选",
            subtitle = "请选择",
            targetLabel = "餐厅",
            options = listOf(
                selectionOption(itemId = "item-1", actionId = "action-a"),
                selectionOption(itemId = "item-2", actionId = "action-b")
            )
        )
    }

    private fun selectionOption(itemId: String, actionId: String): SelectionSheetOption {
        return SelectionSheetOption(
            itemId = itemId,
            title = itemId,
            phone = "10086",
            meta = "",
            actionId = actionId,
            actionLabel = "confirm"
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
