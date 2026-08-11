package com.vvtech.aiassistant.features.assistant_home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.FinalQuickTaskCardV2
import com.vvtech.aiassistant.features.assistant_home.domain.HomeEntryAction

@Composable
internal fun AssistantHomeQuickTaskSection(
    cards: List<AssistantHomeCardUi>,
    onEntry: (AssistantHomeCardUi) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 2.dp, end = 2.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        cards.chunked(2).forEach { rowCards ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                rowCards.forEach { card ->
                    FinalQuickTaskCardV2(
                        modifier = Modifier
                            .weight(1f)
                            .height(126.dp),
                        badge = if (card.enabled) "可用" else card.statusLabel.orEmpty(),
                        title = card.title,
                        subtitle = card.subtitle,
                        imageUrl = card.imageUrl,
                        fallbackImageResId = assistantHomeCardImageRes(card.id),
                        enabled = card.enabled,
                        dotColor = assistantHomeCardStatusDotColor(card),
                        statusLabel = card.statusLabel,
                        onClick = { onEntry(card) }
                    )
                }
                if (rowCards.size == 1) Spacer(modifier = Modifier.weight(1f))
            }
        }
    }
}

internal fun assistantHomeCardStatusDotColor(card: AssistantHomeCardUi): Color? =
    if (card.action == HomeEntryAction.OpenTranslation) Color(0xFF6C5CE7) else null
