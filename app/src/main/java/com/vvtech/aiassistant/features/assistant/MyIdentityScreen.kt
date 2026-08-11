package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.data.model.UserIdentityVerifiedMetadataRequest
import com.vvtech.aiassistant.data.model.WorkIdentityItem

internal val MyIdentityGenderOptions = listOf("不透露", "男", "女")

internal data class MyIdentityDraft(
    val name: String = "",
    val gender: String = "不透露",
    val contactPhone: String = "",
    val workIdentities: List<WorkIdentityItem> = listOf(WorkIdentityItem()),
    val description: String = ""
)

internal fun resolveIdentityPhone(savedPhone: String?): String =
    savedPhone?.trim().orEmpty()

internal fun UserIdentityPayload?.toDraft(): MyIdentityDraft {
    if (this == null) return MyIdentityDraft()
    return MyIdentityDraft(
        name = name.orEmpty(),
        gender = gender.takeIf { !it.isNullOrBlank() } ?: "不透露",
        contactPhone = resolveIdentityPhone(contactPhone),
        workIdentities = workIdentities?.takeIf { it.isNotEmpty() } ?: listOf(WorkIdentityItem()),
        description = description.orEmpty()
    )
}

internal fun shouldShowIdentityAuthentication(status: UserIdentityDisplayStatus): Boolean =
    status != UserIdentityDisplayStatus.VERIFIED

internal fun MyIdentityDraft.toUpsert(userId: String): UserIdentityUpsertRequest {
    val cleanedIdentities = workIdentities
        .map {
            it.copy(
                company = it.company.trim(),
                department = it.department.trim(),
                position = it.position.trim()
            )
        }
        .filter { it.company.isNotBlank() }
    return UserIdentityUpsertRequest(
        userId = userId,
        name = name.trim().ifBlank { null },
        gender = gender.takeIf { it.isNotBlank() } ?: "不透露",
        contactPhone = contactPhone.trim().ifBlank { null },
        workIdentities = cleanedIdentities.ifEmpty { null },
        description = description.trim().ifBlank { null }
    )
}

internal fun MyIdentityDraft.toVerifiedMetadata(
    userId: String
): UserIdentityVerifiedMetadataRequest = UserIdentityVerifiedMetadataRequest(
    userId = userId,
    gender = gender.takeIf { it.isNotBlank() } ?: "不透露",
    contactPhone = contactPhone.trim().ifBlank { null }
)

internal fun MyIdentityDraft.isValid(): Boolean = name.trim().isNotBlank()

@Composable
internal fun MyIdentityScreen(
    initial: UserIdentityPayload?,
    saving: Boolean,
    loading: Boolean,
    error: String?,
    onBack: () -> Unit,
    onSave: (UserIdentityUpsertRequest) -> Unit,
    onDelete: () -> Unit,
    onOpenVoiceModelSettings: () -> Unit
) {
    val status = UserIdentityDisplayStatus.from(initial)
    var draft by remember(initial?.updatedAt, status) {
        mutableStateOf(initial.toDraft())
    }
    var editing by remember(initial?.updatedAt, status) { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }
    val canSave = draft.isValid() && !saving

    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(title = "我的身份", onBack = onBack)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp, vertical = 12.dp)
        ) {
            if (loading) {
                MyIdentityHintCard(text = "正在加载身份信息…")
                Spacer(Modifier.size(10.dp))
            }
            if (!error.isNullOrBlank()) {
                MyIdentityHintCard(text = error, danger = true)
                Spacer(Modifier.size(10.dp))
            }
            when {
                status == UserIdentityDisplayStatus.EMPTY && !editing -> MyIdentityEmptyState(
                    onFill = { editing = true }
                )
                editing -> MyIdentityEditForm(
                    draft = draft,
                    saving = saving,
                    canSave = canSave,
                    nameEditable = status != UserIdentityDisplayStatus.VERIFIED,
                    onDraftChange = { draft = it },
                    onSave = { onSave(draft.toUpsert("")) }
                )
                else -> MyIdentityProfileState(
                    payload = requireNotNull(initial),
                    status = status,
                    saving = saving,
                    onEdit = { editing = true },
                    onDelete = { showDeleteConfirm = true }
                )
            }
            if (!editing && shouldShowIdentityAuthentication(status)) {
                Spacer(Modifier.size(16.dp))
                FinalActionButton(
                    label = "声音克隆",
                    tone = FinalButtonTone.Primary,
                    enabled = !saving,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = onOpenVoiceModelSettings
                )
                Text(
                    text = "声音克隆用于使用我的声音进行 AI 通话",
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    color = Color(0xFF6E6E73),
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
    if (showDeleteConfirm) {
        MyIdentityDeleteDialog(
            saving = saving,
            onDismiss = { showDeleteConfirm = false },
            onConfirm = {
                showDeleteConfirm = false
                onDelete()
            }
        )
    }
}

@Composable
private fun MyIdentityEmptyState(onFill: () -> Unit) {
    Text(
        text = "暂无身份信息",
        modifier = Modifier.fillMaxWidth().padding(top = 72.dp),
        color = Color(0xFF111111),
        fontSize = 20.sp,
        fontWeight = FontWeight.Bold,
        textAlign = TextAlign.Center
    )
    Text(
        text = "用于AI在通话中更好的沟通。",
        modifier = Modifier.fillMaxWidth().padding(top = 10.dp, bottom = 28.dp),
        color = Color(0xFF6E6E73),
        fontSize = 14.sp,
        textAlign = TextAlign.Center
    )
    FinalActionButton(
        label = "填写身份信息",
        tone = FinalButtonTone.Primary,
        enabled = true,
        modifier = Modifier.fillMaxWidth(),
        onClick = onFill
    )
}

@Composable
private fun MyIdentityEditForm(
    draft: MyIdentityDraft,
    saving: Boolean,
    canSave: Boolean,
    nameEditable: Boolean,
    onDraftChange: (MyIdentityDraft) -> Unit,
    onSave: () -> Unit
) {
    MyIdentitySectionTitle("身份信息")
    MyIdentityFieldCard {
        MyIdentityRequiredField(
            label = "姓名",
            value = draft.name,
            placeholder = "让AI知道该如何介绍自己",
            enabled = nameEditable,
            onValueChange = { onDraftChange(draft.copy(name = it.take(128))) }
        )
        MyIdentityDivider()
        MyIdentityRow(
            label = "手机号码",
            value = draft.contactPhone,
            placeholder = "请输入手机号码",
            keyboardType = KeyboardType.Phone,
            onValueChange = {
                onDraftChange(draft.copy(contactPhone = it.filter(Char::isDigit).take(11)))
            }
        )
        MyIdentityDivider()
        MyIdentityGenderRow(
            selected = draft.gender,
            onSelect = { onDraftChange(draft.copy(gender = it)) }
        )
    }
    Spacer(Modifier.size(24.dp))
    FinalActionButton(
        label = if (saving) "保存中" else "保存",
        tone = FinalButtonTone.Primary,
        enabled = canSave,
        modifier = Modifier.fillMaxWidth(),
        onClick = onSave
    )
}
