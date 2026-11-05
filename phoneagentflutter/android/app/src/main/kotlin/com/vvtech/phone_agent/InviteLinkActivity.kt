package com.vvtech.phone_agent

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import java.util.UUID

/** A browser entry transfers to the app task and never becomes a UI page. */
class InviteLinkActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            val incoming = intent
            if (incoming?.action != Intent.ACTION_VIEW ||
                incoming.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
            if (InviteEntryReceipt.parse(this, incoming.dataString) == null) return
            startActivity(Intent(this, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = incoming.data
                putExtra(InviteEntryReceipt.EXTRA, UUID.randomUUID().toString())
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            })
        } finally {
            finish()
        }
    }
}
