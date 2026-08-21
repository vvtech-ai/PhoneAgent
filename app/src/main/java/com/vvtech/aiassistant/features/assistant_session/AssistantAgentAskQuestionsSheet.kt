package com.vvtech.aiassistant.features.assistant_session

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.Checkbox
import androidx.compose.material.OutlinedTextField
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.core.model.AskQuestionItem
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
internal val AgentQuestionSheetTextPrimary = Color(0xFF111111)
internal val AgentQuestionSheetTextSecondary = Color(0xFF6B7280)
internal val AgentQuestionSheetBlue = Color(0xFF0A84FF)
internal val AgentQuestionSheetSurface = Color.White
internal val AgentQuestionSheetBorder = Color(0xFFE8EDF3)
internal val AgentQuestionSheetChipBg = Color(0xFFEEF3F9)
internal val AgentQuestionSheetChipSelectedBg = Color(0xFFE3EEFF)

@Composable
internal fun AssistantAgentAskQuestionsSheet(
    payload: AskQuestionsPayload,
    onSubmit: (Map<String, Any>) -> Unit
) {
    val items = payload.items
    val answers = remember(payload) {
        mutableStateMapOf<String, Any>().apply {
            items.forEach { q ->
                q.defaultValue?.let { put(q.id, it) }
            }
        }
    }

    val allRequiredAnswered = items.all { q ->
        if (q.required == false) return@all true
        when (val v = answers[q.id]) {
            null -> false
            is String -> v.isNotBlank()
            is List<*> -> v.isNotEmpty()
            else -> true
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(listOf(Color(0xFFF7FBFF), Color(0xFFEDF5FF))),
                RoundedCornerShape(22.dp)
            )
            .border(1.dp, Color(0xFFDCEBFF), RoundedCornerShape(22.dp))
            .padding(start = 16.dp, end = 16.dp, top = 18.dp, bottom = 16.dp)
    ) {
        Text(
            text = payload.title.takeUnless { it.isNullOrBlank() } ?: currentAppText("再确认几件事", "Confirm a Few Details"),
            color = AgentQuestionSheetTextPrimary,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(12.dp))

        items.forEach { q ->
            AgentQuestionBlock(
                question = q,
                currentValue = answers[q.id],
                onValueChange = { v -> if (v == null) answers.remove(q.id) else answers[q.id] = v }
            )
            Spacer(modifier = Modifier.height(10.dp))
        }

        Spacer(modifier = Modifier.height(2.dp))
        Button(
            onClick = {
                val payloadMap = mutableMapOf<String, Any>()
                items.forEach { q ->
                    answers[q.id]?.let { payloadMap[q.id] = it }
                }
                onSubmit(payloadMap)
            },
            enabled = allRequiredAnswered,
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(
                backgroundColor = AgentQuestionSheetBlue,
                contentColor = Color.White,
                disabledBackgroundColor = Color(0xFFB7CDEB),
                disabledContentColor = Color.White
            )
        ) {
            Text(text = "Submit Answer", fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}
@Composable
private fun AgentQuestionBlock(
    question: AskQuestionItem,
    currentValue: Any?,
    onValueChange: (Any?) -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = AgentQuestionSheetSurface,
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.dp, AgentQuestionSheetBorder),
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = question.prompt,
                    color = AgentQuestionSheetTextPrimary,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f)
                )
                if (question.required == false) {
                    Text(text = "Optional", color = AgentQuestionSheetTextSecondary, fontSize = 11.sp)
                }
            }
            Spacer(modifier = Modifier.height(8.dp))

            when (question.answerType.lowercase()) {
                "single_choice" -> AgentSingleChoiceField(
                    choices = question.choices.orEmpty(),
                    selected = currentValue as? String,
                    onSelect = onValueChange
                )
                "multi_choice" -> AgentMultiChoiceField(
                    choices = question.choices.orEmpty(),
                    selected = (currentValue as? List<*>)?.filterIsInstance<String>().orEmpty(),
                    onChange = onValueChange
                )
                "phone" -> AgentTextInputField(
                    value = currentValue as? String,
                    hint = question.hint ?: currentAppText("纯数字 7-15 位", "7-15 digits only"),
                    keyboardType = KeyboardType.Phone,
                    onChange = onValueChange
                )
                "number" -> AgentTextInputField(
                    value = currentValue as? String,
                    hint = question.hint ?: currentAppText("请输入数字", "Enter a number"),
                    keyboardType = KeyboardType.Number,
                    onChange = onValueChange
                )
                "date" -> AgentQuestionDateTimeField(
                    value = currentValue as? String,
                    mode = AgentQuestionDateTimeMode.Date,
                    onChange = onValueChange
                )
                "time" -> AgentQuestionDateTimeField(
                    value = currentValue as? String,
                    mode = AgentQuestionDateTimeMode.Time,
                    onChange = onValueChange
                )
                "datetime" -> AgentQuestionDateTimeField(
                    value = currentValue as? String,
                    mode = AgentQuestionDateTimeMode.DateTime,
                    onChange = onValueChange
                )
                "confirm" -> AgentConfirmField(
                    selected = currentValue as? String,
                    onSelect = onValueChange
                )
                else -> AgentTextInputField(
                    value = currentValue as? String,
                    hint = question.hint ?: currentAppText("请输入", "Enter text"),
                    keyboardType = KeyboardType.Text,
                    onChange = onValueChange
                )
            }
        }
    }
}
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun AgentSingleChoiceField(
    choices: List<String>,
    selected: String?,
    onSelect: (String) -> Unit
) {
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        choices.forEach { choice ->
            val isSelected = choice == selected
            Box(
                modifier = Modifier
                    .background(
                        if (isSelected) AgentQuestionSheetChipSelectedBg else AgentQuestionSheetChipBg,
                        RoundedCornerShape(20.dp)
                    )
                    .border(
                        1.dp,
                        if (isSelected) AgentQuestionSheetBlue else Color.Transparent,
                        RoundedCornerShape(20.dp)
                    )
                    .clickable { onSelect(choice) }
                    .padding(horizontal = 14.dp, vertical = 8.dp)
            ) {
                Text(
                    text = choice,
                    color = if (isSelected) AgentQuestionSheetBlue else AgentQuestionSheetTextPrimary,
                    fontSize = 13.sp,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
                )
            }
        }
    }
}

