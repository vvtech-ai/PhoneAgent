package com.vvtech.aiassistant.features.assistant_contacts

import com.vvtech.aiassistant.data.model.ContactDirectoryEntry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AssistantContactRemarkRequestTest {
    @Test
    fun remarkUpdatePreservesExistingDirectoryFields() {
        val request = buildContactRemarkUpsertRequest(
            phone = " 138-0013-8000 ",
            fallbackDisplayName = "设备联系人姓名",
            existing = ContactDirectoryEntry(
                phone = "13800138000",
                displayName = "张三",
                primaryRelation = "同事",
                speakingStyle = "简洁",
                description = "旧备注"
            ),
            remark = "  新备注  "
        )

        assertEquals("", request.userId)
        assertEquals("13800138000", request.phone)
        assertEquals("张三", request.displayName)
        assertEquals("同事", request.primaryRelation)
        assertEquals("简洁", request.speakingStyle)
        assertEquals("新备注", request.description)
    }

    @Test
    fun blankRemarkClearsDescriptionAndUsesFallbackNameForNewEntry() {
        val request = buildContactRemarkUpsertRequest(
            phone = "+86 138 0013 8000",
            fallbackDisplayName = "  李四  ",
            existing = null,
            remark = "   "
        )

        assertEquals("13800138000", request.phone)
        assertEquals("李四", request.displayName)
        assertNull(request.primaryRelation)
        assertNull(request.speakingStyle)
        assertNull(request.description)
    }
}
