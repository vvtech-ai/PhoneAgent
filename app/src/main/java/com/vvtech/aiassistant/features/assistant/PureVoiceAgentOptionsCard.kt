package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.IconButton
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload

@Composable
internal fun PureVoiceAgentOptionsCard(
    options: OptionsPayload,
    onSelectIndex: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    var dismissed by remember(options) { mutableStateOf(false) }
    if (dismissed || options.items.isEmpty()) return
    val closeContactPickerDescription = stringResource(R.string.contact_picker_close_content_description)

    Surface(
        modifier = modifier.padding(horizontal = 12.dp, vertical = 12.dp),
        color = Color.White,
        shape = RoundedCornerShape(20.dp),
        border = BorderStroke(1.dp, Color(0xFFE4E7EC)),
        elevation = 16.dp
    ) {
        Column(modifier = Modifier.padding(start = 12.dp, end = 12.dp, top = 10.dp, bottom = 14.dp)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 2.dp, end = 2.dp, top = 2.dp, bottom = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = options.title,
                    modifier = Modifier.weight(1f),
                    color = Color(0xFF101828),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                IconButton(
                    onClick = { dismissed = true },
                    modifier = Modifier
                        .size(32.dp)
                        .background(Color(0xFFF2F4F7), CircleShape)
                        .semantics { contentDescription = closeContactPickerDescription }
                ) {
                    Text(
                        text = "×",
                        color = Color(0xFF475467),
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Normal
                    )
                }
            }
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 288.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                itemsIndexed(options.items) { index, item ->
                    PureVoiceAgentOptionRow(
                        index = index,
                        item = item,
                        onClick = {
                            dismissed = true
                            onSelectIndex(index)
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun PureVoiceAgentOptionRow(index: Int, item: OptionItem, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .background(Color(0xFFF8FAFC), RoundedCornerShape(14.dp))
            .border(1.dp, Color(0xFFE4E7EC), RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier.width(28.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            Box(
                modifier = Modifier
                    .size(26.dp)
                    .background(Color(0xFFEAF3FF), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "${index + 1}",
                    color = Color(0xFF087FF5),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
        Spacer(modifier = Modifier.width(9.dp))
        Column {
            Text(
                text = item.label,
                color = Color(0xFF101828),
                fontSize = 14.sp,
                fontWeight = FontWeight.Normal
            )
            (item.phone ?: item.detail)?.takeIf { it.isNotBlank() }?.let { detail ->
                Text(
                    text = detail,
                    modifier = Modifier.padding(top = 2.dp),
                    color = Color(0xFF6B7280),
                    fontSize = 13.sp
                )
            }
        }
    }
}
