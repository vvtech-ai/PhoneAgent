package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.MutableState
import com.vvtech.aiassistant.data.repository.voiceclone.VoiceCloneEnrollmentRepository
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentState
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneSubmissionState
import com.vvtech.aiassistant.features.assistant_voice_clone.face.FacePresenceSnapshot
import com.vvtech.aiassistant.model.VoiceCloneScriptItem
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import com.vvtech.aiassistant.repository.TaskRepository
import kotlinx.coroutines.CoroutineScope

internal class AssistantVoiceCloneRuntimeCallbacks(
    val onOpenVoiceCloneSettings: () -> Unit,
    val onOpenVoiceIdentitySettings: () -> Unit
)

internal class AssistantVoiceCloneRuntimeDeps(
    val context: Context,
    val prefs: SharedPreferences,
    val scope: CoroutineScope,
    val taskRepository: TaskRepository,
    val enrollmentRepository: VoiceCloneEnrollmentRepository
)

internal class AssistantVoiceCloneRuntimeState(
    val guideSkipped: MutableState<Boolean>,
    val guideDisabled: MutableState<Boolean>,
    val forceGuide: MutableState<Boolean>,
    val showGuide: MutableState<Boolean>,
    val status: MutableState<VoiceCloneStatusResponse?>,
    val scripts: MutableState<List<VoiceCloneScriptItem>>,
    val scriptsVersion: MutableState<String>,
    val loading: MutableState<Boolean>,
    val uploading: MutableState<Boolean>,
    val actionLoading: MutableState<Boolean>,
    val error: MutableState<String?>,
    val samples: MutableState<Map<String, VoiceCloneLocalSample>>,
    val recordingScriptId: MutableState<String?>,
    val pendingRecordScriptId: MutableState<String?>,
    val rerecordMode: MutableState<Boolean>,
    val enrollment: MutableState<VoiceCloneEnrollmentState>,
    val submissionState: MutableState<VoiceCloneSubmissionState>,
    val currentScriptIndex: MutableState<Int>,
    val playingScriptId: MutableState<String?>,
    val facePresence: MutableState<FacePresenceSnapshot>
)
