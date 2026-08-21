package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
@Composable
internal fun FinalConfirmPageV3(
    restaurantName: String,
    fallbackPlan: String,
    contactMethod: PersonalInfoEntry?,
    attachmentUploaded: Boolean,
    onBack: () -> Unit,
    onStop: () -> Unit,
    onOpenContactMethods: () -> Unit,
    onUploadAttachment: () -> Unit,
    onConfirm: () -> Unit
) {
    val defaultFallback = stringResource(R.string.confirm_default_fallback)
    val fallbackSummary = fallbackPlan.ifBlank { defaultFallback }
    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(
            title = stringResource(R.string.confirm_title),
            onBack = onBack,
            trailing = { FinalStopButton(onClick = onStop) }
        )
        Box(modifier = Modifier.fillMaxSize()) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 10.dp, end = 10.dp, bottom = 148.dp)
            ) {
                item {
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 10.dp),
                        color = Color.White.copy(alpha = 0.80f),
                        shape = RoundedCornerShape(24.dp),
                        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
                        elevation = 0.dp
                    ) {
                        Column(modifier = Modifier.padding(18.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.Top
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .size(7.dp)
                                                .background(Color(0xFF007AFF), CircleShape)
                                        )
                                        Text(
                                            text = stringResource(R.string.confirm_ready_to_call),
                                            color = Color(0xFF007AFF),
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.ExtraBold
                                        )
                                    }
                                    Text(
                                      text = stringResource(R.string.confirm_booking_summary, restaurantName),
                                        modifier = Modifier.padding(top = 8.dp),
                                        color = Color(0xFF111111),
                                        fontSize = 24.sp,
                                        lineHeight = 28.sp,
                                        fontWeight = FontWeight.ExtraBold
                                    )
                                }
                                Surface(
                                    color = Color(0x1F34C759),
                                    shape = RoundedCornerShape(16.dp),
                                    elevation = 0.dp
                                ) {
                                    Text(
                                          text = stringResource(R.string.confirm_executable),
                                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 9.dp),
                                        color = Color(0xFF34C759),
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.ExtraBold
                                    )
                                }
                            }

                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 14.dp),
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                FinalMetricCardV3(
                                    label = stringResource(R.string.confirm_target_label),
                                    value = restaurantName,
                                    modifier = Modifier.weight(1f)
                                )
                                FinalMetricCardV3(
                                    label = stringResource(R.string.confirm_contact_label),
                                    value = if (contactMethod != null) {
                                        "${contactMethod.name}${contactMethod.gender.displayLabel()} · ${maskPhone(contactMethod.phone)}"
                                    } else {
                                          stringResource(R.string.confirm_not_set)
                                    },
                                    modifier = Modifier.weight(1f)
                                )
                            }
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 10.dp),
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                FinalMetricCardV3(
                                    label = stringResource(R.string.confirm_call_voice_label),
                                    value = stringResource(R.string.confirm_agent_voice),
                                    modifier = Modifier.weight(1f)
                                )
                                FinalMetricCardV3(
                                    label = stringResource(R.string.confirm_notification_label),
                              value = stringResource(R.string.confirm_notification_value),
                                    modifier = Modifier.weight(1f)
                                )
                            }
                            if (contactMethod == null) {
                                FinalActionButton(
                              label = stringResource(R.string.confirm_add_contact),
                                    tone = FinalButtonTone.Secondary,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(top = 12.dp),
                                    onClick = onOpenContactMethods
                                )
                            }
                        }
                    }
                }
                item {
                    V88AttachmentSummaryCard(
                        uploaded = attachmentUploaded,
                        onUploadClick = onUploadAttachment
                    )
                }
                item {
                    FinalAssistantRoleBubbleV3(
                        modifier = Modifier.padding(top = 14.dp, bottom = 16.dp),
                        text = stringResource(R.string.confirm_role_text, fallbackSummary)
                    )
                }
            }
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp, vertical = 14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                FinalActionButton(
                    label = stringResource(R.string.confirm_start_call),
                    tone = FinalButtonTone.Success,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = onConfirm
                )
                FinalActionButton(
                    label = stringResource(R.string.confirm_back_edit),
                    tone = FinalButtonTone.Secondary,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = onBack
                )
            }
        }
    }
}
