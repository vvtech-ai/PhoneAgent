package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.mutableStateOf
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant_calls.AssistantDialerPreferenceState
import com.vvtech.aiassistant.features.assistant_calls.AssistantDialerStateHolder
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantCallDialStateTest {
    @Test
    fun defaultsMatchRootDialStateDefaults() {
        val state = state()

        assertEquals("", state.dialer.dialInput)
        assertEquals("", state.dialer.lastDialedNumber)
        assertFalse(state.showCallsDialSheet)
        assertTrue(state.dialer.translateEnabled)
        assertTrue(state.dialer.promptBeforeTranslationCall)
        assertEquals("中文", state.dialer.myLanguage)
        assertEquals("英文", state.dialer.otherLanguage)
        assertEquals("CN", state.dialer.selectedCountryIso)
        assertEquals("Calls", state.normalCallReturnPage)
        assertFalse(state.normalCallMuted)
        assertTrue(state.normalCallSpeaker)
        assertEquals(0, state.normalCallSeconds)
    }

    @Test
    fun openHideAndDialInputKeepPreviousSheetSemantics() {
        val state = state()

        state.dialer.translateEnabled = true
        state.openDialSheet()
        state.dialer.appendDigit("1")
        state.dialer.appendDigit("2")
        state.dialer.deleteDigit()
        state.hideDialSheet()
        state.openDialSheet()

        assertTrue(state.showCallsDialSheet)
        assertTrue(state.dialer.translateEnabled)
        assertEquals("1", state.dialer.dialInput)
    }

    @Test
    fun dialInputStopsAtFourteenDigits() {
        val state = state()

        "123456789012345".forEach { state.dialer.appendDigit(it.toString()) }

        assertEquals("12345678901234", state.dialer.dialInput)

        state.dialer.dialInput = ""
        repeat(15) { state.dialer.appendDigit("*") }
        assertEquals(14, state.dialer.dialInput.length)
    }

    @Test
    fun normalAndTranslationCountriesAreStoredSeparately() {
        val state = state()

        state.dialer.translateEnabled = true
        state.dialer.selectCountry("JP")
        assertEquals("JP", state.dialer.selectedCountryIso)

        state.dialer.translateEnabled = false
        assertEquals("CN", state.dialer.selectedCountryIso)
        state.dialer.selectCountry("US")
        assertEquals("US", state.dialer.selectedCountryIso)

        state.dialer.translateEnabled = true
        assertEquals("JP", state.dialer.selectedCountryIso)
    }

    @Test
    fun contactNumberPreparesCountryAndNationalBody() {
        val state = state()

        val result = state.dialer.prepareContactNumber("+81 90-1234-5678", "田中")

        assertEquals("JP", state.dialer.selectedCountryIso)
        assertEquals("9012345678", state.dialer.dialInput)
        assertEquals("田中", state.dialer.targetDisplayName)
        assertEquals("JP", (result as com.vvtech.aiassistant.features.assistant_calls.ContactDialNumberResult.Supported).countryIso)
    }

    @Test
    fun manualNumberEditClearsSelectedContactName() {
        val state = state()
        state.dialer.prepareContactNumber("+86 18823189131", "张三")

        state.dialer.appendDigit("2")

        assertEquals("", state.dialer.targetDisplayName)
    }

    @Test
    fun normalRedialUpdatesNormalCountryEvenWhileTranslationModeIsSelected() {
        val state = state()
        state.dialer.translateEnabled = true

        state.dialer.prepareContactNumber("+81 90-1234-5678", translationMode = false)
        state.dialer.translateEnabled = false

        assertEquals("JP", state.dialer.selectedCountryIso)
        assertEquals("+819012345678", state.dialer.fullDialNumber())
    }

    @Test
    fun callTargetCombinesSelectedCountryCodeAndNationalBody() {
        val state = state()
        state.dialer.translateEnabled = true
        state.dialer.selectCountry("JP")
        state.dialer.dialInput = "9012345678"

        assertEquals("+819012345678", state.dialer.fullDialNumber())
    }

    @Test
    fun emptyOrSymbolOnlyBodyDoesNotBecomeAValidCountryCodeCall() {
        val state = state()

        assertEquals("", state.dialer.fullDialNumber())
        state.dialer.dialInput = "*#"
        assertEquals("", state.dialer.fullDialNumber())
    }

    @Test
    fun dialReturnDestinationKeepsEntryTabAndPage() {
        val state = state()

        state.captureReturnDestination(FinalMainTab.Contacts, FinalPage.ContactDetail)

        assertEquals(FinalMainTab.Contacts, state.returnDestination.mainTab)
        assertEquals(FinalPage.ContactDetail, state.returnDestination.page)
    }

    @Test
    fun countryChangeInfersOtherLanguageUntilUserOverridesIt() {
        val state = state()

        state.dialer.selectCountry("JP")
        assertEquals("日语", state.dialer.otherLanguage)

        state.dialer.otherLanguage = "法语"
        state.dialer.selectCountry("US")
        assertEquals("法语", state.dialer.otherLanguage)
    }

    @Test
    fun clearAfterDeveloperUnlockClearsDialAndSheetOnly() {
        val state = state()
        state.dialer.dialInput = "*#*#8888#*#*"
        state.dialer.lastDialedNumber = "13800138000"
        state.dialer.translateEnabled = true
        state.showCallsDialSheet = true

        state.dialer.clearNumbers()
        state.hideDialSheet()

        assertEquals("", state.dialer.dialInput)
        assertEquals("", state.dialer.lastDialedNumber)
        assertFalse(state.showCallsDialSheet)
        assertTrue(state.dialer.translateEnabled)
    }

    @Test
    fun normalCallStateIsMutableThroughHolder() {
        val state = state()

        state.dialer.dialInput = "10086"
        state.dialer.lastDialedNumber = "10010"
        state.normalCallSeconds = 42
        state.normalCallMuted = true
        state.normalCallSpeaker = false
        state.normalCallReturnPage = "ContactDetail"

        assertEquals("10086", state.dialer.dialInput)
        assertEquals("10010", state.dialer.lastDialedNumber)
        assertEquals(42, state.normalCallSeconds)
        assertTrue(state.normalCallMuted)
        assertFalse(state.normalCallSpeaker)
        assertEquals("ContactDetail", state.normalCallReturnPage)
    }

    @Test
    fun assistantRootScreenDelegatesDialState() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val runtimeGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val holder =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantCallDialState.kt")
                .readText(Charsets.UTF_8)
        val dialerHolder =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_calls/AssistantDialerStateHolder.kt")
                .readText(Charsets.UTF_8)
        val rootCallEntryAction =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootCallEntryActions.kt")
                .readText(Charsets.UTF_8)
        val mainFactory =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostMainArgsFactory.kt")
                .readText(Charsets.UTF_8)
        val dialFactory =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootOverlayDialDepsFactory.kt")
                .readText(Charsets.UTF_8)

        assertTrue(root.contains("val callDialState = rootRuntimeGraph.state.callDial"))
        assertTrue(runtimeGraph.contains("rememberAssistantCallDialState("))
        assertTrue(root.contains("callDial = callDialState"))
        assertTrue(dialFactory.contains("state.callDial.dialer.dialInput"))
        assertTrue(mainFactory.contains("state.callDial.dialer.lastDialedNumber"))
        assertTrue(dialFactory.contains("state.callDial.showCallsDialSheet"))
        assertTrue(dialFactory.contains("state.callDial.dialer.translateEnabled"))
        assertTrue(mainFactory.contains("state.callDial.normalCallSeconds"))
        assertTrue(rootCallEntryAction.contains("callDialState.dialer.clearNumbers()"))
        assertTrue(rootCallEntryAction.contains("callDialState.hideDialSheet()"))
        assertTrue(rootCallEntryAction.contains("callDialState.openDialSheet()"))
        assertTrue(dialFactory.contains("onDialDigit = state.callDial.dialer::appendDigit"))
        assertTrue(dialFactory.contains("onDialDelete = state.callDial.dialer::deleteDigit"))
        assertTrue(dialerHolder.contains("rememberSaveable { mutableStateOf(\"\") }"))
        assertTrue(holder.contains("rememberSaveable { mutableStateOf(false) }"))
        assertEquals(-1, holder.indexOf("parseContactDialNumber"))
        assertEquals(-1, holder.indexOf("SharedPreferences"))

        assertEquals(-1, root.indexOf("var dialInput by rememberSaveable"))
        assertEquals(-1, root.indexOf("var lastDialedNumber by rememberSaveable"))
        assertEquals(-1, root.indexOf("var showCallsDialSheet by rememberSaveable"))
        assertEquals(-1, root.indexOf("var translateDialEnabled by rememberSaveable"))
        assertEquals(-1, root.indexOf("var normalCallReturnPage by rememberSaveable"))
        assertEquals(-1, root.indexOf("var normalCallMuted by rememberSaveable"))
        assertEquals(-1, root.indexOf("var normalCallSpeaker by rememberSaveable"))
        assertEquals(-1, root.indexOf("var normalCallSeconds by rememberSaveable"))
    }

    @Test
    fun dialSheetProviderUsesTranslationSettingsSingleSourceOfTruth() {
        val dialFactory =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootOverlayDialDepsFactory.kt")
                .readText(Charsets.UTF_8)

        assertTrue(
            dialFactory.contains(
                "activeTranslationProviderTitle = runtime.realtimeTranslation.selectedProviderTitle"
            )
        )
        assertTrue(
            dialFactory.contains(
                "activeTranslationProvider = runtime.realtimeTranslation.selectedProviderId"
            )
        )
        assertTrue(
            dialFactory.contains(
                "onSelectTranslationProvider = runtime.realtimeTranslation::selectProvider"
            )
        )
        assertFalse(dialFactory.contains("runtime.provider.translationProviderResponse"))
    }

    private fun state(defaultReturnPage: String = "Calls"): AssistantCallDialState {
        return AssistantCallDialState(
            dialer = AssistantDialerStateHolder(
                preferences = AssistantDialerPreferenceState(),
                dialInputState = mutableStateOf(""),
                lastDialedNumberState = mutableStateOf("")
            ),
            showCallsDialSheetState = mutableStateOf(false),
            normalCallReturnPageState = mutableStateOf(defaultReturnPage),
            normalCallMutedState = mutableStateOf(false),
            normalCallSpeakerState = mutableStateOf(true),
            normalCallSecondsState = mutableStateOf(0)
        )
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
