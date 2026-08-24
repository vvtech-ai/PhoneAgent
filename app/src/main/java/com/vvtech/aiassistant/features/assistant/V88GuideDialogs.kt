package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Checkbox
import androidx.compose.material.CheckboxDefaults
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.rounded.Check
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
@Composable
internal fun V88PermissionDialog(
    kind: V88PermissionKind,
    onAllow: () -> Unit,
    onDeny: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0x99000000)),
        contentAlignment = Alignment.Center
    ) {
        Surface(
            modifier = Modifier.widthIn(max = 300.dp),
            color = Color(0xFF2A2A2A),
            shape = RoundedCornerShape(16.dp),
            elevation = 0.dp
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 22.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .background(Color(0xFF007AFF), RoundedCornerShape(12.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    Text("AI", color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.Black)
                }
                Text(
                    text = stringResource(R.string.permission_dialog_title, localizedPermissionTitle(kind)),
                    modifier = Modifier.padding(top = 16.dp),
                    color = Color.White,
                    fontSize = 17.sp,
                    lineHeight = 22.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
                Text(
                    text = localizedPermissionDescription(kind),
                    modifier = Modifier.padding(top = 8.dp),
                    color = Color.White.copy(alpha = 0.56f),
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    textAlign = TextAlign.Center
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 20.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    V88DarkDialogButton(stringResource(R.string.permission_deny), Modifier.weight(1f), onDeny)
                    V88DarkDialogButton(stringResource(R.string.permission_allow), Modifier.weight(1f), onAllow, primary = true)
                }
            }
        }
    }
}

@Composable
private fun V88DarkDialogButton(
    text: String,
    modifier: Modifier,
    onClick: () -> Unit,
    primary: Boolean = false
) {
    Surface(
        modifier = modifier.clickable(onClick = onClick),
        color = if (primary) Color(0xFF007AFF) else Color.White.copy(alpha = 0.10f),
        shape = RoundedCornerShape(10.dp),
        elevation = 0.dp
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(vertical = 11.dp),
            color = Color.White,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
internal fun V88VoiceCloneGuideSheet(
    visible: Boolean,
    onStart: () -> Unit,
    onDismiss: () -> Unit,
    onNeverAsk: () -> Unit
) {
    if (!visible) return
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0x73000000)),
        contentAlignment = Alignment.BottomCenter
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding(),
            color = Color.White,
            shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp),
            elevation = 0.dp
        ) {
            Box {
                Text(
                    text = "×",
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = 12.dp, end = 16.dp)
                        .size(32.dp)
                        .clickable(onClick = onDismiss),
                    color = Color(0xFF8B8FA3),
                    fontSize = 26.sp,
                    lineHeight = 30.sp,
                    textAlign = TextAlign.Center
                )
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 24.dp, end = 24.dp, top = 28.dp, bottom = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        imageVector = Icons.Outlined.Mic,
                        contentDescription = null,
                        tint = Color(0xFF0A84FF),
                        modifier = Modifier.size(48.dp)
                    )
                    Text(
                        text = stringResource(R.string.voice_clone_guide_title),
                        modifier = Modifier.padding(top = 16.dp),
                        color = Color(0xFF1A1A2E),
                        fontSize = 20.sp,
                        lineHeight = 24.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    )
                    Text(
                        text = stringResource(R.string.voice_clone_guide_description),
                        modifier = Modifier.padding(top = 8.dp),
                        color = Color(0xFF6B7280),
                        fontSize = 14.sp,
                        lineHeight = 22.sp,
                        textAlign = TextAlign.Center
                    )
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 20.dp)
                            .clickable(onClick = onStart),
                        color = Color(0xFF0A84FF),
                        shape = RoundedCornerShape(12.dp),
                        elevation = 0.dp
                    ) {
                        Text(
                            text = stringResource(R.string.voice_clone_guide_start),
                            modifier = Modifier.padding(vertical = 14.dp),
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            textAlign = TextAlign.Center
                        )
                    }
                    Text(
                        text = stringResource(R.string.guide_never_ask),
                        modifier = Modifier
                            .padding(top = 8.dp)
                            .clickable(onClick = onNeverAsk)
                            .padding(vertical = 10.dp),
                        color = Color(0xFF8B8FA3),
                        fontSize = 14.sp,
                        lineHeight = 18.sp,
                        textAlign = TextAlign.Center
                    )
                    Text(
                        text = stringResource(R.string.voice_clone_guide_later_hint),
                        modifier = Modifier.padding(top = 2.dp),
                        color = Color(0xFFB0B4C3),
                        fontSize = 12.sp,
                        lineHeight = 16.sp,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }
}

