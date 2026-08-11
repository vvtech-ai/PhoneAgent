package com.vvtech.aiassistant

import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material.Surface
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.AssistantRootScreen
import com.vvtech.aiassistant.features.assistant.speech.TtsAudioAttributes
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.MfvcVerificationSession
import com.vvtech.aiassistant.features.assistant_voice_clone.logVoiceCloneRuntime
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.ui.theme.AIAssistantTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (MfvcVerificationSession.shouldSuppressLauncherRelaunch(
                action = intent?.action,
                categories = intent?.categories,
                hasSavedState = savedInstanceState != null
            )
        ) {
            logVoiceCloneRuntime(
                eventType = "VOICE_CLONE_SDK_LAUNCHER_REENTRY_SUPPRESSED",
                result = "suppressed",
                reason = "media_projection_target_launcher",
                provider = "aliyun_mfvc"
            )
            finish()
            return
        }
        volumeControlStream = TtsAudioAttributes.volumeControlStream()
        AppFileLogger.i(
            TAG,
            "TTS_DIAG event=TTS_ROUTE_POLICY provider=android_audio_policy " +
                "policy=${TtsAudioAttributes.routePolicyName()} " +
                "manufacturer=${Build.MANUFACTURER} volumeControlStream=$volumeControlStream"
        )
        setContent {
            AIAssistantTheme {
                Surface(modifier = Modifier) {
                    val assistantViewModel: AssistantViewModel = viewModel()
                    AssistantRootScreen(assistantViewModel = assistantViewModel)
                }
            }
        }
    }

    private companion object {
        const val TAG = "MainActivity"
    }
}
