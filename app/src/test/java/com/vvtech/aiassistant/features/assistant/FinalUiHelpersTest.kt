package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.TranslationCallStartResponse
import com.vvtech.aiassistant.model.ConversationListItem
import com.vvtech.aiassistant.model.ReservationSlot
import com.vvtech.aiassistant.model.TaskListItem
import com.vvtech.aiassistant.features.assistant_tasks.taskStatusAfterConfirmedErrorRecovery
import com.vvtech.aiassistant.features.assistant_tasks.withPendingExecutionErrorExitStatuses
import com.vvtech.aiassistant.features.assistant_tasks.withRecoveredExecutionErrorStatuses
import com.vvtech.aiassistant.features.assistant.viewmodel.isTerminalTaskStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

class FinalUiHelpersTest {

    @Test
    fun contactMethodNameInputKeepsOnlyFourChineseCharacters() {
        assertEquals("张三李四", sanitizeContactMethodNameInput("张三A 李四五·6"))
        assertEquals("", sanitizeContactMethodNameInput("Alice-123"))
    }

    @Test
    fun contactMethodNameValidationRequiresOneToFourChineseCharacters() {
        assertEquals(null, validatePersonalInfoInput("张三", "13800138000"))
        assertEquals("姓名仅支持 1-4 个汉字", validatePersonalInfoInput("张三A", "13800138000"))
        assertEquals("姓名仅支持 1-4 个汉字", validatePersonalInfoInput("张三李四王", "13800138000"))
    }

    @Test
    fun loginPhoneInputRejectsInvalidPrefixDigitsWhileTyping() {
        assertEquals("", sanitizeLoginPhoneInput("2", ""))
        assertEquals("1", sanitizeLoginPhoneInput("12", "1"))
        assertEquals("13", sanitizeLoginPhoneInput("13", "1"))
    }

    @Test
    fun loginPhoneInputKeepsOnlyValidMainlandMobileDigits() {
        assertEquals("13800138000", sanitizeLoginPhoneInput("138001380001234", ""))
        assertEquals("13800138000", sanitizeLoginPhoneInput("+86 138-0013-8000", ""))
        assertEquals("13800138000", sanitizeLoginPhoneInput("１３８００１３８０００", ""))
    }

    @Test
    fun outboundDialNumberAllowsFixedLineAndInternationalNumbers() {
        assertEquals("01077778888", normalizeOutboundDialNumber("010-7777 8888"))
        assertEquals("+14085551212", normalizeOutboundDialNumber("+1 (408) 555-1212"))
        assertEquals("13800138000", normalizeOutboundDialNumber("+86 138-0013-8000"))
        assertEquals("01077778888", normalizeOutboundDialNumber("+86 10 7777 8888"))
    }

    @Test
    fun buildsRestaurantTaskDisplayItemWithSceneTargetAndKeyInfo() {
        val item = FinalTaskRecord(
            title = "订餐任务 · 新荣记",
            status = "已完成",
            detail = "2026-05-15 18:00 · 8 位 · 包房",
            sceneType = "RESTAURANT_BOOKING",
            startedAt = "2026-05-14 19:42"
        ).toFinalTaskDisplayItem()

        assertEquals("订餐厅", item.sceneName)
        assertEquals("新荣记", item.sceneTarget)
        assertEquals("订餐厅 · 新荣记", item.displayTitle)
        assertTrue(item.startTimeLabel.contains("19:42"))
        assertTrue(item.appointmentTimeLabel.contains("18:00"))
        assertTrue(item.secondaryLine.contains("19:42"))
        assertTrue(item.secondaryLine.contains("18:00"))
        assertTrue(item.secondaryLine.contains("\u00B7"))
        assertFalse(item.secondaryLine.contains("路"))
        assertFalse(item.keyInfo.contains("18:00"))
        assertTrue(item.keyInfo.contains("8位") || item.keyInfo.contains("8 位"))
        assertTrue(item.keyInfo.contains("包房"))
        assertEquals(FinalTaskStatusKind.Completed, item.statusKind)
    }

    @Test
    fun taskListDoesNotTreatPartyCountAfterHourAsMinutes() {
        val item = FinalTaskRecord(
            title = "订餐任务 · 最近一通电话",
            status = "COMPLETED",
            detail = "今晚8点7位，包间",
            sceneType = "RESTAURANT_BOOKING",
            startedAt = "2026-05-14 19:42"
        ).toFinalTaskDisplayItem()

        assertEquals("今晚8点", item.appointmentTimeLabel)
        assertFalse(item.appointmentTimeLabel.contains("8点7"))
        assertFalse(item.keyInfo.contains("今晚"))
        assertFalse(item.keyInfo.contains("8点"))
        assertTrue(item.keyInfo.contains("7位"))
        assertTrue(item.secondaryLine.contains("今晚8点"))
        assertFalse(item.secondaryLine.contains("今晚8点7"))
    }

