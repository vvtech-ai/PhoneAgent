package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.data.repository.ContactDirectoryContainer
import com.vvtech.aiassistant.data.repository.ContactDirectoryRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal class AssistantContactAiModelRuntimeCallbacks(
    val onModeledContactCreated: () -> Unit
)

internal data class AssistantContactAiModelRuntimeDeps(
    val context: Context,
    val repository: ContactDirectoryRepository,
    val scope: CoroutineScope
)

internal class AssistantContactAiModelRuntimeState(
    val inFlight: MutableState<Boolean>
)

internal class AssistantContactAiModelRuntimeController(
    private val deps: AssistantContactAiModelRuntimeDeps,
    private val state: AssistantContactAiModelRuntimeState
) {
    var callbacks: AssistantContactAiModelRuntimeCallbacks = AssistantContactAiModelRuntimeCallbacks({})

    var inFlight by state.inFlight

    fun modelCallContact(callId: String) {
        val userId = AccountIdentityProvider.accountId
        if (userId.isBlank() || callId.isBlank()) {
            Toast.makeText(deps.context, "建模缺少账号或通话ID", Toast.LENGTH_SHORT).show()
            return
        }
        if (inFlight) return
        inFlight = true
        deps.scope.launch {
            runCatching {
                deps.repository.aiModelContact(userId, callId)
            }.onSuccess { entry ->
                inFlight = false
                callbacks.onModeledContactCreated()
                Toast.makeText(
                    deps.context,
                    "已建模：${entry.displayName ?: entry.phone}",
                    Toast.LENGTH_SHORT
                ).show()
            }.onFailure { throwable ->
                inFlight = false
                Toast.makeText(
                    deps.context,
                    "建模失败：${throwable.message ?: "请重试"}",
                    Toast.LENGTH_LONG
                ).show()
            }
        }
    }
}

@Composable
internal fun rememberAssistantContactAiModelRuntimeController(
    context: Context,
    scope: CoroutineScope,
    callbacks: AssistantContactAiModelRuntimeCallbacks
): AssistantContactAiModelRuntimeController {
    val repository = remember { ContactDirectoryContainer.repository }
    val state = AssistantContactAiModelRuntimeState(
        inFlight = rememberSaveable { mutableStateOf(false) }
    )
    val deps = remember(context, repository, scope) {
        AssistantContactAiModelRuntimeDeps(context, repository, scope)
    }
    val controller = remember(deps) {
        AssistantContactAiModelRuntimeController(deps, state)
    }
    controller.callbacks = callbacks
    return controller
}
