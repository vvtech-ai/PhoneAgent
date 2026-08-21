package com.vvtech.aiassistant.features.assistant_contacts

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.FinalFlowTopBar
import com.vvtech.aiassistant.features.assistant.localizedFinalContactHint
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal data class AssistantContactDetailPageState(
    val name: String,
    val phone: String,
    val hint: String,
    val remark: String,
    val loading: Boolean,
    val saving: Boolean,
    val error: String?
)

internal data class AssistantContactDetailPageCallbacks(
    val onBack: () -> Unit,
    val onCall: () -> Unit,
    val onSkillSelected: (String) -> Boolean,
    val onSaveRemark: (String) -> Unit
)

@Composable
internal fun AssistantContactDetailPage(
    state: AssistantContactDetailPageState,
    callbacks: AssistantContactDetailPageCallbacks
) {
    var editorVisible by rememberSaveable(state.phone) { mutableStateOf(false) }
    var skillSheetVisible by rememberSaveable(state.phone) { mutableStateOf(false) }
    var pendingRemark by rememberSaveable(state.phone) { mutableStateOf<String?>(null) }

    LaunchedEffect(pendingRemark, state.saving, state.error, state.remark) {
        val submitted = pendingRemark ?: return@LaunchedEffect
        if (!state.saving && state.error == null && state.remark.trim() == submitted) {
            editorVisible = false
            pendingRemark = null
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            FinalFlowTopBar(backLabel = currentAppText("返回联系人", "Back to Contacts"), onBack = callbacks.onBack)
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(start = 18.dp, end = 18.dp, bottom = 18.dp)
            ) {
                item { AssistantContactProfile(state) }
                item {
                    AssistantContactRemarkCard(
                        remark = state.remark,
                        loading = state.loading,
                        onEdit = {
                            pendingRemark = null
                            editorVisible = true
                        }
                    )
                }
            }
            AssistantContactDetailActions(
                onCall = callbacks.onCall,
                onTask = { skillSheetVisible = true }
            )
        }

        if (editorVisible) {
            AssistantContactRemarkEditor(
                initialRemark = state.remark,
                saving = state.saving,
                error = state.error,
                onDismiss = {
                    if (!state.saving) {
                        editorVisible = false
                        pendingRemark = null
                    }
                },
                onSave = { remark ->
                    pendingRemark = remark.trim()
                    callbacks.onSaveRemark(remark)
                }
            )
        }
        AssistantContactSkillSheetRoute(
            visible = skillSheetVisible,
            contactName = state.name,
            onDismiss = { skillSheetVisible = false },
            onSkillSelected = { skillId ->
                skillSheetVisible = false
                callbacks.onSkillSelected(skillId)
            }
        )
    }
}

@Composable
private fun AssistantContactProfile(state: AssistantContactDetailPageState) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        AssistantContactAvatar(
            initial = assistantContactInitial(state.name),
            modifier = Modifier.size(88.dp),
            fontSize = 30
        )
        Text(
            text = state.name.ifBlank { currentAppText("联系人", "Contacts") },
            modifier = Modifier.padding(top = 14.dp),
            color = Color(0xFF111111),
            fontSize = 31.sp,
            fontWeight = FontWeight.ExtraBold
        )
        Text(
            text = state.phone.ifBlank { currentAppText("未设置号码", "No phone number") },
            modifier = Modifier.padding(top = 8.dp),
            color = Color(0xFF6E6E73),
            fontSize = 15.sp
        )
        localizedFinalContactHint(state.hint).takeIf { it.isNotBlank() && it != state.phone }?.let { hint ->
            Text(
                text = hint,
                modifier = Modifier.padding(top = 5.dp),
                color = Color(0xFF8E8E93),
                fontSize = 13.sp
            )
        }
    }
}

@Composable
private fun AssistantContactRemarkCard(
    remark: String,
    loading: Boolean,
    onEdit: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color.White.copy(alpha = 0.80f),
        shape = RoundedCornerShape(24.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(horizontal = 18.dp, vertical = 16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        currentAppText("备注", "Notes"),
                        color = Color(0xFF111111),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        currentAppText("用于 AI 参考的说明", "Notes for AI reference"),
                        modifier = Modifier.padding(top = 3.dp),
                        color = Color(0xFF8E8E93),
                        fontSize = 12.sp
                    )
                }
                Surface(
                    modifier = Modifier.clickable(enabled = !loading, onClick = onEdit),
                    color = Color(0x140A84FF),
                    shape = RoundedCornerShape(14.dp),
                    elevation = 0.dp
                ) {
                    Text(
                        currentAppText("编辑", "Edit"),
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                        color = Color(0xFF0A84FF),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            Text(
                text = when {
                    loading -> currentAppText("备注加载中…", "Loading notes...")
                    remark.isBlank() -> currentAppText("暂无备注", "No notes")
                    else -> remark
                },
                modifier = Modifier.padding(top = 16.dp),
                color = if (remark.isBlank()) Color(0xFF8E8E93) else Color(0xFF111111),
                fontSize = 14.sp,
                lineHeight = 21.sp
            )
        }
    }
}

@Composable
private fun AssistantContactDetailActions(
    onCall: () -> Unit,
    onTask: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 18.dp, end = 18.dp, top = 10.dp, bottom = 24.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        AssistantContactProfileAction(
            label = currentAppText("拨打电话", "Call"),
            primary = true,
            modifier = Modifier.weight(1f),
            onClick = onCall
        )
        AssistantContactProfileAction(
            label = currentAppText("发起任务", "Start Task"),
            modifier = Modifier.weight(1f),
            onClick = onTask
        )
    }
}
