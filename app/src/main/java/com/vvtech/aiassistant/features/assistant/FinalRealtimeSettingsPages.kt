package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.model.RealtimeCallProviderResponse
@Composable
internal fun FinalOutboundNumberPageV3(
    value: String,
    currentNumber: String,
    error: String?,
    saving: Boolean,
    deleting: Boolean,
    loading: Boolean,
    onBack: () -> Unit,
    onValueChange: (String) -> Unit,
    onSave: () -> Unit,
    onDelete: () -> Unit
) {
    val hasSavedNumber = currentNumber.isNotBlank()
    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(title = "固定外呼号码", onBack = onBack)
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 18.dp)
        ) {
            item {
                FinalInputFieldV3(
                    label = "手机号码",
                    value = value,
                    placeholder = "例如：13800138000",
                    keyboardType = KeyboardType.Phone,
                    onValueChange = onValueChange
                )
            }
            if (loading) {
                item {
                    Text(
                        text = "正在读取当前固定外呼号码...",
                        modifier = Modifier.padding(top = 10.dp),
                        color = Color(0xFF6E6E73),
                        fontSize = 13.sp
                    )
                }
            }
            if (!error.isNullOrBlank()) {
                item {
                    Text(
                        text = error,
                        modifier = Modifier.padding(top = 10.dp),
                        color = Color(0xFFE14D46),
                        fontSize = 13.sp
                    )
                }
            }
            item {
                FinalActionButton(
                    label = if (saving) "保存中..." else "保存",
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 18.dp),
                    enabled = !saving && !deleting && !loading,
                    onClick = onSave
                )
            }
            if (hasSavedNumber) {
                item {
                    FinalActionButton(
                        label = if (deleting) "删除中..." else "删除固定外呼号码",
                        tone = FinalButtonTone.Danger,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 10.dp),
                        enabled = !saving && !deleting && !loading,
                        onClick = onDelete
                    )
                }
            }
        }
    }
}

@Composable
internal fun FinalRealtimeProviderPageV3(
    providerResponse: RealtimeCallProviderResponse?,
    loading: Boolean,
    switching: Boolean,
    error: String?,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onSelectProvider: (String) -> Unit,
    onOpenVoiceSettings: () -> Unit
) {
    var pendingVoiceSettingsProvider by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(providerResponse?.activeProvider, pendingVoiceSettingsProvider) {
        val pendingProvider = pendingVoiceSettingsProvider
        val activeProvider = providerResponse?.activeProvider?.let(::normalizeAiCallModelId)
        if (pendingProvider != null && pendingProvider == activeProvider) {
            pendingVoiceSettingsProvider = null
            onOpenVoiceSettings()
        }
    }
    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(title = "语音大模型", onBack = onBack)
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 16.dp)
        ) {
            if (loading && providerResponse == null) {
                item {
                    Text(
                        text = "正在读取通话模型状态...",
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                        color = Color(0xFF6E6E73),
                        fontSize = 13.sp
                    )
                }
            }
            if (!error.isNullOrBlank()) {
                item {
                    Column(modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp)) {
                        Text(text = error, color = Color(0xFFE14D46), fontSize = 13.sp)
                        FinalActionButton(
                            label = "重试",
                            tone = FinalButtonTone.Secondary,
                            enabled = !loading && !switching,
                            modifier = Modifier.padding(top = 10.dp),
                            onClick = onRefresh
                        )
                    }
                }
            }
            val models = providerResponse?.toV88VoiceModelOptions().orEmpty()
            val activeProvider = providerResponse?.activeProvider?.let(::normalizeAiCallModelId)
            items(models, key = { it.id }) { model ->
                val active = model.id == activeProvider
                val canSelect = model.enabled && !loading && !switching
                ProviderModelCard(
                    model = model,
                    active = active,
                    enabled = canSelect,
                    onSelect = { onSelectProvider(model.id) },
                    onOpenVoiceSettings = {
                        if (active) {
                            onOpenVoiceSettings()
                        } else if (canSelect) {
                            pendingVoiceSettingsProvider = model.id
                            onSelectProvider(model.id)
                        }
                    }
                )
            }
            item {
                Text(
                    text = "切换模型后将在下一次通话时生效",
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp, bottom = 12.dp),
                    color = Color(0xFF8B8FA3),
                    fontSize = 12.sp,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                )
            }
        }
    }
}

@Composable
private fun ProviderModelCard(
    model: V88VoiceModelOption,
    active: Boolean,
    enabled: Boolean,
    onSelect: () -> Unit,
    onOpenVoiceSettings: () -> Unit
) {
    val supportsVoiceSettings = model.id == "QWEN_OMNI_PLUS" || model.id == "DOUBAO"
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 10.dp),
        color = if (model.enabled) Color.White else Color(0xFFF7F7F8),
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, if (active) Color(0xFF0A84FF) else Color(0xFFE4E7EC)),
        elevation = 0.dp
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(enabled = enabled && !active, onClick = onSelect)
                    .padding(horizontal = 16.dp, vertical = 15.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        model.title,
                        color = if (model.enabled) Color(0xFF111827) else Color(0xFF9B9BA1),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        model.subtitle,
                        modifier = Modifier.padding(top = 4.dp),
                        color = if (model.enabled) Color(0xFF667085) else Color(0xFFAEAEB2),
                        fontSize = 12.sp,
                        lineHeight = 18.sp
                    )
                }
                ProviderModelRadio(selected = active, enabled = enabled || active)
            }
            if (supportsVoiceSettings) {
                androidx.compose.foundation.layout.Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .height(1.dp)
                        .background(Color(0xFFF2F4F7))
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(enabled = enabled || active, onClick = onOpenVoiceSettings)
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "音色与声音克隆",
                        modifier = Modifier.weight(1f),
                        color = Color(0xFF344054),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Normal
                    )
                    Text("›", color = Color(0xFF98A2B3), fontSize = 24.sp, lineHeight = 24.sp)
                }
            }
        }
    }
}

@Composable
private fun ProviderModelRadio(selected: Boolean, enabled: Boolean) {
    androidx.compose.foundation.layout.Box(
        modifier = Modifier
            .padding(start = 12.dp)
            .size(20.dp)
            .border(
                1.5.dp,
                when {
                    selected -> Color(0xFF0A84FF)
                    enabled -> Color(0xFF98A2B3)
                    else -> Color(0xFFD0D5DD)
                },
                androidx.compose.foundation.shape.CircleShape
            ),
        contentAlignment = Alignment.Center
    ) {
        if (selected) {
            androidx.compose.foundation.layout.Box(
                modifier = Modifier
                    .size(10.dp)
                    .background(Color(0xFF0A84FF), androidx.compose.foundation.shape.CircleShape)
            )
        }
    }
}

internal fun realtimeProviderSettingsSubtitle(
    summary: String,
    loading: Boolean,
    error: String?
): String {
    if (!error.isNullOrBlank()) {
        return error
    }
    if (loading && summary.isBlank()) {
        return "正在读取当前通话语音模型状态"
    }
    return if (summary.isBlank()) {
        "切换通话时使用的实时语音模型"
    } else {
        "当前使用 $summary，切换后新的通话会使用这个模型"
    }
}
