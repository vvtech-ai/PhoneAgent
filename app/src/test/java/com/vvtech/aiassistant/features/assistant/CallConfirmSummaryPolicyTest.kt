package com.vvtech.aiassistant.features.assistant

import org.junit.Assert.assertEquals
import org.junit.Test

class CallConfirmSummaryPolicyTest {
    @Test
    fun hidesContactResolutionMetadataAndKeepsBusinessFacts() {
        assertEquals(
            listOf("会议地点" to "公司会议室"),
            visibleCallConfirmSummaryRows(
                listOf(
                    "targetName：老王",
                    "phoneNumber：13800138000",
                    "contactName：老王",
                    "requestedName：老王",
                    "contactMatchType：name_exact",
                    "会议地点：公司会议室"
                )
            )
        )
    }
}
