package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PendingSelectedContactTurnContextTest {
    @Test
    fun armedContactIsConsumedByTheFirstTurnOnly() {
        val context = PendingSelectedContactTurnContext()
        val contact = contact("陈文轩", "13394013218")

        context.arm(contact)

        assertEquals(contact, context.take(explicit = null))
        assertNull(context.take(explicit = null))
    }

    @Test
    fun explicitContactWinsAndClearsTheArmedContact() {
        val context = PendingSelectedContactTurnContext()
        val armed = contact("陈文轩", "13394013218")
        val explicit = contact("李雷", "13800138000")

        context.arm(armed)

        assertEquals(explicit, context.take(explicit))
        assertNull(context.take(explicit = null))
    }

    @Test
    fun clearDropsAnAbandonedContactEntry() {
        val context = PendingSelectedContactTurnContext()
        context.arm(contact("陈文轩", "13394013218"))

        context.clear()

        assertNull(context.take(explicit = null))
    }

    private fun contact(name: String, phone: String): SelectedContactTaskContext =
        SelectedContactTaskContext.contactDetail(name, phone)
}
