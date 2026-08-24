package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.OutlinedTextField
import androidx.compose.material.AlertDialog
import androidx.compose.material.TextButton
import androidx.compose.material.Text
import androidx.compose.material.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.VoiceAccentBlue
import com.vvtech.aiassistant.features.assistant.VoiceCard
import com.vvtech.aiassistant.features.assistant.VoicePrimaryButton
import com.vvtech.aiassistant.features.assistant.VoiceTextPrimary
import com.vvtech.aiassistant.features.assistant.VoiceTextSecondary
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal const val voiceCloneReadAloudGuidance =
    "请使用正常语速，连续清晰地读完整句话；数字按中文读音读出，例如 7 读作“七”。"

private fun localizedVoiceCloneReadAloudGuidance(): String = currentAppText(
    voiceCloneReadAloudGuidance,
    "Read the full sentence clearly at a natural pace. Read numbers aloud in Chinese, for example 7 as \"qi\"."
)

internal data class VoiceCloneEnrollmentUiArgs(
    val state: VoiceCloneEnrollmentState,
    val onAgreementChange: (Boolean) -> Unit,
    val onContinueConsent: () -> Unit,
    val onIdentityChange: (String, String) -> Unit,
    val onIdentityEditStarted: (VoiceCloneIdentityFieldKind) -> Unit,
    val onPrepareVerification: (() -> Unit) -> Unit,
    val onConfirmReplacement: (() -> Unit) -> Unit,
    val onDismissReplacement: () -> Unit,
    val onStartVerification: () -> Unit,
    val onVerificationPermissionDenied: () -> Unit
)

@Composable
internal fun VoiceCloneEnrollmentContent(args: VoiceCloneEnrollmentUiArgs) {
    val startVerification = rememberMfvcVerificationPermissionGate(
        onGranted = args.onStartVerification,
        onDenied = args.onVerificationPermissionDenied
    )
    when (args.state.step) {
        VoiceCloneEnrollmentStep.CONSENT -> VoiceCloneConsentStep(args)
        VoiceCloneEnrollmentStep.IDENTITY -> VoiceCloneIdentityStep(
            args = args,
            startVerification = startVerification
        )
        VoiceCloneEnrollmentStep.VERIFYING -> VoiceCloneVerifyingStep(args.state)
        VoiceCloneEnrollmentStep.CLONING -> VoiceCloneCloningStep(args.state)
        VoiceCloneEnrollmentStep.VERIFIED -> Unit
    }
}

@Composable
private fun VoiceCloneIdentityStep(
    args: VoiceCloneEnrollmentUiArgs,
    startVerification: () -> Unit
) {
    val state = args.state
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        PrototypeSmallHint(
            currentAppText(
                "请填写本人真实姓名和身份证号",
                "Enter your legal name and Resident ID number."
            )
        )
        VoiceCard(
            modifier = Modifier.fillMaxWidth(),
            color = Color.White,
            borderColor = Color(0xFFF0F2F6),
            shadow = false
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                VoiceCloneIdentityField(
                    label = currentAppText("姓名", "Name"),
                    value = state.displayRealName,
                    placeholder = currentAppText("请输入姓名", "Enter name"),
                    enabled = !state.busy,
                    onEditStarted = {
                        args.onIdentityEditStarted(VoiceCloneIdentityFieldKind.REAL_NAME)
                    },
                    onValueChange = { args.onIdentityChange(it, state.idCardNumber) }
                )
                VoiceCloneIdentityField(
                    label = currentAppText("身份证号", "ID Number"),
                    value = state.displayIdCardNumber,
                    placeholder = currentAppText("请输入身份证号", "Enter your Resident ID number"),
                    enabled = !state.busy,
                    keyboardType = KeyboardType.Ascii,
                    onEditStarted = {
                        args.onIdentityEditStarted(VoiceCloneIdentityFieldKind.ID_CARD)
                    },
                    onValueChange = { args.onIdentityChange(state.realName, it.take(18)) }
                )
            }
        }
        EnrollmentError(state.errorMessage)
        Text(
            currentAppText(
                "提交后将进入阿里云人脸与跟读认证。同一次跟读会同时用于声音克隆，不会再次要求录音。",
                "After submission, you will enter Aliyun face and read-aloud verification. The same read-aloud session is used for voice cloning, so no separate recording is required."
            ),
            color = VoiceTextSecondary,
            fontSize = 13.sp,
            lineHeight = 21.sp
        )
        VoicePrimaryButton(
            text = if (state.busy) {
                currentAppText("正在准备认证…", "Preparing verification...")
            } else {
                currentAppText("开始人脸跟读认证", "Start Face & Voice Verification")
            },
            enabled = !state.busy,
            onClick = { args.onPrepareVerification(startVerification) }
        )
    }
    if (state.replacementConfirmationRequired) {
        VoiceCloneIdentityReplacementDialog(
            onDismiss = args.onDismissReplacement,
            onConfirm = { args.onConfirmReplacement(startVerification) }
        )
    }
}

