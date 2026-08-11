package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.content.Intent
import android.widget.Toast
import com.vvtech.aiassistant.integration.incall.OptionalIncallSdkBridge
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.repository.TaskRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlin.math.max

internal class AssistantAuthRuntimeController(
    private val state: AssistantAuthRuntimeState,
    private val deps: AssistantAuthRuntimeDeps,
    callbacks: AssistantAuthRuntimeCallbacks
) {
    private var callbacks = callbacks

    var mockLoggedIn by state.mockLoggedIn
    var activeAccountId by state.activeAccountId
    var authActivationOpen by state.authActivationOpen
    var authPhoneDraft by state.authPhoneDraft
    var authCodeDraft by state.authCodeDraft
    var authSendingCode by state.authSendingCode
    var authLoggingIn by state.authLoggingIn
    var authCodeRetrySeconds by state.authCodeRetrySeconds
    var authCodeRetryPhone by state.authCodeRetryPhone
    var authActivationDraft by state.authActivationDraft
    var authLoginChallenge by state.authLoginChallenge
    var showLogoutConfirm by state.showLogoutConfirm
    var trustedCalleeAuthorized by state.trustedCalleeAuthorized
    var trustedCalleeGuideSeen by state.trustedCalleeGuideSeen
    var trustedCalleeGuideDisabled by state.trustedCalleeGuideDisabled
    var trustedCalleeSdkGuideSeen by state.trustedCalleeSdkGuideSeen
    var trustedCalleeGuideShownThisSession by state.trustedCalleeGuideShownThisSession
    var trustedCalleeStartupReady by state.trustedCalleeStartupReady
    var showTrustedCalleeGuide by state.showTrustedCalleeGuide
    var showTrustedCalleeSecondModal by state.showTrustedCalleeSecondModal

    fun updateCallbacks(callbacks: AssistantAuthRuntimeCallbacks) {
        this.callbacks = callbacks
    }

    fun onRetrySecondsChange(value: Int) {
        authCodeRetrySeconds = value
    }

    fun sendLoginCode() {
        val phone = normalizeLoginMainlandPhone(authPhoneDraft)
        if (phone.isBlank()) {
            Toast.makeText(deps.context, "请输入正确的手机号码", Toast.LENGTH_SHORT).show()
            return
        }
        if (authSendingCode || (authCodeRetrySeconds > 0 && authCodeRetryPhone == phone)) return
        deps.scope.launch {
            authSendingCode = true
            runCatching {
                deps.taskRepository.sendSmsLoginCode(phone)
            }.onSuccess { response ->
                authPhoneDraft = response.phone
                authCodeRetryPhone = response.phone
                authCodeRetrySeconds = max(1, response.resendCooldownSeconds)
                Toast.makeText(deps.context, "验证码已发送", Toast.LENGTH_SHORT).show()
            }.onFailure { throwable ->
                Toast.makeText(deps.context, throwable.message ?: "验证码发送失败", Toast.LENGTH_SHORT).show()
            }
            authSendingCode = false
        }
    }

    fun loginWithSmsCode() {
        val phone = normalizeLoginMainlandPhone(authPhoneDraft)
        val submission = buildSmsLoginSubmission(
            smsCode = authCodeDraft,
            activationOpen = authActivationOpen,
            activationCode = authActivationDraft,
            loginChallenge = authLoginChallenge
        )
        if (phone.isBlank()) {
            Toast.makeText(deps.context, "请输入正确的手机号码", Toast.LENGTH_SHORT).show()
            return
        }
        if (submission.loginChallenge == null &&
            !Regex("^\\d{4,8}$").matches(submission.smsCode)
        ) {
            Toast.makeText(deps.context, "请输入正确的验证码", Toast.LENGTH_SHORT).show()
            return
        }
        if (authActivationOpen && submission.activationCode.isNullOrBlank()) {
            Toast.makeText(deps.context, "请输入邀请码", Toast.LENGTH_SHORT).show()
            return
        }
        if (authLoggingIn) return
        deps.scope.launch {
            authLoggingIn = true
            runCatching {
                deps.taskRepository.loginWithSmsCode(
                    phone = phone,
                    code = submission.smsCode,
                    activationCode = submission.activationCode,
                    loginChallenge = submission.loginChallenge
                )
            }.onSuccess { response ->
                if (response.inviteRequired) {
                    val loginChallenge = response.loginChallenge.orEmpty()
                    authPhoneDraft = response.phone
                    authLoginChallenge = loginChallenge
                    if (loginChallenge.isNotBlank()) {
                        authCodeDraft = ""
                    }
                    authActivationOpen = true
                    Toast.makeText(deps.context, "请输入邀请码", Toast.LENGTH_SHORT).show()
                    authLoggingIn = false
                    return@onSuccess
                }
                AccountIdentityProvider.signIn(
                    deps.context,
                    response.phone,
                    response.accessToken,
                    response.refreshToken,
                    response.voiceCloneAccessToken
                )
                activeAccountId = AccountIdentityProvider.accountId
                callbacks.onResetSession("login_success")
                syncTrustedCalleeSimNumbersForLogin(deps.context, response.phone)
                authPhoneDraft = response.phone
                authCodeDraft = ""
                authActivationDraft = ""
                authLoginChallenge = ""
                authActivationOpen = false
                authCodeRetrySeconds = 0
                authCodeRetryPhone = ""
                mockLoggedIn = true
                Toast.makeText(deps.context, "登录成功", Toast.LENGTH_SHORT).show()
            }.onFailure { throwable ->
                Toast.makeText(deps.context, throwable.message ?: "登录失败", Toast.LENGTH_SHORT).show()
            }
            authLoggingIn = false
        }
    }

    fun openTrustedCalleeAuthorization() {
        showTrustedCalleeGuide = false
        showTrustedCalleeSecondModal = false
        trustedCalleeAuthorized = true
        syncTrustedCalleeSimNumbersForLogin(
            deps.context,
            AccountIdentityProvider.loggedInPhone.ifBlank { authPhoneDraft }
        )
        if (!trustedCalleeSdkGuideSeen) {
            trustedCalleeSdkGuideSeen = true
            deps.prefs.edit()
                .putBoolean(FinalTrustedCalleeAuthorizedKey, true)
                .putBoolean(FinalTrustedCalleeSdkGuideSeenKey, true)
                .apply()
            if (!OptionalIncallSdkBridge.openMainUi(deps.context)) {
                Toast.makeText(deps.context, "可信来电组件未安装", Toast.LENGTH_SHORT).show()
            }
            return
        }
        deps.prefs.edit().putBoolean(FinalTrustedCalleeAuthorizedKey, true).apply()
        if (!OptionalIncallSdkBridge.openSettings(deps.context)) {
            Toast.makeText(deps.context, "可信来电组件未安装", Toast.LENGTH_SHORT).show()
        }
    }

    fun onTrustedCalleeGuideShown() {
        trustedCalleeGuideShownThisSession = true
        trustedCalleeGuideSeen = true
        deps.prefs.edit().putBoolean(FinalTrustedCalleeGuideSeenKey, true).apply()
        showTrustedCalleeGuide = true
    }

    fun neverAskTrustedCalleeGuide() {
        showTrustedCalleeGuide = false
        trustedCalleeGuideSeen = true
        trustedCalleeGuideDisabled = true
        deps.prefs.edit()
            .putBoolean(FinalTrustedCalleeGuideSeenKey, true)
            .putBoolean(FinalTrustedCalleeGuideDisabledKey, true)
            .apply()
    }

    fun confirmLogout() {
        val authorization = AccountIdentityProvider.accessToken
            .takeIf { it.isNotBlank() }
            ?.let { "Bearer $it" }
            .orEmpty()
        callbacks.onResetSession("logout")
        AccountIdentityProvider.signOut(deps.context)
        activeAccountId = ""
        mockLoggedIn = false
        authActivationOpen = false
        authPhoneDraft = ""
        authCodeDraft = ""
        authActivationDraft = ""
        authLoginChallenge = ""
        authCodeRetrySeconds = 0
        authCodeRetryPhone = ""
        showLogoutConfirm = false
        if (authorization.isNotBlank()) {
            deps.scope.launch {
                runCatching { deps.taskRepository.logoutAppSession(authorization) }
            }
        }
    }

    fun clearSessionScopedUiFlags() {
        showTrustedCalleeGuide = false
        showTrustedCalleeSecondModal = false
        showLogoutConfirm = false
    }

    fun applyTrustedCalleeOverlayArgs(args: AssistantOverlayHostArgs) {
        args.showTrustedCalleeGuide = showTrustedCalleeGuide
        args.onAuthorizeTrustedCallee = ::openTrustedCalleeAuthorization
        args.onDismissTrustedCalleeGuide = {
            showTrustedCalleeGuide = false
            showTrustedCalleeSecondModal = true
        }
        args.onNeverAskTrustedCalleeGuide = ::neverAskTrustedCalleeGuide
        args.showTrustedCalleeSecondModal = showTrustedCalleeSecondModal
        args.onConfirmTrustedCalleeSecondModal = { showTrustedCalleeSecondModal = false }
    }

    fun applyLogoutOverlayArgs(args: AssistantOverlayHostArgs) {
        args.showLogoutConfirm = showLogoutConfirm
        args.onConfirmLogout = ::confirmLogout
        args.onCancelLogout = { showLogoutConfirm = false }
    }
}

