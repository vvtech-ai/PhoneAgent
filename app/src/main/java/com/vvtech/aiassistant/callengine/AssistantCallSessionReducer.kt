package com.vvtech.aiassistant.callengine

internal enum class AssistantCallSignal {
    START,
    REGISTERED,
    RINGING,
    CONNECTED,
    TRANSLATION_READY,
    LOCAL_ENDED,
    REMOTE_ENDED,
    SIGNAL_FAILED,
    MEDIA_FAILED
}

internal class AssistantCallSessionReducer(
    private val translation: Boolean = false
) {
    private var phase = AssistantCallPhase.IDLE
    private var terminalPublished = false

    fun reduce(signal: AssistantCallSignal): AssistantCallSnapshot {
        val previous = phase
        phase = nextPhase(signal)
        val enteredTerminal = phase.isTerminal() && !previous.isTerminal() && !terminalPublished
        if (enteredTerminal) terminalPublished = true
        return AssistantCallSnapshot(
            mode = if (translation) AssistantCallMode.TRANSLATION else AssistantCallMode.NORMAL,
            phase = phase,
            terminalTransition = enteredTerminal
        )
    }

    private fun nextPhase(signal: AssistantCallSignal): AssistantCallPhase {
        if (phase.isTerminal()) return phase
        return when (signal) {
            AssistantCallSignal.START -> AssistantCallPhase.REGISTERING
            AssistantCallSignal.REGISTERED -> AssistantCallPhase.DIALING
            AssistantCallSignal.RINGING -> AssistantCallPhase.RINGING
            AssistantCallSignal.CONNECTED -> AssistantCallPhase.CONNECTED
            AssistantCallSignal.TRANSLATION_READY ->
                if (translation && phase == AssistantCallPhase.CONNECTED) {
                    AssistantCallPhase.TRANSLATING
                } else {
                    phase
                }
            AssistantCallSignal.LOCAL_ENDED,
            AssistantCallSignal.REMOTE_ENDED -> AssistantCallPhase.ENDED
            AssistantCallSignal.SIGNAL_FAILED,
            AssistantCallSignal.MEDIA_FAILED -> AssistantCallPhase.FAILED
        }
    }

    private fun AssistantCallPhase.isTerminal(): Boolean =
        this == AssistantCallPhase.ENDED || this == AssistantCallPhase.FAILED
}