    @Test
    fun backendTaskUsesStructuredPartySizeForRestaurantDisplay() {
        val item = TaskListItem(
            taskId = "task-restaurant-7",
            userId = "user-1",
            status = "COMPLETED",
            originText = "订餐任务 · 最近一通电话 今晚8点7，包间",
            finalResult = "预订成功",
            slot = ReservationSlot(
                reservationTime = "今晚8点",
                partySize = 7,
                restaurantName = "最近一通电话"
            ),
            createdAt = "2026-05-14 19:42"
        ).toFinalTaskRecord().toFinalTaskDisplayItem()

        assertEquals("今晚8点", item.appointmentTimeLabel)
        assertTrue(item.keyInfo.contains("7位"))
        assertFalse(item.keyInfo.split(" · ").contains("7"))
        assertTrue(item.secondaryLine.contains("7位"))
        assertFalse(item.secondaryLine.contains("今晚8点7"))
    }

    @Test
    fun buildsMeetingTaskDisplayItemFromTitleAndRunningStatus() {
        val item = FinalTaskRecord(
            title = "会议通知 · 16 位参会人",
            status = "PROCESSING",
            detail = "准备中",
            sceneType = "MEETING_INVITE"
        ).toFinalTaskDisplayItem()

        assertEquals("会议通知", item.sceneName)
        assertEquals("16 位参会人", item.sceneTarget)
        assertEquals(FinalTaskStatusKind.Running, item.statusKind)
    }

    @Test
    fun formatsTaskTimeWithDailyLabels() {
        val today = LocalDate.of(2026, 5, 14)
        val zoneId = ZoneId.of("Asia/Shanghai")

        assertEquals("今天 18:30", finalTaskRelativeTimeLabel("2026-05-14 18:30", today, zoneId))
        assertEquals("昨天 18:30", finalTaskRelativeTimeLabel("2026-05-13 18:30", today, zoneId))
        assertEquals("星期二 18:30", finalTaskRelativeTimeLabel("2026-05-12 18:30", today, zoneId))
    }

    @Test
    fun sortsTasksByRecordTimeBeforeAppointmentTime() {
        val recentTask = FinalTaskRecord(
            title = "restaurant booking",
            status = "COMPLETED",
            detail = "appointment 2026-05-15 18:00",
            startedAt = "2026-05-14 20:00"
        )
        val olderTaskWithLaterAppointment = FinalTaskRecord(
            title = "hotel booking",
            status = "COMPLETED",
            detail = "appointment 2026-05-16 18:00",
            startedAt = "2026-05-14 19:00"
        )

        assertTrue(
            finalTaskRecordSortEpochMillis(recentTask) >
                finalTaskRecordSortEpochMillis(olderTaskWithLaterAppointment)
        )
    }

    @Test
    fun mapsTaskStatusIntoOnlyFourListDisplayKinds() {
        assertEquals(FinalTaskStatusKind.Running, finalTaskStatusKind("执行中"))
        assertEquals(FinalTaskStatusKind.Running, finalTaskStatusKind("进行中"))
        assertEquals(FinalTaskStatusKind.Running, finalTaskStatusKind("待确认"))
        assertEquals(FinalTaskStatusKind.Completed, finalTaskStatusKind("COMPLETED"))
        assertEquals(FinalTaskStatusKind.Incomplete, finalTaskStatusKind("未完成"))
        assertEquals(FinalTaskStatusKind.Incomplete, finalTaskStatusKind("FAILED"))
        assertEquals(FinalTaskStatusKind.Incomplete, finalTaskStatusKind("UNCLEAR"))
        assertEquals(FinalTaskStatusKind.Incomplete, finalTaskStatusKind("未接电话"))
        assertEquals(FinalTaskStatusKind.Incomplete, finalTaskStatusKind("被挂断"))
        assertEquals(FinalTaskStatusKind.Incomplete, finalTaskStatusKind("未应邀"))
        assertEquals(FinalTaskStatusKind.ExecutionError, finalTaskStatusKind("NETWORK_ERROR"))
        assertEquals(FinalTaskStatusKind.ExecutionError, finalTaskStatusKind("ERROR"))
        assertEquals(FinalTaskStatusKind.ExecutionError, finalTaskStatusKind("SIP_ERROR"))
        assertEquals(FinalTaskStatusKind.ExecutionError, finalTaskStatusKind("执行异常"))
        assertEquals(FinalTaskStatusKind.ExecutionError, finalTaskStatusKind("模型服务异常"))
    }

