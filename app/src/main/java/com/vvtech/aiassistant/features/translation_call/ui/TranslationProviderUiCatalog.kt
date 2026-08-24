package com.vvtech.aiassistant.features.translation_call.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import java.util.Locale

internal data class TranslationProviderUiOption(
    val id: String,
    val provider: TranslationRealtimeProvider,
    val displayName: String,
    val subtitle: String,
    val enabledDuringInitialization: Boolean
)

internal object TranslationProviderUiCatalog {
    const val QwenId = "QWEN_OMNI_PLUS"
    private const val LegacyQwenId = "QWEN_OMNI_FLASH"
    const val DoubaoId = "DOUBAO"
    const val OpenAiId = "OPENAI"
    const val GeminiId = "GEMINI"

    val domesticOptions = listOf(
        TranslationProviderUiOption(
            id = QwenId,
            provider = TranslationRealtimeProvider.Qwen,
            displayName = "Qwen LT Flash",
            subtitle = "Alibaba · realtime two-way translation",
            enabledDuringInitialization = true
        ),
        TranslationProviderUiOption(
            id = DoubaoId,
            provider = TranslationRealtimeProvider.Doubao,
            displayName = "Doubao AST LT",
            subtitle = "ByteDance · realtime speech translation service",
            enabledDuringInitialization = true
        )
    )

    val overseasOptions = listOf(
        TranslationProviderUiOption(
            id = OpenAiId,
            provider = TranslationRealtimeProvider.OpenAi,
            displayName = "GPT RT Translate",
            subtitle = "GPT realtime translation model",
            enabledDuringInitialization = false
        ),
        TranslationProviderUiOption(
            id = GeminiId,
            provider = TranslationRealtimeProvider.Gemini,
            displayName = "Gemini Live",
            subtitle = "Google · realtime translation model",
            enabledDuringInitialization = false
        )
    )

    val allOptions: List<TranslationProviderUiOption> = domesticOptions + overseasOptions

    fun providerId(provider: TranslationRealtimeProvider): String =
        option(provider).id

    fun displayName(provider: TranslationRealtimeProvider): String =
        option(provider).displayName

    fun displayName(rawProviderId: String?): String =
        option(rawProviderId)?.displayName ?: QwenDefault.displayName

    fun normalizeProviderId(rawProviderId: String?): String =
        option(rawProviderId)?.id ?: QwenDefault.id

    fun option(provider: TranslationRealtimeProvider): TranslationProviderUiOption =
        allOptions.first { it.provider == provider }

    fun option(rawProviderId: String?): TranslationProviderUiOption? {
        val normalized = rawProviderId
            ?.trim()
            ?.uppercase(Locale.ROOT)
            ?.replace('-', '_')
            .orEmpty()
        return when {
            normalized in setOf("QWEN", QwenId, LegacyQwenId, "千问", "千问 QWEN", "阿里 QWEN") ||
                normalized.startsWith("QWEN3") -> option(TranslationRealtimeProvider.Qwen)
            normalized in setOf(
                DoubaoId,
                "SEEDUPLEX",
                "DOUBAO AST LT",
                "DOUBAO_AST_LT",
                "豆包",
                "豆包 ATS"
            ) ->
                option(TranslationRealtimeProvider.Doubao)
            normalized in setOf(OpenAiId, "OPEN_AI", "GPT_LIVE_TRANSLATE") ->
                option(TranslationRealtimeProvider.OpenAi)
            normalized in setOf(GeminiId, "GEMINI_LIVE", "GOOGLE_GEMINI_LIVE_TRANSLATE") ->
                option(TranslationRealtimeProvider.Gemini)
            else -> null
        }
    }

    private val QwenDefault: TranslationProviderUiOption
        get() = domesticOptions.first()
}

@Composable
internal fun TranslationProviderUiOption.localizedSubtitle(): String = when (id) {
    TranslationProviderUiCatalog.QwenId -> stringResource(R.string.translation_provider_qwen_subtitle)
    TranslationProviderUiCatalog.DoubaoId -> stringResource(R.string.translation_provider_doubao_subtitle)
    TranslationProviderUiCatalog.OpenAiId -> stringResource(R.string.translation_provider_gpt_subtitle)
    TranslationProviderUiCatalog.GeminiId -> stringResource(R.string.translation_provider_gemini_subtitle)
    else -> subtitle
}
