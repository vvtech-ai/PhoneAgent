package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.data.model.UserIdentityPayload
import org.junit.Assert.assertEquals
import org.junit.Test

class IdentityPhoneDraftTest {

    @Test
    fun `saved identity phone is used as the draft value`() {
        val draft = UserIdentityPayload(
            name = "张三",
            contactPhone = "13912345678"
        ).toDraft()

        assertEquals("13912345678", draft.contactPhone)
    }

    @Test
    fun `missing identity phone stays blank instead of using login phone`() {
        val draft = UserIdentityPayload(name = "张三")
            .toDraft()

        assertEquals("", draft.contactPhone)
    }

    @Test
    fun `blank saved identity phone stays blank after user clears it`() {
        assertEquals(
            "",
            resolveIdentityPhone(savedPhone = "  ")
        )
    }

    @Test
    fun `deleted identity stays blank instead of using login phone`() {
        val draft = null.toDraft()

        assertEquals("", draft.contactPhone)
    }
}
