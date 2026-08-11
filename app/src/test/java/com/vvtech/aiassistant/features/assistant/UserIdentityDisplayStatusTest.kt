package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.WorkIdentityItem
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UserIdentityDisplayStatusTest {

    @Test
    fun `server identity state maps to empty filled and verified`() {
        assertEquals(UserIdentityDisplayStatus.EMPTY, UserIdentityDisplayStatus.from(null))
        assertEquals(
            UserIdentityDisplayStatus.EMPTY,
            UserIdentityDisplayStatus.from(UserIdentityPayload(name = ""))
        )
        assertEquals(
            UserIdentityDisplayStatus.FILLED,
            UserIdentityDisplayStatus.from(
                UserIdentityPayload(name = "张三", verificationStatus = "FILLED")
            )
        )
        assertEquals(
            UserIdentityDisplayStatus.VERIFIED,
            UserIdentityDisplayStatus.from(
                UserIdentityPayload(name = "张三", verificationStatus = "verified")
            )
        )
    }

    @Test
    fun `basic identity edit preserves hidden profile fields`() {
        val payload = UserIdentityPayload(
            name = "张三",
            gender = "男",
            contactPhone = "13800138000",
            workIdentities = listOf(WorkIdentityItem("原公司", "原部门", "原职位")),
            description = "原补充描述"
        )

        val request = payload.toDraft().copy(name = "李四").toUpsert("phone-13800138000")
        val metadata = payload.toDraft()
            .copy(name = "被忽略的姓名", gender = "女", contactPhone = "13912345678")
            .toVerifiedMetadata("phone-13800138000")

        assertEquals("李四", request.name)
        assertEquals("原公司", request.workIdentities?.single()?.company)
        assertEquals("原补充描述", request.description)
        assertEquals("女", metadata.gender)
        assertEquals("13912345678", metadata.contactPhone)
        assertTrue(payload.toDraft().copy(workIdentities = emptyList()).isValid())
    }

    @Test
    fun `only existing identity save returns to settings`() {
        assertFalse(shouldReturnToSettingsAfterIdentitySave(null))
        assertFalse(
            shouldReturnToSettingsAfterIdentitySave(UserIdentityPayload(name = ""))
        )
        assertTrue(
            shouldReturnToSettingsAfterIdentitySave(
                UserIdentityPayload(name = "张三", verificationStatus = "FILLED")
            )
        )
        assertTrue(
            shouldReturnToSettingsAfterIdentitySave(
                UserIdentityPayload(name = "张三", verificationStatus = "VERIFIED")
            )
        )
    }

    @Test
    fun `my identity page keeps only requested states and delete action`() {
        val screen = sourceFile("MyIdentityScreen.kt").readText(Charsets.UTF_8)
        val profile = sourceFile("MyIdentityProfileComponents.kt").readText(Charsets.UTF_8)

        assertTrue(screen.contains("\"暂无身份信息\""))
        assertTrue(screen.contains("\"用于AI在通话中更好的沟通。\""))
        assertFalse(screen.contains("\"工作身份（可多个）\""))
        assertFalse(screen.contains("\"补充描述\""))
        assertTrue(screen.contains("label = \"声音克隆\""))
        assertTrue(screen.contains("声音克隆用于使用我的声音进行 AI 通话"))
        assertTrue(screen.contains("shouldShowIdentityAuthentication(status)"))
        assertFalse(profile.contains("\"未认证\""))
        assertTrue(profile.contains("\"已认证\""))
        assertTrue(profile.contains("description = \"编辑身份\""))
        assertTrue(screen.contains("nameEditable = status != UserIdentityDisplayStatus.VERIFIED"))
        assertTrue(screen.contains("toVerifiedMetadata"))
        assertTrue(profile.contains("删除认证身份后，该身份创建的克隆音色也将一并删除"))
        assertFalse(screen.contains("MyIdentityAuthenticationDialog("))
        assertFalse(profile.contains("前往千问声音克隆页面完成"))
    }

    private fun sourceFile(name: String): File {
        val path = "src/main/java/com/vvtech/aiassistant/features/assistant/$name"
        return listOf(File(path), File("android/app/$path")).first { it.exists() }
    }
}
