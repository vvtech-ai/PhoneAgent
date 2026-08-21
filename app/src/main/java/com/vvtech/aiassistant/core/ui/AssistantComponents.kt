package com.vvtech.aiassistant.core.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Button
import androidx.compose.material.Card
import androidx.compose.material.MaterialTheme
import androidx.compose.material.OutlinedButton
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.core.model.AssistantActionChip
import com.vvtech.aiassistant.core.model.AssistantMessageItem
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.ui.components.ErrorBlock
import com.vvtech.aiassistant.ui.components.GradientBackground
import com.vvtech.aiassistant.ui.components.LoadingBlock
import com.vvtech.aiassistant.ui.components.SectionTitle
import com.vvtech.aiassistant.ui.components.StatusChip

@Composable
fun AssistantBackground(content: @Composable () -> Unit) {
    GradientBackground(content = content)
}

@Composable
fun AssistantHeaderCard(
    title: String,
    subtitle: String?,
    sceneType: String,
    taskStatus: String,
    locationSummary: String
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        elevation = 4.dp
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                SectionTitle(title, subtitle)
                StatusChip(taskStatus.toNaturalStatus())
            }
            Text(
                text = sceneType.toNaturalScene(),
                style = MaterialTheme.typography.caption,
                color = MaterialTheme.colors.secondary
            )
            Text(
                text = locationSummary,
                style = MaterialTheme.typography.body2,
                color = MaterialTheme.colors.onSurface.copy(alpha = 0.65f)
            )
        }
    }
}

@Composable
fun AssistantMessageItemView(
    message: AssistantMessageItem,
    onAction: (AssistantActionChip) -> Unit
) {
    when (message.type) {
        "user_text" -> UserBubble(message.text.orEmpty())
        "assistant_text" -> AssistantBubble(message.text.orEmpty())
        "assistant_suggestion", "action_chip_group" -> SuggestionMessage(message, onAction)
        "task_status" -> StatusMessage(message)
        "restaurant_card" -> RestaurantCardMessage(message, onAction)
        "hotel_card" -> HotelCardMessage(message, onAction)
        "call_confirm_card" -> CallConfirmMessage(message, onAction)
        "result_summary" -> ResultSummaryMessage(message, onAction)
        else -> AssistantBubble(message.text ?: message.title.orEmpty())
    }
}

@Composable
private fun UserBubble(text: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
        MessageShell(
            text = text,
            backgroundColor = MaterialTheme.colors.primary,
            contentColor = Color.White,
            sender = currentAppText("你", "You")
        )
    }
}

@Composable
private fun AssistantBubble(text: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        MessageShell(
            text = text,
            backgroundColor = Color.White,
            contentColor = MaterialTheme.colors.onSurface,
            sender = currentAppText("AI助手", "AI Assistant")
        )
    }
}

@Composable
private fun MessageShell(
    text: String,
    backgroundColor: Color,
    contentColor: Color,
    sender: String
) {
    Box(
        modifier = Modifier
            .fillMaxWidth(0.86f)
            .background(backgroundColor, RoundedCornerShape(22.dp))
            .padding(16.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(text = sender, style = MaterialTheme.typography.caption, color = contentColor.copy(alpha = 0.75f))
            Text(text = text, style = MaterialTheme.typography.body1, color = contentColor)
        }
    }
}

@Composable
private fun SuggestionMessage(
    message: AssistantMessageItem,
    onAction: (AssistantActionChip) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(22.dp),
        elevation = 2.dp
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = message.text.orEmpty(),
                style = MaterialTheme.typography.body1
            )
            ActionChipRow(actions = message.actions, onAction = onAction)
        }
    }
}

@Composable
private fun StatusMessage(message: AssistantMessageItem) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color(0xFFFAF0E0),
        shape = RoundedCornerShape(20.dp)
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = message.statusText ?: currentAppText("处理中", "Processing"),
                style = MaterialTheme.typography.caption,
                color = MaterialTheme.colors.secondary,
                fontWeight = FontWeight.Bold
            )
            Text(text = message.text.orEmpty(), style = MaterialTheme.typography.body2)
        }
    }
}

