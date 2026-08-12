package com.vvtech.aiassistant.features.assistant

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.ExperimentalAnimationApi
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.with
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.ArrowForward
import androidx.compose.material.icons.outlined.Backspace
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Menu
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material.icons.rounded.CallEnd
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.KeyboardVoice
import androidx.compose.material.icons.rounded.Send
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.NonRestartableComposable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.platform.LocalView
import android.view.WindowManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.contacts.DeviceContactResolver
import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.core.model.AssistantHistoryItem
import com.vvtech.aiassistant.devhook.DevMockHooks
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames
import com.vvtech.aiassistant.features.translation_call.ui.TranslationProviderUiCatalog
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.core.model.TranslationCallHangupRequest
import com.vvtech.aiassistant.core.model.TranslationCallStatusRequest
import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.data.repository.AssistantContainer
import com.vvtech.aiassistant.model.RealtimeCallProviderResponse
import com.vvtech.aiassistant.model.RealtimeTranslationProviderResponse
import com.vvtech.aiassistant.model.TaskListItem
import com.vvtech.aiassistant.model.VoiceCloneSampleUploadRequest
import com.vvtech.aiassistant.model.VoiceCloneScriptItem
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import com.vvtech.aiassistant.model.VoiceCloneUploadRequest
import com.vvtech.aiassistant.repository.AppContainer
import java.io.File
import java.util.Base64
import java.time.LocalDate
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max
import java.util.Locale


@Composable
@OptIn(ExperimentalAnimationApi::class)
internal fun FinalRootPageFrame(
    pageBottomInset: Dp,
    currentPage: FinalPage,
    onPageEntered: (FinalPage) -> Unit = {},
    onPageVisibilityChanged: (FinalPage, Boolean) -> Unit = { _, _ -> },
    content: @Composable (FinalPage) -> Unit
) {
    val pageTransitionYOffset = with(LocalDensity.current) { 8.dp.toPx().toInt() }
    val subPageTransitionXOffset = with(LocalDensity.current) { 14.dp.toPx().toInt() }
    val currentOnPageVisibilityChanged by rememberUpdatedState(onPageVisibilityChanged)

    Box(
        modifier = Modifier
            .fillMaxSize()
    ) {
        AnimatedContent(
            targetState = currentPage,
            label = "final_page_transition",
            transitionSpec = {
                val initialTabIndex = initialState.topLevelTabIndex()
                val targetTabIndex = targetState.topLevelTabIndex()
                val isTopLevelSwitch = initialTabIndex != null && targetTabIndex != null
                val targetIsSubPage = !targetState.isTopLevel()
                val initialIsSubPage = !initialState.isTopLevel()
                val isConversationReturn = initialState == FinalPage.SingleFlow && targetTabIndex != null
                val tabMovesForward = (targetTabIndex ?: 0) > (initialTabIndex ?: 0)
                val enter = when {
                    isConversationReturn -> {
                        fadeIn(
                            animationSpec = tween(
                                durationMillis = 150,
                                easing = FinalFadeEase
                            )
                        )
                    }
                    isTopLevelSwitch -> {
                        fadeIn(
                            animationSpec = tween(
                                durationMillis = 180,
                                easing = FinalFadeEase
                            )
                        ) + slideInHorizontally(
                            animationSpec = tween(
                                durationMillis = 240,
                                easing = FinalMotionEase
                            ),
                            initialOffsetX = { width -> if (tabMovesForward) width / 10 else -width / 10 }
                        )
                    }
                    targetIsSubPage -> {
                        fadeIn(
                            animationSpec = tween(
                                durationMillis = FinalSubPageInDurationMs,
                                easing = FinalFadeEase
                            )
                        ) + slideInHorizontally(
                            animationSpec = tween(
                                durationMillis = FinalSubPageInDurationMs,
                                easing = FinalMotionEase
                            ),
                            initialOffsetX = { subPageTransitionXOffset }
                        )
                    }
                    initialIsSubPage && targetTabIndex != null -> {
                        fadeIn(
                            animationSpec = tween(
                                durationMillis = 190,
                                easing = FinalFadeEase
                            )
                        ) + slideInHorizontally(
                            animationSpec = tween(
                                durationMillis = 240,
                                easing = FinalMotionEase
                            ),
                            initialOffsetX = { -subPageTransitionXOffset / 2 }
                        )
                    }
                    else -> {
                        fadeIn(
                            animationSpec = tween(
                                durationMillis = FinalPageInDurationMs,
                                easing = FinalFadeEase
                            )
                        ) + slideInVertically(
                            animationSpec = tween(
                                durationMillis = FinalPageInDurationMs,
                                easing = FinalMotionEase
                            ),
                            initialOffsetY = { pageTransitionYOffset }
                        )
                    }
                }
                val exit = fadeOut(
                    animationSpec = tween(
                        durationMillis = if (isConversationReturn) 150 else FinalFadeDurationMs,
                        easing = FinalFadeEase
                    )
                ) + when {
                    isConversationReturn -> {
                        ExitTransition.None
                    }
                    isTopLevelSwitch -> {
                        slideOutHorizontally(
                            animationSpec = tween(
                                durationMillis = 220,
                                easing = FinalMotionEase
                            ),
                            targetOffsetX = { width -> if (tabMovesForward) -width / 10 else width / 10 }
                        )
                    }
                    targetIsSubPage -> {
                        slideOutHorizontally(
                            animationSpec = tween(
                                durationMillis = FinalSubPageInDurationMs,
                                easing = FinalMotionEase
                            ),
                            targetOffsetX = { -subPageTransitionXOffset / 2 }
                        )
                    }
                    initialIsSubPage && targetTabIndex != null -> {
                        slideOutHorizontally(
                            animationSpec = tween(
                                durationMillis = 240,
                                easing = FinalMotionEase
                            ),
                            targetOffsetX = { subPageTransitionXOffset }
                        )
                    }
                    else -> ExitTransition.None
                }
                enter with exit
            }
        ) { targetPage ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(bottom = if (targetPage.isTopLevel()) pageBottomInset else 0.dp)
            ) {
            DisposableEffect(targetPage) {
                onPageEntered(targetPage)
                currentOnPageVisibilityChanged(targetPage, true)
                onDispose {
                    currentOnPageVisibilityChanged(targetPage, false)
                }
            }
            content(targetPage)
            }
        }
    }
}

