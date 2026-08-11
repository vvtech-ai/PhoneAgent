package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp

/**
 * Agent 选项 / 问询统一悬浮容器：
 * - 与 SelectionSheetOverlay 共享视觉模板（半透明背景 + BottomCenter Sheet）
 * - 真悬浮：覆盖 BottomTabBar，主界面不再受 sheet 高度影响
 * - 内容超过屏高 70% 时局部滚动；不引入 LazyColumn，避免与父容器约束冲突
 */
@Composable
internal fun AgentInteractiveOverlay(
    content: @Composable () -> Unit
) {
    val configuration = LocalConfiguration.current
    val maxSheetHeight = remember(configuration.screenHeightDp) {
        (configuration.screenHeightDp * 0.7f).dp
    }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0x38111827))
            .navigationBarsPadding(),
        contentAlignment = Alignment.BottomCenter
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .widthIn(max = 430.dp)
                .padding(start = 12.dp, end = 12.dp, bottom = 16.dp)
                .heightIn(max = maxSheetHeight)
                .verticalScroll(rememberScrollState())
        ) {
            content()
        }
    }
}
