package com.vvtech.aiassistant.core.model

import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CallResultPayloadReceiptFieldsTest {
    @Test
    fun jsonPreservesReceiptFieldOrderAndValues() {
        val result = Gson().fromJson(
            """{"status":"COMPLETED","headline":"完成","detail":"详情","receiptFields":[{"key":"taskType","label":"任务","value":"餐厅预订"},{"key":"parking","label":"停车","value":"商场 B2"}]}""",
            CallResultPayload::class.java,
        )

        assertEquals(listOf("taskType", "parking"), result.receiptFields.orEmpty().map { it.key })
        assertEquals(listOf("餐厅预订", "商场 B2"), result.receiptFields.orEmpty().map { it.value })
    }

    @Test
    fun legacyJsonWithoutReceiptFieldsRemainsCompatible() {
        val result = Gson().fromJson(
            """{"status":"COMPLETED","headline":"完成","detail":"旧详情"}""",
            CallResultPayload::class.java,
        )

        assertTrue(result.receiptFields.orEmpty().isEmpty())
    }
}
