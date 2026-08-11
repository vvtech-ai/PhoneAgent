package com.vvtech.aiassistant.features.assistant

import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MarkdownTextTest {

    @Test
    fun stripBoldDoubleAsterisks() {
        assertEquals("很久以前羊肉串", stripMarkdownForTts("**很久以前羊肉串**"))
    }

    @Test
    fun stripBoldInsideSentenceKeepsSurroundingText() {
        assertEquals(
            "搜索到 很久以前羊肉串 这家店",
            stripMarkdownForTts("搜索到 **很久以前羊肉串** 这家店")
        )
    }

    @Test
    fun stripItalicAndStrikeAndCode() {
        assertEquals("斜体 删除 代码", stripMarkdownForTts("*斜体* ~~删除~~ `代码`"))
    }

    @Test
    fun stripTripleAsterisksBoldItalic() {
        assertEquals("重点", stripMarkdownForTts("***重点***"))
    }

    @Test
    fun stripHeadingAndListMarkers() {
        val src = """
            # 标题
            - 第一项
            - 第二项
            1. 编号一
        """.trimIndent()
        val out = stripMarkdownForTts(src)
        assertTrue(out, !out.contains("#"))
        assertTrue(out, !out.contains("- "))
        assertTrue(out, out.contains("标题"))
        assertTrue(out, out.contains("第一项"))
        assertTrue(out, out.contains("编号一"))
    }

    @Test
    fun stripCodeFenceBlock() {
        val src = "前置\n```\nhidden code\n```\n后置"
        val out = stripMarkdownForTts(src)
        assertTrue(out, !out.contains("hidden code"))
        assertTrue(out, out.contains("前置"))
        assertTrue(out, out.contains("后置"))
    }

    @Test
    fun stripLinkKeepsLabel() {
        assertEquals("点击 这里 看详情", stripMarkdownForTts("点击 [这里](https://example.com) 看详情"))
    }

    @Test
    fun stripBlankReturnsBlank() {
        assertEquals("", stripMarkdownForTts(""))
        assertEquals("", stripMarkdownForTts("   "))
    }

    @Test
    fun stripLeavesPlainTextUntouched() {
        assertEquals("海底捞万达店 5公里", stripMarkdownForTts("海底捞万达店 5公里"))
    }

    @Test
    fun stripDoesNotEatLoneAsteriskInsideWord() {
        // 1+1*2 应保持原样（无成对 *）
        assertEquals("1+1*2=3", stripMarkdownForTts("1+1*2=3"))
    }

    @Test
    fun parseBoldProducesAnnotatedSpan() {
        val annotated = parseInlineMarkdown("**很久以前羊肉串**")
        assertEquals("很久以前羊肉串", annotated.text)
        val spans = annotated.spanStyles
        assertEquals(1, spans.size)
        assertEquals(FontWeight.Bold, spans[0].item.fontWeight)
        assertEquals(0, spans[0].start)
        assertEquals("很久以前羊肉串".length, spans[0].end)
    }

    @Test
    fun parseMixedBoldKeepsPlainTextAround() {
        val annotated = parseInlineMarkdown("搜索到 **很久以前羊肉串** 这家店")
        assertEquals("搜索到 很久以前羊肉串 这家店", annotated.text)
        val spans = annotated.spanStyles
        assertEquals(1, spans.size)
        assertEquals(FontWeight.Bold, spans[0].item.fontWeight)
        assertEquals("搜索到 ".length, spans[0].start)
        assertEquals("搜索到 ".length + "很久以前羊肉串".length, spans[0].end)
    }

    @Test
    fun parseItalicProducesItalicSpan() {
        val annotated = parseInlineMarkdown("这是 *斜体* 文本")
        assertEquals("这是 斜体 文本", annotated.text)
        val spans = annotated.spanStyles
        assertEquals(1, spans.size)
        assertEquals(FontStyle.Italic, spans[0].item.fontStyle)
    }

    @Test
    fun parseStrikethroughSpan() {
        val annotated = parseInlineMarkdown("~~删掉~~")
        assertEquals("删掉", annotated.text)
        val spans = annotated.spanStyles
        assertEquals(1, spans.size)
        assertEquals(TextDecoration.LineThrough, spans[0].item.textDecoration)
    }

    @Test
    fun parseMultipleBoldSegments() {
        val annotated = parseInlineMarkdown("**A** 和 **B**")
        assertEquals("A 和 B", annotated.text)
        val spans = annotated.spanStyles
        assertEquals(2, spans.size)
        assertEquals(FontWeight.Bold, spans[0].item.fontWeight)
        assertEquals(FontWeight.Bold, spans[1].item.fontWeight)
        assertEquals(0, spans[0].start)
        assertEquals(1, spans[0].end)
        assertEquals("A 和 ".length, spans[1].start)
        assertEquals("A 和 B".length, spans[1].end)
    }

    @Test
    fun parsePlainTextHasNoSpans() {
        val annotated = parseInlineMarkdown("海底捞万达店")
        assertEquals("海底捞万达店", annotated.text)
        assertTrue(annotated.spanStyles.isEmpty())
    }

    @Test
    fun parseEmptyStringIsEmpty() {
        val annotated = parseInlineMarkdown("")
        assertEquals("", annotated.text)
        assertTrue(annotated.spanStyles.isEmpty())
    }

    @Test
    fun stripNestedBoldItalicLeavesOuterBoldUntouched() {
        assertEquals("**a b c**", stripMarkdownForTts("**a *b* c**"))
    }

    @Test
    fun parseNestedBoldItalicOnlyHandlesInner() {
        val annotated = parseInlineMarkdown("**a *b* c**")
        assertEquals("**a b c**", annotated.text)
        val spans = annotated.spanStyles
        assertEquals(1, spans.size)
        assertEquals(FontStyle.Italic, spans[0].item.fontStyle)
        assertEquals("**a ".length, spans[0].start)
        assertEquals("**a b".length, spans[0].end)
    }

    @Test
    fun stripSingleUnderscoreItalicBetweenChinese() {
        assertEquals("文字italic文字", stripMarkdownForTts("文字_italic_文字"))
    }

    @Test
    fun parseSingleUnderscoreItalicBetweenChinese() {
        val annotated = parseInlineMarkdown("文字_italic_文字")
        assertEquals("文字italic文字", annotated.text)
        val spans = annotated.spanStyles
        assertEquals(1, spans.size)
        assertEquals(FontStyle.Italic, spans[0].item.fontStyle)
        assertEquals("文字".length, spans[0].start)
        assertEquals("文字italic".length, spans[0].end)
    }

    @Test
    fun stripBoldHuggingChineseBothEnds() {
        assertEquals("店名：Mike先生", stripMarkdownForTts("店名：**Mike**先生"))
    }

    @Test
    fun parseBoldHuggingChineseBothEnds() {
        val annotated = parseInlineMarkdown("店名：**Mike**先生")
        assertEquals("店名：Mike先生", annotated.text)
        val spans = annotated.spanStyles
        assertEquals(1, spans.size)
        assertEquals(FontWeight.Bold, spans[0].item.fontWeight)
        assertEquals("店名：".length, spans[0].start)
        assertEquals("店名：Mike".length, spans[0].end)
    }
}
