package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguageManager
import com.vvtech.aiassistant.features.assistant_i18n.appText
import com.vvtech.aiassistant.features.assistant_shell.AssistantNormalCallNavigationCallbacks
import com.vvtech.aiassistant.features.assistant_shell.AssistantNormalCallNavigationState
import com.vvtech.aiassistant.features.assistant_shell.navigateAfterAssistantNormalCallHangup
import com.vvtech.aiassistant.features.assistant_shell.navigateBackFromAssistantNormalCall

internal class AssistantCallPageHostArgs(
    val currentPage: FinalPage,
    val callList: CallListPageHostArgs,
    val callDetail: AgentCallDetailPageHostArgs,
    val aiCall: AiCallPageHostArgs,
    val result: CallResultPageHostArgs,
    val normalCall: NormalCallPageHostArgs,
    val translateCall: TranslateCallPageHostArgs
)

internal fun buildAssistantCallPageHostArgs(
    targetPage: FinalPage,
    navigation: PageHostNavigationArgs,
    call: CallPageArgs,
    assistantUiState: Index9AssistantUiState,
    pureVoiceMode: Boolean
): AssistantCallPageHostArgs = with(call) {
    val normalCallNavigationState = AssistantNormalCallNavigationState(
        pureVoiceMode = pureVoiceMode,
        normalCallReturnPage = normalCallReturnPage
    )
    val normalCallNavigationCallbacks = AssistantNormalCallNavigationCallbacks(
        onPageChange = navigation.onPageChange,
        onMainTabChange = navigation.onMainTabChange
    )
    AssistantCallPageHostArgs(
        currentPage = targetPage,
        callList = CallListPageHostArgs(
            records = visibleCallRecords,
            onOpenRecord = onOpenCallRecord
        ),
        callDetail = AgentCallDetailPageHostArgs(
            record = selectedCallRecord ?: visibleCallRecords.firstOrNull(),
            onBack = onBackCallDetail,
            onDial = onDialCallRecord,
            onReturnTask = onReturnTaskFromCallDetail
        ),
        aiCall = AiCallPageHostArgs(
            selectedRestaurantTitle = selectedRestaurantTitle,
            assistantUiState = assistantUiState,
            seconds = aiCallSeconds,
            onHangup = onAiHangup,
            onMonitorToggle = onAiMonitorToggle,
            onAudioRouteSelect = onAiAudioRouteSelect
        ),
        result = CallResultPageHostArgs(
            selectedRestaurantTitle = selectedRestaurantTitle,
            assistantUiState = assistantUiState,
            resultCallId = resultCallId,
            aiModelInFlight = resultAiModelInFlight,
            onBackHome = onBackResultHome,
            onShare = onShareResult,
            onAiModelCallContact = onAiModelCallContact
        ),
        normalCall = NormalCallPageHostArgs(
            phoneNumber = formatDialNumber(lastDialedNumber.ifBlank { dialInput }),
            seconds = normalCallSeconds,
            muted = normalCallMuted,
            speakerEnabled = normalCallSpeaker,
            onBack = {
                navigateBackFromAssistantNormalCall(
                    state = normalCallNavigationState,
                    callbacks = normalCallNavigationCallbacks
                )
            },
            onMuteToggle = { onNormalMutedChange(!normalCallMuted) },
            onSpeakerToggle = { onNormalSpeakerChange(!normalCallSpeaker) },
            onHangup = {
                val appLanguage = AppLanguageManager.currentAppLanguage()
                val targetNumber = lastDialedNumber.ifBlank { dialInput }.ifBlank {
                    "未知号码".appText(appLanguage, "Unknown Number")
                }
                val nowText = "刚刚".appText(appLanguage, "Just now")
                val callEndedText = "普通通话结束".appText(appLanguage, "Regular call ended")
                val durationText = "时长".appText(appLanguage, "Duration")
                val metaSeparator = "，".appText(appLanguage, ", ")
                val nowMeta = "$nowText · $callEndedText$metaSeparator$durationText ${formatSeconds(normalCallSeconds)}"
                val occurredAtMillis = System.currentTimeMillis()
                onAppendCallRecord(
                    FinalCallRecord(
                        title = "拨打 ${formatDialNumber(targetNumber)}".appText(
                            appLanguage,
                            "Call ${formatDialNumber(targetNumber)}"
                        ),
                        status = "普通通话".appText(appLanguage, "Regular Call"),
                        meta = nowMeta,
                        success = true,
                        occurredAtMillis = occurredAtMillis,
                        phoneNumber = targetNumber,
                        durationText = formatSeconds(normalCallSeconds),
                        resultText = nowMeta,
                        callKind = DialCallKind.NORMAL
                    )
                )
                navigateAfterAssistantNormalCallHangup(
                    state = normalCallNavigationState,
                    callbacks = normalCallNavigationCallbacks
                )
            }
        ),
        translateCall = TranslateCallPageHostArgs(
            phoneNumber = formatDialNumber(lastDialedNumber.ifBlank { dialInput }),
            seconds = translateCallSeconds,
            status = translationCallStatus?.localizedForUi(),
            error = translationCallError,
            audioChannelStatus = localizeTranslationCallStatusText(translationAudioChannelStatus),
            muted = translateCallMuted,
            speakerEnabled = translateCallSpeaker,
            panelCollapsed = translateCallPanelCollapsed,
            onMuteToggle = onTranslateMuteToggle,
            onSpeakerToggle = onTranslateSpeakerToggle,
            onPanelToggle = onTranslatePanelToggle,
            onHangup = onTranslateHangup
        )
    )
}

internal class CallListPageHostArgs(
    val records: List<FinalCallRecord>,
    val onOpenRecord: (FinalCallRecord) -> Unit
)

internal class AgentCallDetailPageHostArgs(
    val record: FinalCallRecord?,
    val onBack: () -> Unit,
    val onDial: (FinalCallRecord) -> Unit,
    val onReturnTask: (FinalCallRecord) -> Unit
)

internal class AiCallPageHostArgs(
    val selectedRestaurantTitle: String?,
    val assistantUiState: Index9AssistantUiState,
    val seconds: Int,
    val onHangup: () -> Unit,
    val onMonitorToggle: () -> Unit,
    val onAudioRouteSelect: (CallMonitorAudioRoute) -> Unit
)

internal class CallResultPageHostArgs(
    val selectedRestaurantTitle: String?,
    val assistantUiState: Index9AssistantUiState,
    val resultCallId: String,
    val aiModelInFlight: Boolean,
    val onBackHome: () -> Unit,
    val onShare: () -> Unit,
    val onAiModelCallContact: () -> Unit
)

internal class NormalCallPageHostArgs(
    val phoneNumber: String,
    val seconds: Int,
    val muted: Boolean,
    val speakerEnabled: Boolean,
    val onBack: () -> Unit,
    val onMuteToggle: () -> Unit,
    val onSpeakerToggle: () -> Unit,
    val onHangup: () -> Unit
)

internal class TranslateCallPageHostArgs(
    val phoneNumber: String,
    val seconds: Int,
    val status: TranslationCallStatusResponse?,
    val error: String?,
    val audioChannelStatus: String?,
    val muted: Boolean,
    val speakerEnabled: Boolean,
    val panelCollapsed: Boolean,
    val onMuteToggle: () -> Unit,
    val onSpeakerToggle: () -> Unit,
    val onPanelToggle: () -> Unit,
    val onHangup: () -> Unit
)