@Composable
private fun AgentMultiChoiceField(
    choices: List<String>,
    selected: List<String>,
    onChange: (List<String>) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        choices.forEach { choice ->
            val isSelected = selected.contains(choice)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        val next = if (isSelected) selected - choice else selected + choice
                        onChange(next)
                    }
                    .padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Checkbox(
                    checked = isSelected,
                    onCheckedChange = {
                        val next = if (it) selected + choice else selected - choice
                        onChange(next)
                    }
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(text = choice, color = AgentQuestionSheetTextPrimary, fontSize = 13.sp)
            }
        }
    }
}

@Composable
private fun AgentTextInputField(
    value: String?,
    hint: String,
    keyboardType: KeyboardType,
    onChange: (String?) -> Unit
) {
    OutlinedTextField(
        value = value.orEmpty(),
        onValueChange = { onChange(it.takeIf { valueText -> valueText.isNotEmpty() }) },
        placeholder = { Text(text = hint, color = AgentQuestionSheetTextSecondary, fontSize = 13.sp) },
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        modifier = Modifier.fillMaxWidth(),
        textStyle = androidx.compose.ui.text.TextStyle(
            color = AgentQuestionSheetTextPrimary,
            fontSize = 14.sp
        ),
        colors = TextFieldDefaults.outlinedTextFieldColors(
            focusedBorderColor = AgentQuestionSheetBlue,
            unfocusedBorderColor = AgentQuestionSheetBorder,
            cursorColor = AgentQuestionSheetBlue
        ),
        singleLine = true
    )
}
