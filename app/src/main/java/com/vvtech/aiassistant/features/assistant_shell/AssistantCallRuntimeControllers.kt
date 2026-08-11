package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import com.vvtech.aiassistant.AIAssistantApplication
import com.vvtech.aiassistant.callengine.AndroidAssistantCallEngineGateway
import com.vvtech.aiassistant.callengine.AssistantClientCallController
import com.vvtech.aiassistant.data.translation.TranslationCallSettingsRepository
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationModelNetworkQualityPolicy
import com.vvtech.aiassistant.domain.translation.TranslationModelNetworkQualityState
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import com.vvtech.aiassistant.features.assistant.AssistantAuthRuntimeController
import com.vvtech.aiassistant.features.assistant_calls.callFailureUserMessage
import com.vvtech.aiassistant.features.translation_call.backend.BackendTranslationCallGateway
import com.vvtech.aiassistant.features.translation_call.data.LocalSipTranslationCallGateway
import com.vvtech.aiassistant.features.translation_call.data.RegionAwareTranslationCallGateway
import com.vvtech.aiassistant.features.translation_call.model.TranslationCallSettings
import com.vvtech.aiassistant.features.translation_call.model.TranslationCallSettingsPolicy
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallCoordinator
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallLauncher
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallUiAction
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallUiEffect
import com.vvtech.aiassistant.features.translation_call.state.TranslationModelNetworkQualityCoordinator
import com.vvtech.aiassistant.features.translation_call.ui.TranslationProviderUiCatalog
import kotlinx.coroutines.flow.collect

internal data class AssistantRealtimeTranslationRuntime(
    val coordinator: TranslationCallCoordinator,
    val launcher: TranslationCallLauncher,
    val region: TranslationRegionState,
    val settings: TranslationCallSettings,
    val modelQuality: TranslationModelNetworkQualityState,
    private val modelQualityCoordinator: TranslationModelNetworkQualityCoordinator,
    private val settingsRepository: TranslationCallSettingsRepository
) {
    val selectedProviderId: String
        get() = selectedProvider()?.let(TranslationProviderUiCatalog::providerId).orEmpty()
    val selectedProviderTitle: String
        get() = selectedProvider()?.let(TranslationProviderUiCatalog::displayName)
            ?: "位置待确认"
    val domesticProviderId: String
        get() = TranslationProviderUiCatalog.providerId(settings.domesticProvider)
    val availableProviderIds: Set<String>
        get() = TranslationModelNetworkQualityPolicy.availableProviders(region)
            .mapTo(linkedSetOf(), TranslationProviderUiCatalog::providerId)

    fun selectProvider(raw: String) {
        when (val current = region) {
            is TranslationRegionState.Resolved -> if (current.isChina) {
                settingsRepository.selectDomesticProvider(
                    TranslationCallSettingsPolicy.domesticProvider(raw)
                )
            } else {
                settingsRepository.selectOverseasProvider(
                    TranslationCallSettingsPolicy.overseasProvider(raw)
                )
            }
            else -> Unit
        }
    }

    fun selectDomesticProvider(raw: String) {
        settingsRepository.selectDomesticProvider(
            TranslationCallSettingsPolicy.domesticProvider(
                TranslationProviderUiCatalog.normalizeProviderId(raw)
            )
        )
    }

    fun refreshModelQuality() {
        modelQualityCoordinator.refresh()
    }

    private fun selectedProvider(): TranslationRealtimeProvider? =
        when (val current = region) {
            is TranslationRegionState.Resolved ->
                if (current.isChina) settings.domesticProvider else settings.overseasProvider
            else -> null
        }
}

internal data class AssistantCallRuntimeControllers(
    val clientCall: AssistantClientCallController,
    val realtimeTranslation: AssistantRealtimeTranslationRuntime
)

