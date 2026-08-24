package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.Image
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
@Composable
internal fun V88LoginPage(
    phone: String,
    code: String,
    sendingCode: Boolean,
    loggingIn: Boolean,
    retrySeconds: Int,
    onPhoneChange: (String) -> Unit,
    onCodeChange: (String) -> Unit,
    onSendCode: () -> Unit,
    onLogin: () -> Unit
) {
    val codeFocusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(Color(0xFFFBFBFD), Color(0xFFEDF0F7))
                )
            )
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.74f),
                        Color.White.copy(alpha = 0.70f)
                    )
                )
            )
            .padding(horizontal = 24.dp, vertical = 24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .widthIn(max = 320.dp)
                .fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Image(
                painter = painterResource(id = R.drawable.chakenailogo),
                contentDescription = "Phone Agent",
                modifier = Modifier
                    .width(107.dp)
                    .height(98.dp)
            )
            Spacer(modifier = Modifier.height(14.dp))
            Text(
                text = "Phone Agent",
                color = Color(0xFF1A1A2E),
                fontSize = 28.sp,
                lineHeight = 34.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.sp,
                textAlign = TextAlign.Center
            )
            Text(
                text = stringResource(R.string.auth_tagline),
                modifier = Modifier.padding(top = 6.dp),
                color = Color(0xFF8B8FA3),
                fontSize = 14.sp,
                lineHeight = 20.sp,
                textAlign = TextAlign.Center
            )
            Spacer(modifier = Modifier.height(40.dp))
            V88LoginInputGroup(
                value = phone,
                placeholder = stringResource(R.string.auth_phone_placeholder),
                keyboardType = KeyboardType.Phone,
                prefix = "+86",
                imeAction = ImeAction.Next,
                keyboardActions = KeyboardActions(
                    onNext = { codeFocusRequester.requestFocus() }
                ),
                onValueChange = onPhoneChange
            )
            Spacer(modifier = Modifier.height(12.dp))
            V88LoginInputGroup(
                value = code,
                placeholder = stringResource(R.string.auth_code_placeholder),
                keyboardType = KeyboardType.Number,
                inputModifier = Modifier.focusRequester(codeFocusRequester),
                imeAction = ImeAction.Done,
                keyboardActions = KeyboardActions(
                    onDone = {
                        if (!loggingIn && !sendingCode) {
                            focusManager.clearFocus()
                            onLogin()
                        }
                    }
                ),
                trailing = {
                    V88LoginCodeButton(
                        label = when {
                            sendingCode -> stringResource(R.string.auth_sending_code)
                            retrySeconds > 0 -> stringResource(R.string.auth_retry_seconds, retrySeconds)
                            else -> stringResource(R.string.auth_get_code)
                        },
                        enabled = !sendingCode && !loggingIn && retrySeconds <= 0,
                        onClick = onSendCode
                    )
                },
                onValueChange = onCodeChange
            )
            V88LoginPrimaryButton(
                label = if (loggingIn) {
                    stringResource(R.string.auth_logging_in)
                } else {
                    stringResource(R.string.auth_login_register)
                },
                enabled = !loggingIn && !sendingCode,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 20.dp),
                onClick = onLogin
            )
        }
    }
}