    @Test
    fun simplifiedTaskStatusesUseOnlyNewFourLabels() {
        assertEquals("进行中", finalTaskStatusDisplayLabel("PENDING"))
        assertEquals("进行中", finalTaskStatusDisplayLabel("READY_TO_EXECUTE"))
        assertEquals("未完成", finalTaskStatusDisplayLabel("FAILED"))
        assertEquals("未完成", finalTaskStatusDisplayLabel("INCOMPLETE"))
        assertEquals("已完成", finalTaskStatusDisplayLabel("COMPLETED"))
        assertEquals("执行异常", finalTaskStatusDisplayLabel("NETWORK_ERROR"))
        assertEquals("执行异常", finalTaskStatusDisplayLabel("EXECUTION_ERROR"))

        assertEquals("进行中", conversationStatusLabel("PENDING"))
        assertEquals("未完成", conversationStatusLabel("FAILED"))
        assertEquals("未完成", conversationStatusLabel("INCOMPLETE"))
        assertEquals("已完成", conversationStatusLabel("COMPLETED"))
        assertEquals("执行异常", conversationStatusLabel("NETWORK_ERROR"))
        assertEquals("执行异常", conversationStatusLabel("EXECUTION_ERROR"))
    }

    @Test
    fun interruptedConversationIsTerminalCanceledState() {
        assertEquals("USER_INTERRUPTED", normalizeConversationTaskStatus("USER_INTERRUPTED"))
        assertEquals("进行中", conversationStatusLabel("USER_INTERRUPTED"))
        assertFalse(isCompletedConversationStatus("USER_INTERRUPTED"))
        assertFalse(isReadOnlyConversationStatus("USER_INTERRUPTED"))
        assertEquals(FinalTaskStatusKind.Running, finalTaskStatusKind("USER_INTERRUPTED"))
        assertEquals("进行中", finalTaskStatusDisplayLabel("USER_INTERRUPTED"))

        val item = ConversationListItem(
            sessionId = "session-interrupted",
            title = "interrupted task",
            status = "USER_INTERRUPTED",
            sceneType = "AI_CALL",
            updatedAt = "2026-05-26 12:00"
        ).toFinalTaskDisplayItem()
        assertEquals("进行中", item.statusLabel)
    }

    @Test
    fun executionErrorConversationKeepsExecutionErrorAfterDisplayMapping() {
        val item = ConversationListItem(
            sessionId = "session-error",
            title = "订餐任务",
            status = "EXECUTION_ERROR",
            sceneType = "RESTAURANT_BOOKING",
            updatedAt = "2026-05-30T16:11:03"
        ).toFinalTaskDisplayItem()

        assertEquals(FinalTaskStatusKind.ExecutionError, item.statusKind)
        assertEquals("执行异常", item.statusLabel)
    }

    @Test
    fun activeConversationShortcutOnlyShowsForRecoverableRunningTasks() {
        assertTrue(shouldShowActiveConversationShortcut("session-1", "RUNNING"))
        assertTrue(shouldShowActiveConversationShortcut("session-1", "ACTIVE"))
        assertFalse(shouldShowActiveConversationShortcut(null, "RUNNING"))
        assertFalse(shouldShowActiveConversationShortcut("session-1", "COMPLETED"))
        assertFalse(shouldShowActiveConversationShortcut("session-1", "EXECUTION_ERROR"))
        assertFalse(shouldShowActiveConversationShortcut("session-1", "NETWORK_ERROR"))
    }

    @Test
    fun voiceResumeSyncsActiveConversationsThatMayHaveMissedStreamTerminal() {
        assertTrue(
            shouldSyncConversationBeforeVoiceResume(
                sessionId = "session-1",
                taskStatus = "ACTIVE",
                status = "AI处理中",
                processingTurn = true
            )
        )
        assertTrue(
            shouldSyncConversationBeforeVoiceResume(
                sessionId = "session-1",
                taskStatus = "ACTIVE",
                status = "对话已恢复，点击继续说话",
                processingTurn = false
            )
        )
        assertTrue(
            shouldSyncConversationBeforeVoiceResume(
                sessionId = "session-1",
                taskStatus = "ACTIVE",
                status = "已暂停，返回后可继续",
                processingTurn = false
            )
        )
        assertFalse(
            shouldSyncConversationBeforeVoiceResume(
                sessionId = "",
                taskStatus = "ACTIVE",
                status = "AI处理中",
                processingTurn = true
            )
        )
        assertTrue(
            shouldSyncConversationBeforeVoiceResume(
                sessionId = "session-1",
                taskStatus = "USER_INTERRUPTED",
                status = "对话已恢复，点击继续说话",
                processingTurn = false
            )
        )
    }