internal class AssistantAuthRuntimeState(
    val mockLoggedIn: MutableState<Boolean>,
    val activeAccountId: MutableState<String>,
    val authActivationOpen: MutableState<Boolean>,
    val authPhoneDraft: MutableState<String>,
    val authCodeDraft: MutableState<String>,
    val authSendingCode: MutableState<Boolean>,
    val authLoggingIn: MutableState<Boolean>,
    val authCodeRetrySeconds: MutableState<Int>,
    val authCodeRetryPhone: MutableState<String>,
    val authActivationDraft: MutableState<String>,
    val authLoginChallenge: MutableState<String>,
    val showLogoutConfirm: MutableState<Boolean>,
    val trustedCalleeAuthorized: MutableState<Boolean>,
    val trustedCalleeGuideSeen: MutableState<Boolean>,
    val trustedCalleeGuideDisabled: MutableState<Boolean>,
    val trustedCalleeSdkGuideSeen: MutableState<Boolean>,
    val trustedCalleeGuideShownThisSession: MutableState<Boolean>,
    val trustedCalleeStartupReady: MutableState<Boolean>,
    val showTrustedCalleeGuide: MutableState<Boolean>,
    val showTrustedCalleeSecondModal: MutableState<Boolean>
)

internal data class AssistantAuthRuntimeDeps(
    val context: Context,
    val prefs: android.content.SharedPreferences,
    val taskRepository: TaskRepository,
    val scope: CoroutineScope
)

