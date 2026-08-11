package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Checkbox
import androidx.compose.material.CheckboxDefaults
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.rounded.Check
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.model.VoiceCloneScriptItem
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentStep
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentUiArgs
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentContent
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneDoneStep
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneFlowTopBar
import com.vvtech.aiassistant.features.assistant_voice_clone.face.VoiceCloneFaceUiArgs
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneAvailabilityPolicy
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneSubmissionState
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneStepTitlePolicy
import java.util.Locale
import kotlinx.coroutines.delay

@Composable
internal fun FinalVoiceIdentityPageV3(
    status: VoiceCloneStatusResponse?,
    loading: Boolean,
    actionLoading: Boolean,
    error: String?,
    onBack: () -> Unit,
    onSelectAiVoice: () -> Unit,
    onSelectCloneVoice: () -> Unit,
    onStartClone: () -> Unit
) {
    val statusName = status?.status?.uppercase(Locale.ROOT).orEmpty()
    val hasClone = finalHasUploadedVoiceClone(status)
    val cloneReady = statusName == "READY"
    val cloneExpired = statusName == "EXPIRED"
    val cloneSelected = hasClone && cloneReady && status?.active == true
    val enrollmentAvailable = VoiceCloneAvailabilityPolicy.canEnroll(status)
    val cloneStatus = when {
        cloneExpired -> "已过期"
        !hasClone -> "未克隆"
        !cloneReady -> "生成中"
        cloneSelected -> ""
        else -> "已克隆"
    }
    val cloneDetail = when {
        cloneExpired -> status?.lastError?.ifBlank { "旧版本声音样本已过期，请重新录制。" }
            ?: "旧版本声音样本已过期，请重新录制。"
        !hasClone -> "当前语音引擎还没有克隆音色"
        !cloneReady -> "克隆音色正在生成中，完成后可以切换使用"
        else -> "已为当前语音引擎完成克隆"
    }

    Column(modifier = Modifier.fillMaxSize()) {
        VoiceTopBar(
            backLabel = "返回",
            title = "语音",
            onBack = onBack
        )
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 10.dp, end = 10.dp, bottom = 24.dp)
        ) {
            item { Spacer(modifier = Modifier.height(16.dp)) }
            item {
                VoiceChoiceCard(
                    title = "AI 声音",
                    selected = !cloneSelected,
                    enabled = !actionLoading,
                    onClick = onSelectAiVoice
                )
            }
            if (VoiceCloneAvailabilityPolicy.shouldShowEntry(status, hasClone)) item {
                VoiceCloneGroupCard(
                    selected = cloneSelected,
                    status = cloneStatus,
                    detail = cloneDetail,
                    actionLabel = if (hasClone || cloneExpired) "重新录制" else "开始克隆",
                    enabled = !loading && !actionLoading && (cloneReady || enrollmentAvailable),
                    showAction = enrollmentAvailable,
                    onSelect = {
                        when {
                            hasClone && cloneReady -> onSelectCloneVoice()
                            enrollmentAvailable -> onStartClone()
                        }
                    },
                    onAction = onStartClone
                )
            }
            if (!error.isNullOrBlank()) {
                item {
                    Text(
                        text = error,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 12.dp),
                        color = Color(0xFFE14D46),
                        fontSize = 13.sp,
                        lineHeight = 18.sp
                    )
                }
            }
        }
    }
}

@Composable
internal fun FinalVoiceClonePageV3(
    scripts: List<VoiceCloneScriptItem>,
    samples: Map<String, VoiceCloneLocalSample>,
    loading: Boolean,
    uploading: Boolean,
    actionLoading: Boolean,
    error: String?,
    recordingScriptId: String?,
    face: VoiceCloneFaceUiArgs,
    enrollment: VoiceCloneEnrollmentUiArgs,
    submissionState: VoiceCloneSubmissionState,
    currentScriptIndex: Int,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onRecord: (VoiceCloneScriptItem) -> Unit,
    onStop: (VoiceCloneScriptItem) -> Unit,
    onSubmitRecording: () -> Unit,
    onRerecord: () -> Unit,
    onStartUsing: (Boolean) -> Unit
) {
    val stepTitle = VoiceCloneStepTitlePolicy.title(
        enrollmentStep = enrollment.state.step,
        submissionState = submissionState
    )

    Column(modifier = Modifier.fillMaxSize()) {
        VoiceCloneFlowTopBar(
            title = stepTitle,
            onBack = onBack
        )
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 24.dp)
        ) {
            item {
                Spacer(
                    modifier = Modifier.height(
                        if (enrollment.state.step == VoiceCloneEnrollmentStep.CONSENT) 0.dp else 12.dp
                    )
                )
            }
            when {
                enrollment.state.step != VoiceCloneEnrollmentStep.VERIFIED -> item {
                    VoiceCloneEnrollmentContent(enrollment)
                }

                submissionState == VoiceCloneSubmissionState.READY -> item {
                    VoiceCloneDoneStep(
                        actionLoading = actionLoading,
                        onStartUsing = onStartUsing
                    )
                }

                submissionState != VoiceCloneSubmissionState.IDLE -> item {
                    VoiceCloneSubmissionStep(
                        state = submissionState,
                        error = error,
                        onRefresh = onRefresh,
                        onRerecord = onRerecord
                    )
                }

                else -> item {
                    VoiceCloneRecordStep(
                        scripts = scripts,
                        samples = samples,
                        loading = loading,
                        uploading = uploading,
                        error = error,
                        recordingScriptId = recordingScriptId,
                        face = face,
                        currentScriptIndex = currentScriptIndex,
                        onRefresh = onRefresh,
                        onRecord = onRecord,
                        onStop = onStop,
                        onSubmitRecording = onSubmitRecording
                    )
                }
            }
        }
    }
}