    @Test
    fun activeConversationRestoreShowsResumeControlMode() {
        assertEquals(
            PureVoiceBottomControlMode.Mic,
            resolvePureVoiceBottomControlMode(
                taskStatus = "ACTIVE",
                status = "对话已恢复，点击继续说话",
                manuallyPaused = false
            )
        )
        assertEquals(
            PureVoiceBottomControlMode.Mic,
            resolvePureVoiceBottomControlMode(
                taskStatus = "ACTIVE",
                status = "已暂停，返回后可继续",
                manuallyPaused = false
            )
        )
        assertEquals(
            PureVoiceBottomControlMode.Mic,
            resolvePureVoiceBottomControlMode(
                taskStatus = "ACTIVE",
                status = "已暂停，点击继续说话",
                manuallyPaused = true
            )
        )
        assertEquals(
            PureVoiceBottomControlMode.Mic,
            resolvePureVoiceBottomControlMode(
                taskStatus = "ACTIVE",
                status = "你可以再点一下麦克风继续说",
                manuallyPaused = false
            )
        )
    }

    @Test
    fun pureVoiceBottomControlKeepsPausedUserStateAboveTtsPlayback() {
        assertEquals(
            PureVoiceBottomControlMode.Mic,
            resolveSingleFlowPureVoiceBottomControlMode(
                taskStatus = "ACTIVE",
                status = "Listening...",
                manuallyPaused = true,
                backgroundPaused = false,
                listening = false,
                processingTurn = false,
                aiSpeaking = true
            )
        )
    }

    @Test
    fun networkErrorConversationShowsResumeControlMode() {
        assertFalse(isReadOnlyConversationStatus("NETWORK_ERROR"))
        assertEquals("执行异常", conversationStatusLabel("NETWORK_ERROR"))
        assertEquals(
            PureVoiceBottomControlMode.Mic,
            resolvePureVoiceBottomControlMode(
                taskStatus = "NETWORK_ERROR",
                status = "网络异常，任务已暂停，请检查网络后继续",
                manuallyPaused = false
            )
        )
    }

    @Test
    fun pureVoiceBottomControlUsesPttModesForVisibleTurnStates() {
        assertEquals(
            PureVoiceBottomControlMode.Mic,
            resolveSingleFlowPureVoiceBottomControlMode(
                taskStatus = "ACTIVE",
                status = "",
                manuallyPaused = false,
                backgroundPaused = false,
                listening = false,
                processingTurn = false,
                aiSpeaking = false
            )
        )
        assertEquals(
            PureVoiceBottomControlMode.Recording,
            resolveSingleFlowPureVoiceBottomControlMode(
                taskStatus = "ACTIVE",
                status = "",
                manuallyPaused = false,
                backgroundPaused = false,
                listening = true,
                processingTurn = false,
                aiSpeaking = false
            )
        )
        assertEquals(
            PureVoiceBottomControlMode.Finalizing,
            resolveSingleFlowPureVoiceBottomControlMode(
                taskStatus = "ACTIVE",
                status = "",
                manuallyPaused = false,
                backgroundPaused = false,
                listening = true,
                asrFinalizing = true,
                processingTurn = false,
                aiSpeaking = false
            )
        )
        assertEquals(
            PureVoiceBottomControlMode.Stop,
            resolveSingleFlowPureVoiceBottomControlMode(
                taskStatus = "ACTIVE",
                status = "",
                manuallyPaused = false,
                backgroundPaused = false,
                listening = false,
                processingTurn = true,
                aiSpeaking = false
            )
        )
        assertEquals(
            PureVoiceBottomControlMode.Stop,
            resolveSingleFlowPureVoiceBottomControlMode(
                taskStatus = "ACTIVE",
                status = "",
                manuallyPaused = false,
                backgroundPaused = false,
                listening = false,
                processingTurn = false,
                aiSpeaking = true
            )
        )
    }

