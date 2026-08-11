package com.vvtech.aiassistant.features.assistant_contacts

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Divider
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.vvtech.aiassistant.features.assistant_agent.AgentInitialSkillLaunchStore
import com.vvtech.aiassistant.features.assistant_home.HomeConfigViewModel
import com.vvtech.aiassistant.features.assistant_home.HomeConfigViewModelFactory
import com.vvtech.aiassistant.features.assistant_home.HomeCardEntryDispatcher

@Composable
internal fun AssistantContactSkillSheetRoute(
    visible: Boolean,
    contactName: String,
    onDismiss: () -> Unit,
    onSkillSelected: (String) -> Boolean
) {
    if (!visible) return
    val context = LocalContext.current
    val viewModel: HomeConfigViewModel = viewModel(factory = HomeConfigViewModelFactory(context))
    val state by viewModel.state.collectAsStateWithLifecycle()
    val entryDispatcher = remember {
        HomeCardEntryDispatcher(
            clearInitialSkill = AgentInitialSkillLaunchStore::clear,
            armInitialSkill = AgentInitialSkillLaunchStore::arm
        )
    }

    LaunchedEffect(Unit) {
        viewModel.refresh()
    }

    AssistantContactSkillSheet(
        contactName = contactName,
        options = buildAssistantContactSkillOptions(state.cards),
        loading = state.loading,
        onDismiss = onDismiss,
        onSelect = { option ->
            if (!option.enabled) return@AssistantContactSkillSheet
            val sourceCard = state.cards.firstOrNull { it.id == option.id }
                ?: return@AssistantContactSkillSheet
            entryDispatcher.dispatch(
                card = sourceCard,
                onQuickVoiceEntry = { skillId ->
                    skillId?.let(onSkillSelected) ?: false
                },
                onOpenTranslateDial = {}
            )
        }
    )
}

@Composable
private fun AssistantContactSkillSheet(
    contactName: String,
    options: List<AssistantContactSkillOption>,
    loading: Boolean,
    onDismiss: () -> Unit,
    onSelect: (AssistantContactSkillOption) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0x6B111827))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onDismiss
            ),
        contentAlignment = Alignment.BottomCenter
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = {}
                ),
            color = Color(0xFFFBFCFF),
            shape = RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp),
            elevation = 18.dp
        ) {
            Column(
                modifier = Modifier
                    .navigationBarsPadding()
                    .padding(bottom = 24.dp)
            ) {
                AssistantContactSkillSheetHeader(contactName, onDismiss)
                when {
                    loading && options.isEmpty() ->
                        AssistantContactSkillEmptyText("正在获取可用 Skill…")
                    options.isEmpty() -> AssistantContactSkillEmptyText("暂无可用 Skill")
                    else -> LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 360.dp)
                            .padding(horizontal = 20.dp)
                    ) {
                        items(options, key = AssistantContactSkillOption::id) { option ->
                            AssistantContactSkillRow(option, onSelect)
                            Divider(color = Color(0xFFE4E6EB), thickness = 0.5.dp)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AssistantContactSkillSheetHeader(
    contactName: String,
    onDismiss: () -> Unit
) {
    Column(modifier = Modifier.padding(start = 20.dp, end = 16.dp)) {
        Box(
            modifier = Modifier
                .padding(top = 8.dp)
                .width(36.dp)
                .height(4.dp)
                .background(Color(0xFFD1D4DA), RoundedCornerShape(2.dp))
                .align(Alignment.CenterHorizontally)
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "选择 Skill",
                color = Color(0xFF111318),
                fontSize = 21.sp,
                fontWeight = FontWeight.ExtraBold
            )
            Text(
                text = "×",
                modifier = Modifier
                    .clickable(onClick = onDismiss)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                color = Color(0xFF68707D),
                fontSize = 28.sp
            )
        }
        Text(
            text = contactName.ifBlank { "当前联系人" },
            color = Color(0xFF747B88),
            fontSize = 13.sp
        )
        Divider(
            modifier = Modifier.padding(top = 12.dp),
            color = Color(0x1A3C3C43),
            thickness = 1.dp
        )
    }
}

@Composable
private fun AssistantContactSkillRow(
    option: AssistantContactSkillOption,
    onSelect: (AssistantContactSkillOption) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = option.enabled) { onSelect(option) }
            .padding(horizontal = 2.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = option.title,
                color = if (option.enabled) Color(0xFF15171B) else Color(0xFF9DA2AB),
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = option.subtitle,
                modifier = Modifier.padding(top = 4.dp),
                color = if (option.enabled) Color(0xFF8B919B) else Color(0xFFB7BBC2),
                fontSize = 13.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
        Text(
            text = if (option.enabled) "›" else option.statusLabel.orEmpty(),
            modifier = Modifier.padding(start = 12.dp),
            color = if (option.enabled) Color(0xFF8C939E) else Color(0xFFB0B4BC),
            fontSize = if (option.enabled) 24.sp else 12.sp,
            fontWeight = if (option.enabled) FontWeight.Normal else FontWeight.Medium
        )
    }
}

@Composable
private fun AssistantContactSkillEmptyText(text: String) {
    Text(
        text = text,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 36.dp),
        color = Color(0xFF9298A3),
        fontSize = 14.sp
    )
}
