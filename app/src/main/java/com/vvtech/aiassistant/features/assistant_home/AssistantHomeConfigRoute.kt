package com.vvtech.aiassistant.features.assistant_home

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.localizedInitialSkillOpening
import com.vvtech.aiassistant.features.assistant_agent.AgentInitialSkillLaunchStore
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguageManager

@Composable
internal fun AssistantHomeConfigRoute(
    visible: Boolean,
    onQuickVoiceEntry: (String?) -> Boolean,
    onOpenTranslateDial: () -> Unit,
    onBlockOffline: () -> Boolean,
    content: @Composable (AssistantHomeConfigUiState, (AssistantHomeCardUi) -> Unit) -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val viewModel: HomeConfigViewModel = viewModel(factory = HomeConfigViewModelFactory(context))
    val state by viewModel.state.collectAsStateWithLifecycle()
    val entryDispatcher = remember {
        HomeCardEntryDispatcher(
            clearInitialSkill = AgentInitialSkillLaunchStore::clear,
            armInitialSkill = { skillId, opening ->
                val englishApp = AppLanguageManager.currentAppLanguage() == AppLanguage.English
                val displayLanguage = if (englishApp) {
                    VoiceLanguage.English
                } else {
                    VoiceLanguage.Chinese
                }
                AgentInitialSkillLaunchStore.armWithBackendOpening(
                    skillId = skillId,
                    opening = localizedInitialSkillOpening(skillId, opening, displayLanguage),
                    backendOpening = opening,
                    sendBackendOpening = !englishApp
                )
            }
        )
    }

    DisposableEffect(visible, lifecycleOwner) {
        if (visible && lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
            viewModel.onHomeStarted()
        }
        val observer = LifecycleEventObserver { _, event ->
            if (visible && event == Lifecycle.Event.ON_START) viewModel.onHomeStarted()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    content(state) { card ->
        entryDispatcher.dispatch(
            card = card,
            onQuickVoiceEntry = onQuickVoiceEntry,
            onOpenTranslateDial = onOpenTranslateDial,
            onBlockOffline = onBlockOffline
        )
    }
}