    @Test
    fun pureVoiceLiveLabelsUsePttStatusCopy() {
        assertEquals(
            "语音待命中...",
            pureVoiceLiveLabel(
                state = PureVoiceState.Standby,
                voiceLanguage = VoiceLanguage.Chinese,
                status = "你可以再点一下麦克风继续说",
                showCallPage = false
            )
        )
        assertEquals(
            "语音待命中...",
            pureVoiceLiveLabel(
                state = PureVoiceState.Standby,
                voiceLanguage = VoiceLanguage.Chinese,
                status = "请按住下方语音按钮，说出你的需求。",
                showCallPage = false
            )
        )
        assertEquals(
            "正在聆听...",
            pureVoiceLiveLabel(
                state = PureVoiceState.Listening,
                voiceLanguage = VoiceLanguage.Chinese,
                status = "",
                showCallPage = false
            )
        )
        assertEquals(
            "AI 思考中...",
            pureVoiceLiveLabel(
                state = PureVoiceState.AiThinking,
                voiceLanguage = VoiceLanguage.Chinese,
                status = "正在确认细节",
                showCallPage = false
            )
        )
        assertEquals(
            "AI 回复中...",
            pureVoiceLiveLabel(
                state = PureVoiceState.AiSpeaking,
                voiceLanguage = VoiceLanguage.Chinese,
                status = "AI 正在说话",
                showCallPage = false
            )
        )
    }

    @Test
    fun abnormalTaskExitPersistsExecutionErrorUntilRecoveryIsConfirmed() {
        assertTrue(
            shouldPersistExecutionErrorOnTaskExit(
                taskStatus = "NETWORK_ERROR",
                unresolvedTaskErrorStatus = null,
                taskErrorRecoveryInProgress = false
            )
        )
        assertTrue(
            shouldPersistExecutionErrorOnTaskExit(
                taskStatus = "ACTIVE",
                unresolvedTaskErrorStatus = "EXECUTION_ERROR",
                taskErrorRecoveryInProgress = true
            )
        )
        assertTrue(
            shouldPersistExecutionErrorOnTaskExit(
                taskStatus = "ACTIVE",
                unresolvedTaskErrorStatus = null,
                taskErrorRecoveryInProgress = true
            )
        )
        assertFalse(
            shouldPersistExecutionErrorOnTaskExit(
                taskStatus = "ACTIVE",
                unresolvedTaskErrorStatus = null,
                taskErrorRecoveryInProgress = false
            )
        )
    }

    @Test
    fun pendingExecutionErrorExitOverridesConversationListStatus() {
        val conversations = listOf(
            ConversationListItem(
                sessionId = "session-1",
                title = "订餐任务",
                status = "RUNNING"
            ),
            ConversationListItem(
                sessionId = "session-2",
                title = "普通任务",
                status = "RUNNING"
            )
        )

        val updated = conversations.withPendingExecutionErrorExitStatuses(setOf("session-1"))

        assertEquals("EXECUTION_ERROR", updated.first { it.sessionId == "session-1" }.status)
        assertEquals("RUNNING", updated.first { it.sessionId == "session-2" }.status)
        assertEquals("执行异常", conversationStatusLabel(updated.first().status))
    }

    @Test
    fun recoveredExecutionErrorConversationWaitsForCanonicalProjection() {
        assertEquals("EXECUTION_ERROR", taskStatusAfterConfirmedErrorRecovery("EXECUTION_ERROR"))
        assertEquals("NETWORK_ERROR", taskStatusAfterConfirmedErrorRecovery("NETWORK_ERROR"))
        assertEquals("tool_error", taskStatusAfterConfirmedErrorRecovery("tool_error"))
        assertEquals("network_failure", taskStatusAfterConfirmedErrorRecovery("network_failure"))
        assertEquals("COMPLETED", taskStatusAfterConfirmedErrorRecovery("COMPLETED"))
        assertEquals("custom_state", taskStatusAfterConfirmedErrorRecovery("custom_state"))
        assertTrue(isNetworkTaskStatus("network_failure"))
        assertFalse(isNetworkTaskStatus("EXECUTION_ERROR"))

        val conversations = listOf(
            ConversationListItem(
                sessionId = "session-1",
                title = "task one",
                status = "EXECUTION_ERROR"
            ),
            ConversationListItem(
                sessionId = "session-2",
                title = "task two",
                status = "COMPLETED"
            )
        )

        val updated = conversations.withRecoveredExecutionErrorStatuses(setOf("session-1"))

        assertEquals("EXECUTION_ERROR", updated.first { it.sessionId == "session-1" }.status)
        assertEquals("COMPLETED", updated.first { it.sessionId == "session-2" }.status)
    }

