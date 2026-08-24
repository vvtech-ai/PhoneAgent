package com.vvtech.aiassistant.features.assistant_pure_voice

import android.widget.ImageView
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.TextButton
import androidx.compose.material.ButtonDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import androidx.compose.ui.viewinterop.AndroidView
import com.bumptech.glide.Glide
import com.vvtech.aiassistant.features.assistant.PureVoiceBubble
import com.vvtech.aiassistant.features.assistant.PureVoiceThinkingCard
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrAttachment
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrFailure
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrStatus

internal fun LazyListScope.pureVoiceOcrAttachmentItems(
    attachment: PureVoiceOcrAttachment
) {
    item(key = "ocr_image_${attachment.attachmentId}") {
        PureVoiceOcrImageBubble(attachment)
    }
    item(key = "ocr_state_${attachment.attachmentId}") {
        when (attachment.status) {
            PureVoiceOcrStatus.Processing -> PureVoiceThinkingCard(
                title = "Phone Agent",
                steps = listOf(currentAppText("AI 思考中...", "AI is thinking..."))
            )

            PureVoiceOcrStatus.Success -> PureVoiceOcrResultCard(attachment)
            PureVoiceOcrStatus.Failed -> PureVoiceBubble(
                text = attachment.failure.userMessage(),
                user = false,
                streaming = false,
                keyHint = attachment.attachmentId.hashCode(),
                error = true
            )
        }
    }
}

@Composable
private fun PureVoiceOcrImageBubble(attachment: PureVoiceOcrAttachment) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.End
    ) {
        Box(
            modifier = Modifier
                .width(210.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(Color(0xFFEAF4FF))
                .padding(8.dp)
        ) {
            PureVoiceOcrImage(
                attachment = attachment,
                modifier = Modifier.fillMaxWidth().aspectRatio(4f / 3f)
            )
        }
    }
}

@Composable
private fun PureVoiceOcrResultCard(attachment: PureVoiceOcrAttachment) {
    Surface(
        modifier = Modifier.widthIn(max = 286.dp),
        color = Color.White,
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, Color(0xFFE5EBF3)),
        elevation = 8.dp
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            PureVoiceOcrCardHeader(attachment)
            if (attachment.fields.isNotEmpty()) {
                Spacer(Modifier.height(12.dp))
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    attachment.fields.forEach { field ->
                        PureVoiceOcrFieldRow(field.label, field.value)
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
            Text(
                text = "Full text in image",
                color = Color(0xFF64748B),
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(Modifier.height(6.dp))
            PureVoiceOcrFormattedText(
                attachmentId = attachment.attachmentId,
                fullText = attachment.fullText
            )
        }
    }
}

@Composable
private fun PureVoiceOcrFormattedText(
    attachmentId: String,
    fullText: String
) {
    val collapsible = fullText.isOcrCardCollapsible()
    var expanded by rememberSaveable(attachmentId) { mutableStateOf(false) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFFF8FBFF))
            .padding(horizontal = 10.dp, vertical = 8.dp)
    ) {
        Text(
            text = fullText.ocrCardDisplayText(expanded),
            color = Color(0xFF111827),
            fontSize = 12.sp,
            lineHeight = 19.sp
        )
        if (collapsible) {
            TextButton(
                onClick = { expanded = !expanded },
                modifier = Modifier
                    .align(Alignment.End)
                    .height(28.dp),
                contentPadding = PaddingValues(horizontal = 4.dp),
                colors = ButtonDefaults.textButtonColors(
                    contentColor = Color(0xFF1683FF)
                )
            ) {
                Text(
                    text = if (expanded) currentAppText("收起", "Collapse") else currentAppText("展开", "Expand"),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

@Composable
private fun PureVoiceOcrCardHeader(attachment: PureVoiceOcrAttachment) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        PureVoiceOcrImage(
            attachment = attachment,
            modifier = Modifier.size(60.dp)
        )
        Column(modifier = Modifier.padding(start = 10.dp)) {
            Text(
                text = "Recognized image text",
                color = Color(0xFF111827),
                fontSize = 14.sp,
                fontWeight = FontWeight.ExtraBold
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = attachment.fieldSummary(),
                color = Color(0xFF64748B),
                fontSize = 12.sp,
                lineHeight = 18.sp
            )
        }
    }
}

@Composable
private fun PureVoiceOcrFieldRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFFF8FBFF))
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = label,
            modifier = Modifier.widthIn(min = 54.dp),
            color = Color(0xFF64748B),
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold
        )
        Text(
            text = value,
            color = Color(0xFF111827),
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun PureVoiceOcrImage(
    attachment: PureVoiceOcrAttachment,
    modifier: Modifier
) {
    AndroidView(
        modifier = modifier.clip(RoundedCornerShape(14.dp)),
        factory = { context ->
            ImageView(context).apply {
                scaleType = ImageView.ScaleType.CENTER_CROP
            }
        },
        update = { view ->
            Glide.with(view).clear(view)
            Glide.with(view).load(attachment.imageUri).into(view)
        }
    )
}

private fun PureVoiceOcrAttachment.fieldSummary(): String {
    val labels = fields.map { it.label }.distinct().take(3)
    return if (labels.isEmpty()) {
        currentAppText("已提取图片中的文字信息", "Extracted text from the image")
    } else {
        currentAppText(
            "已从图片中提取${labels.joinToString("、")}等信息",
            "Extracted image details"
        )
    }
}

private fun PureVoiceOcrFailure?.userMessage(): String = when (this) {
    PureVoiceOcrFailure.EmptyText -> currentAppText(
        "未识别到有效文字，请重新选择图片",
        "No readable text found. Please choose another image"
    )
    PureVoiceOcrFailure.AiRefinementFailed -> currentAppText(
        "图片文字整理失败，请重新选择图片",
        "Failed to organize the image text. Please choose another image"
    )
    PureVoiceOcrFailure.CloudCommitFailed -> currentAppText(
        "图片保存失败，请重新选择图片",
        "Failed to save the image. Please choose another image"
    )
    PureVoiceOcrFailure.RecognitionFailed, null -> currentAppText(
        "图片文字识别失败，请重新选择图片",
        "Failed to recognize image text. Please choose another image"
    )
}

internal fun String.isOcrCardCollapsible(): Boolean = length > OCR_CARD_PREVIEW_CHARS

internal fun String.ocrCardDisplayText(expanded: Boolean): String =
    if (expanded || !isOcrCardCollapsible()) {
        this
    } else {
        take(OCR_CARD_PREVIEW_CHARS).trimEnd() + "……"
    }

private const val OCR_CARD_PREVIEW_CHARS = 50
