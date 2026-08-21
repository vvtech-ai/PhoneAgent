package com.vvtech.aiassistant.features.assistant_shell

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_calls.normalizeDialTarget

internal const val AssistantSystemPhoneCallSourceDial = "dial"
internal const val AssistantSystemPhoneCallSourceContact = "contact_call"

internal data class AssistantSystemPhoneCallUiPlan(
    val normalizedNumber: String,
    val source: String,
    val returnPageName: String
)

internal class AssistantSystemPhoneCallActionCallbacks(
    val onPrepareNormalCallAttempt: () -> Unit,
    val onPrepareSystemPhoneCallUi: (AssistantSystemPhoneCallUiPlan) -> Unit,
    val onPhonePermissionGrantedChange: (Boolean) -> Unit,
    val onSetPendingCall: (String, String) -> Unit,
    val onLaunchCallPhonePermission: (String) -> Unit,
    val onShowMessage: (String) -> Unit,
    val onSystemPhoneCallStarted: (AssistantSystemPhoneCallUiPlan) -> Unit = {}
)

internal fun assistantSystemPhoneDialTarget(
    dialInput: String,
    lastDialedNumber: String
): String {
    val normalized = normalizeDialTarget(dialInput)
    return when {
        normalized.isNotBlank() -> normalized
        lastDialedNumber.isNotBlank() -> normalizeDialTarget(lastDialedNumber)
        else -> ""
    }
}

internal fun assistantSystemPhoneContactTarget(
    selectedContactPhone: String,
    lastDialedNumber: String
): String = normalizeDialTarget(selectedContactPhone).ifBlank {
    normalizeDialTarget(lastDialedNumber)
}

internal fun assistantSystemPhoneReturnPageName(source: String): String {
    return if (source == AssistantSystemPhoneCallSourceContact) {
        FinalPage.ContactDetail.name
    } else {
        FinalPage.Calls.name
    }
}

internal fun assistantSystemPhoneCallFailureMessage(throwable: Throwable): String {
    return when (throwable) {
        is SecurityException -> currentAppText(
            "缺少电话权限，已中止本次通话",
            "Phone permission is missing. This call was canceled."
        )
        is ActivityNotFoundException -> currentAppText(
            "未找到可用的系统电话应用",
            "No system phone app is available"
        )
        else -> throwable.message ?: currentAppText("系统电话呼出失败", "Failed to place system phone call")
    }
}

internal fun executeAssistantSystemPhoneCall(
    context: Context,
    target: String,
    source: String,
    callbacks: AssistantSystemPhoneCallActionCallbacks
): Boolean {
    val normalized = normalizeDialTarget(target)
    if (normalized.isBlank()) return false

    val plan = AssistantSystemPhoneCallUiPlan(
        normalizedNumber = normalized,
        source = source,
        returnPageName = assistantSystemPhoneReturnPageName(source)
    )
    callbacks.onPrepareSystemPhoneCallUi(plan)

    val intent = Intent(Intent.ACTION_CALL, Uri.fromParts("tel", normalized, null))
    if (context !is Activity) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    return runCatching {
        context.startActivity(intent)
    }.fold(
        onSuccess = {
            callbacks.onSystemPhoneCallStarted(plan)
            true
        },
        onFailure = { throwable ->
            if (throwable is SecurityException) {
                callbacks.onPhonePermissionGrantedChange(false)
            }
            callbacks.onShowMessage(assistantSystemPhoneCallFailureMessage(throwable))
            false
        }
    )
}

internal fun requestAssistantSystemPhoneCall(
    context: Context,
    target: String,
    source: String,
    callbacks: AssistantSystemPhoneCallActionCallbacks
): Boolean {
    val normalized = normalizeDialTarget(target)
    if (normalized.isBlank()) return false

    val granted = ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.CALL_PHONE
    ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    callbacks.onPhonePermissionGrantedChange(granted)
    return if (granted) {
        executeAssistantSystemPhoneCall(context, normalized, source, callbacks)
    } else {
        callbacks.onSetPendingCall(normalized, source)
        callbacks.onLaunchCallPhonePermission(Manifest.permission.CALL_PHONE)
        true
    }
}

internal fun runAssistantSystemPhoneCallFromDial(
    context: Context,
    dialInput: String,
    lastDialedNumber: String,
    callbacks: AssistantSystemPhoneCallActionCallbacks
): Boolean {
    val target = assistantSystemPhoneDialTarget(dialInput, lastDialedNumber)
    if (target.isBlank()) return false
    callbacks.onPrepareNormalCallAttempt()
    return requestAssistantSystemPhoneCall(
        context = context,
        target = target,
        source = AssistantSystemPhoneCallSourceDial,
        callbacks = callbacks
    )
}

internal fun runAssistantSystemPhoneCallFromContact(
    context: Context,
    selectedContactPhone: String,
    lastDialedNumber: String,
    callbacks: AssistantSystemPhoneCallActionCallbacks
): Boolean {
    val target = assistantSystemPhoneContactTarget(selectedContactPhone, lastDialedNumber)
    if (target.isBlank()) return false
    callbacks.onPrepareNormalCallAttempt()
    return requestAssistantSystemPhoneCall(
        context = context,
        target = target,
        source = AssistantSystemPhoneCallSourceContact,
        callbacks = callbacks
    )
}