@Composable
private fun V88LoginInputGroup(
    value: String,
    placeholder: String,
    keyboardType: KeyboardType,
    modifier: Modifier = Modifier,
    inputModifier: Modifier = Modifier,
    prefix: String? = null,
    imeAction: ImeAction = ImeAction.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    trailing: (@Composable () -> Unit)? = null,
    onValueChange: (String) -> Unit
) {
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp),
        color = Color(0xFFF5F7FA),
        shape = RoundedCornerShape(12.dp),
        elevation = 0.dp
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (prefix != null) {
                Text(
                    text = prefix,
                    modifier = Modifier.padding(start = 14.dp),
                    color = Color(0xFF1A1A2E),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1
                )
            }
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                singleLine = true,
                textStyle = TextStyle(
                    color = Color(0xFF1A1A2E),
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.Normal
                ),
                keyboardOptions = KeyboardOptions(
                    keyboardType = keyboardType,
                    imeAction = imeAction
                ),
                keyboardActions = keyboardActions,
                modifier = inputModifier.weight(1f),
                decorationBox = { inner ->
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(
                                start = 14.dp,
                                end = if (trailing == null) 14.dp else 8.dp,
                                top = 13.dp,
                                bottom = 13.dp
                            )
                    ) {
                        if (value.isBlank()) {
                            Text(
                                text = placeholder,
                                color = Color(0xFFB0B4C3),
                                fontSize = 15.sp,
                                lineHeight = 20.sp,
                                maxLines = 1
                            )
                        }
                        inner()
                    }
                }
            )
            trailing?.invoke()
        }
    }
}

@Composable
private fun V88LoginCodeButton(
    label: String,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .height(48.dp)
            .widthIn(min = 100.dp)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            color = if (enabled) Color(0xFF0A84FF) else Color(0xFFB0B4C3),
            fontSize = 13.sp,
            lineHeight = 18.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun V88LoginPrimaryButton(
    label: String,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Surface(
        modifier = modifier
            .height(50.dp)
            .clickable(enabled = enabled, onClick = onClick),
        color = if (enabled) Color(0xFF0A84FF) else Color(0xFF0A84FF).copy(alpha = 0.45f),
        shape = RoundedCornerShape(12.dp),
        elevation = 0.dp
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(
                text = label,
                color = Color.White,
                fontSize = 16.sp,
                lineHeight = 22.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1
            )
        }
    }
}

@Composable
internal fun V88ActivationPage(
    activationCode: String,
    loggingIn: Boolean,
    onActivationChange: (String) -> Unit,
    onConfirm: () -> Unit,
    onBackLogin: () -> Unit
) {
    val focusManager = LocalFocusManager.current

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(Color(0xFFFBFBFD), Color(0xFFEDF0F7))
                )
            )
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.74f),
                        Color.White.copy(alpha = 0.70f)
                    )
                )
            )
            .padding(horizontal = 24.dp, vertical = 24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .widthIn(max = 320.dp)
                .fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Image(
                painter = painterResource(id = R.drawable.chakenailogo),
                contentDescription = "Phone Agent",
                modifier = Modifier
                    .width(107.dp)
                    .height(98.dp)
            )
            Spacer(modifier = Modifier.height(14.dp))
            Text(
                text = "Phone Agent",
                color = Color(0xFF1A1A2E),
                fontSize = 28.sp,
                lineHeight = 34.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.sp,
                textAlign = TextAlign.Center
            )
            Text(
                text = stringResource(R.string.auth_tagline),
                modifier = Modifier.padding(top = 6.dp),
                color = Color(0xFF8B8FA3),
                fontSize = 14.sp,
                lineHeight = 20.sp,
                textAlign = TextAlign.Center
            )
            Spacer(modifier = Modifier.height(40.dp))
            V88LoginInputGroup(
                value = activationCode,
                placeholder = stringResource(R.string.auth_activation_placeholder),
                keyboardType = KeyboardType.Text,
                imeAction = ImeAction.Done,
                keyboardActions = KeyboardActions(
                    onDone = {
                        if (!loggingIn && activationCode.isNotBlank()) {
                            focusManager.clearFocus()
                            onConfirm()
                        }
                    }
                ),
                onValueChange = onActivationChange
            )
            V88LoginPrimaryButton(
                label = if (loggingIn) {
                    stringResource(R.string.auth_verifying)
                } else {
                    stringResource(R.string.auth_confirm)
                },
                enabled = !loggingIn && activationCode.isNotBlank(),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                onClick = onConfirm
            )
            Text(
                text = stringResource(R.string.auth_back_to_login),
                modifier = Modifier
                    .padding(top = 24.dp)
                    .clickable(onClick = onBackLogin),
                color = Color(0xFF0A84FF),
                fontSize = 14.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center
            )
        }
    }
}
