package com.vvtech.aiassistant.features.assistant_home.domain

internal data class HomeConfig(
    val configVersion: String,
    val slogans: List<HomeSlogan>,
    val cards: List<HomeCard>
)

internal data class HomeSlogan(
    val id: String,
    val line1: String,
    val line2: String,
    val sortOrder: Int
)

internal data class HomeCard(
    val id: String,
    val title: String,
    val subtitle: String,
    val status: HomeCardStatus,
    val sortOrder: Int,
    val imageUrl: String?,
    val entryAction: HomeEntryAction,
    val minClientVersion: String?
)

internal enum class HomeCardStatus { Enabled, ComingSoon, Disabled }

internal sealed interface HomeEntryAction {
    data class OpenSkill(
        val skillId: String,
        val opening: String? = null
    ) : HomeEntryAction
    object OpenTranslation : HomeEntryAction
    object OpenGenericTask : HomeEntryAction
    object None : HomeEntryAction
}

internal enum class HomeConfigSource { Network, Cache, Default }

internal data class HomeConfigLoadResult(
    val config: HomeConfig,
    val source: HomeConfigSource,
    val warning: String? = null
)
