package com.vvtech.aiassistant.features.assistant

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.core.content.ContextCompat

internal data class AssistantRootStartupEffectArgs(
    val context: Context,
    val prefs: SharedPreferences,
    val assistantViewModel: AssistantViewModel,
    val callbacks: AssistantRootStartupCallbacks
)

internal data class AssistantRootStartupCallbacks(
    val onContactsPermissionGrantedChange: (Boolean) -> Unit,
    val onPhonePermissionGrantedChange: (Boolean) -> Unit,
    val onTrustedCalleeStartupReadyChange: (Boolean) -> Unit,
    val onLaunchStartupPermissions: (Array<String>) -> Unit,
    val onRefreshOutboundNumber: () -> Unit,
    val onRefreshRealTasks: () -> Unit,
    val onRefreshRealtimeCallProvider: () -> Unit,
    val onRefreshRealtimeCallVoice: () -> Unit,
    val onRefreshTranslationProvider: () -> Unit,
    val onRefreshVoiceCloneStatus: () -> Unit,
    val onRefreshDeviceContacts: () -> Unit,
    val onRefreshUserIdentity: () -> Unit,
    val onRefreshContactDirectory: () -> Unit
)

@Composable
internal fun AssistantRootStartupEffect(args: AssistantRootStartupEffectArgs) {
    LaunchedEffect(args.assistantViewModel) {
        val callbacks = args.callbacks

        args.assistantViewModel.initialize()
        args.prefs.edit().putBoolean(FinalPureVoiceModeKey, true).apply()

        val contactsGranted = args.context.hasPermission(Manifest.permission.READ_CONTACTS)
        val phoneGranted = args.context.hasPermission(Manifest.permission.CALL_PHONE)
        callbacks.onContactsPermissionGrantedChange(contactsGranted)
        callbacks.onPhonePermissionGrantedChange(phoneGranted)

        callbacks.onTrustedCalleeStartupReadyChange(true)

        args.assistantViewModel.loadLocationIfPermitted()
        callbacks.onRefreshOutboundNumber()
        callbacks.onRefreshRealTasks()
        args.assistantViewModel.loadConversations()
        callbacks.onRefreshRealtimeCallProvider()
        callbacks.onRefreshRealtimeCallVoice()
        callbacks.onRefreshTranslationProvider()
        callbacks.onRefreshVoiceCloneStatus()
        if (contactsGranted) {
            callbacks.onRefreshDeviceContacts()
        }
        callbacks.onRefreshUserIdentity()
        callbacks.onRefreshContactDirectory()
    }
}

internal data class AssistantAiCallPageSyncEffectArgs(
    val showAiCallPage: Boolean,
    val pureVoiceMode: Boolean,
    val currentPage: FinalPage,
    val onMainTabChange: (FinalMainTab) -> Unit,
    val onPageChange: (FinalPage) -> Unit
)

@Composable
internal fun AssistantAiCallPageSyncEffect(args: AssistantAiCallPageSyncEffectArgs) {
    LaunchedEffect(args.showAiCallPage, args.pureVoiceMode) {
        if (args.showAiCallPage) {
            args.onMainTabChange(FinalMainTab.Assistant)
            if (args.pureVoiceMode) {
                if (args.currentPage != FinalPage.SingleFlow) {
                    args.onPageChange(FinalPage.SingleFlow)
                }
            } else {
                args.onPageChange(FinalPage.AiCall)
            }
        } else if (args.currentPage == FinalPage.AiCall) {
            args.onMainTabChange(FinalMainTab.Assistant)
            args.onPageChange(if (args.pureVoiceMode) FinalPage.SingleFlow else FinalPage.Assistant)
        }
    }
}

private fun Context.hasPermission(permission: String): Boolean {
    return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
}
