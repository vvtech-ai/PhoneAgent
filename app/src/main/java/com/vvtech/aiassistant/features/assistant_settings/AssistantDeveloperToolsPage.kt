package com.vvtech.aiassistant.features.assistant_settings

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant.DeveloperDataMode
import com.vvtech.aiassistant.features.assistant.FinalBackTitleBar
import com.vvtech.aiassistant.features.assistant.FinalDeveloperActionRow
import com.vvtech.aiassistant.features.assistant.FinalDeveloperModeButtonV3
import com.vvtech.aiassistant.features.assistant.FinalSettingCardV3
import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.features.assistant.outboundNumberSubtitle

internal data class AssistantDeveloperToolsPageArgs(
    val state: AssistantDeveloperToolsPageState,
    val callbacks: AssistantDeveloperToolsPageCallbacks
)

internal data class AssistantDeveloperToolsPageState(
    val mode: DeveloperDataMode,
    val outboundNumber: String,
    val outboundLoading: Boolean,
    val outboundConfigured: Boolean,
    val networkMode: V88NetworkMode = V88NetworkMode.Normal,
    val locationAvailable: Boolean = false,
    val locationDisplayText: String = ""
)

internal data class AssistantDeveloperToolsPageCallbacks(
    val onBack: () -> Unit,
    val onChangeMode: (DeveloperDataMode) -> Unit,
    val onOpenOutbound: () -> Unit,
    val onNetworkModeChange: (V88NetworkMode) -> Unit = {},
    val onResetPermissions: () -> Unit = {}
)

@Composable
internal fun AssistantDeveloperToolsPage(args: AssistantDeveloperToolsPageArgs) {
    val state = args.state
    val callbacks = args.callbacks
    val mode = state.mode
    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(title = stringResource(R.string.developer_title), onBack = callbacks.onBack)
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 16.dp)
        ) {
            item {
                Text(
                    text = stringResource(R.string.developer_list_data),
                    modifier = Modifier.padding(top = 16.dp, bottom = 10.dp, start = 4.dp),
                    color = Color(0xFF111111),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 10.dp),
                    color = Color.White.copy(alpha = 0.80f),
                    shape = RoundedCornerShape(24.dp),
                    border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
                    elevation = 0.dp
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 16.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.developer_real_data_status),
                            color = Color(0xFF111111),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = stringResource(R.string.developer_real_data_description),
                            modifier = Modifier.padding(top = 6.dp),
                            color = Color(0xFF6E6E73),
                            fontSize = 13.sp,
                            lineHeight = 18.sp
                        )
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 12.dp),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            FinalDeveloperModeButtonV3(
                                label = stringResource(R.string.developer_refetch),
                                selected = mode == DeveloperDataMode.Filled,
                                onClick = { callbacks.onChangeMode(DeveloperDataMode.Filled) },
                                modifier = Modifier.weight(1f)
                            )
                            FinalDeveloperModeButtonV3(
                                label = stringResource(R.string.developer_clear_list),
                                selected = mode == DeveloperDataMode.Empty,
                                onClick = { callbacks.onChangeMode(DeveloperDataMode.Empty) },
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                }
            }
            item {
                Text(
                    text = stringResource(R.string.developer_outbound_debug),
                    modifier = Modifier.padding(top = 14.dp, bottom = 10.dp, start = 4.dp),
                    color = Color(0xFF111111),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                FinalSettingCardV3(
                    title = stringResource(R.string.developer_fixed_outbound_number),
                    subtitle = outboundNumberSubtitle(
                        state.outboundNumber,
                        state.outboundLoading,
                        state.outboundConfigured
                    ),
                    value = stringResource(R.string.developer_edit),
                    onClick = callbacks.onOpenOutbound
                )
            }
            item {
                Text(
                    text = stringResource(R.string.developer_device_location),
                    modifier = Modifier.padding(top = 14.dp, bottom = 10.dp, start = 4.dp),
                    color = Color(0xFF111111),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                FinalSettingCardV3(
                    title = stringResource(R.string.developer_current_location),
                    subtitle = if (state.locationAvailable && state.locationDisplayText.isNotBlank()) {
                        state.locationDisplayText
                    } else {
                        stringResource(R.string.developer_location_unavailable)
                    },
                    value = if (state.locationAvailable) "✓" else "—"
                ) {}
            }
            item {
                Text(
                    text = stringResource(R.string.developer_mock_capabilities),
                    modifier = Modifier.padding(top = 14.dp, bottom = 10.dp, start = 4.dp),
                    color = Color(0xFF111111),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 10.dp),
                    color = Color.White.copy(alpha = 0.80f),
                    shape = RoundedCornerShape(24.dp),
                    border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
                    elevation = 0.dp
                ) {
                    Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp)) {
                        Text(
                            text = stringResource(R.string.developer_network_mock),
                            color = Color(0xFF111111),
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 10.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            V88NetworkMode.values().forEach { item ->
                                FinalDeveloperModeButtonV3(
                                    label = item.label,
                                    selected = state.networkMode == item,
                                    onClick = { callbacks.onNetworkModeChange(item) },
                                    modifier = Modifier.weight(1f)
                                )
                            }
                        }
                        FinalDeveloperActionRow(
                            title = stringResource(R.string.developer_reset_permissions),
                            subtitle = stringResource(R.string.developer_reset_permissions_description),
                            actionText = stringResource(R.string.developer_reset),
                            onClick = callbacks.onResetPermissions
                        )
                    }
                }
            }
        }
    }
}
