package com.vvtech.aiassistant.features.assistant

import org.junit.Assert.assertEquals
import org.junit.Test

class AssistantV62NavigationPolicyTest {
    @Test
    fun settingsMainTabUsesExistingSettingsPage() {
        assertEquals(FinalPage.Settings, finalPageForMainTab(FinalMainTab.Settings))
        assertEquals(FinalPage.Settings, finalPageForIdentityInitFallback(FinalMainTab.Settings))
        assertEquals(
            FinalPage.Settings,
            finalBackTargetPage(
                currentPage = FinalPage.SipAccountSettings,
                pureVoiceMode = true,
                normalCallReturnPage = FinalPage.Calls.name
            )
        )
    }
}