internal data class AssistantAuthRuntimeCallbacks(
    val onResetSession: (String) -> Unit
)

@Composable
internal fun rememberAssistantAuthRuntimeController(
    deps: AssistantAuthRuntimeDeps,
    callbacks: AssistantAuthRuntimeCallbacks
): AssistantAuthRuntimeController {
    val state = AssistantAuthRuntimeState(
        mockLoggedIn = rememberSaveable { mutableStateOf(AccountIdentityProvider.hasSignedInAccount) },
        activeAccountId = rememberSaveable { mutableStateOf(AccountIdentityProvider.accountId) },
        authActivationOpen = rememberSaveable { mutableStateOf(false) },
        authPhoneDraft = rememberSaveable { mutableStateOf(AccountIdentityProvider.loggedInPhone) },
        authCodeDraft = rememberSaveable { mutableStateOf("") },
        authSendingCode = rememberSaveable { mutableStateOf(false) },
        authLoggingIn = rememberSaveable { mutableStateOf(false) },
        authCodeRetrySeconds = rememberSaveable { mutableStateOf(0) },
        authCodeRetryPhone = rememberSaveable { mutableStateOf("") },
        authActivationDraft = rememberSaveable { mutableStateOf("") },
        authLoginChallenge = rememberSaveable { mutableStateOf("") },
        showLogoutConfirm = rememberSaveable { mutableStateOf(false) },
        trustedCalleeAuthorized = rememberSaveable {
            mutableStateOf(deps.prefs.getBoolean(FinalTrustedCalleeAuthorizedKey, false))
        },
        trustedCalleeGuideSeen = rememberSaveable {
            mutableStateOf(
                deps.prefs.getBoolean(FinalTrustedCalleeGuideSeenKey, false) ||
                    deps.prefs.getBoolean(FinalTrustedCalleeAuthorizedKey, false) ||
                    deps.prefs.getBoolean(FinalTrustedCalleeGuideDisabledKey, false)
            )
        },
        trustedCalleeGuideDisabled = rememberSaveable {
            mutableStateOf(deps.prefs.getBoolean(FinalTrustedCalleeGuideDisabledKey, false))
        },
        trustedCalleeSdkGuideSeen = rememberSaveable {
            mutableStateOf(
                deps.prefs.getBoolean(FinalTrustedCalleeSdkGuideSeenKey, false) ||
                    deps.prefs.getBoolean(FinalTrustedCalleeAuthorizedKey, false)
            )
        },
        trustedCalleeGuideShownThisSession = rememberSaveable { mutableStateOf(false) },
        trustedCalleeStartupReady = rememberSaveable { mutableStateOf(false) },
        showTrustedCalleeGuide = rememberSaveable { mutableStateOf(false) },
        showTrustedCalleeSecondModal = rememberSaveable { mutableStateOf(false) }
    )
    val controller = androidx.compose.runtime.remember(deps.context, deps.taskRepository, deps.scope) {
        AssistantAuthRuntimeController(state, deps, callbacks)
    }
    controller.updateCallbacks(callbacks)
    return controller
}

