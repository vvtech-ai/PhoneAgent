package com.vvtech.aiassistant.features.assistant_initialization

internal enum class AssistantInitializationLoadState {
    UNKNOWN,
    LOADING,
    LOADED,
    FAILED
}

internal enum class AssistantInitializationResource {
    IDENTITY,
    CALL_PROVIDER,
    TRANSLATION_PROVIDER
}

internal data class AssistantInitializationSnapshot(
    val identity: AssistantInitializationLoadState,
    val callProvider: AssistantInitializationLoadState,
    val translationProvider: AssistantInitializationLoadState
)

internal fun shouldShowAssistantInitialization(
    loadState: AssistantInitializationLoadState,
    identityName: String?
): Boolean =
    loadState == AssistantInitializationLoadState.LOADED && identityName.isNullOrBlank()

internal fun assistantInitializationRecoveryTargets(
    snapshot: AssistantInitializationSnapshot
): Set<AssistantInitializationResource> = buildSet {
    if (snapshot.identity.needsRecovery()) {
        add(AssistantInitializationResource.IDENTITY)
    }
    if (snapshot.callProvider.needsRecovery()) {
        add(AssistantInitializationResource.CALL_PROVIDER)
    }
    if (snapshot.translationProvider.needsRecovery()) {
        add(AssistantInitializationResource.TRANSLATION_PROVIDER)
    }
}

internal fun assistantProviderLoadState(
    loading: Boolean,
    hasResponse: Boolean,
    error: String?
): AssistantInitializationLoadState = when {
    loading -> AssistantInitializationLoadState.LOADING
    !error.isNullOrBlank() -> AssistantInitializationLoadState.FAILED
    hasResponse -> AssistantInitializationLoadState.LOADED
    else -> AssistantInitializationLoadState.UNKNOWN
}

private fun AssistantInitializationLoadState.needsRecovery(): Boolean =
    this == AssistantInitializationLoadState.UNKNOWN ||
        this == AssistantInitializationLoadState.FAILED
