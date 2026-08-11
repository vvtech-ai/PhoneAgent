package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_tasks.buildTaskPageRows
import com.vvtech.aiassistant.features.assistant_ui.AssistantTaskDesignRow
import com.vvtech.aiassistant.features.assistant_ui.AssistantTaskInitialLoading
import com.vvtech.aiassistant.features.assistant_ui.AssistantTaskSyncStatusRow
import com.vvtech.aiassistant.features.assistant_ui.AssistantTasksTopBar
import com.vvtech.aiassistant.model.ConversationListItem

@Composable
@Suppress("UNUSED_PARAMETER")
internal fun FinalTasksPageV3(
    records: List<FinalTaskRecord>,
    loading: Boolean,
    error: String?,
    activeConversationTitle: String? = null,
    conversations: List<ConversationListItem> = emptyList(),
    onResumeConversation: () -> Unit = {},
    onNewConversation: () -> Unit = {},
    onOpenConversation: (String) -> Unit = {},
    onRefresh: () -> Unit,
    onOpenResult: () -> Unit,
    onFollowup: () -> Unit
) {
    val taskPageRows = buildTaskPageRows(records, conversations)
    val taskRows = taskPageRows.rows
    val hasVisibleTasks = activeConversationTitle != null || taskRows.isNotEmpty()
    val initialLoading = loading && !hasVisibleTasks
    val refreshing = loading && hasVisibleTasks
    val syncError = error?.takeIf { it.isNotBlank() && !loading }

    Column(modifier = Modifier.fillMaxSize()) {
        AssistantTasksTopBar()
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 28.dp, end = 28.dp, bottom = 128.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            if (activeConversationTitle != null) {
                item {
                    AssistantTaskDesignRow(
                        item = FinalTaskRecord(
                            title = activeConversationTitle,
                            status = FinalTaskStatusKind.Running.label,
                            detail = "点击继续对话",
                            sourceText = activeConversationTitle
                        ).toFinalTaskDisplayItem(),
                        onClick = onResumeConversation
                    )
                }
            }
            if (refreshing) {
                item {
                    AssistantTaskSyncStatusRow(
                        title = "正在同步...",
                        detail = "任务列表会自动更新",
                        error = false,
                        onClick = null
                    )
                }
            }
            if (syncError != null) {
                item {
                    AssistantTaskSyncStatusRow(
                        title = "同步失败，点击重试",
                        detail = syncError,
                        error = true,
                        onClick = onRefresh
                    )
                }
            }
            itemsIndexed(taskRows, key = { _, row -> row.key }) { _, row ->
                AssistantTaskDesignRow(
                    item = row.item,
                    onClick = {
                        val sessionId = row.conversationSessionId
                        if (sessionId != null) {
                            onOpenConversation(sessionId)
                        } else {
                            onOpenResult()
                        }
                    }
                )
            }
            if (initialLoading) {
                item {
                    AssistantTaskInitialLoading()
                }
            }
            if (
                shouldShowFinalTaskEmptyState(
                    recordsEmpty = records.isEmpty(),
                    completedConversationsEmpty = taskPageRows.completedConversationCount == 0,
                    activeConversationsEmpty = taskPageRows.activeConversationCount == 0,
                    activeConversationTitle = activeConversationTitle,
                    loading = loading
                )
            ) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 60.dp, bottom = 24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "还没有任务记录",
                            color = Color(0xFF98A2B3),
                            fontSize = 14.sp
                        )
                    }
                }
            }
        }
    }
}
