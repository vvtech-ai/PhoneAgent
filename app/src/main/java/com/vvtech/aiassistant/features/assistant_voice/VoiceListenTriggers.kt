package com.vvtech.aiassistant.features.assistant_voice

internal object VoiceListenTriggers {
    const val Unspecified = "unspecified"
    const val ManualAsrPress = "manual_asr_press"
    const val AgentErrorRecovery = "agent_error_recovery"
    const val AgentUnknownResponseRecovery = "agent_unknown_response_recovery"
    const val AgentTransportFailureRecovery = "agent_transport_failure_recovery"
    const val SessionAutoResume = "session_auto_resume"
    const val LiveTranscriptionRedirect = "live_transcription_redirect"
    const val EnsureRealtimeSession = "ensure_realtime_session"
}
