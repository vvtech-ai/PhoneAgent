package com.vvtech.aiassistant.features.assistant_shell

import android.content.ActivityNotFoundException
import com.vvtech.aiassistant.features.assistant.FinalPage
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSystemPhoneCallActionsTest {
    @Test
    fun dialTargetPrefersDialInputThenLastDialedNumber() {
        assertEquals(
            "13800138000",
            assistantSystemPhoneDialTarget("138 0013 8000", "10086")
        )
        assertEquals(
            "10086",
            assistantSystemPhoneDialTarget("abc", "10086")
        )
        assertEquals(
            "+819012345678",
            assistantSystemPhoneDialTarget("+81 90-1234-5678", "")
        )
        assertEquals(
            "",
            assistantSystemPhoneDialTarget("", "")
        )
    }

    @Test
    fun contactTargetPrefersSelectedContactThenLastDialedNumber() {
        assertEquals(
            "01088886666",
            assistantSystemPhoneContactTarget("010-8888-6666", "10086")
        )
        assertEquals(
            "10086",
            assistantSystemPhoneContactTarget("", "10086")
        )
        assertEquals(
            "",
            assistantSystemPhoneContactTarget("abc", "")
        )
    }

    @Test
    fun returnPageKeepsSourceSemantics() {
        assertEquals(
            FinalPage.ContactDetail.name,
            assistantSystemPhoneReturnPageName(AssistantSystemPhoneCallSourceContact)
        )
        assertEquals(
            FinalPage.Calls.name,
            assistantSystemPhoneReturnPageName(AssistantSystemPhoneCallSourceDial)
        )
        assertEquals(
            FinalPage.Calls.name,
            assistantSystemPhoneReturnPageName("unknown")
        )
    }

    @Test
    fun failureMessagesKeepPreviousCopy() {
        assertEquals(
            "缺少电话权限，已中止本次通话",
            assistantSystemPhoneCallFailureMessage(SecurityException())
        )
        assertEquals(
            "未找到可用的系统电话应用",
            assistantSystemPhoneCallFailureMessage(ActivityNotFoundException())
        )
        assertEquals(
            "系统电话呼出失败",
            assistantSystemPhoneCallFailureMessage(RuntimeException())
        )
        assertEquals(
            "boom",
            assistantSystemPhoneCallFailureMessage(RuntimeException("boom"))
        )
    }

    @Test
    fun dialEntryUsesClientSipWhileLegacySystemPhoneSupportRemainsIsolated() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val action =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantSystemPhoneCallActions.kt")
                .readText(Charsets.UTF_8)
        val callbackFactory =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantSystemPhoneCallCallbackFactory.kt")
                .readText(Charsets.UTF_8)
        val rootSystemPhoneRuntime =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootSystemPhoneRuntime.kt")
                .readText(Charsets.UTF_8)
        val dialCoordinator =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootDialSystemPhoneCoordinator.kt"
            ).readText(Charsets.UTF_8)
        val rootCallEntryAction =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootCallEntryActions.kt")
                .readText(Charsets.UTF_8)
        val actionGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt")
                .readText(Charsets.UTF_8)

        assertTrue(root.contains("val callEntryActions = rootActionGraph.callEntry"))
        assertFalse(root.contains("AssistantRootCallEntryActions("))
        assertTrue(actionGraph.contains("AssistantRootCallEntryActions("))
        assertTrue(root.contains("rememberAssistantRootDialSystemPhoneCoordinator("))
        assertTrue(dialCoordinator.contains("rememberAssistantRootSystemPhoneRuntime("))
        assertTrue(dialCoordinator.contains("buildSystemPhoneCallRecord(plan)"))
        assertFalse(actionGraph.contains("systemPhoneCallbacksProvider ="))
        assertFalse(actionGraph.contains("onLaunchCallPhonePermission ="))
        assertTrue(actionGraph.contains("clientCallController = runtime.clientCall"))
        assertTrue(actionGraph.contains("onLaunchTranslationAudioPermission ="))
        assertFalse(root.contains("runAssistantSystemPhoneCallFromDial("))
        assertFalse(root.contains("runAssistantSystemPhoneCallFromContact("))
        assertFalse(root.contains("executeAssistantSystemPhoneCall("))
        assertFalse(root.contains("buildAssistantSystemPhoneCallCallbacks("))
        assertFalse(root.contains("AssistantSystemPhoneCallCallbackFactoryDeps("))
        assertFalse(root.contains("AssistantSystemPhonePermissionCallbacks("))
        assertTrue(rootSystemPhoneRuntime.contains("AssistantSystemPhoneCallCallbackFactoryDeps("))
        assertTrue(rootSystemPhoneRuntime.contains("buildAssistantSystemPhoneCallCallbacks("))
        assertTrue(rootSystemPhoneRuntime.contains("executeAssistantSystemPhoneCall("))
        assertTrue(rootSystemPhoneRuntime.contains("rememberAssistantSystemPhonePermissionLauncher("))
        assertTrue(rootSystemPhoneRuntime.contains("AssistantSystemPhonePermissionCallbacks("))
        assertTrue(action.contains("Intent(Intent.ACTION_CALL"))
        assertTrue(action.contains("ContextCompat.checkSelfPermission"))
        assertFalse(rootCallEntryAction.contains("runAssistantSystemPhoneCallFromDial("))
        assertFalse(rootCallEntryAction.contains("runAssistantSystemPhoneCallFromContact("))
        assertTrue(rootCallEntryAction.contains("startClientSipCall("))
        assertTrue(rootCallEntryAction.contains("AssistantCallRequest("))
        assertTrue(callbackFactory.contains("AssistantSystemPhoneCallActionCallbacks("))
        assertTrue(callbackFactory.contains("deps.clearTranslationRuntime()"))
        assertTrue(callbackFactory.contains("callDialState.normalCallSeconds = 0"))
        assertTrue(callbackFactory.contains("callDialState.normalCallMuted = false"))
        assertTrue(callbackFactory.contains("callDialState.normalCallSpeaker = true"))
        assertTrue(callbackFactory.contains("callDialState.normalCallReturnPage = plan.returnPageName"))
        assertFalse(callbackFactory.contains("callDialState.hideDialSheet()"))
        assertTrue(action.contains("callbacks.onSystemPhoneCallStarted(plan)"))
        assertTrue(callbackFactory.contains("onSystemPhoneCallStarted = deps.onSystemPhoneCallStarted"))
        assertTrue(callbackFactory.contains("systemPhoneCallState::setPending"))
        assertTrue(callbackFactory.contains("Toast.makeText"))

        assertFalse(root.contains("AssistantSystemPhoneCallActionCallbacks("))
        assertFalse(root.contains("onPrepareNormalCallAttempt = {"))
        assertFalse(root.contains("onPrepareSystemPhoneCallUi = { plan ->"))
        assertFalse(root.contains("callDialState.normalCallSeconds = 0"))
        assertFalse(root.contains("fun requestSystemPhoneCall("))
        assertFalse(root.contains("Intent(Intent.ACTION_CALL"))
        assertFalse(root.contains("Uri.fromParts(\"tel\""))
        assertFalse(root.contains("ActivityNotFoundException"))
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
