package com.vvtech.phone_agent

import android.content.Context

/** Device-global display facts, separate from SDK permissions and authorization. */
internal class TrustedCallerHomeGuide(context: Context) {
    private val prefs = context.getSharedPreferences("trusted_caller_presentation", Context.MODE_PRIVATE)
    fun eligible(): Boolean = TrustedCallerGuidePolicy.homeEligible(prefs.all)
    fun record(disabled: Boolean): Boolean {
        val edit = prefs.edit().putBoolean(TrustedCallerGuidePolicy.HOME_SEEN, true)
        if (disabled) edit.putBoolean(TrustedCallerGuidePolicy.HOME_DISABLED, true)
        return edit.commit()
    }
}
