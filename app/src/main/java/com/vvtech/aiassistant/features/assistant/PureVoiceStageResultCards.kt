package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.util.Locale
@Composable
internal fun PureVoiceSelectionCard(sheet: SelectionSheetData, onSelect: ((SelectionSheetOption) -> Unit)?) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            modifier = Modifier.widthIn(max = 280.dp),
            shape = RoundedCornerShape(16.dp),
            color = Color.White,
            border = BorderStroke(1.dp, Color(0xFFE8EDF2)),
            elevation = 1.dp
        ) {
            Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
                Text(
                    text = sheet.title,
                    color = Color(0xFF111827),
                    fontSize = 14.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                sheet.subtitle.takeIf { it.isNotBlank() }?.let {
                    Text(
                        text = it,
                        modifier = Modifier.padding(top = 4.dp),
                        color = Color(0xFF667085),
                        fontSize = 12.sp,
                        lineHeight = 17.sp
                    )
                }
                Column(modifier = Modifier.padding(top = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    sheet.options.forEachIndexed { index, option ->
                        PureVoiceSelectionOptionRow(index = index, option = option, onSelect = onSelect)
                    }
                }
            }
        }
    }
}

@Composable
internal fun PureVoiceSelectionOptionRow(
    index: Int,
    option: SelectionSheetOption,
    onSelect: ((SelectionSheetOption) -> Unit)?
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = onSelect != null) { onSelect?.invoke(option) },
        shape = RoundedCornerShape(12.dp),
        color = Color(0xFFF8FBFF),
        border = BorderStroke(1.dp, Color(0xFFE4ECF7))
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 9.dp),
            verticalAlignment = Alignment.Top
        ) {
            Box(
                modifier = Modifier
                    .size(22.dp)
                    .clip(CircleShape)
                    .background(VoiceBlue),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "${index + 1}",
                    color = Color.White,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                )
            }
            Column(modifier = Modifier.padding(start = 10.dp).weight(1f)) {
                Text(
                    text = option.title,
                    color = Color(0xFF121A24),
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                val meta = listOf(option.phone, option.meta).filter { it.isNotBlank() }.joinToString(" · ")
                if (meta.isNotBlank()) {
                    Text(
                        text = meta,
                        modifier = Modifier.padding(top = 3.dp),
                        color = Color(0xFF657287),
                        fontSize = 11.sp,
                        lineHeight = 16.sp,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}

@Composable
internal fun PureVoiceDetailCard(supplement: DetailSupplementPageData) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            modifier = Modifier.widthIn(max = 270.dp),
            shape = RoundedCornerShape(12.dp),
            color = Color(0xFFFFF8E1),
            border = BorderStroke(1.dp, Color(0xFFFFE0B2))
        ) {
            Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
                Text(
                    text = supplement.title,
                    color = Color(0xFFE65100),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = supplement.intro,
                    modifier = Modifier.padding(top = 4.dp),
                    color = Color(0xFFE65100),
                    fontSize = 12.sp,
                    lineHeight = 18.sp
                )
                supplement.questions.take(3).forEach { question ->
                    Text(
                        text = "· ${question.prompt}",
                        modifier = Modifier.padding(top = 4.dp),
                        color = Color(0xFF9A5B00),
                        fontSize = 11.sp,
                        lineHeight = 16.sp
                    )
                }
            }
        }
    }
}

@Composable
internal fun PureVoiceCallConfirmSummaryCard(callSpec: CallSpecPayload) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            modifier = Modifier.widthIn(max = 280.dp),
            shape = RoundedCornerShape(16.dp),
            color = Color.Transparent,
            border = BorderStroke(1.dp, Color(0x3334C759))
        ) {
            Column(
                modifier = Modifier
                    .background(Brush.linearGradient(listOf(Color(0xFFEDFAF0), Color(0xFFD6F5DC))))
                    .padding(horizontal = 16.dp, vertical = 14.dp)
            ) {
                Text(
                    text = stringResource(R.string.confirm_title),
                    color = Color(0xFF2E7D32),
                    fontSize = 14.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                PureVoiceLocalizedSummaryRow(stringResource(R.string.pure_voice_summary_target), callSpec.targetName)
                PureVoiceLocalizedSummaryRow(stringResource(R.string.pure_voice_summary_phone), callSpec.phoneNumber)
                PureVoiceLocalizedSummaryRow(stringResource(R.string.pure_voice_summary_goal), callSpec.primaryGoal)
                visibleCallConfirmSummaryRows(callSpec.summaryLines).forEach { (label, value) ->
                    PureVoiceLocalizedSummaryRow(label, value)
                }
            }
        }
    }
}

