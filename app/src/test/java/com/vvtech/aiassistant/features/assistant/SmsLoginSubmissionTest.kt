package com.vvtech.aiassistant.features.assistant

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SmsLoginSubmissionTest {

    @Test
    fun `invite stage submits challenge without original sms code`() {
        val submission = buildSmsLoginSubmission(
            smsCode = "123456",
            activationOpen = true,
            activationCode = "vvtech2014",
            loginChallenge = "challenge-1"
        )

        assertEquals("", submission.smsCode)
        assertEquals("vvtech2014", submission.activationCode)
        assertEquals("challenge-1", submission.loginChallenge)
    }

    @Test
    fun `sms stage submits code without challenge`() {
        val submission = buildSmsLoginSubmission(
            smsCode = "123456",
            activationOpen = false,
            activationCode = "",
            loginChallenge = "stale-challenge"
        )

        assertEquals("123456", submission.smsCode)
        assertNull(submission.activationCode)
        assertNull(submission.loginChallenge)
    }
}
