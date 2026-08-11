package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SingleFlowNativeContentShellGuardTest {
    @Test
    fun nativeScreenDelegatesRenderingToContentShell() {
        val screen = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/SingleFlowNativeDemoScreen.kt"
        ).readText(Charsets.UTF_8)
        val shell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_singleflow/SingleFlowNativeContentShell.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(screen.contains("SingleFlowNativeContentShell("))
        assertTrue(screen.lines().size < 1000)
        assertTrue(shell.lines().size <= 300)

        listOf(
            "SingleFlowHeader(",
            "SingleFlowDialogueList(",
            "SingleFlowRealInputBar(",
            "SingleFlowDemoInputPanel(",
            "SingleFlowMockCallOverlay(",
            "SfTaskReceiptOverlay(",
            "SingleFlowReceiptHintOverlay(",
            "VoiceDebugOverlay("
        ).forEach { token ->
            assertFalse("rendering call should stay in shell: $token", screen.contains(token))
            assertTrue("shell should own rendering call: $token", shell.contains(token))
        }

        listOf(
            "suspend fun handleUserInput(",
            "suspend fun runCallFlow(",
            "fun advanceMockStep(",
            "onSubmitTask?.invoke(",
            "onStartVoiceInteraction?.invoke("
        ).forEach { token ->
            assertFalse("content shell must not own flow behavior: $token", shell.contains(token))
        }
    }

    @Test
    fun inputBarsLiveInSingleFlowBoundary() {
        val legacy = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/SingleFlowInputBars.kt"
        ).readText(Charsets.UTF_8)
        val realInputBar = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_singleflow/SingleFlowRealInputBar.kt"
        ).readText(Charsets.UTF_8)
        val demoInputPanel = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_singleflow/SingleFlowDemoInputPanel.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(legacy.lines().size <= 80)
        assertTrue(realInputBar.lines().size <= 300)
        assertTrue(demoInputPanel.lines().size <= 300)
        assertTrue(legacy.contains("SingleFlowRealInputBarContent("))
        assertTrue(legacy.contains("SingleFlowDemoInputPanelContent("))

        listOf(
            "BasicTextField",
            "Icons.Rounded.Send",
            "Icons.Outlined.Mic",
            "FinalModeButton(",
            "FinalPauseGlyph()",
            "Brush.verticalGradient"
        ).forEach { token ->
            assertFalse("legacy input bars should not own input UI body: $token", legacy.contains(token))
        }

        listOf(
            "BasicTextField",
            "Icons.Rounded.Send",
            "SingleFlowPttInput(",
            "onVoicePress = onVoiceButtonTap",
            "onVoiceRelease = { onStopVoiceInteraction?.invoke() }"
        ).forEach { token ->
            assertTrue("real input bar should own real input UI token: $token", realInputBar.contains(token))
        }

        listOf(
            "BasicTextField",
            "Icons.Rounded.Send",
            "Icons.Outlined.Mic",
            "FinalModeButton(",
            "FinalPauseGlyph()"
        ).forEach { token ->
            assertTrue("demo input panel should own demo input UI token: $token", demoInputPanel.contains(token))
        }

        listOf(
            "Repository",
            "Container",
            "TaskRepository",
            "AudioTrack",
            "MediaPlayer",
            "Sip",
            "SIP"
        ).forEach { token ->
            assertFalse("real input bar should not depend on runtime/data capability: $token", realInputBar.contains(token))
            assertFalse("demo input panel should not depend on runtime/data capability: $token", demoInputPanel.contains(token))
        }
    }

    @Test
    fun restaurantOptionsAndReceiptOverlayLiveInSingleFlowBoundary() {
        val legacy = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/SingleFlowRestaurantAndOverlays.kt"
        ).readText(Charsets.UTF_8)
        val restaurantCards = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_singleflow/SingleFlowRestaurantOptionsCards.kt"
        ).readText(Charsets.UTF_8)
        val receiptOverlay = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_singleflow/SingleFlowTaskReceiptOverlay.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(legacy.lines().size <= 180)
        assertTrue(restaurantCards.lines().size <= 300)
        assertTrue(receiptOverlay.lines().size <= 300)
        assertTrue(legacy.contains("SingleFlowPvRestaurantOptionsCard("))
        assertTrue(legacy.contains("SingleFlowRestaurantOptionsCard("))
        assertTrue(legacy.contains("SingleFlowTaskReceiptOverlay("))

        listOf(
            "options.forEachIndexed",
            "RestaurantOptionRow(",
            "候选餐厅",
            "可以回复餐厅名称或第几个",
            "点击选择",
            "ReceiptRow(",
            "TaskReceiptStatusBadge(",
            "任务回执",
            "已预订大厅座",
            "李先生 139****9999"
        ).forEach { token ->
            assertFalse("legacy restaurant/receipt file should not own UI body: $token", legacy.contains(token))
        }

        listOf(
            "PvRestaurantOptionsCard(",
            "SfRestaurantOptionsCard(",
            "RestaurantOptionRow(",
            "options.forEachIndexed",
            "候选餐厅",
            "点击选择",
            "可以回复餐厅名称或第几个"
        ).forEach { token ->
            assertTrue("restaurant cards should own restaurant option UI token: $token", restaurantCards.contains(token))
        }

        listOf(
            "SfTaskReceiptOverlay(",
            "ReceiptRow(",
            "TaskReceiptStatusBadge(",
            "任务回执",
            "已预订大厅座",
            "李先生 139****9999"
        ).forEach { token ->
            assertTrue("receipt overlay should own receipt UI token: $token", receiptOverlay.contains(token))
        }

        listOf(
            "Repository",
            "Container",
            "TaskRepository",
            "AudioTrack",
            "MediaPlayer",
            "Sip",
            "SIP",
            "AgentStream"
        ).forEach { token ->
            assertFalse("restaurant cards should not depend on runtime/data capability: $token", restaurantCards.contains(token))
            assertFalse("receipt overlay should not depend on runtime/data capability: $token", receiptOverlay.contains(token))
        }
    }

    @Test
    fun mockCallOverlayAndControlsLiveInSingleFlowBoundary() {
        val legacyCallOverlay = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/SingleFlowCallOverlay.kt"
        ).readText(Charsets.UTF_8)
        val legacySharedOverlay = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/SingleFlowRestaurantAndOverlays.kt"
        ).readText(Charsets.UTF_8)
        val mockCallOverlay = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_singleflow/SingleFlowMockCallOverlay.kt"
        ).readText(Charsets.UTF_8)
        val callControls = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_singleflow/SingleFlowCallControls.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(legacyCallOverlay.lines().size <= 80)
        assertTrue(legacySharedOverlay.lines().size <= 150)
        assertTrue(mockCallOverlay.lines().size <= 300)
        assertTrue(callControls.lines().size <= 100)
        assertTrue(legacyCallOverlay.contains("SingleFlowMockCallOverlayContent("))
        assertTrue(legacySharedOverlay.contains("SingleFlowCallControlButton("))

        listOf(
            "LazyColumn",
            "Brush.verticalGradient",
            "使用用户声音 · 正在执行代理任务",
            "通话转写",
            "已静音",
            "扬声器开"
        ).forEach { token ->
            assertFalse("legacy call overlay should not own mock call UI body: $token", legacyCallOverlay.contains(token))
        }

        listOf(
            "Color(0x3DFF3B30)",
            ".height(72.dp)",
            "Text(text = icon",
            "danger ->",
            "active ->"
        ).forEach { token ->
            assertFalse("legacy shared overlay should not own call control body: $token", legacySharedOverlay.contains(token))
            assertTrue("call controls should own call control token: $token", callControls.contains(token))
        }

        listOf(
            "SingleFlowMockCallOverlay(",
            "LazyColumn",
            "Brush.verticalGradient",
            "使用用户声音 · 正在执行代理任务",
            "通话转写",
            "sfFormatCallTime(",
            "SfCallControlButton("
        ).forEach { token ->
            assertTrue("mock call overlay should own mock call token: $token", mockCallOverlay.contains(token))
        }

        listOf(
            "Repository",
            "Container",
            "TaskRepository",
            "AudioTrack",
            "MediaPlayer",
            "Sip",
            "SIP",
            "AgentStream"
        ).forEach { token ->
            assertFalse("mock call overlay should not depend on runtime/data capability: $token", mockCallOverlay.contains(token))
            assertFalse("call controls should not depend on runtime/data capability: $token", callControls.contains(token))
        }
    }

    @Test
    fun singleFlowRealThreadRendersRestoredCallResultSteps() {
        val source = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/SingleFlowConversationContent.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(source.contains("step.callResult?.let"))
        assertTrue(source.contains("AgentCallResultCard(result = result)"))
    }

    @Test
    fun nativeScreenDelegatesLocalStateToStateHolder() {
        val screen = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/SingleFlowNativeDemoScreen.kt"
        ).readText(Charsets.UTF_8)
        val holder = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_singleflow/SingleFlowNativeStateHolder.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(screen.contains("rememberSingleFlowNativeStateHolder("))
        assertTrue(screen.contains("with(singleFlowState)"))
        assertTrue(screen.lines().size < 700)
        assertTrue(holder.lines().size <= 300)

        listOf(
            "internal class SingleFlowNativeStateHolder",
            "internal enum class SfPending",
            "val threadItems = mutableStateListOf<SfThreadItem>()",
            "val callTranscripts = mutableStateListOf<String>()",
            "var stage by mutableStateOf(1)",
            "var inputMode by mutableStateOf(SfInputMode.Text)",
            "var pending by mutableStateOf(SfPending.Task)",
            "fun resetForEntry(",
            "fun resetLocalDemoFlow(",
            "suspend fun aiReply(",
            "fun openCallUi(",
            "fun confirmSupplementContact("
        ).forEach { token ->
            assertTrue("state holder should own local state token: $token", holder.contains(token))
        }

        listOf(
            "val restaurants = remember { sfDefaultRestaurants() }",
            "val threadItems = remember { mutableStateListOf<SfThreadItem>() }",
            "val callTranscripts = remember { mutableStateListOf<String>() }",
            "var nextId by remember",
            "var stage by remember",
            "var inputMode by remember",
            "var pending by remember",
            "var callVisible by remember",
            "var showReceiptOverlay by remember",
            "mutableStateListOf",
            "fun newItemId(",
            "fun openCallUi(",
            "suspend fun aiReply(",
            "fun addCallTranscript(",
            "nextId = 1L"
        ).forEach { token ->
            assertFalse("native screen should not own state holder token: $token", screen.contains(token))
        }
    }

    @Test
    fun nativeScreenDelegatesRuntimeEffectsToEffectShell() {
        val screen = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/SingleFlowNativeDemoScreen.kt"
        ).readText(Charsets.UTF_8)
        val effects = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_singleflow/SingleFlowNativeEffects.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(screen.contains("SingleFlowNativeRuntimeEffects("))
        assertTrue(effects.lines().size <= 300)

        listOf(
            "assistantState?.voiceContactCapture?.eventId",
            "assistantState?.voiceUiCommand?.eventId",
            "voiceSummaryPromptSignature",
            "voiceDetailPromptTaskId",
            "handledVoiceUiCommandEventId",
            "handledVoiceContactEventId",
            "sfSummaryVoiceSignature(",
            "sfVoiceDetailPromptForScene(",
            "sfDetailIdsFromSummary(",
            "callSeconds += 1",
            "callTranscripts.size"
        ).forEach { token ->
            assertFalse("runtime effect bridge should stay in effect shell: $token", screen.contains(token))
            assertTrue("effect shell should own runtime effect bridge: $token", effects.contains(token))
        }
    }

    @Test
    fun nativeScreenDelegatesEntryEffectsToEntryShell() {
        val screen = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/SingleFlowNativeDemoScreen.kt"
        ).readText(Charsets.UTF_8)
        val entryEffects = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_singleflow/SingleFlowNativeEntryEffects.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(screen.contains("SingleFlowNativeEntryEffects("))
        assertTrue(screen.lines().size < 620)
        assertTrue(entryEffects.lines().size <= 180)

        listOf(
            "LaunchedEffect(args.entryKey)",
            "withFrameNanos",
            "VOICE_ENTRY_DEFER_STACK",
            "VOICE_ENTRY_START_STACK",
            "VOICE_ENTRY_WAIT_HISTORY",
            "VoiceEntryStackStartDelayMs",
            "pvWelcomePlayedThisProcess",
            "sfHasRealRestaurantFlowState("
        ).forEach { token ->
            assertFalse("entry effect should stay in entry shell: $token", screen.contains(token))
            assertTrue("entry shell should own entry effect token: $token", entryEffects.contains(token))
        }
    }

    @Test
    fun nativeScreenDelegatesMockFlowToController() {
        val screenFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/SingleFlowNativeDemoScreen.kt"
        )
        val screen = screenFile.readText(Charsets.UTF_8)
        val controllerFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_singleflow/SingleFlowNativeMockFlowController.kt"
        )
        val controller = controllerFile.readText(Charsets.UTF_8)

        assertTrue(screenFile.readLines(Charsets.UTF_8).size < 500)
        assertTrue(controllerFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue(screen.contains("SingleFlowNativeMockFlowController("))
        assertTrue(screen.contains("mockFlowController.runCallFlow()"))
        assertTrue(screen.contains("mockFlowController.advanceMockStep()"))

        listOf(
            "suspend fun runCallFlow(",
            "fun advanceMockStep(",
            "when (mockStep)",
            "AI：您好，我这边帮用户预订晚餐",
            "店员：您好，包间今晚已经满了",
            "执行结果：已预订大厅座 $"
        ).forEach { token ->
            assertFalse("mock flow token should stay out of native screen: $token", screen.contains(token))
            assertTrue("mock flow controller should own token: $token", controller.contains(token))
        }
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