internal fun sanitizeVoiceCloneScriptItem(item: VoiceCloneScriptItem): VoiceCloneScriptItem {
    return VoiceCloneScriptItem(
        scriptId = item.scriptId,
        text = safeVoiceCloneModelText(item.text),
        minDurationSeconds = item.minDurationSeconds,
        title = safeVoiceCloneModelText(item.title),
        recordingTips = safeVoiceCloneModelText(item.recordingTips),
        targetDurationSeconds = item.targetDurationSeconds,
        required = item.required
    )
}

internal fun safeVoiceCloneModelText(value: Any?): String = value?.toString().orEmpty()

internal fun String.toV88VoiceModelId(): String {
    return when (uppercase(Locale.ROOT)) {
        "DOUBAO", "VOLCANO" -> "DOUBAO"
        "DOUBAO_SEEDUPLEX_3_0" -> "QWEN_OMNI_PLUS"
        "QWEN_OMNI_PLUS", "QWEN_OMNI_FLASH", "ALIBABA" -> "QWEN_OMNI_PLUS"
        "OPENAI_GPT_REALTIME_2", "GPT4O", "GPT" -> "GPT"
        else -> V88VoiceModelOptions.first().id
    }
}

internal fun String.toVoiceModelComingSoonName(): String {
    return when {
        startsWith("火山") -> "火山引擎"
        startsWith("GPT") -> "GPT"
        else -> substringBefore(' ').ifBlank { this }
    }
}

internal fun String.toRealtimeCallProviderValue(): String? {
    return when (uppercase(Locale.ROOT)) {
        "QWEN_OMNI_PLUS", "QWEN_OMNI_FLASH", "ALIBABA" -> "QWEN_OMNI_PLUS"
        "DOUBAO", "VOLCANO" -> "DOUBAO"
        "DOUBAO_SEEDUPLEX_3_0" -> "QWEN_OMNI_PLUS"
        "GPT", "GPT4O", "OPENAI_GPT_REALTIME_2" -> null
        else -> null
    }
}

internal fun normalizeRealtimeCallProviderDisplayName(provider: String?, displayName: String?): String? {
    return AssistantCallModelDisplayNames.resolve(provider, displayName)
}

internal fun sanitizeTranslationQwenVoice(raw: String?): String {
    return when (raw?.trim()) {
        "Nofish" -> "Nofish"
        else -> "Nofish"
    }
}

internal fun isQwenTranslationProvider(provider: String?): Boolean {
    return provider?.trim()?.uppercase(Locale.ROOT) in
        setOf("QWEN_OMNI_PLUS", "QWEN_OMNI_FLASH")
}

internal fun translationProviderDisplayName(provider: String?): String {
    return TranslationProviderUiCatalog.displayName(provider)
}

internal fun normalizeTranslationProviderDisplayName(provider: String?, displayName: String?): String {
    return TranslationProviderUiCatalog.option(provider)?.displayName
        ?: displayName?.trim().orEmpty()
}

internal const val FinalUserIdentityPhoneError = "请输入正确的手机号码"
private val FinalUserIdentityPhoneRegex = Regex("^1[3-9]\\d{9}$")

internal fun finalUserIdentityValidationError(
    request: com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
): String? {
    val contactPhone = request.contactPhone?.trim().orEmpty()
    if (contactPhone.isNotBlank() && !FinalUserIdentityPhoneRegex.matches(contactPhone)) {
        return FinalUserIdentityPhoneError
    }
    return null
}

internal fun finalUserIdentitySaveErrorMessage(throwable: Throwable): String {
    val raw = throwable.message.orEmpty()
    return if (
        raw.contains("contactPhone", ignoreCase = true) ||
        raw.contains("手机号") ||
        raw.contains("手机号码") ||
        raw.contains("HTTP 400", ignoreCase = true)
    ) {
        FinalUserIdentityPhoneError
    } else {
        raw.ifBlank { "保存失败" }
    }
}
