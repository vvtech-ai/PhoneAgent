package com.vvtech.aiassistant.features.assistant_settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.VoiceCloneGroupCard
import com.vvtech.aiassistant.features.assistant.finalHasUploadedVoiceClone
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneAvailabilityPolicy
import java.util.Locale

@Composable
internal fun AssistantRealtimeCallCloneVoiceSection(
    state: AssistantRealtimeCallVoiceSettingsPageState,
    callbacks: AssistantRealtimeCallVoiceSettingsPageCallbacks
) {
    val status = state.cloneStatus
    val statusName = status?.status?.uppercase(Locale.ROOT).orEmpty()
    val hasClone = finalHasUploadedVoiceClone(status)
    val cloneReady = statusName == "READY"
    val enrollmentAvailable = VoiceCloneAvailabilityPolicy.canEnroll(status)
    val selected = state.response?.selectionMode.equals("CLONE", ignoreCase = true)
    val presentation = realtimeCallCloneVoicePresentation(status?.status, selected)

    Column {
        if (state.cloneLoading && status == null) {
            Text(
                text = "正在读取克隆音色状态...",
                modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                color = Color(0xFF6E6E73),
                fontSize = 13.sp
            )
        }
        if (VoiceCloneAvailabilityPolicy.shouldShowEntry(status, hasClone)) {
            VoiceCloneGroupCard(
                selected = selected,
                status = presentation.statusText,
                detail = realtimeCallCloneVoiceDetail(
                    status = status?.status,
                    hasClone = hasClone,
                    lastError = status?.lastError
                ),
                actionLabel = presentation.actionText,
                enabled = !state.cloneLoading &&
                    !state.cloneActionLoading &&
                    !state.switching &&
                    (cloneReady || enrollmentAvailable),
                showAction = presentation.actionText.isNotBlank(),
                onSelect = {
                    if (hasClone && cloneReady) {
                        callbacks.onSelectCloneVoice()
                    } else if (enrollmentAvailable) {
                        callbacks.onStartClone()
                    }
                },
                onAction = callbacks.onStartClone
            )
        }
        if (!state.cloneError.isNullOrBlank()) {
            Text(
                text = state.cloneError,
                modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                color = Color(0xFFE14D46),
                fontSize = 13.sp,
                lineHeight = 18.sp
            )
        }
    }
}
