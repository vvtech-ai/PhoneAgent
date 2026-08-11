package com.vvtech.aiassistant.callengine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSipCallEnginePolicyTest {
    @Test
    fun domesticDialNumberMatchesWorldCallFormatting() {
        assertEquals("13812345678", AssistantSipDialNumberFormatter.toDialNumber("+8613812345678", "86"))
        assertEquals("13812345678", AssistantSipDialNumberFormatter.toDialNumber("008613812345678", "86"))
        assertEquals("13812345678", AssistantSipDialNumberFormatter.toDialNumber("8613812345678", "86"))
        assertEquals("13812345678", AssistantSipDialNumberFormatter.toDialNumber("13812345678", "86"))
        assertEquals("01088886666", AssistantSipDialNumberFormatter.toDialNumber("+861088886666", "86"))
        assertEquals("4001234567", AssistantSipDialNumberFormatter.toDialNumber("4001234567", "86"))
    }

    @Test
    fun domesticMobileAlwaysUsesClientSipAccount() {
        val defaultAccount = sipAccount("auto")
        val selectedAccount = sipAccount("domestic-secondary")
        val route = AssistantSipAccountRouter(
            domesticAccounts = listOf(defaultAccount, selectedAccount),
            internationalAccounts = listOf(sipAccount("auto"))
        ).route(
            targetNumber = "+8613812345678",
            defaultCountryDialCode = "86",
            selectedDomesticAccountId = "domestic-secondary",
            selectedInternationalAccountId = "auto"
        )

        assertEquals(selectedAccount, route)
    }

    @Test
    fun domesticLandlineAndServiceNumbersUseDomesticAccount() {
        val domestic = sipAccount("auto")
        val router = AssistantSipAccountRouter(
            domesticAccounts = listOf(domestic),
            internationalAccounts = listOf(sipAccount("auto"))
        )

        assertEquals(domestic, router.route("+861088886666", "86", "auto", "auto"))
        assertEquals(domestic, router.route("4001234567", "86", "auto", "auto"))
        assertEquals(domestic, router.route("95588", "86", "auto", "auto"))
    }

    @Test
    fun internationalNumberUsesSelectedInternationalAccount() {
        val selectedAccount = sipAccount("international-secondary")
        val route = AssistantSipAccountRouter(
            domesticAccounts = listOf(sipAccount("auto")),
            internationalAccounts = listOf(selectedAccount, sipAccount("auto"))
        ).route(
            targetNumber = "+14155550123",
            defaultCountryDialCode = "1",
            selectedDomesticAccountId = "auto",
            selectedInternationalAccountId = "international-secondary"
        )

        assertEquals(selectedAccount, route)
    }

    @Test
    fun unknownSelectionsFallBackToAiphoneDefaults() {
        val defaultDomestic = sipAccount("auto")
        val defaultInternational = sipAccount("auto")
        val router = AssistantSipAccountRouter(
            domesticAccounts = listOf(sipAccount("domestic-secondary"), defaultDomestic),
            internationalAccounts = listOf(sipAccount("international-secondary"), defaultInternational)
        )

        assertEquals(
            defaultDomestic,
            router.route("+8613812345678", "86", "missing", "missing")
        )
        assertEquals(
            defaultInternational,
            router.route("+14155550123", "1", "missing", "missing")
        )
    }

    @Test
    fun callStateAdvancesAndAcceptsOnlyOneTerminalEvent() {
        val reducer = AssistantCallSessionReducer()

        assertEquals(AssistantCallPhase.REGISTERING, reducer.reduce(AssistantCallSignal.START).phase)
        assertEquals(AssistantCallPhase.DIALING, reducer.reduce(AssistantCallSignal.REGISTERED).phase)
        assertEquals(AssistantCallPhase.RINGING, reducer.reduce(AssistantCallSignal.RINGING).phase)
        assertEquals(AssistantCallPhase.CONNECTED, reducer.reduce(AssistantCallSignal.CONNECTED).phase)

        val firstTerminal = reducer.reduce(AssistantCallSignal.REMOTE_ENDED)
        val duplicateTerminal = reducer.reduce(AssistantCallSignal.MEDIA_FAILED)
        assertEquals(AssistantCallPhase.ENDED, firstTerminal.phase)
        assertTrue(firstTerminal.terminalTransition)
        assertEquals(AssistantCallPhase.ENDED, duplicateTerminal.phase)
        assertFalse(duplicateTerminal.terminalTransition)
    }

    @Test
    fun translationSessionEntersTranslatingOnlyAfterConnected() {
        val reducer = AssistantCallSessionReducer(translation = true)

        reducer.reduce(AssistantCallSignal.START)
        assertEquals(AssistantCallPhase.REGISTERING, reducer.reduce(AssistantCallSignal.TRANSLATION_READY).phase)
        reducer.reduce(AssistantCallSignal.REGISTERED)
        reducer.reduce(AssistantCallSignal.CONNECTED)

        assertEquals(
            AssistantCallPhase.TRANSLATING,
            reducer.reduce(AssistantCallSignal.TRANSLATION_READY).phase
        )
    }

    @Test
    fun rtpTelephoneEventMatchesWorldCallPacketShape() {
        val packets = AssistantRtpTelephoneEventPacketizer.packetize(
            key = '#',
            payloadType = 101,
            startSequence = 7,
            startTimestamp = 12_000,
            ssrc = 42,
            durationMillis = 160
        )

        assertTrue(packets.size > 3)
        val first = AssistantRtpPacketCodec.parse(packets.first(), packets.first().size)!!
        val last = AssistantRtpPacketCodec.parse(packets.last(), packets.last().size)!!
        assertEquals(101, first.payloadType)
        assertEquals(11, first.payload[0].toInt() and 0xFF)
        assertEquals(0, first.payload[1].toInt() and 0x80)
        assertEquals(0x80, last.payload[1].toInt() and 0x80)
        assertEquals(first.timestamp, last.timestamp)
    }

    @Test
    fun earlyHangupCancelKeepsInviteTransactionIdentity() {
        val cancel = AssistantSipRequestBuilder.cancel(
            account = sipAccount("test-caller"),
            target = "13812345678",
            localIp = "192.168.1.20",
            localSipPort = 5068,
            callId = "call-123@chaken-ai",
            fromTag = "tag-abc",
            branch = "z9hG4bK-branch",
            inviteCseq = 2
        )

        assertTrue(cancel.startsWith("CANCEL sip:13812345678@sip.example.test:6063;transport=udp;user=phone SIP/2.0"))
        assertTrue(cancel.contains("Via: SIP/2.0/UDP 192.168.1.20:5068;branch=z9hG4bK-branch;rport"))
        assertTrue(cancel.contains("From: <sip:test-caller@sip.example.test:6063>;tag=tag-abc"))
        assertTrue(cancel.contains("To: <sip:13812345678@sip.example.test:6063;user=phone>"))
        assertTrue(cancel.contains("Call-ID: call-123@chaken-ai"))
        assertTrue(cancel.contains("CSeq: 2 CANCEL"))
        assertTrue(cancel.endsWith("Content-Length: 0\r\n\r\n"))
    }

    @Test
    fun registerOrInviteFailureWithinFiveSecondsBeforeRingingRetriesOnce() {
        assertTrue(
            AssistantSipInviteRetryPolicy.shouldRetry(
                failure = AssistantCallEngineEvent.Failure(
                    message = "SIP INVITE 失败：503 Service Unavailable",
                    sipMethod = "INVITE",
                    sipStatusCode = 503
                ),
                retriesUsed = 0,
                connected = false,
                ringing = false,
                elapsedSinceAttemptStartMillis = 1_000L
            )
        )
        assertTrue(
            AssistantSipInviteRetryPolicy.shouldRetry(
                failure = AssistantCallEngineEvent.Failure(
                    message = "SIP REGISTER failed",
                    sipMethod = "REGISTER",
                    sipStatusCode = 503
                ),
                retriesUsed = 0,
                connected = false,
                ringing = false,
                elapsedSinceAttemptStartMillis = 1_000L
            )
        )
    }

    @Test
    fun registerOrInviteFailureDoesNotRetryAfterFirstRetryConnectedRingingOrOverFiveSeconds() {
        val failure = AssistantCallEngineEvent.Failure(
            message = "SIP INVITE 失败：503 Service Unavailable",
            sipMethod = "INVITE",
            sipStatusCode = 503
        )

        assertFalse(
            AssistantSipInviteRetryPolicy.shouldRetry(
                failure = failure,
                retriesUsed = 1,
                connected = false,
                ringing = false,
                elapsedSinceAttemptStartMillis = 1_000L
            )
        )
        assertFalse(
            AssistantSipInviteRetryPolicy.shouldRetry(
                failure = failure,
                retriesUsed = 0,
                connected = true,
                ringing = false,
                elapsedSinceAttemptStartMillis = 1_000L
            )
        )
        assertFalse(
            AssistantSipInviteRetryPolicy.shouldRetry(
                failure = failure,
                retriesUsed = 0,
                connected = false,
                ringing = true,
                elapsedSinceAttemptStartMillis = 1_000L
            )
        )
        assertFalse(
            AssistantSipInviteRetryPolicy.shouldRetry(
                failure = failure,
                retriesUsed = 0,
                connected = false,
                ringing = false,
                elapsedSinceAttemptStartMillis = 5_001L
            )
        )
    }

    @Test
    fun nonRegisterOrInviteFailureDoesNotRetry() {
        assertFalse(
            AssistantSipInviteRetryPolicy.shouldRetry(
                failure = AssistantCallEngineEvent.Failure(
                    message = "SIP REGISTER 失败：503 Service Unavailable",
                    sipMethod = "BYE",
                    sipStatusCode = 503
                ),
                retriesUsed = 0,
                connected = false,
                ringing = false,
                elapsedSinceAttemptStartMillis = 1_000L
            )
        )
        assertFalse(
            AssistantSipInviteRetryPolicy.shouldRetry(
                failure = AssistantCallEngineEvent.Failure(
                    message = "SIP INVITE 失败：486 Busy Here",
                    sipMethod = "OPTIONS",
                    sipStatusCode = 486
                ),
                retriesUsed = 0,
                connected = false,
                ringing = false,
                elapsedSinceAttemptStartMillis = 1_000L
            )
        )
    }

    private fun sipAccount(id: String) = AssistantSipAccount(
        id = id,
        server = "sip.example.test",
        port = 6063,
        username = id,
        password = "secret",
        callerNumber = id
    )
}
