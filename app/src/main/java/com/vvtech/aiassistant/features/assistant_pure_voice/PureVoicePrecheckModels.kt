package com.vvtech.aiassistant.features.assistant_pure_voice

import com.vvtech.aiassistant.features.assistant.V88NetworkMode
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
        title = "正在初始化任务执行环境",
        items = items,
        footer = ""
    )
}

private fun buildNetworkPrecheckItem(networkMode: V88NetworkMode): PureVoicePrecheckItemUiState =
    when (networkMode) {
        V88NetworkMode.Offline -> PureVoicePrecheckItemUiState(
            title = "网络连接",
            value = "不可用",
            detail = "网络连接不可用",
            state = PureVoicePrecheckItemState.Blocked
        )

        V88NetworkMode.Weak -> PureVoicePrecheckItemUiState(
            title = "网络连接",
            value = "弱网",
            detail = "网络连接较弱",
            state = PureVoicePrecheckItemState.Warning
        )

        V88NetworkMode.Normal -> PureVoicePrecheckItemUiState(
            title = "网络连接",
            value = "正常",
            detail = "网络连接正常",
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
            title = "大模型服务",
            value = "检测中",
            detail = "正在连接大模型服务",
            state = PureVoicePrecheckItemState.Checking
        )
    }
    if (cleanError.isNotBlank()) {
        return PureVoicePrecheckItemUiState(
            title = "大模型服务",
            value = "不可用",
            detail = cleanError,
            state = PureVoicePrecheckItemState.Blocked
        )
    }
    if (response == null) {
        return PureVoicePrecheckItemUiState(
            title = "大模型服务",
            value = "待确认",
            detail = "正在连接大模型服务",
            state = PureVoicePrecheckItemState.Warning
        )
    }

    val activeProvider = response.providers.firstOrNull { it.active }
        ?: response.providers.firstOrNull { it.provider == response.activeProvider }
    val displayName = response.activeProviderDisplayName.ifBlank {
        activeProvider?.displayName ?: response.activeProvider.ifBlank { "实时语音模型" }
    }
    if (activeProvider != null && (!activeProvider.configured || !activeProvider.available)) {
        return PureVoicePrecheckItemUiState(
            title = "大模型服务",
            value = "不可用",
            detail = activeProvider.statusMessage.ifBlank { "$displayName 未配置或不可用" },
            state = PureVoicePrecheckItemState.Blocked
        )
    }
    return PureVoicePrecheckItemUiState(
        title = "大模型服务",
        value = displayName,
        detail = "$displayName 已就绪",
        state = PureVoicePrecheckItemState.Passed
    )
}

private fun buildSipPrecheckItem(modelReady: Boolean): PureVoicePrecheckItemUiState =
    if (modelReady) {
        PureVoicePrecheckItemUiState(
            title = "外呼通道",
            value = "执行前校验",
            detail = "执行通话前校验外呼通道",
            state = PureVoicePrecheckItemState.Warning
        )
    } else {
        PureVoicePrecheckItemUiState(
            title = "外呼通道",
            value = "等待检测",
            detail = "等待检测",
            state = PureVoicePrecheckItemState.Warning
        )
    }

private fun PureVoicePrecheckItemUiState.asNetworkDisplay(
    stage: PureVoicePrecheckDisplayStage
): PureVoicePrecheckItemUiState =
    when {
        state == PureVoicePrecheckItemState.Blocked -> this
        stage == PureVoicePrecheckDisplayStage.Network -> copy(
            value = "检测中",
            detail = "正在检查网络连接",
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
            value = "等待检测",
            detail = "等待检测",
            state = PureVoicePrecheckItemState.Warning
        )
        stage == PureVoicePrecheckDisplayStage.Model -> copy(
            value = "检测中",
            detail = "正在连接大模型服务",
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
                value = "等待检测",
                detail = "等待检测",
                state = PureVoicePrecheckItemState.Warning
            )
        stage == PureVoicePrecheckDisplayStage.Outbound -> copy(
            value = "检测中",
            detail = "正在检查外呼通道",
            state = PureVoicePrecheckItemState.Checking
        )
        stage == PureVoicePrecheckDisplayStage.Passed ||
            stage == PureVoicePrecheckDisplayStage.Complete -> copy(
            value = "已就绪",
            detail = "外呼通道已就绪",
            state = PureVoicePrecheckItemState.Passed
        )
        else -> this
    }
