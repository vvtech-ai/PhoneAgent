package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.features.translation_call.ui.TranslationProviderUiCatalog

@Composable
internal fun V61InitializationOverlay(
    saving: Boolean,
    error: String?,
    completionOnly: Boolean,
    initialIdentity: UserIdentityPayload?,
    callProviderOptions: List<V88VoiceModelOption>,
    initialTranslationProvider: String,
    onDismiss: () -> Unit,
    onSkipIdentityForSession: () -> Unit,
    onSubmit: (UserIdentityUpsertRequest) -> Unit,
    onSelectCallProvider: (String) -> Unit,
    onSelectTranslationProvider: (String) -> Unit
) {
    if (completionOnly) {
        V61IdentityCompletionOverlay(
            saving = saving,
            error = error,
            initialIdentity = initialIdentity,
            onDismiss = onDismiss,
            onSubmit = onSubmit
        )
        return
    }
    var step by rememberSaveable { mutableStateOf(1) }
    var name by rememberSaveable(initialIdentity?.updatedAt) {
        mutableStateOf(initialIdentity?.name.orEmpty())
    }
    var gender by rememberSaveable(initialIdentity?.updatedAt) {
        mutableStateOf(initialIdentity?.gender?.takeIf { it.isNotBlank() } ?: "不透露")
    }
    var callProvider by rememberSaveable { mutableStateOf("QWEN_OMNI_PLUS") }
    var translationProvider by rememberSaveable(initialTranslationProvider) {
        mutableStateOf(
            TranslationProviderUiCatalog.normalizeProviderId(initialTranslationProvider)
        )
    }
    var identitySubmitted by rememberSaveable { mutableStateOf(false) }
    var phone by rememberSaveable(initialIdentity?.updatedAt) {
        mutableStateOf(resolveIdentityPhone(initialIdentity?.contactPhone))
    }
    val resolvedCallProviderOptions = callProviderOptions
        .map { V61ProviderOption(it.id, it.title, it.subtitle, it.enabled) }
        .ifEmpty { V61CallProviderOptions }

    LaunchedEffect(identitySubmitted, saving, error) {
        if (identitySubmitted && !saving && error.isNullOrBlank()) {
            onDismiss()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
    ) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = Color.White,
            elevation = 0.dp
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 22.dp, vertical = 18.dp)
            ) {
                V61InitializationHeader(
                    step = step,
                    onBack = { step -= 1 },
                    onSkipIdentity = { step = 2 }
                )
                Box(modifier = Modifier.weight(1f)) {
                    when (step) {
                    1 -> V61IdentityStep(
                        name = name,
                        gender = gender,
                        phone = phone,
                        error = error,
                        saving = saving,
                        onNameChange = { name = it },
                        onGenderChange = { gender = it },
                        onPhoneChange = { phone = it.filter(Char::isDigit).take(11) },
                        actionLabel = stringResource(R.string.initialization_next),
                        onNext = { step = 2 }
                    )
                    2 -> V61ProviderStep(
                        title = stringResource(R.string.initialization_call_model_title),
                        subtitle = stringResource(R.string.initialization_call_model_subtitle),
                        selected = callProvider,
                        options = resolvedCallProviderOptions,
                        primaryLabel = stringResource(R.string.initialization_next),
                        onSelected = { callProvider = it },
                        onContinue = {
                            onSelectCallProvider(callProvider)
                            step = 3
                        }
                    )
                    else -> V61ProviderStep(
                        title = stringResource(R.string.initialization_translation_model_title),
                        subtitle = stringResource(R.string.initialization_translation_model_subtitle),
                        selected = translationProvider,
                        options = V61TranslationProviderOptions,
                        primaryLabel = if (saving) {
                            stringResource(R.string.identity_saving)
                        } else {
                            stringResource(R.string.initialization_done)
                        },
                        error = error,
                        onSelected = { translationProvider = it },
                        onContinue = {
                            onSelectTranslationProvider(translationProvider)
                            if (name.isNotBlank()) {
                                identitySubmitted = true
                                onSubmit(
                                    UserIdentityUpsertRequest(
                                        userId = "",
                                        name = name.trim(),
                                        gender = gender,
                                        contactPhone = phone.ifBlank { null },
                                        workIdentities = null,
                                        description = null
                                    )
                                )
                            } else {
                                onSkipIdentityForSession()
                            }
                        }
                    )
                    }
                }
            }
        }
    }
}

