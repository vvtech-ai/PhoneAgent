package com.vvtech.aiassistant.features.assistant_home

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantHomeConfigRefreshGuardTest {

    @Test
    fun homeRouteLoadsPublishedConfigWhenItIsDisplayed() {
        val legacyHomePage = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_conversation/ui/page/" +
                "AssistantConversationLegacyHomePage.kt"
        ).readText(Charsets.UTF_8)
        val configRoute = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_home/AssistantHomeConfigRoute.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(legacyHomePage.contains("visible = true"))
        assertFalse(legacyHomePage.contains("visible = composerState.assistantFocused"))
        assertTrue(
            configRoute.contains(
                "lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)"
            )
        )
        assertTrue(configRoute.contains("event == Lifecycle.Event.ON_START"))
        assertTrue(configRoute.contains("viewModel.onHomeStarted()"))
    }

    @Test
    fun publishedVersionReplacesCardsMatching304UsesCacheAndFailuresUseBuiltin() {
        val repository = sourceFile(
            "src/main/java/com/vvtech/aiassistant/data/homeconfig/HomeConfigRepository.kt"
        ).readText(Charsets.UTF_8)
        val localDataSource = sourceFile(
            "src/main/java/com/vvtech/aiassistant/data/homeconfig/HomeConfigLocalDataSource.kt"
        ).readText(Charsets.UTF_8)
        val viewModel = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_home/HomeConfigViewModel.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(repository.contains("getPublishedHomeConfig(cached?.etag)"))
        assertTrue(repository.contains("response.code() == 304 && cached != null"))
        assertTrue(repository.contains("mapper.map(cached.dto)"))
        assertTrue(repository.contains("local.write(dto, response.headers()[\"ETag\"])"))
        assertTrue(repository.contains("HomeConfigFallbackPolicy.resolve(error.message)"))
        assertFalse(repository.contains("val cachedConfig = cached?.let"))
        assertTrue(localDataSource.contains("putString(KeyJson, gson.toJson(dto)).putString(KeyEtag, etag)"))
        assertTrue(viewModel.contains("currentConfig = result.config"))
        assertTrue(viewModel.contains("private var sessionSlogan"))
        assertTrue(viewModel.contains("sessionSlogan ?: rotationStore.next(currentConfig)"))
        assertFalse(viewModel.contains("rotationStore.reset(currentConfig.configVersion)"))
        assertFalse(viewModel.contains("currentSloganId"))
        assertTrue(viewModel.contains("cards = cardsUi"))
    }

    private fun sourceFile(path: String): File = File(path).also {
        check(it.exists()) { "Missing source path: ${it.absolutePath}" }
    }
}
