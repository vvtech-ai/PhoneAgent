package com.vvtech.aiassistant.features.assistant_contacts

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.FinalContactRecord

@Composable
internal fun AssistantContactsPage(
    records: List<FinalContactRecord>,
    onOpenDetail: (FinalContactRecord) -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        AssistantContactsTopBar()
        if (records.isEmpty()) {
            AssistantContactsEmptyState()
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 18.dp, end = 18.dp, bottom = 128.dp)
            ) {
                itemsIndexed(records) { index, record ->
                    AssistantContactPlainRow(
                        record = record,
                        showDivider = index != records.lastIndex,
                        onClick = { onOpenDetail(record) }
                    )
                }
            }
        }
    }
}

internal fun normalizeAssistantContactPhoneKey(raw: String): String {
    val digits = raw.filter(Char::isDigit)
    return when {
        digits.startsWith("0086") && digits.length > 11 -> digits.removePrefix("0086")
        digits.startsWith("86") && digits.length > 11 -> digits.removePrefix("86")
        else -> digits
    }
}