@Composable
private fun V61InitializationHeader(
    step: Int,
    onBack: () -> Unit,
    onSkipIdentity: () -> Unit
) {
    Box(modifier = Modifier.fillMaxWidth()) {
        if (step > 1) {
            Text(
                text = "‹",
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .size(36.dp)
                    .clickable(onClick = onBack)
                    .padding(bottom = 4.dp),
                color = Color(0xFF111111),
                fontSize = 32.sp,
                lineHeight = 32.sp
            )
        }
        Text(
            text = stringResource(R.string.initialization_title),
            modifier = Modifier.align(Alignment.Center),
            color = Color(0xFF111111),
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold
        )
        if (step == 1) {
            Text(
                text = stringResource(R.string.initialization_skip),
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .clickable(onClick = onSkipIdentity)
                    .padding(vertical = 8.dp),
                color = Color(0xFF667085),
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
internal fun V61IdentityStep(
    name: String,
    gender: String,
    phone: String,
    error: String?,
    saving: Boolean,
    onNameChange: (String) -> Unit,
    onGenderChange: (String) -> Unit,
    onPhoneChange: (String) -> Unit,
    actionLabel: String,
    onNext: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = stringResource(R.string.identity_section_profile),
            modifier = Modifier.padding(top = 34.dp),
            color = Color(0xFF111111),
            fontSize = 22.sp,
            fontWeight = FontWeight.ExtraBold
        )
        Text(
            text = stringResource(R.string.identity_init_subtitle),
            modifier = Modifier.padding(top = 8.dp),
            color = Color(0xFF667085),
            fontSize = 14.sp
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 10.dp, vertical = 30.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            V61InputCard(
                stringResource(R.string.identity_name_label),
                name,
                stringResource(R.string.identity_name_placeholder),
                onNameChange
            )
            V61GenderCard(gender, onGenderChange)
            V61InputCard(
                label = stringResource(R.string.identity_phone_label),
                value = phone,
                placeholder = stringResource(R.string.identity_phone_placeholder),
                onValueChange = onPhoneChange,
                keyboardType = KeyboardType.Phone
            )
            if (!error.isNullOrBlank()) {
                Text(error, color = Color(0xFFE14D46), fontSize = 13.sp)
            }
        }
        Spacer(modifier = Modifier.weight(1f))
        FinalActionButton(
            label = if (saving) stringResource(R.string.identity_saving) else actionLabel,
            enabled = name.isNotBlank() && !saving,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp, bottom = 36.dp),
            onClick = onNext
        )
    }
}

@Composable
private fun V61LegacyInputCard(
    label: String,
    value: String,
    placeholder: String,
    onValueChange: (String) -> Unit,
    keyboardType: KeyboardType = KeyboardType.Text,
    enabled: Boolean = true
) {
    Surface(color = Color(0xFFF7F8FA), shape = RoundedCornerShape(14.dp), elevation = 0.dp) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Text(label, color = Color(0xFF344054), fontSize = 12.sp, fontWeight = FontWeight.Medium)
            androidx.compose.material.OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                enabled = enabled,
                placeholder = { Text(placeholder) },
                keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = keyboardType),
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun V61InputCard(
    label: String,
    value: String,
    placeholder: String,
    onValueChange: (String) -> Unit,
    keyboardType: KeyboardType = KeyboardType.Text,
    enabled: Boolean = true
) {
    V61DemoIdentityInputField(
        label = label,
        value = value,
        placeholder = placeholder,
        onValueChange = onValueChange,
        keyboardType = keyboardType,
        enabled = enabled
    )
}

@Composable
private fun V61DemoIdentityInputField(
    label: String,
    value: String,
    placeholder: String,
    onValueChange: (String) -> Unit,
    keyboardType: KeyboardType,
    enabled: Boolean
) {
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Text(
            label,
            color = Color(0xFF4B5563),
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold
        )
        Surface(
            modifier = Modifier.fillMaxWidth(),
            color = if (enabled) Color(0xFFF9FAFB) else Color(0xFFF3F4F6),
            shape = RoundedCornerShape(14.dp),
            border = BorderStroke(1.dp, Color(0x213C3C43)),
            elevation = 0.dp
        ) {
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                enabled = enabled,
                singleLine = true,
                keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = keyboardType),
                textStyle = TextStyle(
                    color = if (enabled) Color(0xFF111111) else Color(0xFF6E6E73),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 13.dp, vertical = 13.dp),
                decorationBox = { innerTextField ->
                    if (value.isBlank()) {
                        Text(
                            placeholder,
                            color = Color(0x5C3C3C43),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    innerTextField()
                }
            )
        }
    }
}

@Composable
private fun V61DemoIdentityGenderField(selected: String, onSelected: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Text(
            stringResource(R.string.identity_gender_label),
            color = Color(0xFF4B5563),
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MyIdentityGenderOptions.forEach { option ->
                val selectedOption = selected == option
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .clickable { onSelected(option) },
                    color = if (selectedOption) Color(0x1A0A84FF) else Color(0xFFF9FAFB),
                    shape = RoundedCornerShape(14.dp),
                    border = BorderStroke(
                        1.dp,
                        if (selectedOption) Color(0x520A84FF) else Color(0x1F3C3C43)
                    ),
                    elevation = 0.dp
                ) {
                    Box(
                        modifier = Modifier.padding(vertical = 11.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            localizedV61IdentityGenderOption(option),
                            color = if (selectedOption) Color(0xFF0A84FF) else Color(0xFF4B5563),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun V61GenderCard(selected: String, onSelected: (String) -> Unit) {
    V61DemoIdentityGenderField(selected = selected, onSelected = onSelected)
}

@Composable
private fun localizedV61IdentityGenderOption(option: String): String =
    when (option) {
        "男" -> stringResource(R.string.identity_gender_male)
        "女" -> stringResource(R.string.identity_gender_female)
        else -> stringResource(R.string.identity_gender_unspecified)
    }

@Composable
private fun V61LegacyGenderCard(selected: String, onSelected: (String) -> Unit) {
    Surface(color = Color(0xFFF7F8FA), shape = RoundedCornerShape(14.dp), elevation = 0.dp) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Text(
                stringResource(R.string.identity_gender_label),
                color = Color(0xFF344054),
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium
            )
            Row(modifier = Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MyIdentityGenderOptions.forEach { option ->
                    Surface(
                        modifier = Modifier.clickable { onSelected(option) },
                        color = if (selected == option) Color(0x1A6C5CE7) else Color.White,
                        shape = RoundedCornerShape(999.dp),
                        border = BorderStroke(1.dp, if (selected == option) Color(0xFF6C5CE7) else Color(0xFFE4E7EC)),
                        elevation = 0.dp
                    ) {
                        Text(
                            localizedV61IdentityGenderOption(option),
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp),
                            color = Color(0xFF344054),
                            fontSize = 13.sp
                        )
                    }
                }
            }
        }
    }
}
