package com.vvtech.aiassistant.features.assistant

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle

private val MARKDOWN_STRIP_PATTERNS: List<Pair<Regex, String>> = listOf(
    Regex("```[\\s\\S]*?```") to "",
    Regex("`([^`]+)`") to "$1",
    Regex("!\\[[^\\]]*]\\([^)]*\\)") to "",
    Regex("\\[([^\\]]+)]\\([^)]*\\)") to "$1",
    Regex("(\\*\\*\\*|___)([^*_\\n]+?)\\1") to "$2",
    Regex("(\\*\\*|__)([^*_\\n]+?)\\1") to "$2",
    Regex("(?<![\\w*])\\*([^*\\n]+?)\\*(?![\\w*])") to "$1",
    Regex("(?<![\\w_])_([^_\\n]+?)_(?![\\w_])") to "$1",
    Regex("~~([^~\\n]+?)~~") to "$1",
    Regex("(?m)^\\s{0,3}#{1,6}\\s+") to "",
    Regex("(?m)^\\s{0,3}>\\s+") to "",
    Regex("(?m)^\\s{0,3}[-*+]\\s+") to "",
    Regex("(?m)^\\s{0,3}\\d+\\.\\s+") to "",
    Regex("(?m)^\\s*[-*_]{3,}\\s*$") to ""
)

fun stripMarkdownForTts(text: String): String {
    if (text.isEmpty()) return text
    var result = text
    for ((regex, replacement) in MARKDOWN_STRIP_PATTERNS) {
        result = regex.replace(result, replacement)
    }
    return result.replace(Regex("[ \\t]+"), " ").trim()
}
private data class InlineMarker(
    val token: String,
    val openRegex: Regex,
    val style: SpanStyle
)

private val INLINE_MARKERS: List<InlineMarker> = listOf(
    InlineMarker(
        token = "**",
        openRegex = Regex("\\*\\*([^*\\n]+?)\\*\\*"),
        style = SpanStyle(fontWeight = FontWeight.Bold)
    ),
    InlineMarker(
        token = "__",
        openRegex = Regex("__([^_\\n]+?)__"),
        style = SpanStyle(fontWeight = FontWeight.Bold)
    ),
    InlineMarker(
        token = "*",
        openRegex = Regex("(?<![\\w*])\\*([^*\\n]+?)\\*(?![\\w*])"),
        style = SpanStyle(fontStyle = FontStyle.Italic)
    ),
    InlineMarker(
        token = "_",
        openRegex = Regex("(?<![\\w_])_([^_\\n]+?)_(?![\\w_])"),
        style = SpanStyle(fontStyle = FontStyle.Italic)
    ),
    InlineMarker(
        token = "~~",
        openRegex = Regex("~~([^~\\n]+?)~~"),
        style = SpanStyle(textDecoration = TextDecoration.LineThrough)
    ),
    InlineMarker(
        token = "`",
        openRegex = Regex("`([^`\\n]+?)`"),
        style = SpanStyle(fontWeight = FontWeight.Medium)
    )
)

fun parseInlineMarkdown(text: String): AnnotatedString {
    if (text.isEmpty()) return AnnotatedString("")
    return buildAnnotatedString {
        var cursor = 0
        while (cursor < text.length) {
            var bestMatch: MatchResult? = null
            var bestMarker: InlineMarker? = null
            for (marker in INLINE_MARKERS) {
                val match = marker.openRegex.find(text, cursor) ?: continue
                if (bestMatch == null || match.range.first < bestMatch.range.first) {
                    bestMatch = match
                    bestMarker = marker
                }
            }
            if (bestMatch == null || bestMarker == null) {
                append(text.substring(cursor))
                break
            }
            if (bestMatch.range.first > cursor) {
                append(text.substring(cursor, bestMatch.range.first))
            }
            val inner = bestMatch.groupValues[1]
            withStyle(bestMarker.style) { append(inner) }
            cursor = bestMatch.range.last + 1
        }
    }
}
