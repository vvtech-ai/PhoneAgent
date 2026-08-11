package com.vvtech.aiassistant.features.assistant_pure_voice.ocr

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PureVoiceOcrFieldExtractorTest {

    @Test
    fun extractsExplicitFieldsInFrozenPriorityOrder() {
        val fields = PureVoiceOcrFieldExtractor.extract(
            listOf(
                "地址：上海市南京西路 1888 号",
                "时间：2026-07-24 18:30",
                "公司：VVTech",
                "姓名：陈先生",
                "电话：021-3386 23566",
                "桌号：A18"
            )
        )

        assertEquals(
            listOf("phone", "name", "organization", "time", "place", "other_桌号"),
            fields.map { it.key }
        )
        assertEquals("021-3386 23566", fields.first().value)
    }

    @Test
    fun findsRawPhoneAndDeduplicatesLabeledValue() {
        val fields = PureVoiceOcrFieldExtractor.extract(
            listOf(
                "联系电话：13800138000",
                "如有问题请拨打 13800138000"
            )
        )

        assertEquals(1, fields.count { it.key == "phone" })
        assertEquals("13800138000", fields.first { it.key == "phone" }.value)
    }

    @Test
    fun doesNotInventImageCategory() {
        val fields = PureVoiceOcrFieldExtractor.extract(
            listOf("电子发票", "总金额 100.00", "感谢惠顾")
        )

        assertTrue(fields.isEmpty())
    }
}
