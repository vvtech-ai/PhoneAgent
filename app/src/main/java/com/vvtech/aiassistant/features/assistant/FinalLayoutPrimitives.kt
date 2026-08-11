package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun StandardPage(
    bottomPadding: Dp = 0.dp,
    scrollable: Boolean = false,
    content: @Composable ColumnScope.() -> Unit
) {
    PhoneWidthFrame(modifier = Modifier.fillMaxSize()) {
        val baseModifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .padding(start = 16.dp, end = 16.dp, top = 18.dp, bottom = bottomPadding)
        if (scrollable) {
            Column(
                modifier = baseModifier.verticalScroll(rememberScrollState()),
                content = content
            )
        } else {
            Column(
                modifier = baseModifier,
                content = content
            )
        }
    }
}

@Composable
internal fun BackNavigationBar(label: String, onBack: () -> Unit) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 18.dp)
    ) {
        Surface(
            modifier = Modifier
                .shadow(8.dp, RoundedCornerShape(14.dp), clip = false)
                .clickable(onClick = onBack),
            color = Color.White.copy(alpha = 0.82f),
            shape = RoundedCornerShape(14.dp),
            elevation = 0.dp
        ) {
            Text(
                text = label,
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                color = Color(0xFF223042),
                fontSize = 14.sp
            )
        }
    }
}

@Composable
internal fun PhoneWidthFrame(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit
) {
    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.TopCenter
    ) {
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .fillMaxWidth()
                .widthIn(max = 430.dp),
            content = content
        )
    }
}

internal object DesignTokens {
    val textPrimary = Color(0xFF111111)
    val textSecondary = Color(0xFF6B7280)
    val blue = Color(0xFF0A84FF)
    val blueDeep = Color(0xFF0666C9)
    val green = Color(0xFF18A957)
    val red = Color(0xFFE14D46)
    val orange = Color(0xFFF39A2D)
}
