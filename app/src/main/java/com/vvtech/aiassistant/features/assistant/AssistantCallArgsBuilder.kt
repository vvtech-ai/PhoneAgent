package com.vvtech.aiassistant.features.assistant

internal class AssistantCallArgsBuilderInput(
    val ai: AssistantCallAiInput,
    val normal: AssistantNormalCallInput,
    val callbacks: AssistantCallCallbacksInput
)

internal class AssistantCallAiInput(
    val visibleCallRecords: List<FinalCallRecord>,
    val selectedCallRecord: FinalCallRecord?,
    val selectedRestaurantTitle: String?,
    val aiCallSeconds: Int,
    val resultCallId: String,
    val resultAiModelInFlight: Boolean
)

internal class AssistantNormalCallInput(
    val lastDialedNumber: String,
    val dialInput: String,
    val normalCallSeconds: Int,
    val normalCallMuted: Boolean,
    val normalCallSpeaker: Boolean,
    val normalCallReturnPage: String
)

internal class AssistantCallCallbacksInput(
    val onAiHangup: () -> Unit,
    val onAiMonitorToggle: () -> Unit,
    val onAiAudioRouteSelect: (CallMonitorAudioRoute) -> Unit,
    val onBackResultHome: () -> Unit,
    val onShareResult: () -> Unit,
    val onAiModelCallContact: () -> Unit,
    val onOpenCallRecord: (FinalCallRecord) -> Unit,
    val onBackCallDetail: () -> Unit,
    val onDialCallRecord: (FinalCallRecord) -> Unit,
    val onReturnTaskFromCallDetail: (FinalCallRecord) -> Unit,
    val onNormalMutedChange: (Boolean) -> Unit,
    val onNormalSpeakerChange: (Boolean) -> Unit,
    val onAppendCallRecord: (FinalCallRecord) -> Unit,
    val onApplyTranslationCallArgs: (CallPageArgs) -> Unit
)

internal fun buildAssistantCallArgs(
    input: AssistantCallArgsBuilderInput
): CallPageArgs = CallPageArgs().also { args ->
    with(input.ai) {
        args.visibleCallRecords = visibleCallRecords
        args.selectedCallRecord = selectedCallRecord
        args.selectedRestaurantTitle = selectedRestaurantTitle
        args.aiCallSeconds = aiCallSeconds
        args.resultCallId = resultCallId
        args.resultAiModelInFlight = resultAiModelInFlight
    }
    with(input.callbacks) {
        args.onAiHangup = onAiHangup
        args.onAiMonitorToggle = onAiMonitorToggle
        args.onAiAudioRouteSelect = onAiAudioRouteSelect
        args.onBackResultHome = onBackResultHome
        args.onShareResult = onShareResult
        args.onAiModelCallContact = onAiModelCallContact
        args.onOpenCallRecord = onOpenCallRecord
        args.onBackCallDetail = onBackCallDetail
        args.onDialCallRecord = onDialCallRecord
        args.onReturnTaskFromCallDetail = onReturnTaskFromCallDetail
    }
    with(input.normal) {
        args.lastDialedNumber = lastDialedNumber
        args.dialInput = dialInput
        args.normalCallSeconds = normalCallSeconds
        args.normalCallMuted = normalCallMuted
        args.normalCallSpeaker = normalCallSpeaker
        args.normalCallReturnPage = normalCallReturnPage
    }
    with(input.callbacks) {
        args.onNormalMutedChange = onNormalMutedChange
        args.onNormalSpeakerChange = onNormalSpeakerChange
        args.onAppendCallRecord = onAppendCallRecord
        onApplyTranslationCallArgs(args)
    }
}
