package com.vvtech.aiassistant.features.assistant_singleflow

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.withFrameNanos
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.SfInputMode
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.pvWelcomePlayedThisProcess
import com.vvtech.aiassistant.features.assistant.sfHasRealRestaurantFlowState
import com.vvtech.aiassistant.features.assistant.sfRealRestaurantStage
import com.vvtech.aiassistant.features.assistant_agent.AgentInitialSkillLaunchStore
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoicePrecheckUiState
import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.delay

private const val VoiceEntryLogTag = "VoiceEntryPerf"
private const val VoiceEntryStackStartDelayMs = 180L
private const val VoiceEntryPrecheckMinimumMs = 1_600L

internal data class SingleFlowNativeEntryEffectsArgs(
    val state: SingleFlowNativeStateHolder,
    val initialCommand: String?,
    val startInVoice: Boolean,
    val resumeListeningOnly: Boolean,
    val entryKey: Long,
    val assistantState: Index9AssistantUiState?,
    val pureVoiceMode: Boolean,
    val pureVoicePrecheck: PureVoicePrecheckUiState?,
    val voiceLanguage: VoiceLanguage
)

internal data class SingleFlowNativeEntryEffectCallbacks(
    val onHandleUserInput: suspend (String) -> Unit,
    val onStartVoiceInteraction: (() -> Unit)?,
    val onStartNewVoiceTaskEntry: (() -> Unit)?,
    val onSpeakVoicePrompt: ((String) -> Unit)?
)

@Composable
internal fun SingleFlowNativeEntryEffects(
    args: SingleFlowNativeEntryEffectsArgs,
    callbacks: SingleFlowNativeEntryEffectCallbacks
) {
    val state = args.state
    val realFlowEnabled = args.assistantState != null
    val latestPrecheck = rememberUpdatedState(args.pureVoicePrecheck)

    LaunchedEffect(args.entryKey) {
        val seed = args.initialCommand?.trim().orEmpty()
        val activeRealState = args.assistantState

        suspend fun startVoiceListeningAfterStackReady(reason: String) {
            state.inputMode = SfInputMode.Voice
            AppFileLogger.i(
                VoiceEntryLogTag,
                "VOICE_ENTRY_DEFER_STACK reason=$reason entryKey=${args.entryKey} " +
                    "pureVoiceMode=${args.pureVoiceMode} realFlowEnabled=$realFlowEnabled"
            )
            withFrameNanos { }
            withFrameNanos { }
            delay(VoiceEntryStackStartDelayMs)
            AppFileLogger.i(
                VoiceEntryLogTag,
                "VOICE_ENTRY_START_STACK reason=$reason entryKey=${args.entryKey} " +
                    "delayMs=$VoiceEntryStackStartDelayMs pureVoiceMode=${args.pureVoiceMode} " +
                    "realFlowEnabled=$realFlowEnabled"
            )
            if (realFlowEnabled) {
                callbacks.onStartVoiceInteraction?.invoke()
            } else {
                state.listening = true
                state.addUserWave()
            }
        }

        suspend fun waitForEnvironmentPrecheck() {
            // Provider loading may start a few frames after the page enters.
            delay(VoiceEntryPrecheckMinimumMs)
            while (latestPrecheck.value?.visible == true) {
                delay(80L)
            }
        }

        if (
            realFlowEnabled &&
            seed.isBlank() &&
            activeRealState?.showAiCallPage == true &&
            sfHasRealRestaurantFlowState(activeRealState)
        ) {
            state.stage = sfRealRestaurantStage(activeRealState)
            state.inputMode = if (args.pureVoiceMode) SfInputMode.Voice else state.inputMode
            state.listening = false
            state.callRunning = false
            state.callVisible = false
            return@LaunchedEffect
        }
        if (realFlowEnabled && activeRealState?.clarificationSteps?.isNotEmpty() == true && seed.isBlank()) {
            state.inputMode = if (args.pureVoiceMode || args.resumeListeningOnly) {
                SfInputMode.Voice
            } else {
                state.inputMode
            }
            if (args.resumeListeningOnly) {
                startVoiceListeningAfterStackReady("resume_history")
            }
            return@LaunchedEffect
        }
        state.resetForEntry(if (args.pureVoiceMode) SfInputMode.Voice else SfInputMode.Text)

        when {
            seed.isNotBlank() -> {
                callbacks.onHandleUserInput(seed)
            }

            args.resumeListeningOnly -> {
                state.inputMode = SfInputMode.Voice
                AppFileLogger.i(
                    VoiceEntryLogTag,
                    "VOICE_ENTRY_WAIT_HISTORY reason=resume_empty entryKey=${args.entryKey} " +
                        "pureVoiceMode=${args.pureVoiceMode} realFlowEnabled=$realFlowEnabled"
                )
            }

            args.startInVoice -> {
                state.inputMode = SfInputMode.Voice
                AppFileLogger.i(
                    VoiceEntryLogTag,
                    "VOICE_ENTRY_DEFER_STACK entryKey=${args.entryKey} " +
                        "pureVoiceMode=${args.pureVoiceMode} realFlowEnabled=$realFlowEnabled"
                )
                withFrameNanos { }
                withFrameNanos { }
                delay(VoiceEntryStackStartDelayMs)
                AppFileLogger.i(
                    VoiceEntryLogTag,
                    "VOICE_ENTRY_START_STACK entryKey=${args.entryKey} delayMs=$VoiceEntryStackStartDelayMs " +
                        "pureVoiceMode=${args.pureVoiceMode} realFlowEnabled=$realFlowEnabled"
                )
                if (args.pureVoiceMode) {
                    waitForEnvironmentPrecheck()
                    AppFileLogger.i(
                        VoiceEntryLogTag,
                        "VOICE_ENTRY_PURE_VOICE_STANDBY entryKey=${args.entryKey} " +
                            "realFlowEnabled=$realFlowEnabled"
                    )
                    val welcomeText = AgentInitialSkillLaunchStore.peekOpening()
                        ?: if (!pvWelcomePlayedThisProcess) {
                            pvWelcomePlayedThisProcess = true
                            args.voiceLanguage.firstWelcome
                        } else {
                            args.voiceLanguage.repeatWelcome
                        }
                    AgentInitialSkillLaunchStore.rememberOpening(welcomeText)
                    callbacks.onSpeakVoicePrompt?.invoke(welcomeText)
                    if (realFlowEnabled) {
                        (callbacks.onStartNewVoiceTaskEntry ?: callbacks.onStartVoiceInteraction)?.invoke()
                    }
                } else if (realFlowEnabled) {
                    (callbacks.onStartNewVoiceTaskEntry ?: callbacks.onStartVoiceInteraction)?.invoke()
                } else {
                    state.listening = true
                    state.addUserWave()
                }
            }

            else -> {
                if (!realFlowEnabled) {
                    state.aiReply("你好，我是 Phone Agent。请直接告诉我你的任务需求，我会在同一个对话流里完成全部确认与执行。")
                }
            }
        }
    }
}
