package com.vvtech.aiassistant.features.assistant_ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Divider
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant.CallMonitorAudioRoute
import com.vvtech.aiassistant.features.assistant.CallMonitorAudioRouteState
import com.vvtech.aiassistant.features.assistant.availableCallMonitorAudioRoutes
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

@Composable
internal fun AiCallAudioSourceSheet(
    routeState: CallMonitorAudioRouteState,
    onDismiss: () -> Unit,
    onRouteSelect: (CallMonitorAudioRoute) -> Unit
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.48f))
                    .clickable(onClick = onDismiss)
            )
            Surface(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .clickable(onClick = {}),
                color = Color(0xFFFAFAFC),
                shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
                elevation = 18.dp
            ) {
                Column(
                    modifier = Modifier
                        .navigationBarsPadding()
                        .padding(top = 12.dp, bottom = 16.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.CenterHorizontally)
                            .size(width = 38.dp, height = 4.dp)
                            .background(
                                color = Color(0xFFD5D7DC),
                                shape = RoundedCornerShape(999.dp)
                            )
                    )
                    Text(
                        text = "Choose Audio Source",
                        modifier = Modifier.padding(start = 22.dp, top = 20.dp),
                        color = Color(0xFF16181D),
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "Choose the playback device for AI agent call audio",
                        modifier = Modifier.padding(start = 22.dp, top = 6.dp, bottom = 12.dp),
                        color = Color(0xFF777B85),
                        fontSize = 13.sp
                    )
                    availableCallMonitorAudioRoutes(routeState.bluetoothAvailable)
                        .forEachIndexed { index, route ->
                            if (index > 0) {
                                Divider(
                                    modifier = Modifier.padding(horizontal = 22.dp),
                                    color = Color(0xFFE9EAF0)
                                )
                            }
                            AiCallAudioSourceRow(
                                route = route,
                                selected = routeState.selected == route,
                                onClick = {
                                    onRouteSelect(route)
                                    onDismiss()
                                }
                            )
                        }
                }
            }
        }
    }
}

@Composable
private fun AiCallAudioSourceRow(
    route: CallMonitorAudioRoute,
    selected: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 22.dp, vertical = 17.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Surface(
            modifier = Modifier.size(42.dp),
            shape = RoundedCornerShape(14.dp),
            color = if (selected) Color(0xFF2188F5) else Color(0xFFEAECF2),
            elevation = 0.dp
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    painter = painterResource(route.iconResource()),
                    contentDescription = null,
                    tint = if (selected) Color.White else Color(0xFF353A45),
                    modifier = Modifier.size(21.dp)
                )
            }
        }
        Text(
            text = route.displayLabel(),
            modifier = Modifier.weight(1f),
            color = Color(0xFF16181D),
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium
        )
        if (selected) {
            Icon(
                imageVector = Icons.Rounded.Check,
                contentDescription = "Selected",
                tint = Color(0xFF2188F5),
                modifier = Modifier.size(22.dp)
            )
        }
    }
}

internal fun CallMonitorAudioRoute.displayLabel(): String =
    when (this) {
        CallMonitorAudioRoute.Earpiece -> currentAppText("听筒", "Earpiece")
        CallMonitorAudioRoute.Speaker -> currentAppText("扬声器", "Speaker")
        CallMonitorAudioRoute.Bluetooth -> currentAppText("蓝牙", "Bluetooth")
    }

internal fun CallMonitorAudioRoute.iconResource(): Int =
    when (this) {
        CallMonitorAudioRoute.Earpiece -> R.drawable.ic_agent_call_earpiece
        CallMonitorAudioRoute.Speaker -> R.drawable.ic_agent_call_speaker
        CallMonitorAudioRoute.Bluetooth -> R.drawable.ic_agent_call_bluetooth
    }