    @Test
    fun taskEmptyStateWaitsForAllTaskSourcesToFinishLoading() {
        assertTrue(isFinalTaskPageLoading(realTaskLoading = false, conversationLoading = true))
        assertFalse(
            shouldShowFinalTaskEmptyState(
                recordsEmpty = true,
                completedConversationsEmpty = true,
                activeConversationsEmpty = true,
                activeConversationTitle = null,
                loading = true
            )
        )
        assertTrue(
            shouldShowFinalTaskEmptyState(
                recordsEmpty = true,
                completedConversationsEmpty = true,
                activeConversationsEmpty = true,
                activeConversationTitle = null,
                loading = false
            )
        )
    }

    @Test
    fun pureVoiceListeningStateDoesNotTreatConnectingAsRecording() {
        assertFalse(
            resolvePureVoiceListeningState(
                manuallyPaused = false,
                voiceConnecting = true,
                listening = false,
                apiAsrListening = false
            )
        )
        assertTrue(
            resolvePureVoiceListeningState(
                manuallyPaused = false,
                voiceConnecting = true,
                listening = false,
                apiAsrListening = true
            )
        )
    }

    @Test
    fun pausedVoiceToolbarShowsContinueInsteadOfSupplementOrProcessing() {
        assertEquals(
            "继续",
            resolveVoiceInputToolbarLabel(
                listening = false,
                processingTurn = false,
                manuallyPaused = true,
                sceneType = "FOOD_ORDERING"
            )
        )
        assertEquals(
            "继续",
            resolveVoiceInputToolbarLabel(
                listening = false,
                processingTurn = true,
                manuallyPaused = true,
                sceneType = "AI_CALL"
            )
        )
    }

    @Test
    fun forceNewTaskVoiceEntryStartOnlyForFreshBlankVoiceEntry() {
        assertTrue(
            shouldForceNewTaskVoiceEntryStart(
                startInVoice = true,
                resumeListeningOnly = false,
                resumeExisting = false,
                initialCommand = ""
            )
        )
        assertFalse(
            shouldForceNewTaskVoiceEntryStart(
                startInVoice = true,
                resumeListeningOnly = true,
                resumeExisting = false,
                initialCommand = ""
            )
        )
        assertFalse(
            shouldForceNewTaskVoiceEntryStart(
                startInVoice = true,
                resumeListeningOnly = false,
                resumeExisting = true,
                initialCommand = ""
            )
        )
        assertFalse(
            shouldForceNewTaskVoiceEntryStart(
                startInVoice = true,
                resumeListeningOnly = false,
                resumeExisting = false,
                initialCommand = "帮我订今晚的餐厅"
            )
        )
        assertFalse(
            shouldForceNewTaskVoiceEntryStart(
                startInVoice = false,
                resumeListeningOnly = false,
                resumeExisting = false,
                initialCommand = ""
            )
        )
    }

    @Test
    fun terminatedConversationCanResumeFromVoiceControl() {
        assertEquals(
            PureVoiceBottomControlMode.Mic,
            resolvePureVoiceBottomControlMode(
                taskStatus = "USER_INTERRUPTED",
                status = "对话已恢复，点击继续说话",
                manuallyPaused = false
            )
        )
        assertEquals(
            PureVoiceBottomControlMode.Mic,
            resolvePureVoiceBottomControlMode(
                taskStatus = "CLOSED",
                status = "对话已恢复，点击继续说话",
                manuallyPaused = true
            )
        )
        assertEquals(
            PureVoiceBottomControlMode.Mic,
            resolvePureVoiceBottomControlMode(
                taskStatus = "COMPLETED",
                status = "对话已恢复，点击继续说话",
                manuallyPaused = false
            )
        )
    }

    @Test
    fun failedConversationCanResumeFromVoiceControl() {
        assertTrue(isTerminalTaskStatus("DONE"))
        assertTrue(isTerminalTaskStatus("succeeded"))
        assertFalse(isTerminalTaskStatus("FAILED"))
        assertFalse(isTerminalTaskStatus("INCOMPLETE"))
        assertFalse(isTerminalTaskStatus("CANCELLED"))
        assertFalse(isReadOnlyConversationStatus("FAILED"))
        assertFalse(isReadOnlyConversationStatus("未完成"))
        assertEquals("未完成", conversationStatusLabel("FAILED"))
        assertEquals(
            PureVoiceBottomControlMode.Mic,
            resolvePureVoiceBottomControlMode(
                taskStatus = "FAILED",
                status = "对话已恢复，点击继续说话",
                manuallyPaused = false
            )
        )
        assertEquals(
            PureVoiceBottomControlMode.Mic,
            resolvePureVoiceBottomControlMode(
                taskStatus = "未完成",
                status = "对话已恢复，点击继续说话",
                manuallyPaused = false
            )
        )
    }

