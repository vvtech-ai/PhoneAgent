package com.vvtech.aiassistant.features.assistant_calls

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantDialerPreferenceStateTest {
    @Test
    fun countrySelectionSynchronizesPeerLanguageForEverySupportedCountry() {
        val state = AssistantDialerPreferenceState()

        state.selectCountry("JP", translationMode = true)
        assertEquals("日语", state.otherLanguage)

        state.selectCountry("CN", translationMode = true)
        assertEquals("中文", state.otherLanguage)

        state.selectCountry("SG", translationMode = true)
        assertEquals("英文", state.otherLanguage)

        state.selectCountry("US", translationMode = true)
        assertEquals("英文", state.otherLanguage)

        state.selectCountry("JP", translationMode = false)
        assertEquals("日语", state.otherLanguage)
    }

    @Test
    fun nextCountrySelectionReplacesPreviouslyManualPeerLanguage() {
        val state = AssistantDialerPreferenceState()

        state.otherLanguage = "德语"
        state.selectCountry("JP", translationMode = true)

        assertEquals("日语", state.otherLanguage)
    }

    @Test
    fun legacyHistoryWithoutLanguageSnapshotKeepsCurrentPeerLanguage() {
        val state = AssistantDialerStateHolder()
        state.otherLanguage = "德语"

        val result = state.restoreHistoryTarget(
            DialTargetSelection(
                phoneNumber = "5023258388",
                countryIso = "US",
                callKind = DialRecentCallKind.TRANSLATION
            )
        )

        assertTrue(result is ContactDialNumberResult.Supported)
        assertEquals("US", state.selectedCountryIso)
        assertEquals("德语", state.otherLanguage)
    }

    @Test
    fun normalHistorySelectionKeepsEnabledTranslationToggle() {
        val state = AssistantDialerStateHolder()
        state.translateEnabled = true

        state.restoreHistoryTarget(
            DialTargetSelection(
                phoneNumber = "18823189131",
                countryIso = "CN",
                callKind = DialRecentCallKind.NORMAL
            )
        )

        assertTrue(state.translateEnabled)
        assertEquals("18823189131", state.dialInput)
    }

    @Test
    fun translationHistorySelectionKeepsDisabledTranslationToggle() {
        val state = AssistantDialerStateHolder()
        state.translateEnabled = false

        state.restoreHistoryTarget(
            DialTargetSelection(
                phoneNumber = "18823189131",
                countryIso = "CN",
                callKind = DialRecentCallKind.TRANSLATION
            )
        )

        assertFalse(state.translateEnabled)
        assertEquals("18823189131", state.dialInput)
    }

    @Test
    fun locationConsentFlagsPersistThroughPreferenceStore() {
        val store = MemoryDialerPreferenceStore()
        val state = AssistantDialerPreferenceState(store = store)

        assertFalse(state.locationPromptShown)
        assertFalse(state.locationSystemPermissionRequested)
        assertFalse(state.callLogPermissionRequested)

        state.locationPromptShown = true
        state.locationSystemPermissionRequested = true
        state.callLogPermissionRequested = true

        assertTrue(store.booleans.getValue("dial_location_prompt_shown"))
        assertTrue(store.booleans.getValue("dial_location_permission_requested"))
        assertTrue(store.booleans.getValue("dial_call_log_permission_requested"))
    }

    @Test
    fun dialerLimitCountsOnlyDigits() {
        val state = AssistantDialerStateHolder()

        repeat(14) { state.appendDigit("1") }
        state.appendDigit("*")
        state.appendDigit("#")
        state.appendDigit("2")

        assertEquals("11111111111111*#", state.dialInput)
    }

    @Test
    fun locationPromptFrequencyAndBlockedDecisionFollowConsentState() {
        assertTrue(
            shouldShowInitialDialerLocationPrompt(
                hasPermission = false,
                promptShown = false
            )
        )
        assertFalse(
            shouldShowInitialDialerLocationPrompt(
                hasPermission = false,
                promptShown = true
            )
        )
        assertFalse(
            shouldShowInitialDialerLocationPrompt(
                hasPermission = true,
                promptShown = false
            )
        )
        assertEquals(
            DialerLocationDialogKind.REQUEST,
            dialerLocationDialogKind(
                systemPermissionRequested = true,
                canRequestAgain = true
            )
        )
        assertEquals(
            DialerLocationDialogKind.BLOCKED,
            dialerLocationDialogKind(
                systemPermissionRequested = true,
                canRequestAgain = false
            )
        )
    }

    @Test
    fun locationEntryRefreshesSharedRegionWhenPermissionAlreadyGranted() {
        assertEquals(
            DialerLocationEntryAction.REFRESH_REGION,
            dialerLocationEntryAction(
                hasPermission = true,
                promptShown = true
            )
        )
        assertEquals(
            DialerLocationEntryAction.SHOW_REQUEST,
            dialerLocationEntryAction(
                hasPermission = false,
                promptShown = false
            )
        )
        assertEquals(
            DialerLocationEntryAction.NONE,
            dialerLocationEntryAction(
                hasPermission = false,
                promptShown = true
            )
        )
    }
}

private class MemoryDialerPreferenceStore : DialerPreferenceStore {
    val booleans = mutableMapOf<String, Boolean>()
    private val strings = mutableMapOf<String, String>()

    override fun getBoolean(key: String, default: Boolean): Boolean =
        booleans[key] ?: default

    override fun getString(key: String, default: String): String =
        strings[key] ?: default

    override fun putBoolean(key: String, value: Boolean) {
        booleans[key] = value
    }

    override fun putString(key: String, value: String) {
        strings[key] = value
    }
}