@Composable
internal fun V88TrustedCalleeGuideSheet(
    visible: Boolean,
    onAuthorize: () -> Unit,
    onDismiss: () -> Unit,
    onNeverAsk: () -> Unit
) {
    if (!visible) return
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0x73000000))
            .clickable(
                interactionSource = MutableInteractionSource(),
                indication = null,
                onClick = onDismiss
            ),
        contentAlignment = Alignment.BottomCenter
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(
                    interactionSource = MutableInteractionSource(),
                    indication = null
                ) {},
            color = Color.White,
            shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp),
            elevation = 0.dp
        ) {
            Box {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = 12.dp, end = 16.dp)
                        .size(32.dp)
                        .clickable(onClick = onDismiss),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "×",
                        color = Color(0xFF8B8FA3),
                        fontSize = 24.sp,
                        lineHeight = 24.sp,
                        textAlign = TextAlign.Center
                    )
                }
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 24.dp, end = 24.dp, top = 28.dp, bottom = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = stringResource(R.string.trusted_callee_title),
                        color = Color(0xFF1A1A2E),
                        fontSize = 20.sp,
                        lineHeight = 24.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    )
                    Image(
                        painter = painterResource(id = R.drawable.chakencalledicon),
                        contentDescription = stringResource(R.string.trusted_callee_title),
                        modifier = Modifier
                            .padding(top = 8.dp)
                            .size(117.dp)
                    )
                    Text(
                        text = stringResource(R.string.trusted_callee_description),
                        modifier = Modifier.padding(top = 14.dp),
                        color = Color(0xFF6B7280),
                        fontSize = 14.sp,
                        lineHeight = 22.sp,
                        textAlign = TextAlign.Center
                    )
                    V88TrustedCalleePrimaryButton(
                        label = stringResource(R.string.trusted_callee_authorize),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 20.dp),
                        onClick = onAuthorize
                    )
                    Text(
                        text = stringResource(R.string.guide_never_ask),
                        modifier = Modifier
                            .padding(top = 8.dp)
                            .clickable(onClick = onNeverAsk)
                            .padding(vertical = 10.dp),
                        color = Color(0xFF8B8FA3),
                        fontSize = 14.sp,
                        lineHeight = 18.sp,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }
}

@Composable
internal fun V88TrustedCalleeSecondDialog(
    visible: Boolean,
    onConfirm: () -> Unit
) {
    if (!visible) return
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0x2E0F0F12)),
        contentAlignment = Alignment.Center
    ) {
        Surface(
            modifier = Modifier
                .width(280.dp)
                .shadow(18.dp, RoundedCornerShape(22.dp)),
            color = Color.White.copy(alpha = 0.96f),
            shape = RoundedCornerShape(22.dp),
            elevation = 0.dp
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = stringResource(R.string.trusted_callee_later_message),
                    color = Color(0xFF111111),
                    fontSize = 14.sp,
                    lineHeight = 21.sp,
                    textAlign = TextAlign.Center
                )
                V88TrustedCalleePrimaryButton(
                    label = stringResource(R.string.ota_got_it),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 16.dp),
                    onClick = onConfirm
                )
            }
        }
    }
}

@Composable
private fun localizedPermissionTitle(kind: V88PermissionKind): String =
    when (kind) {
        V88PermissionKind.Microphone -> stringResource(R.string.permission_microphone_title)
        V88PermissionKind.Storage -> stringResource(R.string.permission_storage_title)
        V88PermissionKind.Contacts -> stringResource(R.string.permission_contacts_title)
        V88PermissionKind.Phone -> stringResource(R.string.permission_phone_title)
    }

@Composable
private fun localizedPermissionDescription(kind: V88PermissionKind): String =
    when (kind) {
        V88PermissionKind.Microphone -> stringResource(R.string.permission_microphone_description)
        V88PermissionKind.Storage -> stringResource(R.string.permission_storage_description)
        V88PermissionKind.Contacts -> stringResource(R.string.permission_contacts_description)
        V88PermissionKind.Phone -> stringResource(R.string.permission_phone_description)
    }

@Composable
private fun V88TrustedCalleePrimaryButton(
    label: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val shape = RoundedCornerShape(14.dp)
    Box(
        modifier = modifier
            .height(52.dp)
            .shadow(14.dp, shape)
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(Color(0xFF0A84FF), Color(0xFF0071EB))
                ),
                shape = shape
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            color = Color.White,
            fontSize = 16.sp,
            lineHeight = 22.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
    }
}
