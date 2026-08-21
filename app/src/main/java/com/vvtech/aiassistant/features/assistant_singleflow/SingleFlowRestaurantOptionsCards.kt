package com.vvtech.aiassistant.features.assistant_singleflow

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant.SfRestaurantOption

@Composable
internal fun PvRestaurantOptionsCard(
    options: List<SfRestaurantOption>,
    onSelect: (SfRestaurantOption) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = Color.White.copy(alpha = 0.86f),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.92f)),
        modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 8.dp)
    ) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            RestaurantOptionsHeader(subtitle = stringResource(R.string.restaurant_options_tap_to_select))
            Spacer(modifier = Modifier.height(10.dp))
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                options.forEachIndexed { index, option ->
                    RestaurantOptionRow(
                        index = index,
                        option = option,
                        showTags = false,
                        onSelect = { onSelect(option) }
                    )
                }
            }
        }
    }
}

@Composable
internal fun SfRestaurantOptionsCard(options: List<SfRestaurantOption>) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = Color.White.copy(alpha = 0.86f),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.92f))
    ) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            RestaurantOptionsHeader(subtitle = stringResource(R.string.restaurant_options_voice_hint))
            Spacer(modifier = Modifier.height(10.dp))
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                options.forEachIndexed { index, option ->
                    RestaurantOptionRow(index = index, option = option, showTags = true)
                }
            }
        }
    }
}

@Composable
private fun RestaurantOptionsHeader(subtitle: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = stringResource(R.string.restaurant_options_title),
            color = Color(0xFF121A24),
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = subtitle,
            color = Color(0xFF6E788B),
            fontSize = 12.sp
        )
    }
}

@Composable
private fun RestaurantOptionRow(
    index: Int,
    option: SfRestaurantOption,
    showTags: Boolean,
    onSelect: (() -> Unit)? = null
) {
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = Color(0xFFF8FBFF),
        border = BorderStroke(1.dp, Color(0xFFE4ECF7)),
        modifier = if (onSelect != null) Modifier.clickable(onClick = onSelect) else Modifier
    ) {
        Row(modifier = Modifier.padding(horizontal = 10.dp, vertical = 10.dp)) {
            Surface(
                modifier = Modifier.size(24.dp),
                shape = CircleShape,
                color = Color(0xFF007AFF)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        text = "${index + 1}",
                        color = Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            Spacer(modifier = Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = option.name,
                    color = Color(0xFF121A24),
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp
                )
                Text(
                    text = option.note,
                    color = Color(0xFF657287),
                    fontSize = 12.sp,
                    lineHeight = 18.sp,
                    modifier = Modifier.padding(top = 4.dp)
                )
                if (showTags && option.tags.isNotEmpty()) {
                    Row(
                        modifier = Modifier.padding(top = 7.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        option.tags.take(3).forEach { tag ->
                            Surface(
                                shape = RoundedCornerShape(999.dp),
                                color = Color(0xFFEFF4FB)
                            ) {
                                Text(
                                    text = tag,
                                    color = Color(0xFF53627C),
                                    fontSize = 11.sp,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
