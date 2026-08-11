package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_settings.AssistantDeveloperToolsPageArgs
import com.vvtech.aiassistant.features.assistant_settings.AssistantDeveloperToolsPageCallbacks
import com.vvtech.aiassistant.features.assistant_settings.AssistantDeveloperToolsPageState
import com.vvtech.aiassistant.features.assistant_shell.AssistantSettingsNavigationCallbacks
import com.vvtech.aiassistant.features.assistant_shell.openAssistantOutboundNumberEdit
import com.vvtech.aiassistant.features.assistant_shell.returnToAssistantDeveloperTools
import com.vvtech.aiassistant.features.assistant_shell.returnToAssistantSettings

@Composable
internal fun AssistantDeveloperPermissionPageHost(
    targetPage: FinalPage,
    navigation: PageHostNavigationArgs,
    assistant: AssistantPageArgs,
    settings: SettingsPageArgs,
    permissionDeveloper: PermissionDeveloperArgs
) {
    with(navigation) {
        with(assistant) {
            with(settings) {
                with(permissionDeveloper) {
                    val settingsNavigationCallbacks = AssistantSettingsNavigationCallbacks(
                        onPageChange = onPageChange,
                        onOpenSubPage = onOpenSubPage
                    )
                    when (targetPage) {
                        FinalPage.DeveloperTools -> FinalDeveloperToolsPageV3(
                            args = AssistantDeveloperToolsPageArgs(
                                state = AssistantDeveloperToolsPageState(
                                    mode = runCatching {
                                        DeveloperDataMode.valueOf(developerDataMode)
                                    }.getOrDefault(DeveloperDataMode.Empty),
                                    outboundNumber = outboundNumber,
                                    outboundLoading = outboundLoading,
                                    outboundConfigured = outboundConfigured,
                                    networkMode = networkMode,
                                    locationAvailable = assistantUiState.locationAvailable,
                                    locationDisplayText = assistantUiState.locationDisplayText
                                ),
                                callbacks = AssistantDeveloperToolsPageCallbacks(
                                    onBack = { returnToAssistantSettings(settingsNavigationCallbacks) },
                                    onChangeMode = onApplyDeveloperDataMode,
                                    onOpenOutbound = {
                                        onRefreshOutboundNumber()
                                        onOutboundDraftChange(outboundNumber)
                                        onOutboundErrorChange(null)
                                        openAssistantOutboundNumberEdit(settingsNavigationCallbacks)
                                    },
                                    onNetworkModeChange = {
                                        onNetworkModeNameChange(it.name)
                                        onShowNetworkBlockerChange(false)
                                        when (it) {
                                            V88NetworkMode.Weak -> {
                                                Toast.makeText(context, "网络信号弱，加载可能较慢", Toast.LENGTH_SHORT).show()
                                            }
                                            V88NetworkMode.Offline -> {
                                                Toast.makeText(context, "网络已断开", Toast.LENGTH_SHORT).show()
                                            }
                                            V88NetworkMode.Normal -> Unit
                                        }
                                    },
                                    onResetPermissions = {
                                        onMicrophonePermissionGrantedChange(false)
                                        onStoragePermissionGrantedChange(false)
                                        onContactsPermissionGrantedChange(false)
                                        onPhonePermissionGrantedChange(false)
                                        onResetDialerLocationPermissionAndOpenDialSheet()
                                        Toast.makeText(context, "模拟权限已重置", Toast.LENGTH_SHORT).show()
                                    }
                                )
                            )
                        )

                        FinalPage.OutboundNumberEdit -> FinalOutboundNumberPageV3(
                            value = outboundDraft,
                            currentNumber = outboundNumber,
                            error = outboundError,
                            saving = outboundSaving,
                            deleting = outboundDeleting,
                            loading = outboundLoading,
                            onBack = { returnToAssistantDeveloperTools(settingsNavigationCallbacks) },
                            onValueChange = {
                                onOutboundDraftChange(it)
                                onOutboundErrorChange(null)
                            },
                            onSave = onSaveOutboundNumber,
                            onDelete = onDeleteOutboundNumber
                        )

                        else -> Unit
                    }
                }
            }
        }
    }
}

internal class PermissionDeveloperArgs {
    var developerDataMode: String = ""
    lateinit var networkMode: V88NetworkMode
    lateinit var onNetworkModeNameChange: (String) -> Unit
    lateinit var onShowNetworkBlockerChange: (Boolean) -> Unit
    lateinit var onMicrophonePermissionGrantedChange: (Boolean) -> Unit
    lateinit var onStoragePermissionGrantedChange: (Boolean) -> Unit
    lateinit var onContactsPermissionGrantedChange: (Boolean) -> Unit
    lateinit var onPhonePermissionGrantedChange: (Boolean) -> Unit
    lateinit var onResetDialerLocationPermissionAndOpenDialSheet: () -> Unit
    lateinit var onApplyDeveloperDataMode: (DeveloperDataMode) -> Unit
    lateinit var context: Context
}
