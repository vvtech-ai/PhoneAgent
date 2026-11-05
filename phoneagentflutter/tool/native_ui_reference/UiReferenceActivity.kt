package com.vvtech.aiassistant.uireference

import android.os.Bundle
import com.vvtech.aiassistant.features.assistant.PureVoiceState
import com.vvtech.aiassistant.features.points.PointsWalletScreen
import com.vvtech.aiassistant.features.points.PointsWalletUiState
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.AssistantSystemBarChromeEffect
import com.vvtech.aiassistant.domain.translation.*
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Surface
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.ui.theme.AIAssistantTheme
import com.vvtech.aiassistant.features.assistant_ui.AssistantTaskCard
import com.vvtech.aiassistant.features.assistant_ui.AssistantTaskInitialLoading
import com.vvtech.aiassistant.features.assistant_ui.AssistantTaskSyncStatusRow
import com.vvtech.aiassistant.features.invite.InviteActivityInfo
import com.vvtech.aiassistant.features.invite.InviteRulesSheet
import com.vvtech.aiassistant.features.translation_call.ui.TranslationCallScreen
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallUiState
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallPhase
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallTranscriptItem

/** Debug-only component reference; no repository, SDK, account or device action. */
class UiReferenceActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val scene = intent.getStringExtra("scene") ?: "tasks"
        setContent {
            AIAssistantTheme {
                if (scene.startsWith("translation")) AssistantSystemBarChromeEffect(FinalPage.TranslateCall)
                else if (scene == "wallet") AssistantSystemBarChromeEffect(FinalPage.PointsWallet)
                else if (scene.startsWith("ledger")) AssistantSystemBarChromeEffect(FinalPage.PointsLedger)
                else if (scene.startsWith("contacts") || scene.startsWith("clone-result") || scene == "settings" || scene == "models" || scene == "voices" || scene == "original-audio" || scene.startsWith("identity") || scene.startsWith("clone-consent") || scene.startsWith("clone-identity") || scene.startsWith("clone-collecting") || scene.startsWith("clone-checking") || scene.startsWith("clone-generating") || scene.startsWith("clone-processing")) AssistantSystemBarChromeEffect(FinalPage.Settings)
                when (scene) {
                    "options" -> OptionsReference()
                    "document" -> DocumentReference()
                    "batch-result" -> BatchResultReference()
                    "batch-result-transcript" -> BatchResultReference(withTranscript = true)
                    "conversation-opening" -> ConversationOpeningReference()
                    "conversation-voice-press" -> ConversationVoicePressReference()
                    "conversation-voice-finalizing" -> ConversationHeaderReference(showFinalizing = true)
                    "conversation-model" -> ConversationHeaderReference(showModel = true)
                    "conversation-wave-listening" -> ConversationHeaderReference(showWave = true, waveState = PureVoiceState.Listening)
                    "conversation-wave-speaking" -> ConversationHeaderReference(showWave = true, waveState = PureVoiceState.AiSpeaking)
                    "conversation-wave" -> ConversationHeaderReference(showWave = true)
                    "conversation-header" -> ConversationHeaderReference()
                    "conversation-header-clarification" -> ConversationHeaderReference(2)
                    "conversation-header-execution" -> ConversationHeaderReference(3)
                    "conversation-header-result" -> ConversationHeaderReference(4)
                    "contacts-permission" -> ContactsPermissionReference(false)
                    "contacts-permission-settings" -> ContactsPermissionReference(true)
                    "contacts-skills", "contacts-skills-empty", "contacts-skills-loading" -> ContactsSkillsReference(scene)
                    "contacts-remark", "contacts-remark-filled", "contacts-remark-busy", "contacts-remark-error" -> ContactsRemarkReference(scene)
                    "contacts", "contacts-empty", "contacts-detail", "contacts-detail-loading", "contacts-detail-saved" -> ContactsReference(scene)
                    "clone-result", "clone-result-playing", "clone-result-busy", "clone-result-error" -> CloneResultReference(scene) { finish() }
                    "clone-collecting", "clone-checking", "clone-generating", "clone-processing-error" -> CloneProcessingReference(scene) { finish() }
                    "clone-identity", "clone-identity-verified", "clone-identity-error" -> CloneIdentityReference(scene) { finish() }
                    "clone-consent", "clone-consent-agreed", "clone-consent-busy" -> CloneConsentReference(scene) { finish() }
                    "identity", "identity-verified", "identity-empty", "identity-loading", "identity-error" -> IdentityReference(scene) { finish() }
                    "original-audio" -> OriginalAudioReference { finish() }
                    "translation", "translation-subtitles", "translation-international" -> TranslationCallScreen(
                        state = TranslationCallUiState(
                            targetDisplayName = "合成翻译对象",
                            plan = if (scene == "translation-international") TranslationCallPlan(
                                locationCountryIso = "US", locationSource = TranslationRegionSource.LiveLocation,
                                targetE164 = "+12025550123", transport = TranslationCallTransport.BackendWebRtc,
                                provider = TranslationRealtimeProvider.Gemini, sipAccountId = null,
                                serviceRegion = TranslationServiceRegion.UnitedStates
                            ) else null,
                            phase = TranslationCallPhase.Translating,
                            elapsedSeconds = 65,
                            speakerEnabled = false,
                            transcripts = if (scene != "translation") listOf(
                                TranslationCallTranscriptItem("1", "user", "zh", "请问几点营业？", "en", "What time do you open?", true),
                                TranslationCallTranscriptItem("2", "merchant", "en", "We open at nine.", "zh", "我们九点营业。", true)
                            ) else emptyList()
                        ),
                        onAction = {}
                    )
                    "wallet" -> PointsWalletScreen(
                        state = PointsWalletUiState(
                            availableBalance = 900, totalBalance = 900,
                            todayDailyGrantPoints = 100, balanceAvailable = true
                        ), onBack = { finish() }, onOpenLedger = {}, onRefresh = {}
                    )
                    "ledger", "ledger-empty", "ledger-loading", "ledger-error" ->
                        LedgerReference(scene) { finish() }
                    "settings" -> SettingsReference()
                    "models" -> ModelsReference { finish() }
                    "voices" -> VoicesReference { finish() }
                    "rules-modal" -> RulesReference { finish() }
                    "rules" -> Surface(color = Color.White) {
                        InviteRulesSheet(
                            InviteActivityInfo(
                                periodId = "synthetic", name = "合成活动", quota = 8,
                                inviterPoints = 0, inviteePoints = 0, bonusEnabled = false,
                                bonusThreshold = 0, bonusPoints = 0,
                                rules = "1. 仅限新用户。\n2. 积分以实际到账为准。"
                            ),
                            close = { finish() }
                        )
                    }
                    else -> Column(
                        Modifier.fillMaxSize().background(Color(0xFFFBFCFD))
                            .verticalScroll(rememberScrollState()).padding(28.dp)
                    ) {
                        AssistantTaskCard(
                            title = "MOCK · 单路回执与评分", detail = "9月20日 09:00",
                            statusLabel = "已完成", statusColor = Color(0xFF1F8F46), onClick = {}
                        )
                        Spacer(Modifier.height(10.dp))
                        AssistantTaskSyncStatusRow("正在同步...", "任务列表会自动更新", false, null)
                        Spacer(Modifier.height(10.dp))
                        AssistantTaskSyncStatusRow("同步失败，点击重试", "部分任务同步失败（保留上次数据）", true, {})
                        AssistantTaskInitialLoading()
                    }
                }
            }
        }
    }
}