@Composable
private fun RestaurantCardMessage(
    message: AssistantMessageItem,
    onAction: (AssistantActionChip) -> Unit
) {
    val card = message.restaurantCard ?: return
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        elevation = 4.dp
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(text = card.name, style = MaterialTheme.typography.h6, fontWeight = FontWeight.Bold)
            Text(
                text = listOfNotNull(card.cuisine?.takeIf { it.isNotBlank() }, card.area?.takeIf { it.isNotBlank() })
                    .joinToString(" · "),
                style = MaterialTheme.typography.body2,
                color = MaterialTheme.colors.secondary
            )
            Text(text = card.address, style = MaterialTheme.typography.body2)
            Text(
                text = buildString {
                    append(card.phone)
                    if (card.distanceMeters != null) {
                        append(currentAppText(" · 约 ", " · approx. "))
                        append(card.distanceMeters)
                        append(currentAppText(" 米", " m"))
                    }
                },
                style = MaterialTheme.typography.body2,
                color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
            )
            ActionChipRow(actions = card.actions, onAction = onAction)
        }
    }
}

@Composable
private fun HotelCardMessage(
    message: AssistantMessageItem,
    onAction: (AssistantActionChip) -> Unit
) {
    val card = message.hotelCard ?: return
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        elevation = 4.dp
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(text = card.name, style = MaterialTheme.typography.h6, fontWeight = FontWeight.Bold)
            Text(
                text = "${card.city} · ${card.priceHint} · ${card.roomType}",
                style = MaterialTheme.typography.body2,
                color = MaterialTheme.colors.secondary
            )
            Text(text = card.summary, style = MaterialTheme.typography.body2)
            Text(
                text = card.address,
                style = MaterialTheme.typography.body2,
                color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
            )
            ActionChipRow(actions = card.actions, onAction = onAction)
        }
    }
}

@Composable
private fun CallConfirmMessage(
    message: AssistantMessageItem,
    onAction: (AssistantActionChip) -> Unit
) {
    val card = message.callConfirmCard ?: return
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        backgroundColor = Color(0xFFF8F4FF),
        elevation = 3.dp
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(text = card.targetName, style = MaterialTheme.typography.h6, fontWeight = FontWeight.Bold)
            Text(
                text = listOfNotNull(card.phone?.takeIf { it.isNotBlank() }, card.purpose).joinToString(" · "),
                style = MaterialTheme.typography.body2,
                color = MaterialTheme.colors.secondary
            )
            Text(text = card.summary, style = MaterialTheme.typography.body2)
            ActionChipRow(actions = card.actions, onAction = onAction)
        }
    }
}

@Composable
private fun ResultSummaryMessage(
    message: AssistantMessageItem,
    onAction: (AssistantActionChip) -> Unit
) {
    val summary = message.resultSummary ?: return
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        backgroundColor = Color(0xFFEFF8F1),
        elevation = 2.dp
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(text = summary.headline, style = MaterialTheme.typography.h6, fontWeight = FontWeight.Bold)
            Text(text = summary.detail, style = MaterialTheme.typography.body2)
            ActionChipRow(actions = summary.actions, onAction = onAction)
        }
    }
}

@Composable
fun ActionChipRow(
    actions: List<AssistantActionChip>,
    onAction: (AssistantActionChip) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        actions.forEach { action ->
            if (action.kind == "primary") {
                Button(onClick = { onAction(action) }) {
                    Text(action.label)
                }
            } else {
                OutlinedButton(onClick = { onAction(action) }) {
                    Text(action.label)
                }
            }
        }
    }
}

fun String.toNaturalScene(): String = when (this) {
    "FOOD_ORDERING" -> currentAppText("订餐", "Restaurant Booking")
    "HOTEL_BOOKING" -> currentAppText("订酒店", "Hotel Booking")
    "AI_CALL" -> currentAppText("帮打电话", "AI Call")
    else -> currentAppText("生活任务助手", "Life Task Assistant")
}

fun String.toNaturalStatus(): String = when (this) {
    "SCENE_IDENTIFIED" -> currentAppText("已理解", "Understood")
    "COLLECTING_REQUIRED_INFO" -> currentAppText("继续聊", "Collecting Details")
    "READY_TO_EXECUTE" -> currentAppText("准备继续", "Ready")
    "EXECUTING" -> currentAppText("处理中", "Processing")
    "WAITING_EXTERNAL_RESULT" -> currentAppText("等你拍板", "Awaiting Confirmation")
    "COMPLETED" -> currentAppText("已完成", "Completed")
    "FAILED" -> currentAppText("需要调整", "Needs Adjustment")
    "USER_MODIFIED_REQUEST" -> currentAppText("已改条件", "Updated")
    else -> currentAppText("待处理", "Pending")
}

@Composable
fun AssistantStatusBlock(loading: Boolean, error: String?) {
    when {
        loading -> {
            Spacer(modifier = Modifier.height(4.dp))
            LoadingBlock(currentAppText("我在整理这件事...", "Organizing this task..."))
        }
        !error.isNullOrBlank() -> {
            Spacer(modifier = Modifier.height(4.dp))
            ErrorBlock(error)
        }
    }
}
