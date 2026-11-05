package com.vvtech.phone_agent

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

/** Persist only an opaque entry UUID, never an invitation URL or code. */
object InviteEntryReceipt {
    const val EXTRA = "com.vvtech.aiassistant.INVITE_ENTRY_ID"
    fun parse(context: Context, url: String?): String? {
        val metadata = context.packageManager.getApplicationInfo(
            context.packageName, PackageManager.GET_META_DATA).metaData
        return InviteAppLinkPolicy.parse(url,
            metadata.getString("phone_agent.invite_host").orEmpty(),
            "/aiassistant-api/invite/",
            metadata.getString("phone_agent.invite_scheme").orEmpty())
    }
    fun accept(context: Context, intent: Intent): Boolean {
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return false
        val entry = intent.getStringExtra(EXTRA) ?: return true
        val prefs = context.getSharedPreferences("flutter_invite_entry_receipt", Context.MODE_PRIVATE)
        if (prefs.getString("lastEntryId", null) == entry) return false
        return prefs.edit().putString("lastEntryId", entry).commit()
    }
}
