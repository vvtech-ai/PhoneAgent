package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.core.model.AssistantActionChip
import com.vvtech.aiassistant.core.model.AssistantMessageItem
import com.vvtech.aiassistant.core.model.AssistantSessionMeta
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.core.model.HotelCardPayload
import com.vvtech.aiassistant.core.model.RestaurantCardPayload
import com.vvtech.aiassistant.features.assistant.SelectionSheetData
import com.vvtech.aiassistant.features.assistant.SelectionSheetOption
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant_tasks.CallDisplayOutcome
import com.vvtech.aiassistant.features.assistant_tasks.callPageResultStatusFromSource
import com.vvtech.aiassistant.features.assistant_tasks.callResultOutcome
import com.vvtech.aiassistant.features.assistant_tasks.callResultStatusText
import com.vvtech.aiassistant.features.assistant_tasks.callResultTaskStatus
import com.vvtech.aiassistant.features.assistant_tasks.callSessionDisplayDecision
import com.vvtech.aiassistant.features.assistant_tasks.shouldClearCallResultForContinuation
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Index9PureFunctionsTest {
    @Test
    fun suppressesDialogAudioDuringCallLaunchOrVisibleCallPage() {
        assertFalse(shouldSuppressDialogAudioForCall(showAiCallPage = false, pendingAiCallLaunch = false))
        assertEquals(true, shouldSuppressDialogAudioForCall(showAiCallPage = true, pendingAiCallLaunch = false))
        assertEquals(true, shouldSuppressDialogAudioForCall(showAiCallPage = false, pendingAiCallLaunch = true))
        assertEquals(true, shouldSuppressDialogAudioForCall(showAiCallPage = true, pendingAiCallLaunch = true))
        assertEquals(
            true,
            shouldSuppressDialogAudioForCall(
                showAiCallPage = false,
                pendingAiCallLaunch = false,
                currentCallId = "call-active"
            )
        )
    }

    @Test
    fun normalizesChineseHourAsWholeNumber() {
        assertEquals("明天12点", replaceChineseDigits("明天十二点"))
        assertEquals("明天11点半", replaceChineseDigits("明天十一点半"))
        assertEquals("明天23点15分", replaceChineseDigits("明天二十三点十五分"))
    }

    @Test
    fun correctsMergedAsrHourBeforeDian() {
        assertEquals(
            "帮忙联系卓优，让他明天12点过来加班",
            replaceChineseDigits("帮忙联系卓优，让他明天102点过来加班")
        )
        assertEquals("明天12点30分", replaceChineseDigits("明天102点30分"))
        assertEquals("明天19点", replaceChineseDigits("明天109点"))
    }

    @Test
    fun keepsNonMergedTimeAndPointWordsStable() {
        assertEquals("明天10点2分", replaceChineseDigits("明天10点2分"))
        assertEquals("会议室102点位", replaceChineseDigits("会议室102点位"))
    }

    @Test
    fun normalizesSpokenMobileNumberDigits() {
        assertEquals(
            "我的手机号是13800138000",
            replaceChineseDigits("我的手机号是幺三八零零幺三八零零零")
        )
        assertEquals(
            "联系电话 18812345678",
            replaceChineseDigits("联系电话 幺八八 一二三四 五六七八")
        )
    }

    @Test
    fun normalizesSpokenPhoneTailDigits() {
        assertEquals("留尾号1234的号码", replaceChineseDigits("留尾号幺二三四的号码"))
        assertEquals("电话尾号9999。", replaceChineseDigits("电话尾号九九九九。"))
        assertEquals("后四位是1208", replaceChineseDigits("后四位是幺二零八"))
    }

    @Test
    fun honoursAgentOutcomeAsSingleSourceOfTruth() {
        val detail = successfulRestaurantCallDetail()
        // Backend status 故意写错 ("未完成"), 但 agentOutcome=SUCCESS 应胜出
        val result = CallResultPayload(
            status = "未完成",
            headline = "AI 电话已结束",
            detail = detail,
            metadata = mapOf("agentOutcome" to "SUCCESS")
        )

        assertEquals(CallDisplayOutcome.Completed, callResultOutcome(result))
        assertEquals("任务完成", callResultStatusText(result, "FOOD_ORDERING"))
    }

    @Test
    fun agentOutcomeFailureOverridesCompletedTransportStatus() {
        val result = CallResultPayload(
            status = "COMPLETED",
            headline = "SIP completed",
            detail = "transport completed",
            metadata = mapOf("agentOutcome" to "FAILED", "agentReason" to "merchant rejected")
        )

        assertEquals(CallDisplayOutcome.Failed, callResultOutcome(result))
        assertEquals("INCOMPLETE", callResultTaskStatus(result))
    }

    @Test
    fun failureSummaryOverridesCompletedTransportStatusWhenAgentOutcomeMissing() {
        val result = CallResultPayload(
            status = "COMPLETED",
            headline = "AI agent summary",
            detail = "本次任务失败，商家拒绝接单，需要继续跟进",
            metadata = null
        )

        assertEquals(CallDisplayOutcome.Failed, callResultOutcome(result))
        assertEquals("INCOMPLETE", callResultTaskStatus(result))
        assertEquals("未完成", callResultStatusText(result, "FOOD_ORDERING"))
    }

    @Test
    fun failedCallResultShouldClearBeforeContinuation() {
        val result = CallResultPayload(
            status = "FAILED",
            headline = "not done",
            detail = "merchant rejected",
            metadata = mapOf("agentOutcome" to "FAILED")
        )

        assertTrue(shouldClearCallResultForContinuation("FAILED", result))
        assertTrue(shouldClearCallResultForContinuation("COMPLETED", result))
        assertTrue(shouldClearCallResultForContinuation("未完成", result))
        assertFalse(shouldClearCallResultForContinuation("FAILED", null))
    }

    @Test
    fun fallsBackToResultCodeWhenAgentOutcomeMissing() {
        val detail = successfulRestaurantCallDetail()
        val result = CallResultPayload(
            status = "COMPLETED",
            headline = "订餐预订已确认",
            detail = detail,
            metadata = mapOf("resultCode" to "SUCCESS_CONFIRMED")
        )

        assertEquals(CallDisplayOutcome.Completed, callResultOutcome(result))
        assertEquals("任务完成", callResultStatusText(result, "FOOD_ORDERING"))
    }

    @Test
    fun trustsUpstreamStatusWithoutScanningTranscript() {
        // 即使 transcript 看起来像成功，status="未完成" → 前端不再覆盖
        val detail = successfulRestaurantCallDetail()
        assertEquals("未完成", callPageResultStatusFromSource("未完成", detail, "FOOD_ORDERING"))
        assertEquals("未完成", callPageResultStatusFromSource("CANCELLED", detail, "FOOD_ORDERING"))
        assertEquals("结果未确认", callPageResultStatusFromSource("COMPLETED", "", "FOOD_ORDERING"))
    }

    @Test
    fun treatsEndedRestaurantSessionWithMerchantConfirmationAsBookingSuccess() {
        val decision = callSessionDisplayDecision(
            CallSessionStatusResponse(
                callId = "call-1",
                taskId = "task-1",
                sceneType = "FOOD_ORDERING",
                targetName = "北海渔村",
                phoneNumber = "0755-86966889",
                callState = "ENDED",
                handoffMode = "COMPLETED",
                backendCallEnabled = true,
                handoffSupported = true,
                appRtcRequired = false,
                dialogueDetail = successfulRestaurantCallDetail(),
                statusMessage = "通话已结束",
                resultCode = "SUCCESS_CONFIRMED",
                updatedAt = "2026-05-12T05:40:52Z"
            )
        )

        assertEquals(CallDisplayOutcome.Completed, decision.outcome)
        assertEquals("任务完成", decision.statusText)
        assertEquals("任务完成", decision.historyStatus)
    }

    @Test
    fun keepsRestaurantCallWithoutPrivateRoomAsFailed() {
        // 新契约：失败必须由后端 status="FAILED" 表达；前端不再从 transcript 反推
        val detail = """
            assistant: 今晚还有包间吗？
            callee: 没有包间，已经满位。
        """.trimIndent()

        assertEquals("未完成", callPageResultStatusFromSource("FAILED", detail, "FOOD_ORDERING"))
    }

    @Test
    fun hidesStructuredSupplementSyncMessagesForNonChineseClarification() {
        val steps = mapClarificationSteps(
            listOf(
                message("user_text", "本次预订请预留信息：Alex，联系电话13800138000。"),
                message("assistant_text", "Please confirm the booking contact.")
            ),
            hideInternalSync = true
        )

        assertEquals(0, steps.size)
    }

    @Test
    fun localizesRestaurantSelectionSheetLabels() {
        val sheet = resolveSelectionSheetFromSession(
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
        assertFalse(sheet?.subtitle.orEmpty().contains("请选择"))
    }

    @Test
    fun localizesHotelSelectionSheetLabels() {
        val sheet = resolveSelectionSheetFromSession(
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
        assertFalse(sheet?.subtitle.orEmpty().contains("请选择"))
    }

    @Test
    fun detectsEnglishBackendScenesForRealtimeSuppression() {
        assertEquals(
            "FOOD_ORDERING",
            detectLocalSceneHint(
                "Please book a private room at the Beihai Fish Village for six people at 8 o'clock tonight."
            )
        )
        assertEquals(
            "HOTEL_BOOKING",
            detectLocalSceneHint("Please book a hotel room in Tokyo for tomorrow night.")
        )
        assertEquals(
            "FLIGHT_BOOKING",
            detectLocalSceneHint("Please book a flight from Shenzhen to Tokyo tomorrow.")
        )
    }

    @Test
    fun resolvesEnglishOrdinalSelectionLocally() {
        val sheet = selectionSheet()

        assertEquals("r1", resolveVoiceSelectionOption("the first", sheet)?.itemId)
        assertEquals("r1", resolveVoiceSelectionOption("the first one", sheet)?.itemId)
        assertEquals("r1", resolveVoiceSelectionOption("one", sheet)?.itemId)
        assertEquals("r2", resolveVoiceSelectionOption("second", sheet)?.itemId)
        assertEquals("r3", resolveVoiceSelectionOption("option three", sheet)?.itemId)
    }

    @Test
    fun resolvesJapaneseOrdinalSelectionLocally() {
        val sheet = selectionSheet()

        assertEquals("r1", resolveVoiceSelectionOption("一番目", sheet)?.itemId)
        assertEquals("r2", resolveVoiceSelectionOption("二番", sheet)?.itemId)
        assertEquals("r3", resolveVoiceSelectionOption("第三", sheet)?.itemId)
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
        text: String? = null,
        restaurantCard: RestaurantCardPayload? = null,
        hotelCard: HotelCardPayload? = null
    ): AssistantMessageItem = AssistantMessageItem(
        messageId = type + "-1",
        type = type,
        role = if (type == "user_text") "user" else "assistant",
        text = text,
        title = null,
        subtitle = null,
        statusText = null,
        restaurantCard = restaurantCard,
        hotelCard = hotelCard
    )

    private fun selectionSheet(): SelectionSheetData = SelectionSheetData(
        title = "Choose a restaurant",
        subtitle = "",
        targetLabel = "restaurant",
        options = listOf(
            selectionOption("r1", "Bistro One"),
            selectionOption("r2", "Bistro Two"),
            selectionOption("r3", "Bistro Three")
        )
    )

    private fun selectionOption(itemId: String, title: String): SelectionSheetOption = SelectionSheetOption(
        itemId = itemId,
        title = title,
        phone = "",
        meta = "",
        actionId = "food.select:$itemId",
        actionLabel = "Choose"
    )

    private fun successfulRestaurantCallDetail(): String {
        return """
            assistant: 你好，是北海渔村吗？
            callee: 嗯，是的。
            assistant: 今晚还有包间吗？
            callee: 嗯，有的。
            assistant: 两个人用，大概六点到。
            callee: 好的。
            assistant: 请问包间有低消或者其他额外费用吗？
            callee: 没有的。
            assistant: 好的，那帮我订上吧，我姓罗。麻烦你再确认下信息可以吗？
            callee: 嗯，好的。
            assistant: 手机号是18823189131。
            callee: 嗯，罗先生，尾号 9131。
            assistant: 对的，没错。那我晚上见啦。
        """.trimIndent()
    }
}
