package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.view.WindowManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.getValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import com.vvtech.aiassistant.features.app_ota.FinalOtaInstallRequest
import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.delay
import kotlin.math.max

@Composable
internal fun FinalVoiceLanguageEffect(
    voiceLanguage: VoiceLanguage,
    assistantViewModel: AssistantViewModel
) {
    LaunchedEffect(voiceLanguage.code) {
        assistantViewModel.setVoiceLanguage(voiceLanguage.code)
    }
}

@Composable
internal fun FinalPageLifecycleLoggingEffects(
    lifecycleOwner: LifecycleOwner,
    currentPage: FinalPage,
    currentMainTab: FinalMainTab,
    previousMainTab: FinalMainTab
) {
    val lifecycleCurrentPage by rememberUpdatedState(currentPage)
    val lifecycleCurrentMainTab by rememberUpdatedState(currentMainTab)

    LaunchedEffect(currentPage, currentMainTab, previousMainTab) {
        AppFileLogger.lifecycle(
            "AssistantRootScreen",
            "visible page=${currentPage.name} tab=${currentMainTab.name} previousTab=${previousMainTab.name}"
        )
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            AppFileLogger.lifecycle(
                "AssistantRootScreen",
                "event=$event page=${lifecycleCurrentPage.name} tab=${lifecycleCurrentMainTab.name}"
            )
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }
}

@Composable
internal fun FinalAuthCodeRetryEffect(
    mockLoggedIn: Boolean,
    authCodeRetrySeconds: Int,
    onRetrySecondsChange: (Int) -> Unit
) {
    LaunchedEffect(mockLoggedIn, authCodeRetrySeconds) {
        if (!mockLoggedIn && authCodeRetrySeconds > 0) {
            delay(1000)
            onRetrySecondsChange(max(0, authCodeRetrySeconds - 1))
        }
    }
}

@Composable
internal fun FinalVoiceCloneResourceCleanupEffect(
    onDisposeVoiceCloneRuntime: () -> Unit
) {
    DisposableEffect(Unit) {
        onDispose {
            onDisposeVoiceCloneRuntime()
        }
    }
}

@Composable
internal fun FinalSystemContactsSyncEffects(
    context: Context,
    lifecycleOwner: LifecycleOwner,
    contactsPermissionGranted: Boolean,
    mockLoggedIn: Boolean,
    onRefreshDeviceContacts: () -> Unit
) {
    DisposableEffect(context, contactsPermissionGranted, mockLoggedIn) {
        if (!mockLoggedIn || !contactsPermissionGranted) {
            onDispose { }
        } else {
            val handler = Handler(Looper.getMainLooper())
            val refreshRunnable = Runnable {
                AppFileLogger.i("CONTACT_SYNC_DIAG", "refresh contacts after provider change")
                onRefreshDeviceContacts()
            }
            val observer = object : ContentObserver(handler) {
                override fun onChange(selfChange: Boolean) {
                    onChange(selfChange, null)
                }

                override fun onChange(selfChange: Boolean, uri: Uri?) {
                    AppFileLogger.i("CONTACT_SYNC_DIAG", "contacts provider changed uri=${uri ?: "unknown"}")
                    handler.removeCallbacks(refreshRunnable)
                    handler.postDelayed(refreshRunnable, 800L)
                }
            }
            context.contentResolver.registerContentObserver(
                ContactsContract.AUTHORITY_URI,
                true,
                observer
            )
            context.contentResolver.registerContentObserver(
                ContactsContract.Contacts.CONTENT_URI,
                true,
                observer
            )
            context.contentResolver.registerContentObserver(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                true,
                observer
            )
            onDispose {
                handler.removeCallbacks(refreshRunnable)
                runCatching { context.contentResolver.unregisterContentObserver(observer) }
            }
        }
    }

    DisposableEffect(lifecycleOwner, contactsPermissionGranted, mockLoggedIn) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME && mockLoggedIn && contactsPermissionGranted) {
                AppFileLogger.i("CONTACT_SYNC_DIAG", "refresh contacts on app resume")
                onRefreshDeviceContacts()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }
}

@Composable
internal fun FinalLocationPermissionResumeEffect(
    context: Context,
    lifecycleOwner: LifecycleOwner,
    onLoadLocationIfPermitted: () -> Unit
) {
    DisposableEffect(context, lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME && hasAssistantLocationPermission(context)) {
                onLoadLocationIfPermitted()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }
}

@Composable
internal fun FinalPageResourceEffects(
    context: Context,
    currentPage: FinalPage,
    translationCallAudioClient: TranslationCallAudioSocketClient
) {
    val pageForDispose = currentPage
    DisposableEffect(pageForDispose) {
        AppFileLogger.lifecycle("FinalPage", "enter page=${pageForDispose.name}")
        if (pageForDispose == FinalPage.SingleFlow) {
            val activity = context as? androidx.activity.ComponentActivity
            activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        onDispose {
            AppFileLogger.lifecycle("FinalPage", "leave page=${pageForDispose.name}")
            val activity = context as? androidx.activity.ComponentActivity
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            if (pageForDispose == FinalPage.TranslateCall) {
                translationCallAudioClient.stop("screen_disposed")
            }
        }
    }
}

@Composable
internal fun FinalTranslationCallKeepScreenOnEffect(
    context: Context,
    lifecycleOwner: LifecycleOwner,
    keepScreenOnForTranslationCall: Boolean
) {
    DisposableEffect(keepScreenOnForTranslationCall, lifecycleOwner, context) {
        val activity = context as? androidx.activity.ComponentActivity
        fun applyKeepScreenOnIfForeground() {
            if (
                keepScreenOnForTranslationCall &&
                lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
            ) {
                activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
        fun clearKeepScreenOn() {
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        applyKeepScreenOnIfForeground()
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START,
                Lifecycle.Event.ON_RESUME -> applyKeepScreenOnIfForeground()
                Lifecycle.Event.ON_PAUSE,
                Lifecycle.Event.ON_STOP -> clearKeepScreenOn()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            if (keepScreenOnForTranslationCall) {
                clearKeepScreenOn()
            }
        }
    }
}

@Composable
internal fun FinalOtaInstallerLifecycleEffect(
    otaInstaller: FinalOtaUpdateInstaller,
    lifecycleOwner: LifecycleOwner,
    onInstallRequest: (FinalOtaInstallRequest) -> Unit = {}
) {
    DisposableEffect(otaInstaller, lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                otaInstaller.onAppResumed()
                val request = otaInstaller.resumeInstallAfterPermissionIfReady("app_resume")
                if (request != FinalOtaInstallRequest.None) {
                    onInstallRequest(request)
                }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            otaInstaller.dispose()
        }
    }
}

@Composable
internal fun FinalSingleFlowBackgroundEffect(
    currentPage: FinalPage,
    lifecycleOwner: LifecycleOwner,
    assistantViewModel: AssistantViewModel
) {
    DisposableEffect(currentPage, lifecycleOwner, assistantViewModel) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_STOP -> {
                    if (currentPage == FinalPage.SingleFlow) {
                        assistantViewModel.pauseTaskConversationForBackground()
                    }
                }
                Lifecycle.Event.ON_START,
                Lifecycle.Event.ON_RESUME -> {
                    if (currentPage == FinalPage.SingleFlow) {
                        assistantViewModel.resumeTaskConversationForForeground()
                    }
                }
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }
}

private fun hasAssistantLocationPermission(context: Context): Boolean {
    return ContextCompat.checkSelfPermission(
        context,
        android.Manifest.permission.ACCESS_FINE_LOCATION
    ) == android.content.pm.PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.ACCESS_COARSE_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
}
