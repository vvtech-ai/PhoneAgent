package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactDetailPageCallbacks
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactDetailPageState
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactDetailPage
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactsPage
import com.vvtech.aiassistant.features.assistant_contacts.normalizeAssistantContactPhoneKey

internal fun normalizeFinalContactPhoneKey(raw: String): String =
    normalizeAssistantContactPhoneKey(raw)

@Composable
internal fun FinalContactsPageV3(
    records: List<FinalContactRecord>,
    onOpenDetail: (FinalContactRecord) -> Unit
) {
    AssistantContactsPage(
        records = records,
        onOpenDetail = onOpenDetail
    )
}

@Composable
internal fun FinalContactDetailPageV3(
    state: AssistantContactDetailPageState,
    callbacks: AssistantContactDetailPageCallbacks
) {
    AssistantContactDetailPage(
        state = state,
        callbacks = callbacks
    )
}
