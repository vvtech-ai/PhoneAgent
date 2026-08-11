package com.vvtech.aiassistant.features.assistant_shell

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import com.vvtech.aiassistant.features.assistant_calls.normalizeDialTarget

internal data class AssistantSystemDialIntentSpec(
    val action: String,
    val uri: String
)

internal fun launchAssistantSystemDialer(
    context: Context,
    target: String,
    onShowMessage: (String) -> Unit
): Boolean {
    val spec = buildAssistantSystemDialIntentSpec(target) ?: return false
    val intent = Intent(spec.action, Uri.parse(spec.uri))
    if (context !is Activity) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    return runCatching {
        context.startActivity(intent)
    }.fold(
        onSuccess = { true },
        onFailure = { throwable ->
            onShowMessage(
                if (throwable is ActivityNotFoundException) {
                    "未找到可用的系统拨号应用"
                } else {
                    "无法打开系统拨号盘，请稍后重试"
                }
            )
            false
        }
    )
}

internal fun buildAssistantSystemDialIntentSpec(target: String): AssistantSystemDialIntentSpec? {
    val normalized = normalizeDialTarget(target)
    if (normalized.isBlank()) return null
    return AssistantSystemDialIntentSpec(
        action = Intent.ACTION_DIAL,
        uri = "tel:$normalized"
    )
}
