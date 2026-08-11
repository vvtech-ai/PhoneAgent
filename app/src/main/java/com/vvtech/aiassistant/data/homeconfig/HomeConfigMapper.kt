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
        require(dto.version == "home-config-v1") { "不支持的首页配置协议" }
        require(!dto.configId.isNullOrBlank()) { "首页配置 ID 为空" }
        require(!dto.configVersion.isNullOrBlank()) { "首页配置版本为空" }
        require(dto.publicationStatus.equals("published", ignoreCase = true)) { "首页配置尚未发布" }
        val home = requireNotNull(dto.home) { "首页配置内容为空" }
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
        require(slogans.isNotEmpty()) { "没有可用 Slogan" }
        require(cards.isNotEmpty()) { "没有首页卡片" }
        requireUnique(slogans.map(HomeSlogan::id), "Slogan ID")
        requireUnique(cards.map(HomeCard::id), "卡片 ID")
        requireUnique(slogans.map(HomeSlogan::sortOrder), "Slogan 排序")
        requireUnique(cards.map(HomeCard::sortOrder), "卡片排序")
        return HomeConfig(dto.configVersion.orEmpty(), slogans, cards)
    }

    private fun mapSlogan(dto: HomeSloganDto): HomeSlogan? {
        val status = dto.status.orEmpty()
        require(status == "enabled" || status == "disabled") { "未知 Slogan 状态" }
        if (status == "disabled") return null
        val id = dto.id.orEmpty().trim()
        val line1 = dto.line1.orEmpty().trim()
        val line2 = dto.line2.orEmpty().trim()
        val order = dto.sortOrder ?: 0
        require(id.isNotEmpty() && line1.isNotEmpty() && line2.isNotEmpty() && order > 0) { "Slogan 字段无效" }
        require(line1.codePointCount() <= 10 && line2.codePointCount() <= 20) { "Slogan 文案超长" }
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
        require(id.isNotEmpty() && title.isNotEmpty() && subtitle.isNotEmpty() && order > 0) { "卡片字段无效" }
        require(title.codePointCount() <= 6 && subtitle.codePointCount() <= 20) { "卡片文案超长" }
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
            val skillId = requireText(dto.skillId, "Skill ID 为空")
            HomeEntryAction.OpenSkill(skillId, skillOpenings[skillId])
        }
        "openTranslation" -> {
            require(dto.skillId == "simultaneous_interpretation") { "同声传译绑定错误" }
            HomeEntryAction.OpenTranslation
        }
        "openGenericTask" -> {
            require(dto.skillId == "generic_task") { "通用任务绑定错误" }
            HomeEntryAction.OpenGenericTask
        }
        "none" -> HomeEntryAction.None
        else -> error("未知首页入口类型")
    }

    private fun resolveAssetUrl(cardId: String, image: HomeBackgroundImageDto?): String? {
        if (image == null) return null
        val url = requireText(image.url, "首页图片资源地址为空")
        val assetId = image.assetId?.trim().orEmpty()
        if (assetId.isEmpty()) {
            return requireNotNull(HomeConfigDefaultImages.resolve(cardId, url)) {
                "首页图片资源地址无效"
            }
        }
        require(ASSET_ID_PATTERN.matches(assetId)) { "首页图片资源 ID 无效" }
        val expectedPath = "/api/home-config/assets/$assetId"
        require(url == expectedPath) { "首页图片资源地址无效" }
        val base = URI(baseUrl)
        require(base.isAbsolute && base.scheme in setOf("http", "https")) { "首页接口基地址无效" }
        return base.resolve(expectedPath.removePrefix("/")).toString()
    }

    private fun <T> requireUnique(values: List<T>, label: String) {
        require(values.size == values.toSet().size) { "$label 重复" }
    }

    private fun requireText(value: String?, message: String): String =
        value?.trim()?.takeIf(String::isNotEmpty) ?: error(message)

    private fun String.codePointCount(): Int = codePointCount(0, length)

    private companion object {
        val ASSET_ID_PATTERN = Regex("[A-Za-z0-9-]+")
    }
}
