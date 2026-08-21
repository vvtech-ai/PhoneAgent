package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

@Composable
internal fun DialHistoryList(
    history: List<DialRecentCall>,
    onSelect: (DialTargetSelection) -> Unit,
    modifier: Modifier = Modifier
) {
    val listState = rememberLazyListState()
    LaunchedEffect(history.firstOrNull()?.id) {
        if (history.isNotEmpty()) listState.scrollToItem(0)
    }
    LazyColumn(
        state = listState,
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(bottom = 12.dp)
    ) {
        if (history.isEmpty()) {
            item {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 28.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = stringResource(R.string.dial_history_empty),
                        color = Color(0xFF8E8E93),
                        fontSize = 14.sp,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
        items(history, key = { "${it.source}:${it.id}" }) { record ->
            DialRecentCallRow(record, onSelect)
        }
    }
}

@Composable
private fun DialRecentCallRow(record: DialRecentCall, onSelect: (DialTargetSelection) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable {
                if (dialRecentCallClickAction(record) == DialRecentCallClickAction.FILL_INPUT) {
                    onSelect(
                        DialTargetSelection(
                            phoneNumber = record.phoneNumber,
                            displayName = record.displayName,
                            callKind = record.kind,
                            countryIso = record.countryIso,
                            callerLanguageCode = record.callerLanguageCode,
                            calleeLanguageCode = record.calleeLanguageCode
                        )
                    )
                }
            }
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = dialHistoryDisplayTitle(record),
                    modifier = Modifier.weight(1f, fill = false),
                    color = Color(0xFF111318),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Clip
                )
                dialHistoryTypeLabel(record.kind)?.let { DialHistoryTypeTag(it) }
            }
            DialHistoryNumberAndTimeRow(record)
        }
    }
}

@Composable
private fun DialHistoryNumberAndTimeRow(record: DialRecentCall) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(top = 3.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = formatDialHistoryNumberForDisplay(record.phoneNumber),
            modifier = Modifier.weight(1f),
            color = Color(0xFF8E8E93),
            fontSize = 12.sp,
            maxLines = 1,
            overflow = TextOverflow.Clip
        )
        Text(
            text = recentCallTime(record.startedAtMillis),
            modifier = Modifier.padding(start = 8.dp),
            color = Color(0xFF94A3B8),
            fontSize = 11.sp,
            maxLines = 1
        )
    }
}

@Composable
private fun DialHistoryTypeTag(label: String) {
    Surface(
        modifier = Modifier.padding(start = 7.dp),
        color = Color(0x146C55ED),
        shape = RoundedCornerShape(50),
        elevation = 0.dp
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 7.dp, vertical = 2.dp),
            color = Color(0xFF6C55ED),
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1
        )
    }
}

private fun dialHistoryDisplayTitle(record: DialRecentCall): String =
    record.displayName
        .removePrefix("翻译通话 ")
        .removePrefix("实时翻译 ")
        .removePrefix("普通通话 ")
        .ifBlank { record.phoneNumber }

@Composable
private fun recentCallTime(timeMillis: Long): String {
    if (timeMillis <= 0) return ""
    val now = Calendar.getInstance()
    val target = Calendar.getInstance().apply { this.timeInMillis = timeMillis }
    return when {
        sameDay(now, target) -> SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(timeMillis))
        now.get(Calendar.YEAR) == target.get(Calendar.YEAR) &&
            now.get(Calendar.DAY_OF_YEAR) - target.get(Calendar.DAY_OF_YEAR) == 1 ->
            stringResource(R.string.dial_history_yesterday)
        else -> SimpleDateFormat("M/d", Locale.getDefault()).format(Date(timeMillis))
    }
}

private fun sameDay(left: Calendar, right: Calendar): Boolean =
    left.get(Calendar.YEAR) == right.get(Calendar.YEAR) &&
        left.get(Calendar.DAY_OF_YEAR) == right.get(Calendar.DAY_OF_YEAR)