    @Test
    fun buildsHomeNotificationQueueFromRealCompletedItems() {
        val items = buildHomeNotificationItems(
            completedTaskRecords = listOf(
                FinalTaskRecord(
                    title = "订餐任务 · 新荣记",
                    status = "已完成",
                    detail = "2026-05-13 18:30"
                )
            ),
            completedConversations = listOf(
                ConversationListItem(
                    sessionId = "session-1",
                    title = "联系餐厅",
                    status = "COMPLETED",
                    sceneType = "RESTAURANT_BOOKING",
                    updatedAt = "2026-05-13 19:00"
                )
            )
        )

        assertEquals(2, items.size)
        assertTrue(items[0].text.contains("订餐厅已完成"))
        assertTrue(items[0].text.contains("联系餐厅"))
        assertTrue(items[1].text.contains("订餐厅已完成"))
        assertTrue(items[1].text.contains("新荣记"))
    }

    @Test
    fun dismissingCurrentHomeNotificationShowsNextOne() {
        val items = listOf(
            FinalHomeNotificationItem(id = "n1", text = "第一条"),
            FinalHomeNotificationItem(id = "n2", text = "第二条"),
            FinalHomeNotificationItem(id = "n3", text = "第三条")
        )

        val pending = pendingHomeNotificationItems(items, dismissedIds = listOf("n1"))

        assertEquals(2, pending.size)
        assertEquals("n2", pending.first().id)
    }

    @Test
    fun backendTaskNotificationIdUsesStableTaskId() {
        val record = TaskListItem(
            taskId = "task-123",
            userId = "user-1",
            status = "COMPLETED",
            originText = "book dinner",
            finalResult = "done",
            createdAt = "2026-05-14 12:00"
        ).toFinalTaskRecord()

        val items = buildHomeNotificationItems(
            completedTaskRecords = listOf(record),
            completedConversations = emptyList()
        )

        assertEquals("legacy_task_task-123", record.notificationId)
        assertEquals("legacy_task_task-123", items.single().id)
        assertTrue(pendingHomeNotificationItems(items, dismissedIds = listOf("legacy_task_task-123")).isEmpty())
    }

    @Test
    fun sortsRealHomeNotificationsByCompletedTime() {
        val items = buildHomeNotificationItems(
            completedTaskRecords = listOf(
                FinalTaskRecord(
                    title = "订酒店任务 · 宝格丽",
                    status = "已完成",
                    detail = "已预订成功 · 2026-05-13 18:30"
                ),
                FinalTaskRecord(
                    title = "订餐任务 · 新荣记",
                    status = "已完成",
                    detail = "已预订成功 · 2026-05-13 20:00"
                )
            ),
            completedConversations = listOf(
                ConversationListItem(
                    sessionId = "session-1",
                    title = "联系餐厅",
                    status = "COMPLETED",
                    sceneType = "RESTAURANT_BOOKING",
                    updatedAt = "2026-05-13 19:00"
                )
            )
        )

        assertEquals(3, items.size)
        assertTrue(items[0].text.contains("订餐厅已完成"))
        assertTrue(items[0].text.contains("新荣记"))
        assertTrue(items[1].text.contains("联系餐厅"))
        assertTrue(items[2].text.contains("订酒店已完成"))
        assertTrue(items[2].text.contains("宝格丽"))
    }

    @Test
    fun treatsChineseCompletedStatusAsSuccessfulResultPageState() {
        val method = Class.forName("com.vvtech.aiassistant.features.assistant.FinalResultPolicyKt")
            .getDeclaredMethod("finalResultIsSuccess", String::class.java, String::class.java, StatusStyle::class.java)
        method.isAccessible = true

        val success = method.invoke(null, "已完成", "", StatusStyle.Success) as Boolean

        assertTrue(success)
    }

    @Test
    fun taskBadgeMatchesPendingNotificationCount() {
        val count = taskBadgeCountFromPendingNotifications(
            listOf(
                FinalHomeNotificationItem(id = "n1", text = "第一条"),
                FinalHomeNotificationItem(id = "n2", text = "第二条"),
                FinalHomeNotificationItem(id = "n3", text = "第三条")
            )
        )

        assertEquals(3, count)
    }

