package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.data.model.WorkIdentityItem
@Composable
internal fun MyIdentityRequiredField(
    label: String,
    value: String,
    placeholder: String,
    enabled: Boolean = true,
    onValueChange: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp)
    ) {
        Text(
            text = buildAnnotatedString {
                append(label)
                withStyle(SpanStyle(color = Color(0xFFE14D46))) { append(" *") }
            },
            color = Color(0xFF111111),
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold
        )
        MyIdentityInputField(
            value = value,
            placeholder = placeholder,
            keyboardType = KeyboardType.Text,
            enabled = enabled,
            onValueChange = onValueChange
        )
    }
}

@Composable
internal fun MyIdentityRow(
    label: String,
    value: String,
    placeholder: String,
    keyboardType: KeyboardType = KeyboardType.Text,
    enabled: Boolean = true,
    onValueChange: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp)
    ) {
        Text(text = label, color = Color(0xFF111111), fontSize = 14.sp, fontWeight = FontWeight.Bold)
        MyIdentityInputField(
            value = value,
            placeholder = placeholder,
            keyboardType = keyboardType,
            enabled = enabled,
            onValueChange = onValueChange
        )
    }
}

@Composable
internal fun MyIdentityInputField(
    value: String,
    placeholder: String,
    keyboardType: KeyboardType,
    enabled: Boolean = true,
    onValueChange: (String) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .background(
                if (enabled) Color(0xFFF7F8FA) else Color(0xFFF1F2F4),
                RoundedCornerShape(12.dp)
            )
            .padding(horizontal = 12.dp, vertical = 12.dp)
    ) {
        if (value.isBlank()) {
            Text(text = placeholder, color = Color(0xFF8E8E93), fontSize = 15.sp)
        }
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            enabled = enabled,
            singleLine = keyboardType != KeyboardType.Text || placeholder.length < 30,
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            textStyle = TextStyle(
                color = if (enabled) Color(0xFF111111) else Color(0xFF8E8E93),
                fontSize = 15.sp
            ),
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
internal fun MyIdentityGenderRow(selected: String, onSelect: (String) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp)
    ) {
        Text(text = "性别", color = Color(0xFF111111), fontSize = 14.sp, fontWeight = FontWeight.Bold)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            MyIdentityGenderOptions.forEach { option ->
                val active = option == selected
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .heightIn(min = 38.dp)
                        .clickable { onSelect(option) },
                    color = if (active) Color(0xFFE7F0FF) else Color(0xFFF7F8FA),
                    shape = RoundedCornerShape(10.dp),
                    border = BorderStroke(
                        width = if (active) 1.dp else 0.dp,
                        color = if (active) Color(0xFF0A84FF) else Color.Transparent
                    ),
                    elevation = 0.dp
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Text(
                            text = option,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 8.dp),
                            color = if (active) Color(0xFF0A84FF) else Color(0xFF111111),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}

@Composable
internal fun MyIdentityFieldCard(content: @Composable () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color.White,
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, Color(0x143C3C43)),
        elevation = 0.dp
    ) {
        Column { content() }
    }
}

@Composable
internal fun MyIdentityDivider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .background(Color(0x143C3C43))
            .heightIn(min = 1.dp)
    )
}

@Composable
internal fun MyIdentityWorkCard(
    item: WorkIdentityItem,
    removable: Boolean,
    onChange: (WorkIdentityItem) -> Unit,
    onRemove: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color.White,
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, Color(0x143C3C43)),
        elevation = 0.dp
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp)
        ) {
            MyIdentityRequiredField(
                label = "公司",
                value = item.company,
                placeholder = "例如：chaken智能科技",
                onValueChange = { onChange(item.copy(company = it)) }
            )
            MyIdentityDivider()
            MyIdentityRow(
                label = "部门",
                value = item.department,
                placeholder = "例如：产品平台部",
                onValueChange = { onChange(item.copy(department = it)) }
            )
            MyIdentityDivider()
            MyIdentityRow(
                label = "职位",
                value = item.position,
                placeholder = "例如：产品负责人",
                onValueChange = { onChange(item.copy(position = it)) }
            )
            if (removable) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onRemove)
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Rounded.DeleteOutline,
                        contentDescription = null,
                        tint = Color(0xFFE14D46),
                        modifier = Modifier.size(18.dp)
                    )
                    Text(
                        text = "移除这条",
                        modifier = Modifier.padding(start = 6.dp),
                        color = Color(0xFFE14D46),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
internal fun MyIdentityMultilineCard(
    value: String,
    placeholder: String,
    onValueChange: (String) -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 140.dp),
        color = Color.White,
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, Color(0x143C3C43)),
        elevation = 0.dp
    ) {
        Box(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            if (value.isBlank()) {
                Text(
                    text = placeholder,
                    color = Color(0xFF8E8E93),
                    fontSize = 14.sp,
                    lineHeight = 20.sp
                )
            }
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                textStyle = TextStyle(color = Color(0xFF111111), fontSize = 14.sp, lineHeight = 20.sp),
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
internal fun MyIdentitySectionTitle(text: String) {
    Text(
        text = text,
        modifier = Modifier.padding(start = 4.dp, top = 4.dp, bottom = 8.dp),
        color = Color(0xFF111111),
        fontSize = 16.sp,
        fontWeight = FontWeight.ExtraBold
    )
}

@Composable
internal fun MyIdentitySectionTitleWithAction(
    title: String,
    actionLabel: String,
    onAction: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 4.dp, end = 4.dp, top = 4.dp, bottom = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            color = Color(0xFF111111),
            fontSize = 16.sp,
            fontWeight = FontWeight.ExtraBold
        )
        Row(
            modifier = Modifier
                .clickable(onClick = onAction)
                .padding(horizontal = 6.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Rounded.Add,
                contentDescription = null,
                tint = Color(0xFF0A84FF),
                modifier = Modifier.size(16.dp)
            )
            Text(
                text = actionLabel.removePrefix("+ "),
                modifier = Modifier.padding(start = 4.dp),
                color = Color(0xFF0A84FF),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
internal fun MyIdentityHintCard(text: String, danger: Boolean = false) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = if (danger) Color(0x1FE14D46) else Color(0xFFF7F8FA),
        shape = RoundedCornerShape(14.dp),
        elevation = 0.dp
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            color = if (danger) Color(0xFFE14D46) else Color(0xFF111111),
            fontSize = 13.sp,
            lineHeight = 19.sp
        )
    }
}

@Composable
internal fun MyIdentitySaveButton(enabled: Boolean, label: String, onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .heightIn(min = 32.dp)
            .clickable(enabled = enabled, onClick = onClick),
        color = if (enabled) Color(0xFF0A84FF) else Color(0xFFB8C0CC),
        shape = CircleShape,
        elevation = 0.dp
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
            color = Color.White,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
