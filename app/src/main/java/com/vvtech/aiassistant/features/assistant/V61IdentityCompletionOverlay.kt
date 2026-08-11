package com.vvtech.aiassistant.features.assistant

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest

@Composable
internal fun V61IdentityCompletionOverlay(
    saving: Boolean,
    error: String?,
    initialIdentity: UserIdentityPayload?,
    onDismiss: () -> Unit,
    onSubmit: (UserIdentityUpsertRequest) -> Unit
) {
    BackHandler(enabled = !saving, onBack = onDismiss)
    var name by rememberSaveable(initialIdentity?.updatedAt) {
        mutableStateOf(initialIdentity?.name.orEmpty())
    }
    var gender by rememberSaveable(initialIdentity?.updatedAt) {
        mutableStateOf(initialIdentity?.gender?.takeIf { it.isNotBlank() } ?: "不透露")
    }
    var submitted by rememberSaveable { mutableStateOf(false) }
    var phone by rememberSaveable(initialIdentity?.updatedAt) {
        mutableStateOf(resolveIdentityPhone(initialIdentity?.contactPhone))
    }

    LaunchedEffect(submitted, saving, error) {
        if (submitted && !saving && error.isNullOrBlank()) onDismiss()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .padding(horizontal = 22.dp, vertical = 18.dp)
    ) {
        Box(modifier = Modifier.fillMaxWidth()) {
            Icon(
                imageVector = Icons.Rounded.ArrowBack,
                contentDescription = "返回首页",
                tint = Color(0xFF111111),
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .size(36.dp)
                    .clickable(enabled = !saving, onClick = onDismiss)
                    .padding(7.dp)
            )
            Text(
                text = "补齐身份信息",
                modifier = Modifier.align(Alignment.Center),
                color = Color(0xFF111111),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )
        }
        Box(modifier = Modifier.weight(1f)) {
            V61IdentityStep(
                name = name,
                gender = gender,
                phone = phone,
                error = error,
                saving = saving,
                onNameChange = { name = it },
                onGenderChange = { gender = it },
                onPhoneChange = { phone = it.filter(Char::isDigit).take(11) },
                actionLabel = "保存并继续",
                onNext = {
                    submitted = true
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
                }
            )
        }
    }
}