@Composable
private fun VoiceCloneIdentityReplacementDialog(
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                currentAppText("替换当前认证身份？", "Replace the current verified identity?"),
                fontWeight = FontWeight.Bold
            )
        },
        text = {
            Text(
                currentAppText(
                    "检测到本次认证人与当前已认证身份不是同一人。继续后，仅在新身份认证成功时更新身份信息，并使原身份创建的克隆音色不可用。",
                    "The person in this verification does not match the currently verified identity. Continuing will update the identity only if the new verification succeeds, and cloned voices created by the old identity will become unavailable."
                )
            )
        },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(
                    currentAppText("继续并替换", "Continue and Replace"),
                    color = Color(0xFFE14D46),
                    fontWeight = FontWeight.Bold
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(currentAppText("取消", "Cancel"), color = VoiceTextPrimary)
            }
        }
    )
}

@Composable
private fun VoiceCloneVerifyingStep(state: VoiceCloneEnrollmentState) {
    val collectionFinished =
        state.verificationPhase == VoiceCloneVerificationPhase.RESULT_CHECKING
    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
        PrototypeSmallHint(
            if (collectionFinished) {
                currentAppText("人脸与跟读采集已完成", "Face and read-aloud capture complete")
            } else {
                currentAppText(
                    "请按阿里云页面提示保持本人正脸并准确跟读",
                    "Follow the Aliyun page instructions: keep your face centered and read aloud accurately"
                )
            }
        )
        VoiceCard(
            modifier = Modifier.fillMaxWidth(),
            color = Color(0xFFF8FAFC),
            borderColor = Color(0xFFE8ECF3),
            shadow = false
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    currentAppText("请朗读以下内容：", "Please read the following:"),
                    color = VoiceTextSecondary,
                    fontSize = 13.sp
                )
                Text(
                    state.scriptText.orEmpty(),
                    color = VoiceTextPrimary,
                    fontSize = 16.sp,
                    lineHeight = 25.sp,
                    fontWeight = FontWeight.Medium
                )
                Text(
                    localizedVoiceCloneReadAloudGuidance(),
                    color = VoiceTextSecondary,
                    fontSize = 12.sp,
                    lineHeight = 18.sp
                )
            }
        }
        VoiceCloneVerificationCard(
            status = state.errorMessage ?: if (collectionFinished) {
                currentAppText(
                    "采集已完成，正在核验认证结果并生成克隆音色，请稍候…",
                    "Capture complete. Verifying results and creating your cloned voice..."
                )
            } else {
                currentAppText(
                    "正在进行人脸与跟读采集，请按阿里云页面提示完成操作…",
                    "Face and read-aloud capture is in progress. Follow the Aliyun page instructions..."
                )
            },
            error = !state.errorMessage.isNullOrBlank()
        )
    }
}

@Composable
private fun VoiceCloneCloningStep(state: VoiceCloneEnrollmentState) {
    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
        PrototypeSmallHint(currentAppText("人脸与跟读认证已通过", "Face and read-aloud verification passed"))
        VoiceCloneVerificationCard(
            status = state.errorMessage ?: currentAppText(
                "正在使用本次跟读生成克隆音色，请稍候…",
                "Creating your cloned voice from this read-aloud session..."
            ),
            error = !state.errorMessage.isNullOrBlank()
        )
    }
}

@Composable
private fun PrototypeSmallHint(text: String) {
    Text(
        text = text,
        modifier = Modifier.fillMaxWidth(),
        color = Color(0xFFB0B4C3),
        fontSize = 12.sp,
        lineHeight = 17.sp,
        textAlign = TextAlign.Center
    )
}

@Composable
private fun VoiceCloneIdentityField(
    label: String,
    value: String,
    placeholder: String,
    enabled: Boolean,
    keyboardType: KeyboardType = KeyboardType.Text,
    onEditStarted: () -> Unit,
    onValueChange: (String) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, color = Color(0xFF8B8FA3), fontSize = 13.sp)
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .fillMaxWidth()
                .onFocusChanged { if (it.isFocused) onEditStarted() },
            placeholder = { Text(placeholder, color = Color(0xFFB0B4C3)) },
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            singleLine = true,
            enabled = enabled,
            shape = RoundedCornerShape(12.dp),
            colors = TextFieldDefaults.outlinedTextFieldColors(
                backgroundColor = Color(0xFFF8FAFC),
                focusedBorderColor = VoiceAccentBlue,
                unfocusedBorderColor = Color.Transparent,
                disabledBorderColor = Color.Transparent
            )
        )
    }
}

@Composable
private fun EnrollmentError(message: String?) {
    if (!message.isNullOrBlank()) {
        Text(message, color = Color(0xFFE14D46), fontSize = 13.sp, lineHeight = 18.sp)
    }
}
