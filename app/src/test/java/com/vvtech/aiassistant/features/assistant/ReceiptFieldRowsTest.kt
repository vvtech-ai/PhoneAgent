package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.domain.task.ReceiptField
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReceiptFieldRowsTest {
    private val requiredFields = listOf(
        ReceiptField("taskType", "任务", "餐厅预订"),
        ReceiptField("restaurantName", "餐厅", "海底捞"),
        ReceiptField("partySize", "人数", "4 人"),
        ReceiptField("reservationTime", "时间", " 今晚 8 点 "),
    )

    @Test
    fun dynamicRowsAndCopyKeepServerOrderAndExactValues() {
        val fields = requiredFields + listOf(
            ReceiptField("parking", "停车", "商场 B2"),
            ReceiptField("smsConfirmation", "短信", "已发送"),
        )

        assertEquals(
            listOf("任务", "餐厅", "人数", "时间", "停车", "短信"),
            receiptFieldDisplayRows(fields).map { it.first },
        )
        assertEquals(" 今晚 8 点 ", receiptFieldDisplayRows(fields)[3].second)
        assertEquals(
            "任务回执\n任务：餐厅预订\n餐厅：海底捞\n人数：4 人\n时间： 今晚 8 点 \n停车：商场 B2\n短信：已发送",
            receiptFieldsCopyText(fields),
        )
    }

    @Test
    fun failedStructuredReceiptStillUsesBaseFieldsAndNeverCopiesPhoneMetadata() {
        val result = CallResultPayload(
            status = "FAILED",
            headline = "预订失败",
            detail = "legacy detail should not replace fields",
            metadata = mapOf("phoneNumber" to "18812345678", "targetName" to "海底捞"),
            receiptFields = requiredFields,
        )

        assertEquals(requiredFields.map { it.label to it.value }, receiptFieldDisplayRows(result.receiptFields))
        assertFalse(callResultCopyText(result).contains("18812345678"))
        assertFalse(callResultCopyText(result).contains("legacy detail"))
    }

    @Test
    fun missingOptionalFieldsRenderOnlyTheFourBaseRows() {
        assertEquals(4, receiptFieldDisplayRows(requiredFields).size)
        assertTrue(receiptFieldDisplayRows(emptyList()).isEmpty())
    }

    @Test
    fun oldReceiptCopyRetainsLegacyDetailFallback() {
        val result = CallResultPayload(
            status = "COMPLETED",
            headline = "完成",
            detail = "旧详情",
            metadata = mapOf("门店" to "旧门店"),
        )

        val copy = callResultCopyText(result)

        assertTrue(copy.contains("详情：旧详情"))
        assertTrue(copy.contains("门店：旧门店"))
    }
}
