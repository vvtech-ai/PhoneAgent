package com.vvtech.aiassistant.features.assistant_contacts

import org.junit.Assert.assertEquals
import org.junit.Test

class AssistantContactPermissionConsentDialogTest {

    @Test
    fun copyExplainsContactUseBeforeLaunchingSystemPermission() {
        assertEquals("允许访问通讯录？", AssistantContactPermissionDialogText.title)
        assertEquals(
            "用于选择联系人并发起通话任务",
            AssistantContactPermissionDialogText.description
        )
        assertEquals("继续授权", AssistantContactPermissionDialogText.allow)
        assertEquals("暂不", AssistantContactPermissionDialogText.deny)
    }
}
