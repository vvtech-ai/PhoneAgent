package com.vvtech.aiassistant.features.assistant_pure_voice

import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.model.RealtimeCallProviderResponse

internal enum class PureVoicePrecheckItemState {
    Checking,
    Passed,
    Warning,
    Blocked
}

internal enum class PureVoicePrecheckDisplayStage {
    Network,
    Model,
    Outbound,
    Passed,
    Complete
}

internal data class PureVoicePrecheckItemUiState(
    val title: String,
    val value: String,
    val detail: String,
    val state: PureVoicePrecheckItemState
)

internal data class PureVoicePrecheckUiState(
    val visible: Boolean,
    val inline: Boolean,
    val blocking: Boolean,
    val title: String,
    val items: List<PureVoicePrecheckItemUiState>,
    val footer: String
)

internal fun PureVoicePrecheckUiState.asSequentialDisplay(
    stage: PureVoicePrecheckDisplayStage
): PureVoicePrecheckUiState {
    val network = items.getOrNull(0)
    val model = items.getOrNull(1)
    val outbound = items.getOrNull(2)
    val stagedItems = listOfNotNull(
        network?.asNetworkDisplay(stage),
        model?.asModelDisplay(stage),
        outbound?.asOutboundDisplay(stage)
    )
    return copy(
        visible = true,
        inline = false,
        items = stagedItems
    )
}

internal fun buildPureVoicePrecheckUiState(
    networkMode: V88NetworkMode,
    providerLoading: Boolean,
    providerError: String?,
    providerResponse: RealtimeCallProviderResponse?
): PureVoicePrecheckUiState {
    val modelItem = buildModelPrecheckItem(
        loading = providerLoading,
        error = providerError,
        response = providerResponse
    )
    val items = listOf(
        buildNetworkPrecheckItem(networkMode),
        modelItem,
        buildSipPrecheckItem(modelReady = modelItem.state == PureVoicePrecheckItemState.Passed)
    )
    val blocking = items.any { it.state == PureVoicePrecheckItemState.Blocked }
    val waitingForModel = providerLoading || (providerResponse == null && providerError.isNullOrBlank())
    return PureVoicePrecheckUiState(
        visible = blocking || waitingForModel,
        inline = false,
        blocking = blocking,
        title = currentAppText("正在初始化任务执行环境", "Initializing task environment"),
        items = items,
        footer = ""
    )
}

private fun buildNetworkPrecheckItem(networkMode: V88NetworkMode): PureVoicePrecheckItemUiState =
    when (networkMode) {
        V88NetworkMode.Offline -> PureVoicePrecheckItemUiState(
            title = currentAppText("网络连接", "Network Connection"),
            value = currentAppText("不可用", "Unavailable"),
            detail = currentAppText("网络不可用，请检查后重试", "Network unavailable. Check your connection and try again."),
            state = PureVoicePrecheckItemState.Blocked
        )

        V88NetworkMode.Weak -> PureVoicePrecheckItemUiState(
            title = currentAppText("网络连接", "Network Connection"),
            value = currentAppText("较弱", "Weak"),
            detail = currentAppText("网络较弱，仍可继续执行", "Weak network. You can continue."),
            state = PureVoicePrecheckItemState.Warning
        )

        V88NetworkMode.Normal -> PureVoicePrecheckItemUiState(
            title = currentAppText("网络连接", "Network Connection"),
            value = currentAppText("正常", "Normal"),
            detail = currentAppText("网络连接正常", "Network connected"),
            state = PureVoicePrecheckItemState.Passed
        )
    }

