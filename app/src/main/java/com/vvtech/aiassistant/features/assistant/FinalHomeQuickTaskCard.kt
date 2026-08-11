package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.widget.ImageView
import com.bumptech.glide.Glide

@Composable
internal fun FinalQuickTaskCardV2(
    modifier: Modifier = Modifier,
    badge: String,
    title: String,
    subtitle: String,
    imageUrl: String? = null,
    fallbackImageResId: Int? = null,
    enabled: Boolean,
    dotColor: Color? = null,
    statusLabel: String? = null,
    onClick: () -> Unit
) {
    val containerColor = Color.White.copy(alpha = 0.80f)
    val badgeDotColor = dotColor ?: if (enabled) Color(0xFF0A84FF) else Color(0xFFC7C7CC)
    val titleColor = if (enabled) Color(0xFF121826) else Color(0xFF8E8E93)
    val subtitleColor = if (enabled) Color(0xFF6E6E73) else Color(0xFFA3A3AA)

    Surface(
        modifier = modifier
            .heightIn(min = 100.dp)
            .clickable(enabled = enabled, onClick = onClick)
            .shadow(
                elevation = 10.dp,
                shape = RoundedCornerShape(24.dp),
                ambientColor = Color(0x14101114),
                spotColor = Color(0x14101114)
            ),
        color = containerColor,
        shape = RoundedCornerShape(24.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
        elevation = 0.dp
    ) {
        Box(
            modifier = Modifier.fillMaxSize()
        ) {
            val imageModifier = Modifier
                .align(Alignment.BottomEnd)
                .offset(x = 2.dp, y = 2.dp)
                .size(82.dp)
                .alpha(if (enabled) 0.95f else 0.62f)
            if (!imageUrl.isNullOrBlank() || fallbackImageResId != null) {
                AndroidView(
                    modifier = imageModifier,
                    factory = { context ->
                        ImageView(context).apply { scaleType = ImageView.ScaleType.FIT_CENTER }
                    },
                    update = { view ->
                        Glide.with(view).clear(view)
                        view.setImageDrawable(null)
                        if (imageUrl.isNullOrBlank()) {
                            fallbackImageResId?.let { view.setImageResource(fallbackImageResId) }
                        } else {
                            val request = Glide.with(view).load(imageUrl)
                            if (fallbackImageResId != null) {
                                request
                                    .placeholder(fallbackImageResId)
                                    .error(fallbackImageResId)
                            }
                            request.into(view)
                        }
                    }
                )
            }
            if (!statusLabel.isNullOrBlank()) {
                Surface(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = 16.dp, end = 16.dp),
                    color = Color(0x1F8E8E93),
                    shape = RoundedCornerShape(999.dp),
                    elevation = 0.dp
                ) {
                    Text(
                        text = statusLabel,
                        modifier = Modifier.padding(horizontal = 7.dp, vertical = 4.dp),
                        color = Color(0xFF8E8E93),
                        fontSize = 10.sp,
                        lineHeight = 12.sp,
                        fontWeight = FontWeight.Black
                    )
                }
            }
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(7.dp)
                        .background(badgeDotColor, CircleShape)
                )
                Text(
                    text = title,
                    modifier = Modifier.padding(top = 14.dp),
                    color = titleColor,
                    fontSize = 18.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = subtitle.ifBlank { badge },
                    modifier = Modifier.padding(top = 8.dp),
                    color = subtitleColor,
                    fontSize = 13.sp,
                    lineHeight = 19.sp
                )
            }
        }
    }
}
