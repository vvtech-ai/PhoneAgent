package com.vvtech.aiassistant.features.assistant_session

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.Context
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.OutlinedButton
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.util.Calendar

internal enum class AgentQuestionDateTimeMode { Date, Time, DateTime }

@Composable
internal fun AgentQuestionDateTimeField(
    value: String?,
    mode: AgentQuestionDateTimeMode,
    onChange: (String) -> Unit
) {
    val context = LocalContext.current
    val display = value.orEmpty().ifBlank {
        when (mode) {
            AgentQuestionDateTimeMode.Date -> currentAppText("选择日期", "Select Date")
            AgentQuestionDateTimeMode.Time -> currentAppText("选择时间", "Select Time")
            AgentQuestionDateTimeMode.DateTime -> currentAppText("选择日期和时间", "Select Date and Time")
        }
    }
    OutlinedButton(
        onClick = {
            val cal = Calendar.getInstance()
            when (mode) {
                AgentQuestionDateTimeMode.Date -> showAgentQuestionDatePicker(context, cal) { y, m, d ->
                    onChange("%04d-%02d-%02d".format(y, m + 1, d))
                }
                AgentQuestionDateTimeMode.Time -> showAgentQuestionTimePicker(context, cal) { h, min ->
                    onChange("%02d:%02d".format(h, min))
                }
                AgentQuestionDateTimeMode.DateTime -> showAgentQuestionDatePicker(context, cal) { y, m, d ->
                    showAgentQuestionTimePicker(context, cal) { h, min ->
                        onChange("%04d-%02d-%02d %02d:%02d".format(y, m + 1, d, h, min))
                    }
                }
            }
        },
        modifier = Modifier
            .fillMaxWidth()
            .height(44.dp),
        shape = RoundedCornerShape(10.dp),
        border = BorderStroke(1.dp, AgentQuestionSheetBorder)
    ) {
        Text(
            text = display,
            color = if (value.isNullOrBlank()) {
                AgentQuestionSheetTextSecondary
            } else {
                AgentQuestionSheetTextPrimary
            },
            fontSize = 13.sp
        )
    }
}

@Composable
internal fun AgentConfirmField(
    selected: String?,
    onSelect: (String) -> Unit
) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf(
            "yes" to currentAppText("是", "Yes"),
            "no" to currentAppText("否", "No")
        ).forEach { (id, label) ->
            val isSelected = id == selected
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(40.dp)
                    .background(
                        if (isSelected) AgentQuestionSheetChipSelectedBg else AgentQuestionSheetChipBg,
                        RoundedCornerShape(10.dp)
                    )
                    .border(
                        1.dp,
                        if (isSelected) AgentQuestionSheetBlue else Color.Transparent,
                        RoundedCornerShape(10.dp)
                    )
                    .clickable { onSelect(id) },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = label,
                    color = if (isSelected) AgentQuestionSheetBlue else AgentQuestionSheetTextPrimary,
                    fontSize = 14.sp,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
                )
            }
        }
    }
}

private fun showAgentQuestionDatePicker(
    context: Context,
    cal: Calendar,
    onPicked: (Int, Int, Int) -> Unit
) {
    DatePickerDialog(
        context,
        { _, y, m, d -> onPicked(y, m, d) },
        cal.get(Calendar.YEAR),
        cal.get(Calendar.MONTH),
        cal.get(Calendar.DAY_OF_MONTH)
    ).show()
}

private fun showAgentQuestionTimePicker(
    context: Context,
    cal: Calendar,
    onPicked: (Int, Int) -> Unit
) {
    TimePickerDialog(
        context,
        { _, h, min -> onPicked(h, min) },
        cal.get(Calendar.HOUR_OF_DAY),
        cal.get(Calendar.MINUTE),
        true
    ).show()
}
