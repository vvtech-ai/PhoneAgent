package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.logging.AppFileLogger

import com.vvtech.aiassistant.core.model.VoiceClientDiagnosticRequest
import com.vvtech.aiassistant.network.NetworkModule
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

internal object VoiceClientDiagnosticsReporter {

    private const val TAG = "VoiceDiagReporter"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun report(request: VoiceClientDiagnosticRequest) {
        scope.launch {
            runCatching {
                NetworkModule.assistantApiService.reportVoiceClientDiagnostic(request)
            }.onFailure { throwable ->
                AppFileLogger.w(TAG, "report failed: ${throwable.message}", throwable)
            }
        }
    }
}
