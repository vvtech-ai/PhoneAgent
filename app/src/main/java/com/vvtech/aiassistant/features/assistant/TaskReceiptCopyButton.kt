package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload

private const val TaskReceiptCopyButtonsVisible = false

@Composable
internal fun TaskReceiptCopyButton(
    copyText: String,
    iconColor: Color = Color(0xFF111111),
    modifier: Modifier = Modifier
) {
    if (!TaskReceiptCopyButtonsVisible) return

    val clipboard = LocalClipboardManager.current
    val normalizedText = remember(copyText) { copyText.trim() }
    Box(
        modifier = modifier
            .size(32.dp)
            .clickable(
                enabled = normalizedText.isNotBlank(),
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) {
                clipboard.setText(AnnotatedString(normalizedText))
            },
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = ReceiptCopyIcon,
            contentDescription = stringResource(R.string.receipt_copy_content_description),
            tint = iconColor,
            modifier = Modifier.size(20.dp)
        )
    }
}

internal fun callResultCopyText(result: CallResultPayload): String {
    if (receiptFieldDisplayRows(result.receiptFields).isNotEmpty()) {
        return receiptFieldsCopyText(result.receiptFields)
    }
    return buildList {
        add("任务回执")
        addCopyLine("状态", result.status)
        addCopyLine("标题", result.headline)
        addCopyLine("详情", result.detail)
        result.metadata.orEmpty().forEach { (key, value) ->
            addCopyLine(key, value)
        }
    }.joinToString("\n")
}

internal fun batchCallResultCopyText(result: BatchCallResultPayload): String {
    return buildList {
        add("任务回执")
        addCopyLine("状态", result.status)
        addCopyLine("标题", result.headline)
        result.items.forEachIndexed { index, item ->
            if (index > 0) add("")
            add("${index + 1}. ${item.targetName.ifBlank { "目标对象" }}")
            addCopyLine("状态", item.status)
            addCopyLine("标题", item.headline)
            addCopyLine("详情", item.detail)
            addCopyLine("转写", item.transcript.orEmpty())
        }
    }.joinToString("\n")
}

internal fun receiptRowsCopyText(title: String, rows: List<Pair<String, String>>): String {
    return buildList {
        add(title.ifBlank { "任务回执" })
        rows.forEach { (label, value) ->
            addCopyLine(label, value)
        }
    }.joinToString("\n")
}

private fun MutableList<String>.addCopyLine(label: String, value: String) {
    val normalized = value.trim()
    if (normalized.isNotBlank()) {
        add("$label：$normalized")
    }
}

private val ReceiptCopyIcon: ImageVector
    get() {
        if (_receiptCopyIcon != null) return _receiptCopyIcon!!
        _receiptCopyIcon = ImageVector.Builder(
            name = "ReceiptCopyIcon",
            defaultWidth = 24.dp,
            defaultHeight = 24.dp,
            viewportWidth = 24f,
            viewportHeight = 24f
        ).apply {
            path(
                fill = null,
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.9f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(6.4f, 5.2f)
                horizontalLineTo(4.8f)
                curveTo(3.7f, 5.2f, 2.8f, 6.1f, 2.8f, 7.2f)
                verticalLineTo(20.2f)
                curveTo(2.8f, 21.3f, 3.7f, 22.2f, 4.8f, 22.2f)
                horizontalLineTo(15.6f)
                curveTo(16.7f, 22.2f, 17.6f, 21.3f, 17.6f, 20.2f)
                verticalLineTo(18.8f)

                moveTo(8.4f, 2.0f)
                horizontalLineTo(15.2f)
                lineTo(21.2f, 8.0f)
                verticalLineTo(17.2f)
                curveTo(21.2f, 18.3f, 20.3f, 19.2f, 19.2f, 19.2f)
                horizontalLineTo(8.4f)
                curveTo(7.3f, 19.2f, 6.4f, 18.3f, 6.4f, 17.2f)
                verticalLineTo(4.0f)
                curveTo(6.4f, 2.9f, 7.3f, 2.0f, 8.4f, 2.0f)
                close()

                moveTo(15.2f, 2.0f)
                verticalLineTo(8.0f)
                horizontalLineTo(21.2f)
            }
        }.build()
        return _receiptCopyIcon!!
    }

private var _receiptCopyIcon: ImageVector? = null