@Composable
internal fun rememberAssistantCallRuntimeControllers(
    context: Context,
    callRecordState: AssistantCallRecordState,
    authRuntime: AssistantAuthRuntimeController,
    navigationState: AssistantNavigationState,
    callDialState: AssistantCallDialState
): AssistantCallRuntimeControllers {
    val clientCall = remember(
        context,
        callRecordState,
        authRuntime,
        navigationState,
        callDialState
    ) {
        AssistantClientCallController(
            gateway = AndroidAssistantCallEngineGateway(context),
            onTerminal = { result ->
                callRecordState.appendIfAbsentForAccount(
                    authRuntime.activeAccountId,
                    buildAssistantClientCallRecord(result)
                )
                restoreDialAfterCall(navigationState, callDialState)
                if (!result.success && result.failureReason.isNotBlank()) {
                    Toast.makeText(
                        context,
                        callFailureUserMessage(result.failureKind),
                        Toast.LENGTH_LONG
                    ).show()
                }
            }
        )
    }
    val application = context.applicationContext as AIAssistantApplication
    val regionRepository = application.translationRegionRepository
    val settingsRepository = application.translationCallSettingsRepository
    val region by regionRepository.state.collectAsState()
    val settings by settingsRepository.state.collectAsState()
    val modelQualityCoordinator = remember {
        TranslationModelNetworkQualityCoordinator()
    }
    val coordinator = remember(context, modelQualityCoordinator) {
        TranslationCallCoordinator(
            RegionAwareTranslationCallGateway(
                localSip = LocalSipTranslationCallGateway(
                    context = context,
                    modelQualityProvider = { modelQualityCoordinator.state.value }
                ),
                backendWebRtc = BackendTranslationCallGateway(context)
            )
        )
    }
    val launcher = remember(coordinator, application) {
        TranslationCallLauncher(
            coordinator = coordinator,
            regionRepository = application.translationRegionRepository,
            settingsRepository = application.translationCallSettingsRepository
        )
    }
    val modelQuality by modelQualityCoordinator.state.collectAsState()
    LaunchedEffect(regionRepository) {
        regionRepository.refresh()
    }
    LaunchedEffect(modelQualityCoordinator, region, settings.serviceRegion) {
        modelQualityCoordinator.updateContext(region, settings.serviceRegion)
    }
    LaunchedEffect(coordinator) {
        coordinator.effects.collect { effect ->
            when (effect) {
                is TranslationCallUiEffect.ShowMessage ->
                    Toast.makeText(context, effect.message, Toast.LENGTH_LONG).show()
                is TranslationCallUiEffect.ShowFailure ->
                    Toast.makeText(
                        context,
                        callFailureUserMessage(effect.failureKind),
                        Toast.LENGTH_LONG
                    ).show()
                is TranslationCallUiEffect.Finished -> {
                    val finalState = coordinator.state.value
                    callRecordState.appendIfAbsentForAccount(
                        authRuntime.activeAccountId,
                        buildTranslationCallRecord(finalState, effect.success)
                    )
                    restoreDialAfterCall(navigationState, callDialState)
                    coordinator.dispatch(TranslationCallUiAction.DismissTerminal)
                }
            }
        }
    }
    DisposableEffect(clientCall, coordinator, modelQualityCoordinator) {
        onDispose {
            clientCall.release()
            coordinator.release()
            modelQualityCoordinator.release()
        }
    }
    return AssistantCallRuntimeControllers(
        clientCall = clientCall,
        realtimeTranslation = AssistantRealtimeTranslationRuntime(
            coordinator = coordinator,
            launcher = launcher,
            region = region,
            settings = settings,
            modelQuality = modelQuality,
            modelQualityCoordinator = modelQualityCoordinator,
            settingsRepository = settingsRepository
        )
    )
}

private fun restoreDialAfterCall(
    navigationState: AssistantNavigationState,
    callDialState: AssistantCallDialState
) {
    navigationState.restoreDialDestination(callDialState.returnDestination)
    callDialState.openDialSheet()
}