@Composable
internal fun FinalAuthGate(runtime: AssistantAuthRuntimeController): Boolean {
    if (runtime.mockLoggedIn) return false
    PhoneFrameWithBackground {
        if (runtime.authActivationOpen) {
            V88ActivationPage(
                activationCode = runtime.authActivationDraft,
                loggingIn = runtime.authLoggingIn,
                onActivationChange = { runtime.authActivationDraft = it },
                onConfirm = runtime::loginWithSmsCode,
                onBackLogin = { runtime.authActivationOpen = false }
            )
        } else {
            V88LoginPage(
                phone = runtime.authPhoneDraft,
                code = runtime.authCodeDraft,
                sendingCode = runtime.authSendingCode,
                loggingIn = runtime.authLoggingIn,
                retrySeconds = if (normalizeLoginMainlandPhone(runtime.authPhoneDraft) == runtime.authCodeRetryPhone) {
                    runtime.authCodeRetrySeconds
                } else {
                    0
                },
                onPhoneChange = { runtime.authPhoneDraft = sanitizeLoginPhoneInput(it, runtime.authPhoneDraft) },
                onCodeChange = { runtime.authCodeDraft = it },
                onSendCode = runtime::sendLoginCode,
                onLogin = runtime::loginWithSmsCode
            )
        }
    }
    return true
}

@Composable
internal fun FinalTrustedCalleeRuntimeEffect(
    currentPage: FinalPage,
    runtime: AssistantAuthRuntimeController
) {
    FinalTrustedCalleeGuideEffect(
        FinalTrustedCalleeGuideEffectArgs(
            runtime.mockLoggedIn,
            runtime.trustedCalleeStartupReady,
            currentPage,
            runtime.trustedCalleeAuthorized,
            runtime.trustedCalleeGuideSeen,
            runtime.trustedCalleeGuideDisabled,
            runtime.trustedCalleeGuideShownThisSession
        ) {
            runtime.onTrustedCalleeGuideShown()
        }
    )
}
