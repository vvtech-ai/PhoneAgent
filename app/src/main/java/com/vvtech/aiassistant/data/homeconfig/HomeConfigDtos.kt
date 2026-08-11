package com.vvtech.aiassistant.data.homeconfig

data class HomeConfigDto(
    val version: String?,
    val configId: String?,
    val configVersion: String?,
    val publicationStatus: String?,
    val home: HomeDto?,
    val skillRefs: List<HomeSkillReferenceDto>? = null
)

data class HomeDto(
    val slogans: List<HomeSloganDto>?,
    val cards: List<HomeCardDto>?
)

data class HomeSloganDto(
    val id: String?,
    val line1: String?,
    val line2: String?,
    val status: String?,
    val sortOrder: Int?
)

data class HomeCardDto(
    val id: String?,
    val title: String?,
    val subtitle: String?,
    val status: String?,
    val sortOrder: Int?,
    val backgroundImage: HomeBackgroundImageDto?,
    val entryAction: HomeEntryActionDto?,
    val minClientVersion: String?
)

data class HomeBackgroundImageDto(val assetId: String?, val url: String?)
data class HomeEntryActionDto(val type: String?, val skillId: String?)
data class HomeSkillReferenceDto(
    val id: String?,
    val opening: String?
)
