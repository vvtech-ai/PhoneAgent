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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant.FinalQuickTaskCardV2
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguageManager
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
        val cardHeight = if (AppLanguageManager.currentAppLanguage() == AppLanguage.English) {
            144.dp
        } else {
            126.dp
        }
        cards.chunked(2).forEach { rowCards ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                rowCards.forEach { card ->
                    FinalQuickTaskCardV2(
                        modifier = Modifier
                            .weight(1f)
                            .height(cardHeight),
                        badge = if (card.enabled) {
                            stringResource(R.string.home_status_available)
                        } else {
                            localizedHomeCardStatus(card.statusLabel)
                        },
                        title = localizedHomeCardTitle(card),
                        subtitle = localizedHomeCardSubtitle(card),
                        imageUrl = card.imageUrl,
                        fallbackImageResId = assistantHomeCardImageRes(card.id),
                        enabled = card.enabled,
                        dotColor = assistantHomeCardStatusDotColor(card),
                        statusLabel = card.statusLabel,
                        minHeight = cardHeight,
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

@Composable
private fun localizedHomeCardStatus(raw: String?): String =
    when (raw?.trim()) {
        "请升级客户端", "Please upgrade" -> stringResource(R.string.home_status_upgrade_required)
        "即将提供", "Coming Soon" -> stringResource(R.string.home_status_coming_soon)
        else -> raw.orEmpty()
    }

@Composable
private fun localizedHomeCardTitle(card: AssistantHomeCardUi): String =
    when (card.id) {
        "restaurant_booking" -> stringResource(R.string.home_card_restaurant_title)
        "meeting_invite" -> stringResource(R.string.home_card_meeting_title)
        "simultaneous_interpretation" -> stringResource(R.string.home_card_translation_title)
        "apology" -> stringResource(R.string.home_card_apology_title)
        "event_invite" -> stringResource(R.string.home_card_event_title)
        "move_car" -> stringResource(R.string.home_card_move_car_title)
        "sales_promotion" -> stringResource(R.string.home_card_sales_title)
        else -> card.title
    }

@Composable
private fun localizedHomeCardSubtitle(card: AssistantHomeCardUi): String =
    when (card.id) {
        "restaurant_booking" -> stringResource(R.string.home_card_restaurant_subtitle)
        "meeting_invite" -> stringResource(R.string.home_card_meeting_subtitle)
        "simultaneous_interpretation" -> stringResource(R.string.home_card_translation_subtitle)
        "apology" -> stringResource(R.string.home_card_apology_subtitle)
        "event_invite" -> stringResource(R.string.home_card_event_subtitle)
        "move_car" -> stringResource(R.string.home_card_move_car_subtitle)
        "sales_promotion" -> stringResource(R.string.home_card_sales_subtitle)
        else -> card.subtitle
    }
