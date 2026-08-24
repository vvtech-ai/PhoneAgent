package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.res.stringResource
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.app_ota.FinalOtaInstallUiState

internal data class FinalOtaUpdateDialogState(
    val hasUpdate: Boolean,
    val versionName: String,
    val versionCode: Long?,
    val releaseNotes: String,
    val forceUpdate: Boolean,
    val apkUrl: String,
    val downloadHeaders: Map<String, String> = emptyMap(),
    val fileSize: Long? = null,
    val checksumSha256: String = ""
)

@Composable
internal fun FinalOtaUpdateDialog(
    state: FinalOtaUpdateDialogState,
    installState: FinalOtaInstallUiState,
    onDismiss: () -> Unit,
    onPrimaryAction: (FinalOtaUpdateDialogState) -> Unit
) {
    val contentScrollState = rememberScrollState()

    Dialog(
        onDismissRequest = {
            if (!state.forceUpdate) {
                onDismiss()
            }
        },
        properties = DialogProperties(
            dismissOnBackPress = !state.forceUpdate,
            dismissOnClickOutside = !state.forceUpdate
        )
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 560.dp),
            color = Color.White,
            shape = RoundedCornerShape(24.dp),
            border = BorderStroke(1.dp, Color(0xFFE8EDF4)),
            elevation = 12.dp
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 18.dp, vertical = 18.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f, fill = false)
                        .verticalScroll(contentScrollState)
                ) {
                    Text(
                        text = when {
                            !state.hasUpdate -> stringResource(R.string.ota_latest_title)
                            state.forceUpdate -> stringResource(R.string.ota_force_update_title)
                            else -> stringResource(R.string.ota_update_title)
                        },
                        color = Color(0xFF111111),
                        fontSize = 19.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                    if (state.hasUpdate) {
                        Text(
                            text = stringResource(R.string.ota_new_version, state.versionName.ifBlank { "-" }),
                            modifier = Modifier.padding(top = 8.dp),
                            color = Color(0xFF344054),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    Text(
                        text = when {
                            !state.hasUpdate -> stringResource(R.string.ota_latest_detail)
                            state.releaseNotes.isNotBlank() -> state.releaseNotes
                            else -> stringResource(R.string.ota_default_release_notes)
                        },
                        modifier = Modifier.padding(top = 12.dp),
                        color = Color(0xFF6E6E73),
                        fontSize = 14.sp,
                        lineHeight = 20.sp
                    )
                    if (state.forceUpdate) {
                        Text(
                            text = stringResource(R.string.ota_force_update_detail),
                            modifier = Modifier.padding(top = 10.dp),
                            color = Color(0xFFE14D46),
                            fontSize = 13.sp,
                            lineHeight = 18.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    if (installState.message.isNotBlank()) {
                        Text(
                            text = installState.message,
                            modifier = Modifier.padding(top = 10.dp),
                            color = Color(0xFF344054),
                            fontSize = 13.sp,
                            lineHeight = 18.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    if (installState.error.isNotBlank()) {
                        Text(
                            text = installState.error,
                            modifier = Modifier.padding(top = 10.dp),
                            color = Color(0xFFE14D46),
                            fontSize = 13.sp,
                            lineHeight = 18.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 18.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    if (!state.forceUpdate) {
                        FinalActionButton(
                            label = if (state.hasUpdate) {
                                stringResource(R.string.ota_later)
                            } else {
                                stringResource(R.string.ota_got_it)
                            },
                            tone = FinalButtonTone.Secondary,
                            modifier = Modifier.weight(1f),
                            onClick = onDismiss
                        )
                    }
                    if (state.hasUpdate) {
                        FinalActionButton(
                            label = installState.primaryButtonLabel,
                            tone = FinalButtonTone.Primary,
                            modifier = Modifier.weight(1f),
                            enabled = installState.primaryButtonEnabled,
                            onClick = { onPrimaryAction(state) }
                        )
                    }
                }
            }
        }
    }
}