@Composable
internal fun PureVoiceSummaryCard(
    summary: SummaryData,
    confirmLabel: String,
    onConfirmTask: (() -> Unit)?
) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            modifier = Modifier.widthIn(max = 280.dp),
            shape = RoundedCornerShape(16.dp),
            color = Color.Transparent,
            border = BorderStroke(1.dp, Color(0x3334C759))
        ) {
            Column(
                modifier = Modifier
                    .background(Brush.linearGradient(listOf(Color(0xFFEDFAF0), Color(0xFFD6F5DC))))
                    .padding(horizontal = 16.dp, vertical = 14.dp)
            ) {
                Text(
                    text = stringResource(R.string.confirm_title),
                    color = Color(0xFF2E7D32),
                    fontSize = 14.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                PureVoiceLocalizedSummaryRow(summary.taskLabel, summary.task)
                PureVoiceLocalizedSummaryRow(summary.targetLabel, summary.target)
                PureVoiceLocalizedSummaryRow(summary.timeLabel, summary.time)
                PureVoiceLocalizedSummaryRow(summary.extraLabel, summary.extra)
                summary.contactLabel?.let { PureVoiceLocalizedSummaryRow(it, summary.contactValue.orEmpty()) }
                summary.detailLabel?.let { PureVoiceLocalizedSummaryRow(it, summary.detailValue.orEmpty()) }
                if (onConfirmTask != null) {
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 10.dp)
                            .height(36.dp)
                            .clickable(onClick = onConfirmTask),
                        shape = RoundedCornerShape(18.dp),
                        color = VoiceBlue
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                text = confirmLabel,
                                color = Color.White,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PureVoiceLocalizedSummaryRow(label: String, value: String) {
    PureVoiceSummaryRow(
        label = pureVoiceSummaryDisplayLabel(label),
        value = pureVoiceSummaryDisplayValue(label, value)
    )
}

private fun pureVoiceSummaryDisplayLabel(label: String): String {
    val raw = label.trim()
    val key = raw.lowercase(Locale.US)
    return when (key) {
        "任务", "task", "tasktype" -> currentAppText("任务", "Task")
        "对象", "目标", "target", "targetname", "resolvedname", "requestedname" -> currentAppText("对象", "Target")
        "餐厅", "restaurant", "restaurantname" -> currentAppText("餐厅", "Restaurant")
        "酒店", "hotel", "hotelname" -> currentAppText("酒店", "Hotel")
        "电话", "联系电话", "手机号", "phone", "phonenumber", "contactphone" -> currentAppText("电话", "Phone")
        "联系人", "contact", "contactname" -> currentAppText("联系人", "Contact")
        "目的", "需求", "重点", "goal", "primarygoal", "purpose" -> currentAppText("重点", "Goal")
        "时间", "用餐时间", "到店时间", "reservationtime", "maindate" -> currentAppText("时间", "Time")
        "人数", "用餐人数", "partysize", "guestcount" -> currentAppText("人数", "Party Size")
        "包房", "包间", "包房情况", "privateroom", "needprivateroom" -> currentAppText("包房", "Private Room")
        "低消", "低消信息", "minimumspend" -> currentAppText("低消", "Minimum Spend")
        "短信", "sms", "smsconfirmation" -> currentAppText("短信", "SMS")
        else -> currentAppText(raw, sanitizeUserFacingNetworkText(raw, VoiceLanguage.English))
    }
}

private fun pureVoiceSummaryDisplayValue(label: String, value: String): String {
    val raw = value.trim()
    if (raw.isBlank()) return ""
    val key = label.trim().lowercase(Locale.US)
    val english = when {
        key in setOf("人数", "用餐人数", "partysize", "guestcount") ->
            Regex("""^(\d+)\s*(?:人|people)?$""", RegexOption.IGNORE_CASE)
                .matchEntire(raw)
                ?.let { "${it.groupValues[1]} people" }
                ?: sanitizeUserFacingNetworkText(raw, VoiceLanguage.English)
        key in setOf("包房", "包间", "包房情况", "privateroom", "needprivateroom") ->
            englishBooleanValue(raw) ?: sanitizeUserFacingNetworkText(raw, VoiceLanguage.English)
        raw.equals("true", ignoreCase = true) || raw.equals("false", ignoreCase = true) ->
            englishBooleanValue(raw).orEmpty()
        else -> sanitizeUserFacingNetworkText(raw, VoiceLanguage.English)
    }
    return currentAppText(raw, english)
}

private fun englishBooleanValue(raw: String): String? {
    return when (raw.trim().lowercase(Locale.US)) {
        "true", "yes", "有", "需要", "是" -> "Yes"
        "false", "no", "无", "不需要", "否" -> "No"
        else -> null
    }
}
