package com.vvtech.aiassistant.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material.MaterialTheme
import androidx.compose.material.darkColors
import androidx.compose.material.lightColors
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val AppLightColors = lightColors(
    primary = Color(0xFF0A84FF),
    primaryVariant = Color(0xFF0666C9),
    secondary = Color(0xFF6B7280),
    background = Color(0xFFEEF1F5),
    surface = Color(0xFFFFFFFF),
    onPrimary = Color.White,
    onSecondary = Color.White,
    onBackground = Color(0xFF111111),
    onSurface = Color(0xFF111111)
)

private val AppDarkColors = darkColors(
    primary = Color(0xFF0A84FF),
    secondary = Color(0xFF6B7280),
    background = Color(0xFFEEF1F5),
    surface = Color(0xFFFFFFFF),
    onPrimary = Color.White,
    onSecondary = Color.White,
    onBackground = Color(0xFF111111),
    onSurface = Color(0xFF111111)
)

@Composable
fun AIAssistantTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colors = if (isSystemInDarkTheme()) AppDarkColors else AppLightColors,
        content = content
    )
}
