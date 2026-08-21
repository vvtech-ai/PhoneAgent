package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import com.vvtech.aiassistant.data.repository.voiceclone.VoiceCloneEnrollmentRepository
import com.vvtech.aiassistant.data.local.voiceclone.AndroidVoiceCloneVerificationEnvironmentProvider
import com.vvtech.aiassistant.features.assistant_voice_clone.AssistantVoiceCloneRecordingController
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneRecordingWatchdog
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneSubmissionState
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.AliyunIdProSdkAdapter
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentCoordinator
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentState
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneIdentityPrefill
import com.vvtech.aiassistant.features.assistant_voice_clone.face.FacePresenceSnapshot
import com.vvtech.aiassistant.features.assistant_voice_clone.face.FacePresenceTracker
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.model.VoiceCloneScriptItem
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import com.vvtech.aiassistant.repository.TaskRepository
import kotlinx.coroutines.CoroutineScope

@Composable
internal fun rememberAssistantVoiceCloneRuntimeController(
    context: Context,
    prefs: SharedPreferences,
    scope: CoroutineScope,
    taskRepository: TaskRepository,
    enrollmentRepository: VoiceCloneEnrollmentRepository,
    identityPrefillLoader: suspend () -> VoiceCloneIdentityPrefill?,
    onIdentityVerified: () -> Unit,
    callbacks: AssistantVoiceCloneRuntimeCallbacks
): AssistantVoiceCloneRuntimeController {
    val state = rememberVoiceCloneRuntimeState(prefs)
    val recorder = remember(context) { VoiceCloneRecorder(context) }
    val previewPlayer = remember(context) { VoiceCloneAudioPreviewPlayer(context) }
    val faceTracker = remember { FacePresenceTracker() }
    val watchdog = remember(scope) { VoiceCloneRecordingWatchdog(scope) }
    val recording = remember(context, state, recorder, previewPlayer, faceTracker, watchdog) {
        AssistantVoiceCloneRecordingController(
            context, state, recorder, previewPlayer, faceTracker, watchdog
        )
    }
    val controllerHolder = remember {
        arrayOfNulls<AssistantVoiceCloneRuntimeController>(1)
    }
    val enrollment = remember(
        context,
        scope,
        enrollmentRepository,
        state.enrollment,
        controllerHolder
    ) {
        VoiceCloneEnrollmentCoordinator(
            context,
            scope,
            enrollmentRepository,
            AliyunIdProSdkAdapter(),
            AndroidVoiceCloneVerificationEnvironmentProvider(context),
            state.enrollment,
            identityPrefillLoader,
            onIdentityVerified
        ) { response ->
            controllerHolder[0]?.onMfvcCloneAccepted(response)
        }
    }
    val completionActivation = remember(state, enrollment) {
        VoiceCloneCompletionActivationHandler(state, enrollment::activateCompletedClone)
    }
    val flowOpenHandler = remember(scope, taskRepository, state) {
        AssistantVoiceCloneFlowOpenHandler(
            scope,
            taskRepository::getVoiceCloneStatus,
            state
        )
    }
    val controller = remember(
        context,
        prefs,
        scope,
        taskRepository,
        recording,
        enrollment,
        completionActivation,
        flowOpenHandler
    ) {
        AssistantVoiceCloneRuntimeController(
            AssistantVoiceCloneRuntimeDeps(context, prefs, scope, taskRepository, enrollmentRepository),
            state,
            recording,
            enrollment,
            completionActivation,
            flowOpenHandler
        )
    }
    controllerHolder[0] = controller
    recording.onCollectionInvalidated = {
        controller.terminateAndReset(currentAppText(
            "本次人脸跟读认证已失效，请重新开始。",
            "This face and read-aloud verification has expired. Please start again."
        ))
    }
    recording.onTerminalInterrupted = controller::terminateAndReset
    controller.callbacks = callbacks
    return controller
}

@Composable
private fun rememberVoiceCloneRuntimeState(prefs: SharedPreferences) = AssistantVoiceCloneRuntimeState(
    guideSkipped = rememberSaveable { mutableStateOf(false) },
    guideDisabled = rememberSaveable {
        mutableStateOf(prefs.getBoolean(FinalVoiceCloneGuideDisabledKey, false))
    },
    forceGuide = rememberSaveable { mutableStateOf(false) },
    showGuide = rememberSaveable { mutableStateOf(false) },
    status = remember { mutableStateOf<VoiceCloneStatusResponse?>(null) },
    scripts = remember { mutableStateOf<List<VoiceCloneScriptItem>>(emptyList()) },
    scriptsVersion = remember { mutableStateOf("") },
    loading = remember { mutableStateOf(false) },
    uploading = remember { mutableStateOf(false) },
    actionLoading = remember { mutableStateOf(false) },
    error = remember { mutableStateOf<String?>(null) },
    samples = remember { mutableStateOf<Map<String, VoiceCloneLocalSample>>(emptyMap()) },
    recordingScriptId = remember { mutableStateOf<String?>(null) },
    pendingRecordScriptId = remember { mutableStateOf<String?>(null) },
    rerecordMode = remember { mutableStateOf(false) },
    enrollment = remember { mutableStateOf(VoiceCloneEnrollmentState()) },
    submissionState = remember { mutableStateOf(VoiceCloneSubmissionState.IDLE) },
    currentScriptIndex = remember { mutableStateOf(0) },
    playingScriptId = remember { mutableStateOf<String?>(null) },
    facePresence = remember { mutableStateOf(FacePresenceSnapshot()) }
)
