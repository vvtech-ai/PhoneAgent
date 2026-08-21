package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.domain.task.TaskReceiptOutcome

internal fun BatchCallItemResultPayload.display(): TaskReceiptOutcome {
    return TaskReceiptOutcome.fromRaw(status)
}

@Composable
internal fun BatchCallResultCard(
    result: BatchCallResultPayload,
    modifier: Modifier = Modifier
) {
    val expanded = remember(result) {
        mutableStateMapOf<String, Boolean>().apply {
            result.items.forEach { item -> put(item.itemId, item.display() != TaskReceiptOutcome.Success) }
        }
    }
    val displays = result.items.map { it.display() }
    val successCount = displays.count { it == TaskReceiptOutcome.Success }
    val failedCount = displays.count { it == TaskReceiptOutcome.Failed }
    val unclearCount = displays.count { it == TaskReceiptOutcome.Unclear }
    val cancelledCount = displays.count { it == TaskReceiptOutcome.Cancelled }
    val runningCount = displays.count { it == TaskReceiptOutcome.Running }
    val followupCount = failedCount + unclearCount + cancelledCount
    val allSuccess = successCount > 0 && followupCount == 0 && runningCount == 0
    val showCopyButton = successCount > 0 && failedCount == 0 && cancelledCount == 0
    val invitationReceiptTitle = stringResource(R.string.receipt_invitation_title)
    val successCountText = stringResource(R.string.receipt_success_count, successCount)
    val failedCountText = stringResource(R.string.receipt_failed_count, failedCount)
    val unclearCountText = stringResource(R.string.receipt_unclear_count, unclearCount)
    val cancelledCountText = stringResource(R.string.receipt_cancelled_count, cancelledCount)
    val runningCountText = stringResource(R.string.receipt_running_count, runningCount)
    val countSeparator = stringResource(R.string.receipt_count_separator)
    val headerColor = when {
        allSuccess -> Color(0xFF15803D)
        failedCount > 0 || cancelledCount > 0 -> Color(0xFFDC2626)
        unclearCount > 0 -> Color(0xFFD97706)
        runningCount > 0 -> Color(0xFF2563EB)
        else -> Color(0xFF101828)
    }
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        color = if (allSuccess) Color(0xFFF0FDF4) else Color(0xFFF8FAFC),
        border = BorderStroke(1.dp, if (allSuccess) Color(0xFFBBF7D0) else Color(0xFFE4ECF7)),
        elevation = 0.dp
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (successCount > 0 && followupCount == 0) invitationReceiptTitle else result.headline,
                        color = headerColor,
                        fontSize = 12.sp,
                        lineHeight = 15.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                    Text(
                        text = buildList {
                            if (successCount > 0) add(successCountText)
                            if (failedCount > 0) add(failedCountText)
                            if (unclearCount > 0) add(unclearCountText)
                            if (cancelledCount > 0) add(cancelledCountText)
                            if (runningCount > 0) add(runningCountText)
                        }.joinToString(countSeparator).ifBlank { result.headline },
                        modifier = Modifier.padding(top = 4.dp),
                        color = Color(0xFF101828),
                        fontSize = 16.sp,
                        lineHeight = 21.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
                Text(
                    text = "${successCount}/${result.items.size}",
                    color = headerColor,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold
                )
                if (showCopyButton) {
                    TaskReceiptCopyButton(
                        copyText = batchCallResultCopyText(result),
                        iconColor = headerColor,
                        modifier = Modifier.padding(start = 8.dp)
                    )
                }
            }
            result.items.forEach { item ->
                BatchCallItemRow(
                    item = item,
                    expanded = expanded[item.itemId] == true,
                    onToggle = { expanded[item.itemId] = expanded[item.itemId] != true }
                )
            }
        }
    }
}