private fun buildModelPrecheckItem(
    loading: Boolean,
    error: String?,
    response: RealtimeCallProviderResponse?
): PureVoicePrecheckItemUiState {
    val cleanError = error?.trim().orEmpty()
    if (loading) {
        return PureVoicePrecheckItemUiState(
            title = currentAppText("大模型服务", "AI Model Service"),
            value = currentAppText("检测中", "Checking"),
            detail = currentAppText("正在连接大模型服务", "Connecting to AI model service"),
            state = PureVoicePrecheckItemState.Checking
        )
    }
    if (cleanError.isNotBlank()) {
        return PureVoicePrecheckItemUiState(
            title = currentAppText("大模型服务", "AI Model Service"),
            value = currentAppText("不可用", "Unavailable"),
            detail = cleanError,
            state = PureVoicePrecheckItemState.Blocked
        )
    }
    if (response == null) {
        return PureVoicePrecheckItemUiState(
            title = currentAppText("大模型服务", "AI Model Service"),
            value = currentAppText("等待检测", "Waiting to check"),
            detail = currentAppText("正在连接大模型服务", "Connecting to AI model service"),
            state = PureVoicePrecheckItemState.Warning
        )
    }

    val activeProvider = response.providers.firstOrNull { it.active }
        ?: response.providers.firstOrNull { it.provider == response.activeProvider }
    val displayName = response.activeProviderDisplayName.ifBlank {
        activeProvider?.displayName ?: response.activeProvider.ifBlank {
            currentAppText("实时语音模型", "Realtime Voice Model")
        }
    }
    if (activeProvider != null && (!activeProvider.configured || !activeProvider.available)) {
        return PureVoicePrecheckItemUiState(
            title = currentAppText("大模型服务", "AI Model Service"),
            value = currentAppText("不可用", "Unavailable"),
            detail = activeProvider.statusMessage.ifBlank {
                currentAppText("$displayName 未配置或不可用", "$displayName is not configured or unavailable")
            },
            state = PureVoicePrecheckItemState.Blocked
        )
    }
    return PureVoicePrecheckItemUiState(
        title = currentAppText("大模型服务", "AI Model Service"),
        value = displayName,
        detail = currentAppText("${displayName} 已就绪", "$displayName ready"),
        state = PureVoicePrecheckItemState.Passed
    )
}

private fun buildSipPrecheckItem(modelReady: Boolean): PureVoicePrecheckItemUiState =
    if (modelReady) {
        PureVoicePrecheckItemUiState(
            title = currentAppText("外呼通道", "Outbound Call Service"),
            value = currentAppText("等待检测", "Waiting to check"),
            detail = currentAppText("等待检测", "Waiting to check"),
            state = PureVoicePrecheckItemState.Warning
        )
    } else {
        PureVoicePrecheckItemUiState(
            title = currentAppText("外呼通道", "Outbound Call Service"),
            value = currentAppText("等待检测", "Waiting to check"),
            detail = currentAppText("等待检测", "Waiting to check"),
            state = PureVoicePrecheckItemState.Warning
        )
    }

private fun PureVoicePrecheckItemUiState.asNetworkDisplay(
    stage: PureVoicePrecheckDisplayStage
): PureVoicePrecheckItemUiState =
    when {
        state == PureVoicePrecheckItemState.Blocked -> this
        stage == PureVoicePrecheckDisplayStage.Network -> copy(
            value = currentAppText("检测中", "Checking"),
            detail = currentAppText("正在确认网络连接", "Checking network connection"),
            state = PureVoicePrecheckItemState.Checking
        )
        else -> this
    }

private fun PureVoicePrecheckItemUiState.asModelDisplay(
    stage: PureVoicePrecheckDisplayStage
): PureVoicePrecheckItemUiState =
    when {
        state == PureVoicePrecheckItemState.Blocked -> this
        stage == PureVoicePrecheckDisplayStage.Network -> copy(
            value = currentAppText("等待检测", "Waiting to check"),
            detail = currentAppText("等待检测", "Waiting to check"),
            state = PureVoicePrecheckItemState.Warning
        )
        stage == PureVoicePrecheckDisplayStage.Model -> copy(
            value = currentAppText("检测中", "Checking"),
            detail = currentAppText("正在连接大模型服务", "Connecting to AI model service"),
            state = PureVoicePrecheckItemState.Checking
        )
        else -> this
    }

private fun PureVoicePrecheckItemUiState.asOutboundDisplay(
    stage: PureVoicePrecheckDisplayStage
): PureVoicePrecheckItemUiState =
    when {
        stage == PureVoicePrecheckDisplayStage.Network ||
            stage == PureVoicePrecheckDisplayStage.Model -> copy(
                value = currentAppText("等待检测", "Waiting to check"),
                detail = currentAppText("等待检测", "Waiting to check"),
                state = PureVoicePrecheckItemState.Warning
            )
        stage == PureVoicePrecheckDisplayStage.Outbound -> copy(
            value = currentAppText("检测中", "Checking"),
            detail = currentAppText("正在检查外呼通道", "Checking outbound call service"),
            state = PureVoicePrecheckItemState.Checking
        )
        stage == PureVoicePrecheckDisplayStage.Passed ||
            stage == PureVoicePrecheckDisplayStage.Complete -> copy(
            value = currentAppText("已就绪", "Ready"),
            detail = currentAppText("外呼通道已就绪", "Outbound call service ready"),
            state = PureVoicePrecheckItemState.Passed
        )
        else -> this
    }
