package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCloneEnrollmentReducerTest {

    @Test
    fun `consent must be accepted before identity entry`() {
        val refused = VoiceCloneEnrollmentReducer.reduce(
            VoiceCloneEnrollmentState(),
            VoiceCloneEnrollmentEvent.ContinueAfterConsent
        )
        assertEquals(VoiceCloneEnrollmentStep.CONSENT, refused.step)
        assertFalse(refused.busy)

        val accepted = VoiceCloneEnrollmentReducer.reduce(
            VoiceCloneEnrollmentState(agreementAccepted = true),
            VoiceCloneEnrollmentEvent.ContinueAfterConsent
        )
        assertEquals(VoiceCloneEnrollmentStep.IDENTITY, accepted.step)
    }

    @Test
    fun `sdk callback cannot mark verification passed`() {
        val initialized = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.VERIFYING,
            attemptId = "attempt-1",
            certifyId = "certify-1",
            scriptText = "今天3点，我去公园散步，顺便购买两本故事书籍。",
            busy = true
        )

        val afterSdk = VoiceCloneEnrollmentReducer.reduce(
            initialized,
            sdkFinished(1000, VoiceCloneSdkReasonCategory.SUCCESS)
        )

        assertEquals(VoiceCloneEnrollmentStep.VERIFYING, afterSdk.step)
        assertEquals("attempt-1", afterSdk.attemptId)
        assertEquals(
            "今天3点，我去公园散步，顺便购买两本故事书籍。",
            afterSdk.scriptText
        )
        assertTrue(afterSdk.busy)
        assertEquals(
            VoiceCloneVerificationPhase.RESULT_CHECKING,
            afterSdk.verificationPhase
        )
    }

    @Test
    fun `verification initialization keeps the server generated read aloud text`() {
        val initialized = VoiceCloneEnrollmentReducer.reduce(
            VoiceCloneEnrollmentState(
                step = VoiceCloneEnrollmentStep.IDENTITY,
                realName = "张三",
                idCardNumber = "11010519491231002X",
                busy = true
            ),
            VoiceCloneEnrollmentEvent.VerificationInitialized(
                attemptId = "attempt-1",
                certifyId = "certify-1",
                scriptText = "今晚7点，我准备整理房间，并把常用物品放回原位。",
                scriptVersion = "voice-clone-intent-v2",
                scriptTemplateId = "T01"
            )
        )

        assertEquals(VoiceCloneEnrollmentStep.VERIFYING, initialized.step)
        assertEquals(
            "今晚7点，我准备整理房间，并把常用物品放回原位。",
            initialized.scriptText
        )
        assertEquals("voice-clone-intent-v2", initialized.scriptVersion)
        assertEquals("T01", initialized.scriptTemplateId)

        val failed = VoiceCloneEnrollmentReducer.reduce(
            initialized,
            VoiceCloneEnrollmentEvent.ServerStatus("FAIL", "220")
        )
        assertNull(failed.scriptText)
        assertNull(failed.scriptVersion)
        assertNull(failed.scriptTemplateId)
    }

    @Test
    fun `mfvc sdk rejection code continues to authoritative server result`() {
        val verifying = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.VERIFYING,
            attemptId = "attempt-1",
            certifyId = "certify-1",
            busy = true
        )

        val afterSdk = VoiceCloneEnrollmentReducer.reduce(
            verifying,
            sdkFinished(2006, VoiceCloneSdkReasonCategory.VERIFICATION_REJECTED)
        )

        assertEquals(VoiceCloneEnrollmentStep.VERIFYING, afterSdk.step)
        assertEquals("attempt-1", afterSdk.attemptId)
        assertTrue(afterSdk.busy)
        assertEquals(
            VoiceCloneVerificationPhase.RESULT_CHECKING,
            afterSdk.verificationPhase
        )
        assertNull(afterSdk.errorMessage)
    }

    @Test
    fun `sdk result query policy includes provider rejection callback`() {
        assertTrue(VoiceCloneSdkResultPolicy.requiresServerQuery(1000))
        assertTrue(VoiceCloneSdkResultPolicy.requiresServerQuery(2006))
        assertFalse(VoiceCloneSdkResultPolicy.requiresServerQuery(1003))
        assertFalse(VoiceCloneSdkResultPolicy.requiresServerQuery(2002))
    }

    @Test
    fun `sdk system error is not reported as user cancellation`() {
        val verifying = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.VERIFYING,
            attemptId = "attempt-1",
            certifyId = "certify-1",
            busy = true
        )

        val failed = VoiceCloneEnrollmentReducer.reduce(
            verifying,
            sdkFinished(1001, VoiceCloneSdkReasonCategory.SDK_INTERNAL)
        )

        assertEquals(VoiceCloneEnrollmentStep.CONSENT, failed.step)
        assertNull(failed.attemptId)
        assertEquals(
            "认证组件运行异常，请重新开始；若连续出现，请检查摄像头和麦克风权限。",
            failed.errorMessage
        )
    }

    @Test
    fun `sdk interruption and network error have distinct messages`() {
        val verifying = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.VERIFYING,
            attemptId = "attempt-1",
            certifyId = "certify-1",
            busy = true
        )

        val interrupted = VoiceCloneEnrollmentReducer.reduce(
            verifying,
            sdkFinished(1003, VoiceCloneSdkReasonCategory.USER_CANCELLED)
        )
        val networkError = VoiceCloneEnrollmentReducer.reduce(
            verifying,
            sdkFinished(2002, VoiceCloneSdkReasonCategory.NETWORK_ACCESS)
        )

        assertEquals("认证已取消或中断，请重新开始。", interrupted.errorMessage)
        assertEquals(
            "网络连接异常，请检查网络后重新开始；若网络正常，请确认系统时间为自动设置。",
            networkError.errorMessage
        )
        assertFalse(networkError.busy)
        assertNull(networkError.attemptId)
        assertNull(networkError.certifyId)
    }

    @Test
    fun `verification cannot start again while the first request is busy`() {
        val ready = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.IDENTITY,
            agreementAccepted = true,
            realName = "张三",
            idCardNumber = "11010519491231002X"
        )
        assertTrue(ready.canStartVerification())

        val requested = VoiceCloneEnrollmentReducer.reduce(
            ready,
            VoiceCloneEnrollmentEvent.VerificationRequested
        )

        assertFalse(requested.canStartVerification())
    }

    @Test
    fun `fresh retry initializes a new attempt before starting sdk`() {
        val coordinator = sourceFile("VoiceCloneEnrollmentCoordinator.kt")
        val initializeIndex = coordinator.indexOf("repository.initialize(")
        val verifyIndex = coordinator.indexOf("sdk.verify(activity, initialized.certifyId)")

        assertTrue(initializeIndex >= 0)
        assertTrue(verifyIndex > initializeIndex)
        assertFalse(coordinator.contains("sdk.verify(activity, snapshot.certifyId)"))
    }

    @Test
    fun `different identity requires confirmation before provider initialization`() {
        val identity = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.IDENTITY,
            agreementAccepted = true,
            realName = "李四",
            idCardNumber = "11010519491231002X",
            busy = true
        )

        val confirmation = VoiceCloneEnrollmentReducer.reduce(
            identity,
            VoiceCloneEnrollmentEvent.ReplacementConfirmationRequired
        )
        assertTrue(confirmation.replacementConfirmationRequired)
        assertFalse(confirmation.replacementConfirmed)
        assertFalse(confirmation.busy)

        val confirmed = VoiceCloneEnrollmentReducer.reduce(
            confirmation,
            VoiceCloneEnrollmentEvent.ReplacementConfirmed
        )
        assertFalse(confirmed.replacementConfirmationRequired)
        assertTrue(confirmed.replacementConfirmed)
    }

    @Test
    fun `server pass starts clone directly without a second recording step`() {
        val verifying = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.VERIFYING,
            attemptId = "attempt-1",
            certifyId = "certify-1",
            busy = true
        )

        val pending = VoiceCloneEnrollmentReducer.reduce(
            verifying,
            VoiceCloneEnrollmentEvent.ServerStatus("PROCESSING")
        )
        assertEquals(VoiceCloneEnrollmentStep.VERIFYING, pending.step)

        val passed = VoiceCloneEnrollmentReducer.reduce(
            pending,
            VoiceCloneEnrollmentEvent.ServerStatus("PASS")
        )
        assertEquals(VoiceCloneEnrollmentStep.CLONING, passed.step)
        assertTrue(passed.busy)

        val ready = VoiceCloneEnrollmentReducer.reduce(
            passed,
            VoiceCloneEnrollmentEvent.CloneAccepted("READY")
        )
        assertEquals(VoiceCloneEnrollmentStep.VERIFIED, ready.step)
        assertFalse(ready.busy)
        assertEquals("attempt-1", passed.attemptId)
        assertNull(ready.collection)
    }

    @Test
    fun `clone submission failure returns to identity for a fresh attempt`() {
        val cloning = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.CLONING,
            realName = "张三",
            idCardNumber = "11010519491231002X",
            attemptId = "attempt-1",
            certifyId = "certify-1",
            busy = true
        )

        val failed = VoiceCloneEnrollmentReducer.reduce(
            cloning,
            VoiceCloneEnrollmentEvent.Failed("声音克隆失败，请重新开始。")
        )

        assertEquals(VoiceCloneEnrollmentStep.IDENTITY, failed.step)
        assertNull(failed.attemptId)
        assertFalse(failed.busy)
        assertEquals("声音克隆失败，请重新开始。", failed.errorMessage)
    }

    @Test
    fun `verification failure masks identity for retry while exit discards all progress`() {
        val verifying = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.VERIFYING,
            agreementAccepted = true,
            realName = "张三",
            idCardNumber = "11010519491231002X",
            attemptId = "attempt-1",
            certifyId = "certify-1",
            busy = true
        )

        val cancelled = VoiceCloneEnrollmentReducer.reduce(
            verifying,
            sdkFinished(1003, VoiceCloneSdkReasonCategory.USER_CANCELLED)
        )
        assertEquals(VoiceCloneEnrollmentStep.IDENTITY, cancelled.step)
        assertNull(cancelled.attemptId)
        assertNull(cancelled.certifyId)
        assertEquals("张三", cancelled.realName)
        assertEquals("11010519491231002X", cancelled.idCardNumber)
        assertEquals("张*", cancelled.displayRealName)
        assertEquals("110***********002X", cancelled.displayIdCardNumber)
        assertTrue(cancelled.realNameMasked)
        assertTrue(cancelled.idCardNumberMasked)
        assertTrue(cancelled.canStartVerification())

        val exited = VoiceCloneEnrollmentReducer.reduce(
            verifying,
            VoiceCloneEnrollmentEvent.Exit
        )
        assertEquals(VoiceCloneEnrollmentState(), exited)
    }

    @Test
    fun `mfvc intent failure explains that the reading was unclear`() {
        val verifying = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.VERIFYING,
            realName = "张三",
            idCardNumber = "11010519491231002X",
            attemptId = "attempt-1",
            certifyId = "certify-1",
            busy = true
        )

        val failed = VoiceCloneEnrollmentReducer.reduce(
            verifying,
            VoiceCloneEnrollmentEvent.ServerStatus("FAIL", "220")
        )

        assertEquals(VoiceCloneEnrollmentStep.IDENTITY, failed.step)
        assertEquals(
            "跟读内容未完整识别，请在安静环境中连续读完整句话后重新认证。",
            failed.errorMessage
        )
        assertNull(failed.attemptId)
    }

    @Test
    fun `mfvc liveness risk explains that a normal device environment is required`() {
        val verifying = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.VERIFYING,
            realName = "张三",
            idCardNumber = "11010519491231002X",
            attemptId = "attempt-1",
            certifyId = "certify-1",
            busy = true
        )

        val failed = VoiceCloneEnrollmentReducer.reduce(
            verifying,
            VoiceCloneEnrollmentEvent.ServerStatus("FAIL", "205")
        )

        assertEquals(VoiceCloneEnrollmentStep.IDENTITY, failed.step)
        assertEquals(
            "活体检测存在风险，请确认由本人在正常设备环境下重新认证。",
            failed.errorMessage
        )
        assertNull(failed.attemptId)
    }

    @Test
    fun `invalid identity keeps user on identity step`() {
        val identity = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.IDENTITY,
            agreementAccepted = true,
            realName = "张",
            idCardNumber = "123"
        )

        val rejected = VoiceCloneEnrollmentReducer.reduce(
            identity,
            VoiceCloneEnrollmentEvent.InputRejected("请输入正确的身份信息。")
        )

        assertEquals(VoiceCloneEnrollmentStep.IDENTITY, rejected.step)
        assertEquals("张", rejected.realName)
        assertEquals("123", rejected.idCardNumber)
        assertEquals("请输入正确的身份信息。", rejected.errorMessage)
    }

    @Test
    fun `editing a masked id card clears only its retained full value`() {
        val retry = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.IDENTITY,
            agreementAccepted = true,
            realName = "张三",
            idCardNumber = "11010519491231002X",
            realNameMasked = true,
            idCardNumberMasked = true
        )

        val editing = VoiceCloneEnrollmentReducer.reduce(
            retry,
            VoiceCloneEnrollmentEvent.IdentityEditStarted(VoiceCloneIdentityFieldKind.ID_CARD)
        )

        assertEquals("", editing.idCardNumber)
        assertFalse(editing.idCardNumberMasked)
        assertEquals("张三", editing.realName)
        assertTrue(editing.realNameMasked)
        assertEquals("张*", editing.displayRealName)
    }

    @Test
    fun `terminal verification failure stops polling while user edits masked identity`() {
        val verifying = VoiceCloneEnrollmentState(
            step = VoiceCloneEnrollmentStep.VERIFYING,
            agreementAccepted = true,
            realName = "张三",
            idCardNumber = "11010519491231002X",
            attemptId = "attempt-1",
            certifyId = "certify-1",
            busy = true
        )
        val failed = VoiceCloneEnrollmentReducer.reduce(
            verifying,
            VoiceCloneEnrollmentEvent.ServerStatus("FAIL", "201")
        )
        val editing = VoiceCloneEnrollmentReducer.reduce(
            failed,
            VoiceCloneEnrollmentEvent.IdentityEditStarted(VoiceCloneIdentityFieldKind.ID_CARD)
        )

        assertEquals(VoiceCloneEnrollmentStep.IDENTITY, editing.step)
        assertFalse(shouldContinueVoiceCloneStatusPolling(editing.step))
        assertTrue(
            sourceFile("VoiceCloneEnrollmentCoordinator.kt")
                .contains("if (!shouldContinueVoiceCloneStatusPolling(state.step))")
        )
    }

    private fun sourceFile(name: String): String = listOf(
        File("src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/$name"),
        File("android/app/src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/$name")
    ).first { it.exists() }.readText(Charsets.UTF_8)

    private fun sdkFinished(
        code: Int,
        category: VoiceCloneSdkReasonCategory
    ) = VoiceCloneEnrollmentEvent.SdkFinished(
        VoiceCloneSdkDiagnosis(code, null, category)
    )
}
