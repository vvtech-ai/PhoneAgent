package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun AssistantDialContactSuggestionList(
    suggestions: List<DialContactSuggestion>,
    onSelect: (DialTargetSelection) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier.fillMaxWidth().testTag("route:dial-contact-search"),
        contentPadding = PaddingValues(bottom = 12.dp)
    ) {
        itemsIndexed(
            items = suggestions,
            key = { index, item ->
                "${item.contactId ?: item.displayName}:${item.phoneNumber}:$index"
            }
        ) { index, suggestion ->
            DialContactSuggestionRow(
                suggestion = suggestion,
                onSelect = onSelect,
                modifier = Modifier.testTag("interaction:dial-contact-suggestion:$index")
            )
        }
    }
}

@Composable
private fun DialContactSuggestionRow(
    suggestion: DialContactSuggestion,
    onSelect: (DialTargetSelection) -> Unit,
    modifier: Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable {
                onSelect(DialTargetSelection(suggestion.phoneNumber, suggestion.displayName))
            }
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(Color(0xFFE9E6FF), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = suggestion.displayName.firstOrNull()?.toString().orEmpty(),
                color = Color(0xFF6C55ED),
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold
            )
        }
        Column(Modifier.weight(1f).padding(start = 12.dp)) {
            Text(
                text = suggestion.displayName,
                color = Color(0xFF111318),
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Clip
            )
            Text(
                text = highlightedDialContactNumber(suggestion),
                modifier = Modifier.padding(top = 3.dp),
                color = Color(0xFF8E8E93),
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Clip
            )
        }
    }
}

private fun highlightedDialContactNumber(
    suggestion: DialContactSuggestion
) = buildAnnotatedString {
    val formatted = formatDialHistoryNumberForDisplay(suggestion.phoneNumber)
    append(formatted)
    if (suggestion.matchKind != DialContactMatchKind.NUMBER) return@buildAnnotatedString
    val range = formattedDigitHighlightRange(
        formattedNumber = formatted,
        rawDigitStart = suggestion.numberHitStart,
        rawDigitEndExclusive = suggestion.numberHitEndExclusive
    ) ?: return@buildAnnotatedString
    addStyle(
        style = SpanStyle(
            color = Color(0xFF1687F8),
            fontWeight = FontWeight.Bold
        ),
        start = range.first,
        end = range.last + 1
    )
}
