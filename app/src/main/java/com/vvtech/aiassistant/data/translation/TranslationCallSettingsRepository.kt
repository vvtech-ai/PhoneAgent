package com.vvtech.aiassistant.data.translation

import android.content.Context
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import com.vvtech.aiassistant.features.translation_call.model.TranslationCallSettings
import com.vvtech.aiassistant.features.translation_call.model.TranslationCallSettingsPolicy
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

interface TranslationCallSettingsStore {
    fun getString(key: String): String?
    fun putString(key: String, value: String)
    fun getBoolean(key: String, defaultValue: Boolean): Boolean
    fun putBoolean(key: String, value: Boolean)
    fun getInt(key: String, defaultValue: Int): Int
    fun putInt(key: String, value: Int)
}

interface TranslationCallSettingsRepository {
    val state: StateFlow<TranslationCallSettings>
    fun selectDomesticProvider(provider: TranslationRealtimeProvider)
    fun selectOverseasProvider(provider: TranslationRealtimeProvider)
    fun selectServiceRegion(region: TranslationServiceRegion)
    fun setPlayOriginalAudio(enabled: Boolean)
    fun setOriginalAudioGainPercent(percent: Int)
    fun setOriginalAudioVolumePercent(percent: Int)
}

class DefaultTranslationCallSettingsRepository(
    private val store: TranslationCallSettingsStore
) : TranslationCallSettingsRepository {
    private val mutableState = MutableStateFlow(load())

    override val state: StateFlow<TranslationCallSettings> = mutableState.asStateFlow()

    override fun selectDomesticProvider(provider: TranslationRealtimeProvider) {
        val selected = provider.takeIf {
            it in TranslationCallSettingsPolicy.domesticProviders
        } ?: TranslationRealtimeProvider.Qwen
        update(mutableState.value.copy(domesticProvider = selected))
    }

    override fun selectOverseasProvider(provider: TranslationRealtimeProvider) {
        val selected = provider.takeIf {
            it in TranslationCallSettingsPolicy.overseasProviders
        } ?: TranslationRealtimeProvider.Gemini
        update(mutableState.value.copy(overseasProvider = selected))
    }

    override fun selectServiceRegion(region: TranslationServiceRegion) {
        val selected = region.takeIf {
            it in TranslationCallSettingsPolicy.serviceRegions
        } ?: TranslationServiceRegion.Default
        update(mutableState.value.copy(serviceRegion = selected))
    }

    override fun setPlayOriginalAudio(enabled: Boolean) {
        update(mutableState.value.copy(playOriginalAudio = enabled))
    }

    override fun setOriginalAudioGainPercent(percent: Int) {
        update(
            mutableState.value.copy(
                originalAudioGainPercent =
                    TranslationCallSettingsPolicy.originalAudioGainPercent(percent)
            )
        )
    }

    override fun setOriginalAudioVolumePercent(percent: Int) {
        update(
            mutableState.value.copy(
                originalAudioVolumePercent =
                    TranslationCallSettingsPolicy.originalAudioVolumePercent(percent)
            )
        )
    }

    private fun load() = TranslationCallSettings(
        domesticProvider = TranslationCallSettingsPolicy.domesticProvider(
            store.getString(DomesticProviderKey)
        ),
        overseasProvider = TranslationCallSettingsPolicy.overseasProvider(
            store.getString(OverseasProviderKey)
        ),
        serviceRegion = TranslationCallSettingsPolicy.serviceRegion(
            store.getString(ServiceRegionKey)
        ),
        playOriginalAudio = store.getBoolean(PlayOriginalAudioKey, false),
        originalAudioGainPercent = TranslationCallSettingsPolicy.originalAudioGainPercent(
            store.getInt(
                OriginalAudioGainPercentKey,
                TranslationCallSettingsPolicy.DefaultOriginalAudioGainPercent
            )
        ),
        originalAudioVolumePercent = TranslationCallSettingsPolicy.originalAudioVolumePercent(
            store.getInt(
                OriginalAudioVolumePercentKey,
                TranslationCallSettingsPolicy.DefaultOriginalAudioVolumePercent
            )
        )
    )

    private fun update(settings: TranslationCallSettings) {
        mutableState.value = settings
        store.putString(DomesticProviderKey, settings.domesticProvider.name)
        store.putString(OverseasProviderKey, settings.overseasProvider.name)
        store.putString(ServiceRegionKey, settings.serviceRegion.name)
        store.putBoolean(PlayOriginalAudioKey, settings.playOriginalAudio)
        store.putInt(OriginalAudioGainPercentKey, settings.originalAudioGainPercent)
        store.putInt(OriginalAudioVolumePercentKey, settings.originalAudioVolumePercent)
    }

    private companion object {
        const val DomesticProviderKey = "translation_domestic_provider"
        const val OverseasProviderKey = "translation_overseas_provider"
        const val ServiceRegionKey = "translation_service_region"
        const val PlayOriginalAudioKey = "translation_play_original_audio"
        const val OriginalAudioGainPercentKey = "translation_original_audio_gain_percent"
        const val OriginalAudioVolumePercentKey = "translation_original_audio_volume_percent"
    }
}

class SharedPreferencesTranslationCallSettingsStore(
    context: Context
) : TranslationCallSettingsStore {
    private val preferences = context.applicationContext.getSharedPreferences(
        PreferencesName,
        Context.MODE_PRIVATE
    )

    override fun getString(key: String): String? = preferences.getString(key, null)

    override fun putString(key: String, value: String) {
        preferences.edit().putString(key, value).apply()
    }

    override fun getBoolean(key: String, defaultValue: Boolean): Boolean =
        preferences.getBoolean(key, defaultValue)

    override fun putBoolean(key: String, value: Boolean) {
        preferences.edit().putBoolean(key, value).apply()
    }

    override fun getInt(key: String, defaultValue: Int): Int =
        preferences.getInt(key, defaultValue)

    override fun putInt(key: String, value: Int) {
        preferences.edit().putInt(key, value).apply()
    }

    private companion object {
        const val PreferencesName = "translation_call_settings"
    }
}
