package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalOption

internal class AssistantTaskEntryOptionsInput(
    val selectedRestaurantId: String?,
    val selectedFallbackIds: Iterable<String>
)

internal class AssistantTaskEntryOptionsState(
    val restaurantOptions: List<FinalOption>,
    val fallbackOptions: List<FinalOption>,
    val selectedRestaurant: FinalOption?,
    val selectedFallbacks: List<FinalOption>
)

private val DefaultRestaurantOptions: List<FinalOption> = emptyList()

private val DefaultFallbackOptions: List<FinalOption> = listOf(
    FinalOption(
        "f2",
        "包间优先",
        "没有包间则不成立，不接受大厅。",
        "必须是包间，没有包间就不订。"
    ),
    FinalOption(
        "f3",
        "接受相邻时段",
        "若 19:00 无位，可询问 19:30 或 20:00。",
        "问是否可以改到 19:30 或 20:00。"
    )
)

internal fun deriveAssistantTaskEntryOptions(
    input: AssistantTaskEntryOptionsInput
): AssistantTaskEntryOptionsState {
    val selectedFallbackIds = input.selectedFallbackIds.toSet()
    return AssistantTaskEntryOptionsState(
        restaurantOptions = DefaultRestaurantOptions,
        fallbackOptions = DefaultFallbackOptions,
        selectedRestaurant = DefaultRestaurantOptions.firstOrNull { it.id == input.selectedRestaurantId },
        selectedFallbacks = DefaultFallbackOptions.filter { selectedFallbackIds.contains(it.id) }
    )
}
