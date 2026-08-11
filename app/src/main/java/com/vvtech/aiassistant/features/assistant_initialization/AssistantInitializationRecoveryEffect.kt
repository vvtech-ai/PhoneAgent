package com.vvtech.aiassistant.features.assistant_initialization

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal data class AssistantInitializationRecoveryCallbacks(
    val refreshIdentity: () -> Unit,
    val refreshCallProvider: () -> Unit,
    val refreshTranslationProvider: () -> Unit
)

private class AssistantInitializationRecoveryCoordinator(
    scope: CoroutineScope,
    private val snapshot: () -> AssistantInitializationSnapshot,
    private val callbacks: () -> AssistantInitializationRecoveryCallbacks
) {
    private val requests = Channel<String>(capacity = Channel.CONFLATED)
    private val worker: Job = scope.launch {
        for (trigger in requests) {
            delay(RecoveryDebounceMillis)
            val mergedTriggers = linkedSetOf(trigger)
            while (true) {
                val nextTrigger = requests.tryReceive().getOrNull() ?: break
                mergedTriggers += nextTrigger
            }
            val triggerValue = mergedTriggers.joinToString(separator = ",")
            val targets = assistantInitializationRecoveryTargets(snapshot())
            if (targets.isEmpty()) {
                AppFileLogger.i(
                    RecoveryLogTag,
                    "event=initialization_recovery trigger=$triggerValue result=skipped reason=no_pending_resource"
                )
                continue
            }
            AppFileLogger.i(
                RecoveryLogTag,
                "event=initialization_recovery trigger=$triggerValue result=started targets=${targets.logValue()}"
            )
            val actions = callbacks()
            targets.forEach { target ->
                when (target) {
                    AssistantInitializationResource.IDENTITY -> actions.refreshIdentity()
                    AssistantInitializationResource.CALL_PROVIDER -> actions.refreshCallProvider()
                    AssistantInitializationResource.TRANSLATION_PROVIDER ->
                        actions.refreshTranslationProvider()
                }
            }
        }
    }

    fun request(trigger: String) {
        requests.trySend(trigger)
    }

    fun close() {
        requests.close()
        worker.cancel()
    }
}

@Composable
internal fun AssistantInitializationRecoveryEffect(
    context: Context,
    lifecycleOwner: LifecycleOwner,
    enabled: Boolean,
    snapshot: AssistantInitializationSnapshot,
    callbacks: AssistantInitializationRecoveryCallbacks
) {
    val currentSnapshot = rememberUpdatedState(snapshot)
    val currentCallbacks = rememberUpdatedState(callbacks)
    val scope = rememberCoroutineScope()
    val coordinator = remember(scope, enabled) {
        AssistantInitializationRecoveryCoordinator(
            scope = scope,
            snapshot = { currentSnapshot.value },
            callbacks = { currentCallbacks.value }
        )
    }
    val appContext = context.applicationContext

    DisposableEffect(appContext, lifecycleOwner, enabled, coordinator) {
        if (!enabled) {
            onDispose { coordinator.close() }
        } else {
            val manager = appContext.getSystemService(Context.CONNECTIVITY_SERVICE)
                as? ConnectivityManager
            val networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    coordinator.request("network_available")
                }

                override fun onCapabilitiesChanged(
                    network: Network,
                    networkCapabilities: NetworkCapabilities
                ) {
                    if (networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) {
                        coordinator.request("network_validated")
                    }
                }
            }
            val lifecycleObserver = LifecycleEventObserver { _, event ->
                if (event == Lifecycle.Event.ON_RESUME) {
                    coordinator.request("app_resume")
                }
            }
            lifecycleOwner.lifecycle.addObserver(lifecycleObserver)
            val networkRegistered = runCatching {
                manager?.registerDefaultNetworkCallback(networkCallback)
                manager != null
            }.onFailure { throwable ->
                AppFileLogger.w(
                    RecoveryLogTag,
                    "event=initialization_recovery result=failed reason=network_callback_register",
                    throwable
                )
            }.getOrDefault(false)

            onDispose {
                lifecycleOwner.lifecycle.removeObserver(lifecycleObserver)
                if (networkRegistered) {
                    runCatching { manager?.unregisterNetworkCallback(networkCallback) }
                }
                coordinator.close()
            }
        }
    }
}

private fun Set<AssistantInitializationResource>.logValue(): String =
    joinToString(separator = ",") { it.name.lowercase() }

private const val RecoveryDebounceMillis = 300L
private const val RecoveryLogTag = "APP_INIT_RECOVERY"
