package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun AssistantDialPad(onDigit: (String) -> Unit) {
    val keys = listOf(
        "1" to "", "2" to "ABC", "3" to "DEF",
        "4" to "GHI", "5" to "JKL", "6" to "MNO",
        "7" to "PQRS", "8" to "TUV", "9" to "WXYZ",
        "*" to "", "0" to "+", "#" to ""
    )
    Column {
        keys.chunked(3).forEach { row ->
            Box {
                Box(Modifier.fillMaxWidth().height(1.dp).background(Color(0xFFE5E8EE)))
                Row(Modifier.fillMaxWidth()) {
                    row.forEachIndexed { columnIndex, (digit, letters) ->
                        Box(modifier = Modifier.weight(1f).height(64.dp)) {
                            Column(
                                modifier = Modifier.fillMaxSize().clickable { onDigit(digit) },
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center
                            ) {
                                Text(
                                    digit,
                                    color = Color(0xFF111111),
                                    fontSize = 24.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                if (letters.isNotEmpty()) {
                                    Text(
                                        letters,
                                        color = Color(0xFF70737B),
                                        fontSize = 9.sp,
                                        fontWeight = FontWeight.Bold,
                                        letterSpacing = 1.sp
                                    )
                                }
                            }
                            if (columnIndex < 2) {
                                Box(
                                    Modifier
                                        .align(Alignment.CenterEnd)
                                        .fillMaxHeight()
                                        .width(1.dp)
                                        .background(Color(0xFFE5E8EE))
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
