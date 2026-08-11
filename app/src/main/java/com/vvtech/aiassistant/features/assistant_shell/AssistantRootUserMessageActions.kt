package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember

private const val AssistantRootSystemPhonePermissionDeniedMessage = "未授予电话权限，已中止本次通话"

internal class AssistantRootUserMessageActions(
    private val context: Context
) {
    fun showMessage(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    fun showSystemPhonePermissionDenied() {
        showMessage(AssistantRootSystemPhonePermissionDeniedMessage)
    }
}

@Composable
internal fun rememberAssistantRootUserMessageActions(
    context: Context
): AssistantRootUserMessageActions {
    val appContext = context.applicationContext
    return remember(appContext) {
        AssistantRootUserMessageActions(appContext)
    }
}
