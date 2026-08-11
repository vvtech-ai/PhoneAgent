package com.vvtech.aiassistant.data.homeconfig

import com.vvtech.aiassistant.features.assistant_home.domain.HomeCardStatus
import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfigSource
import com.vvtech.aiassistant.features.assistant_home.domain.HomeEntryAction
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeConfigMapperTest {
    private val mapper = HomeConfigMapper("http://127.0.0.1:8080/")

    @Test
    fun mapsSortsAndResolvesAllEntryActions() {
        val config = mapper.map(validDto())

        assertEquals(listOf("s1", "s2"), config.slogans.map { it.id })
        assertEquals(listOf("skill", "translation", "generic", "unknown"), config.cards.map { it.id })
        assertEquals(
            HomeEntryAction.OpenSkill("restaurant_booking", "想订哪家餐厅？"),
            config.cards[0].entryAction
        )
        assertEquals(HomeEntryAction.OpenTranslation, config.cards[1].entryAction)
        assertEquals(HomeEntryAction.OpenGenericTask, config.cards[2].entryAction)
        assertEquals(HomeCardStatus.Disabled, config.cards[3].status)
        assertEquals("http://127.0.0.1:8080/api/home-config/assets/a1", config.cards[0].imageUrl)
    }

    @Test
    fun preservesGatewayPrefixWhenResolvingAssetPath() {
        val config = HomeConfigMapper("https://phone-agent.example/aiassistant-api/").map(validDto())

        assertEquals(
            "https://phone-agent.example/aiassistant-api/api/home-config/assets/a1",
            config.cards[0].imageUrl
        )
    }

    @Test
    fun normalizesLegacyTrustedDefaultCdnImageToCurrentVersion() {
        val config = mapper.map(dtoWithRestaurantImage(
            "https://cdn.chaken.net.cn/ai/homeicon/restaurant-booking-transparent.png"
        ))

        assertEquals(
            "https://cdn.chaken.net.cn/ai/homeicon/restaurant-booking-transparent.png?v=20260727",
            config.cards.first { it.id == "restaurant_booking" }.imageUrl
        )
    }

    @Test
    fun keepsCurrentVersionTrustedDefaultCdnImage() {
        val versionedUrl =
            "https://cdn.chaken.net.cn/ai/homeicon/restaurant-booking-transparent.png?v=20260727"

        val config = mapper.map(dtoWithRestaurantImage(versionedUrl))

        assertEquals(
            versionedUrl,
            config.cards.first { it.id == "restaurant_booking" }.imageUrl
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsTrustedDefaultCdnImageAssignedToDifferentCard() {
        val dto = validDto()
        val home = requireNotNull(dto.home)
        val cards = home.cards!!.map { card ->
            if (card.id == "skill") {
                card.copy(backgroundImage = HomeBackgroundImageDto(
                    null,
                    "https://cdn.chaken.net.cn/ai/homeicon/restaurant-booking-transparent.png"
                ))
            } else {
                card
            }
        }

        mapper.map(dto.copy(home = home.copy(cards = cards)))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsExternalAssetUrl() {
        val dto = validDto()
        val home = requireNotNull(dto.home)
        val cards = home.cards!!.map { card ->
            if (card.id == "skill") {
                card.copy(backgroundImage = HomeBackgroundImageDto("a1", "https://example.com/a.png"))
            } else {
                card
            }
        }

        mapper.map(dto.copy(home = home.copy(cards = cards)))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsUnknownProtocolBeforeItCanReplaceCache() {
        mapper.map(validDto().copy(version = "home-config-v2"))
    }

    @Test
    fun failureUsesBuiltinEvenWhenLastKnownGoodExists() {
        val cached = mapper.map(validDto())
        assertTrue(cached.cards.isNotEmpty())

        val result = HomeConfigFallbackPolicy.resolve("offline")

        assertEquals(HomeConfigSource.Default, result.source)
        assertEquals("builtin-1", result.config.configVersion)
        assertEquals(listOf("primary", "secondary"), result.config.slogans.map { it.id })
        assertEquals(listOf(
            "restaurant_booking", "meeting_invite", "apology", "event_invite",
            "move_car", "sales_promotion", "simultaneous_interpretation"
        ), result.config.cards.map { it.id })
        assertEquals(listOf(
            "帮你询位、预订包房", "批量通知参会、确认回执", "代你表达歉意", "邀约嘉宾参加",
            "联系车主协调挪车", "介绍产品服务", "实时翻译通话。"
        ), result.config.cards.map { it.subtitle })
        assertEquals(listOf(
            HomeCardStatus.Enabled, HomeCardStatus.Enabled,
            HomeCardStatus.ComingSoon, HomeCardStatus.ComingSoon,
            HomeCardStatus.ComingSoon, HomeCardStatus.ComingSoon,
            HomeCardStatus.ComingSoon
        ), result.config.cards.map { it.status })
        assertTrue("APK 默认配置不得为卡片图片再次请求 CDN", result.config.cards.all { it.imageUrl == null })
        assertEquals("offline", result.warning)
    }

    private fun validDto() = HomeConfigDto(
        version = "home-config-v1",
        configId = "default",
        configVersion = "20260718.1",
        publicationStatus = "published",
        home = HomeDto(
            slogans = listOf(
                HomeSloganDto("s2", "老大请吩咐", "我来帮你打电话", "enabled", 2),
                HomeSloganDto("s1", "给我一个任务", "我来帮你打电话", "enabled", 1)
            ),
            cards = listOf(
                card("unknown", "未知", "不会显示", "future", 4, HomeEntryActionDto("none", null)),
                card("generic", "普通任务", "进入通用任务", "enabled", 3,
                    HomeEntryActionDto("openGenericTask", "generic_task")),
                card("translation", "同声传译", "实时翻译通话", "comingSoon", 2,
                    HomeEntryActionDto("openTranslation", "simultaneous_interpretation")),
                card("skill", "订餐厅", "帮你预订包房", "enabled", 1,
                    HomeEntryActionDto("openSkill", "restaurant_booking"), "/api/home-config/assets/a1")
            )
        ),
        skillRefs = listOf(
            HomeSkillReferenceDto(
                id = "restaurant_booking",
                opening = "想订哪家餐厅？"
            )
        )
    )

    private fun dtoWithRestaurantImage(url: String): HomeConfigDto {
        val dto = validDto()
        val home = requireNotNull(dto.home)
        val cards = home.cards!!.map { card ->
            if (card.id == "skill") {
                card.copy(
                    id = "restaurant_booking",
                    backgroundImage = HomeBackgroundImageDto(null, url)
                )
            } else {
                card
            }
        }
        return dto.copy(home = home.copy(cards = cards))
    }

    private fun card(
        id: String,
        title: String,
        subtitle: String,
        status: String,
        order: Int,
        action: HomeEntryActionDto,
        imageUrl: String? = null
    ) = HomeCardDto(
        id, title, subtitle, status, order,
        imageUrl?.let { HomeBackgroundImageDto("a1", it) }, action, null
    )
}
