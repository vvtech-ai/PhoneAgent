package com.vvtech.aiassistant.features.assistant_timeline

/**
 * A pure reducer for runtime and restored timeline events. Equal item ids update in
 * place; this makes progress updates idempotent and preserves the original position.
 */
object ConversationTimelineReducer {
    fun reduce(
        current: List<ConversationTimelineItem>,
        event: ConversationTimelineEvent
    ): List<ConversationTimelineItem> {
        return when (event) {
            is ConversationTimelineEvent.Upsert -> upsert(current, event.item)
            is ConversationTimelineEvent.Remove -> current.filterNot { it.itemId == event.itemId }
        }
    }

    fun reduceAll(
        current: List<ConversationTimelineItem>,
        events: Iterable<ConversationTimelineEvent>
    ): List<ConversationTimelineItem> = events.fold(current, ::reduce)

    private fun upsert(
        current: List<ConversationTimelineItem>,
        item: ConversationTimelineItem
    ): List<ConversationTimelineItem> {
        val existingIndex = current.indexOfFirst { it.itemId == item.itemId }
        val merged = if (existingIndex < 0) current + item else current.mapIndexed { index, existing ->
            if (index == existingIndex) item else existing
        }
        return merged.sortedWith(
            compareBy<ConversationTimelineItem> { it.ledgerSequence ?: Long.MAX_VALUE }
                .thenBy { it.orderKey }
                .thenBy { it.itemId }
        )
    }
}

sealed interface ConversationTimelineEvent {
    data class Upsert(val item: ConversationTimelineItem) : ConversationTimelineEvent
    data class Remove(val itemId: String) : ConversationTimelineEvent
}