    @Test
    fun dismissingNotificationReducesTaskBadgeCount() {
        val pending = pendingHomeNotificationItems(
            items = listOf(
                FinalHomeNotificationItem(id = "n1", text = "第一条"),
                FinalHomeNotificationItem(id = "n2", text = "第二条"),
                FinalHomeNotificationItem(id = "n3", text = "第三条")
            ),
            dismissedIds = listOf("n1")
        )

        assertEquals(2, taskBadgeCountFromPendingNotifications(pending))
    }
    @Test
    fun mapsTranslationStartResponseToRealtimeStatusShape() {
        val status = TranslationCallStartResponse(
            callId = "call-123",
            callState = "CONNECTED",
            translationState = "TRANSLATING",
            provider = "DOUBAO",
            voiceCapability = "SOURCE_VOICE_MIMIC_ONLY",
            callerDetectedLanguage = "zh",
            calleeDetectedLanguage = "en",
            effectiveCallerToCalleeVoice = "",
            passthroughActive = false,
            passthroughReason = null,
            statusMessage = "connected"
        ).toStatusResponse()

        assertEquals("call-123", status.callId)
        assertEquals("CONNECTED", status.callState)
        assertEquals("TRANSLATING", status.translationState)
        assertEquals("DOUBAO", status.provider)
        assertEquals("SOURCE_VOICE_MIMIC_ONLY", status.voiceCapability)
        assertTrue(status.subtitleItems.isEmpty())
        assertEquals("", status.updatedAt)
    }

    @Test
    fun buildsPendingTranslationStatusWithDoubaoDefaults() {
        val status = buildPendingTranslationStatus(
            provider = "DOUBAO",
            statusMessage = "starting"
        )

        assertEquals("DIALING", status.callState)
        assertEquals("LANGUAGE_DETECTING", status.translationState)
        assertEquals("DOUBAO", status.provider)
        assertEquals("SOURCE_VOICE_MIMIC_ONLY", status.voiceCapability)
        assertEquals("starting", status.statusMessage)
        assertTrue(status.subtitleItems.isEmpty())
    }

    @Test
    fun callTimeLabelUsesActualTimestampInsteadOfListIndexFallback() {
        val zoneId = ZoneId.of("Asia/Shanghai")
        val now = ZonedDateTime.of(2026, 5, 14, 10, 0, 30, 0, zoneId).toInstant().toEpochMilli()
        val tenSecondsAgo = ZonedDateTime.of(2026, 5, 14, 10, 0, 20, 0, zoneId).toInstant().toEpochMilli()
        val twentySecondsAgo = ZonedDateTime.of(2026, 5, 14, 10, 0, 10, 0, zoneId).toInstant().toEpochMilli()

        assertEquals(
            "刚刚",
            finalCallTimeLabel(
                meta = "刚刚 · 实时翻译通话结束，时长 00:12",
                index = 0,
                occurredAtMillis = tenSecondsAgo,
                nowMillis = now,
                zoneId = zoneId
            )
        )
        assertEquals(
            "刚刚",
            finalCallTimeLabel(
                meta = "刚刚 · 实时翻译通话结束，时长 00:08",
                index = 1,
                occurredAtMillis = twentySecondsAgo,
                nowMillis = now,
                zoneId = zoneId
            )
        )
    }

    @Test
    fun callTimeLabelFormatsOlderCallsByActualDay() {
        val zoneId = ZoneId.of("Asia/Shanghai")
        val now = ZonedDateTime.of(2026, 5, 14, 10, 0, 0, 0, zoneId).toInstant().toEpochMilli()
        val todayEarlier = ZonedDateTime.of(2026, 5, 14, 8, 35, 0, 0, zoneId).toInstant().toEpochMilli()
        val yesterday = ZonedDateTime.of(2026, 5, 13, 21, 20, 0, 0, zoneId).toInstant().toEpochMilli()

        assertEquals(
            "08:35",
            finalCallTimeLabel(
                meta = "刚刚 · 普通通话结束，时长 03:12",
                index = 1,
                occurredAtMillis = todayEarlier,
                nowMillis = now,
                zoneId = zoneId
            )
        )
        assertEquals(
            "昨天",
            finalCallTimeLabel(
                meta = "刚刚 · 普通通话结束，时长 03:12",
                index = 2,
                occurredAtMillis = yesterday,
                nowMillis = now,
                zoneId = zoneId
            )
        )
    }
}
