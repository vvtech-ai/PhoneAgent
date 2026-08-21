package com.vvtech.aiassistant.data.homeconfig

import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.features.assistant_home.domain.HomeCard
import com.vvtech.aiassistant.features.assistant_home.domain.HomeCardStatus
import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfig
import com.vvtech.aiassistant.features.assistant_home.domain.HomeEntryAction
import com.vvtech.aiassistant.features.assistant_home.domain.HomeSlogan
import java.net.URI

internal class HomeConfigMapper(
    private val baseUrl: String = BuildConfig.BASE_URL
) {
    fun map(dto: HomeConfigDto): HomeConfig {
        require(dto.version == "home-config-v1") { "Unsupported home config protocol" }
        require(!dto.configId.isNullOrBlank()) { "Home config ID is empty" }
        require(!dto.configVersion.isNullOrBlank()) { "Home config version is empty" }
        require(dto.publicationStatus.equals("published", ignoreCase = true)) { "Home config is not published" }
        val home = requireNotNull(dto.home) { "Home config content is empty" }
        val skillOpenings = dto.skillRefs.orEmpty()
            .mapNotNull { ref ->
                val id = ref.id?.trim().orEmpty()
                val opening = ref.opening?.trim().orEmpty()
                if (id.isEmpty() || opening.isEmpty()) null else id to opening
            }
            .toMap()
        val slogans = home.slogans.orEmpty().mapNotNull(::mapSlogan).sortedBy(HomeSlogan::sortOrder)
        val cards = home.cards.orEmpty()
            .map { mapCard(it, skillOpenings) }
            .sortedBy(HomeCard::sortOrder)
        require(slogans.isNotEmpty()) { "No available slogans" }
        require(cards.isNotEmpty()) { "No home cards" }
        requireUnique(slogans.map(HomeSlogan::id), "Slogan ID")
        requireUnique(cards.map(HomeCard::id), "Card ID")
        requireUnique(slogans.map(HomeSlogan::sortOrder), "Slogan sort order")
        requireUnique(cards.map(HomeCard::sortOrder), "Card sort order")
        return HomeConfig(dto.configVersion.orEmpty(), slogans, cards)
    }

    private fun mapSlogan(dto: HomeSloganDto): HomeSlogan? {
        val status = dto.status.orEmpty()
        require(status == "enabled" || status == "disabled") { "Unknown slogan status" }
        if (status == "disabled") return null
        val id = dto.id.orEmpty().trim()
        val line1 = dto.line1.orEmpty().trim()
        val line2 = dto.line2.orEmpty().trim()
        val order = dto.sortOrder ?: 0
        require(id.isNotEmpty() && line1.isNotEmpty() && line2.isNotEmpty() && order > 0) { "Invalid slogan fields" }
        require(line1.codePointCount() <= 10 && line2.codePointCount() <= 20) { "Slogan text is too long" }
        return HomeSlogan(id, line1, line2, order)
    }

    private fun mapCard(
        dto: HomeCardDto,
        skillOpenings: Map<String, String>
    ): HomeCard {
        val id = dto.id.orEmpty().trim()
        val title = dto.title.orEmpty().trim()
        val subtitle = dto.subtitle.orEmpty().trim()
        val order = dto.sortOrder ?: 0
        require(id.isNotEmpty() && title.isNotEmpty() && subtitle.isNotEmpty() && order > 0) { "Invalid card fields" }
        require(title.codePointCount() <= 6 && subtitle.codePointCount() <= 20) { "Card text is too long" }
        val status = when (dto.status) {
            "enabled" -> HomeCardStatus.Enabled
            "comingSoon" -> HomeCardStatus.ComingSoon
            "disabled" -> HomeCardStatus.Disabled
            else -> HomeCardStatus.Disabled
        }
        return HomeCard(
            id = id,
            title = title,
            subtitle = subtitle,
            status = status,
            sortOrder = order,
            imageUrl = resolveAssetUrl(id, dto.backgroundImage),
            entryAction = mapAction(dto.entryAction, skillOpenings),
            minClientVersion = dto.minClientVersion?.trim()?.takeIf(String::isNotEmpty)
        )
    }

    private fun mapAction(
        dto: HomeEntryActionDto?,
        skillOpenings: Map<String, String>
    ): HomeEntryAction = when (dto?.type) {
        "openSkill" -> {
            val skillId = requireText(dto.skillId, "Skill ID is empty")
            HomeEntryAction.OpenSkill(skillId, skillOpenings[skillId])
        }
        "openTranslation" -> {
            require(dto.skillId == "simultaneous_interpretation") { "Live translation binding is invalid" }
            HomeEntryAction.OpenTranslation
        }
        "openGenericTask" -> {
            require(dto.skillId == "generic_task") { "Generic task binding is invalid" }
            HomeEntryAction.OpenGenericTask
        }
        "none" -> HomeEntryAction.None
        else -> error("Unknown home entry type")
    }

    private fun resolveAssetUrl(cardId: String, image: HomeBackgroundImageDto?): String? {
        if (image == null) return null
        val url = requireText(image.url, "Home image resource URL is empty")
        val assetId = image.assetId?.trim().orEmpty()
        if (assetId.isEmpty()) {
            return requireNotNull(HomeConfigDefaultImages.resolve(cardId, url)) {
                "Home image resource URL is invalid"
            }
        }
        require(ASSET_ID_PATTERN.matches(assetId)) { "Home image resource ID is invalid" }
        val expectedPath = "/api/home-config/assets/$assetId"
        require(url == expectedPath) { "Home image resource URL is invalid" }
        val base = URI(baseUrl)
        require(base.isAbsolute && base.scheme in setOf("http", "https")) { "Home API base URL is invalid" }
        return base.resolve(expectedPath.removePrefix("/")).toString()
    }

    private fun <T> requireUnique(values: List<T>, label: String) {
        require(values.size == values.toSet().size) { "$label is duplicated" }
    }

    private fun requireText(value: String?, message: String): String =
        value?.trim()?.takeIf(String::isNotEmpty) ?: error(message)

    private fun String.codePointCount(): Int = codePointCount(0, length)

    private companion object {
        val ASSET_ID_PATTERN = Regex("[A-Za-z0-9-]+")
    }
}
