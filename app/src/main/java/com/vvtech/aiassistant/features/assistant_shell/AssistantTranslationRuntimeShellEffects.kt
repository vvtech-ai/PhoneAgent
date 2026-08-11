package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.lifecycle.LifecycleOwner
import com.vvtech.aiassistant.features.assistant.AssistantTranslationCallRuntimeController
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant_translation.FinalTranslationCallRuntimeEffects

internal data class AssistantTranslationRuntimeShellEffectsArgs(
    val context: Context,
    val lifecycleOwner: LifecycleOwner,
    val currentPage: FinalPage,
    val runtime: AssistantTranslationCallRuntimeController
)

@Composable
internal fun AssistantTranslationRuntimeShellEffects(
    args: AssistantTranslationRuntimeShellEffectsArgs
) {
    FinalTranslationCallRuntimeEffects(
        context = args.context,
        lifecycleOwner = args.lifecycleOwner,
        currentPage = args.currentPage,
        runtime = args.runtime
    )
}
