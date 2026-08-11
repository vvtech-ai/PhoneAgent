package com.vvtech.aiassistant.features.assistant_home

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.data.homeconfig.HomeConfigContainer
import com.vvtech.aiassistant.data.homeconfig.HomeConfigDefaults
import com.vvtech.aiassistant.data.homeconfig.HomeSloganRotationStore
import com.vvtech.aiassistant.features.assistant_home.domain.HomeCardStatus
import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfig
import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfigPolicy
import com.vvtech.aiassistant.features.assistant_home.domain.HomeEntryAction
import com.vvtech.aiassistant.features.assistant_home.domain.HomeSlogan
import com.vvtech.aiassistant.features.assistant_home.domain.LoadHomeConfigUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

internal class HomeConfigViewModel(
    private val loadHomeConfig: LoadHomeConfigUseCase,
    private val rotationStore: HomeSloganRotationStore
) : ViewModel() {
    private var currentConfig = HomeConfigDefaults.create()
    private var sessionSlogan: HomeSlogan? = null
    private var refreshJob: Job? = null
    private val mutableState = MutableStateFlow(currentConfig.toUiState(loading = true))
    val state: StateFlow<AssistantHomeConfigUiState> = mutableState.asStateFlow()

    fun refresh() {
        refreshJob?.cancel()
        refreshJob = viewModelScope.launch {
            mutableState.update { it.copy(loading = true) }
            val result = loadHomeConfig()
            currentConfig = result.config
            val selectedSlogan = sessionSlogan ?: rotationStore.next(currentConfig)
                .also { sessionSlogan = it }
            mutableState.value = currentConfig.toUiState(
                loading = false,
                source = result.source,
                warning = result.warning,
                slogan = selectedSlogan
            )
            Log.i(Tag, "HOME_CONFIG_LOADED version=${currentConfig.configVersion} source=${result.source} warning=${result.warning}")
        }
    }

    fun onHomeStarted() {
        refresh()
    }

    private fun HomeConfig.toUiState(
        loading: Boolean,
        source: com.vvtech.aiassistant.features.assistant_home.domain.HomeConfigSource =
            com.vvtech.aiassistant.features.assistant_home.domain.HomeConfigSource.Default,
        warning: String? = null,
        slogan: HomeSlogan? = null
    ): AssistantHomeConfigUiState {
        val selected = slogan ?: slogans.first()
        val cardsUi = cards
            .filter { it.status != HomeCardStatus.Disabled }
            .map { card ->
                val versionSupported = HomeConfigPolicy.isVersionSupported(BuildConfig.VERSION_NAME, card.minClientVersion)
                val enabled = card.status == HomeCardStatus.Enabled && versionSupported && card.entryAction != HomeEntryAction.None
                AssistantHomeCardUi(
                    id = card.id,
                    title = card.title,
                    subtitle = card.subtitle,
                    imageUrl = card.imageUrl,
                    enabled = enabled,
                    statusLabel = if (enabled) null else if (!versionSupported) "请升级客户端" else "即将提供",
                    action = card.entryAction
                )
            }
        return AssistantHomeConfigUiState(
            configVersion = configVersion,
            slogan = AssistantHomeSloganUi(selected.line1, selected.line2),
            cards = cardsUi,
            source = source,
            loading = loading,
            warning = warning
        )
    }

    private companion object { const val Tag = "HomeConfig" }
}

internal class HomeConfigViewModelFactory(context: Context) : ViewModelProvider.Factory {
    private val appContext = context.applicationContext

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(HomeConfigViewModel::class.java))
        return HomeConfigViewModel(
            loadHomeConfig = LoadHomeConfigUseCase(HomeConfigContainer.repository(appContext)),
            rotationStore = HomeSloganRotationStore(appContext)
        ) as T
    }
}
