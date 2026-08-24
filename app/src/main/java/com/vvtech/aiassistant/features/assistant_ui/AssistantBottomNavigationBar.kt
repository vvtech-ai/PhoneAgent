package com.vvtech.aiassistant.features.assistant_ui

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant.FinalFadeDurationMs
import com.vvtech.aiassistant.features.assistant.FinalFadeEase
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalMotionDurationMs
import com.vvtech.aiassistant.features.assistant.FinalMotionEase
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage

@Composable
internal fun AssistantBottomNavigationBar(
    selected: FinalMainTab,
    onSelect: (FinalMainTab) -> Unit,
    onDialClick: () -> Unit,
    hidden: Boolean = false,
    taskBadgeCount: Int = 0,
    appLanguage: AppLanguage = AppLanguage.English
) {
    var navContainerHeightPx by remember { mutableStateOf(0) }
    val density = LocalDensity.current
    val navHiddenOffset = with(density) {
        if (navContainerHeightPx > 0) navContainerHeightPx.toDp() + 24.dp else 140.dp
    }
    val navOffsetY by animateDpAsState(
        targetValue = if (hidden) navHiddenOffset else 0.dp,
        animationSpec = tween(durationMillis = FinalMotionDurationMs, easing = FinalMotionEase)
    )
    val navAlpha by animateFloatAsState(
        targetValue = if (hidden) 0f else 1f,
        animationSpec = tween(durationMillis = FinalFadeDurationMs, easing = FinalFadeEase)
    )
    Box(
        modifier = Modifier
            .fillMaxSize()
            .navigationBarsPadding()
            .offset(y = navOffsetY)
            .alpha(navAlpha),
        contentAlignment = Alignment.BottomCenter
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .onSizeChanged { navContainerHeightPx = it.height }
                .padding(horizontal = 28.dp, vertical = 18.dp)
        ) {
            BottomNavigationSurface(
                selected = selected,
                onSelect = onSelect,
                taskBadgeCount = taskBadgeCount,
                appLanguage = appLanguage
            )
            CenterActionButton(
                centerDialMode = true,
                centerFabHopOffsetDp = 0f,
                centerFabHopScale = 1f,
                onClick = onDialClick
            )
        }
    }
}

@Composable
private fun BottomNavigationSurface(
    selected: FinalMainTab,
    onSelect: (FinalMainTab) -> Unit,
    taskBadgeCount: Int,
    appLanguage: AppLanguage
) {
    val items = listOf(
        BottomNavigationItemSpec(FinalMainTab.Home, R.drawable.ic_final_tab_home, tabLabel(appLanguage, "Home", "首页")),
        BottomNavigationItemSpec(FinalMainTab.Contacts, R.drawable.ic_final_tab_contacts, tabLabel(appLanguage, "Contacts", "联系人")),
        BottomNavigationItemSpec(FinalMainTab.Tasks, R.drawable.ic_final_tab_tasks, tabLabel(appLanguage, "Tasks", "任务"), taskBadgeCount),
        BottomNavigationItemSpec(FinalMainTab.Settings, R.drawable.ic_final_tab_settings, tabLabel(appLanguage, "Settings", "设置"))
    )
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height(74.dp)
            .shadow(
                elevation = 18.dp,
                shape = RoundedCornerShape(30.dp),
                ambientColor = Color(0x1A000000),
                spotColor = Color(0x1A000000)
            ),
        color = Color(0xADF8F8FA),
        shape = RoundedCornerShape(30.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.84f)),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 8.dp, end = 8.dp, top = 8.dp, bottom = 10.dp),
            verticalAlignment = Alignment.Bottom
        ) {
            items.forEachIndexed { index, item ->
                BottomNavigationItem(
                    modifier = Modifier.weight(1f),
                    iconResId = item.iconResId,
                    label = item.label,
                    active = selected == item.tab,
                    badgeCount = item.badgeCount,
                    onClick = { onSelect(item.tab) }
                )
                if (index == 1) {
                    Spacer(modifier = Modifier.width(72.dp))
                }
            }
        }
    }
}

private fun tabLabel(language: AppLanguage, english: String, chinese: String): String =
    if (language == AppLanguage.English) english else chinese

private data class BottomNavigationItemSpec(
    val tab: FinalMainTab,
    val iconResId: Int,
    val label: String,
    val badgeCount: Int = 0
)