@Composable
private fun BatchCallItemRow(
    item: BatchCallItemResultPayload,
    expanded: Boolean,
    onToggle: () -> Unit
) {
    val display = item.display()
    val isRunning = display == TaskReceiptOutcome.Running
    val isRecalling = item.status.equals("RECALLING", ignoreCase = true)
    val needsAttention = display == TaskReceiptOutcome.Failed ||
        display == TaskReceiptOutcome.Unclear ||
        display == TaskReceiptOutcome.Cancelled
    val dotColor = when (display) {
        TaskReceiptOutcome.Running -> Color(0xFF2563EB)
        TaskReceiptOutcome.Success -> Color(0xFF22C55E)
        TaskReceiptOutcome.Failed -> Color(0xFFEF4444)
        TaskReceiptOutcome.Unclear -> Color(0xFFF97316)
        TaskReceiptOutcome.Cancelled -> Color(0xFF9CA3AF)
    }
    val rowColor = when (display) {
        TaskReceiptOutcome.Running -> Color(0xFFEFF6FF)
        TaskReceiptOutcome.Success -> Color.White
        TaskReceiptOutcome.Failed -> Color(0xFFFEF2F2)
        TaskReceiptOutcome.Unclear -> Color(0xFFFFFBEB)
        TaskReceiptOutcome.Cancelled -> Color(0xFFF9FAFB)
    }
    val pillBackground = when (display) {
        TaskReceiptOutcome.Running -> Color(0xFFDBEAFE)
        TaskReceiptOutcome.Success -> Color(0xFFDCFCE7)
        TaskReceiptOutcome.Failed -> Color(0xFFFEE2E2)
        TaskReceiptOutcome.Unclear -> Color(0xFFFFEDD5)
        TaskReceiptOutcome.Cancelled -> Color(0xFFF3F4F6)
    }
    val pillText = when {
        isRunning && isRecalling -> stringResource(R.string.receipt_pill_recalling)
        isRunning -> stringResource(R.string.receipt_pill_calling)
        display == TaskReceiptOutcome.Success -> stringResource(R.string.receipt_pill_task_complete)
        display == TaskReceiptOutcome.Failed -> stringResource(R.string.receipt_pill_incomplete)
        display == TaskReceiptOutcome.Unclear -> stringResource(R.string.receipt_pill_needs_confirmation)
        display == TaskReceiptOutcome.Cancelled -> stringResource(R.string.receipt_pill_cancelled)
        else -> stringResource(R.string.receipt_pill_needs_confirmation)
    }
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onToggle() },
        shape = RoundedCornerShape(10.dp),
        color = rowColor,
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Spacer(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(dotColor)
                )
                Text(
                    text = item.targetName,
                    color = if (needsAttention) Color(0xFF92400E) else Color(0xFF101828),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .padding(start = 8.dp)
                        .weight(1f)
                )
                StatusPill(text = pillText, color = dotColor, background = pillBackground)
            }
            if (item.headline.isNotBlank() &&
                !item.headline.equals(pillText, ignoreCase = true)
            ) {
                Text(
                    text = item.headline,
                    color = Color(0xFF475467),
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 6.dp, start = 16.dp)
                )
            }
            if (item.recalled) {
                Text(
                    text = stringResource(R.string.receipt_auto_redial_once),
                    color = Color(0xFF7C3AED),
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }
            if (!expanded && !item.transcript.isNullOrBlank()) {
                Text(
                    text = stringResource(R.string.receipt_transcript_ready),
                    color = Color(0xFF667085),
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }
            if (expanded) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = item.detail,
                    color = Color(0xFF475467),
                    fontSize = 12.sp,
                    lineHeight = 17.sp
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = item.transcript?.takeIf { it.isNotBlank() } ?: stringResource(R.string.receipt_no_valid_transcript),
                    color = Color(0xFF344054),
                    fontSize = 12.sp,
                    lineHeight = 18.sp
                )
            }
        }
    }
}

@Composable
private fun StatusPill(
    text: String,
    color: Color,
    background: Color
) {
    Box(
        modifier = Modifier
            .widthIn(min = 46.dp)
            .clip(RoundedCornerShape(999.dp))
            .background(background)
            .border(1.dp, color.copy(alpha = 0.18f), RoundedCornerShape(999.dp))
            .padding(horizontal = 9.dp, vertical = 4.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            color = color,
            fontSize = 12.sp,
            lineHeight = 14.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
