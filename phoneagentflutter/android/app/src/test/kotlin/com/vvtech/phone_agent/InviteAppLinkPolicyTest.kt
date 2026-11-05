package com.vvtech.phone_agent

import org.junit.Assert.*
import org.junit.Test

class InviteAppLinkPolicyTest {
    private val host = "chakenai-dev.vvtech.tech"
    private val path = "/aiassistant-api/invite/"
    private fun parse(url: String) = InviteAppLinkPolicy.parse(url, host, path, "phoneagent-dev")

    @Test fun webAndBrowserSchemeUseTheSameCodeRules() {
        assertEquals("ABCD", parse("https://$host$path?code=ABCD"))
        assertEquals("ABCD", parse("phoneagent-dev://invite/?invite=ABCD"))
        assertEquals("你好AB", parse("https://$host$path?code=%E4%BD%A0%E5%A5%BDAB"))
        assertEquals("ABCD", parse("https://$host$path?code=ABCD&invite=ABCD"))
        assertEquals("ABCD", parse("https://$host:443$path?code=ABCD"))
    }

    @Test fun wrongEnvironmentAmbiguityAndMalformedLinksAreRejected() {
        for (url in listOf(
            "https://chakenai-test.vvtech.tech$path?code=ABCD",
            "https://agent.vvtech.tech$path?code=ABCD",
            "https://$host:444$path?code=ABCD",
            "http://$host$path?code=ABCD",
            "https://user@$host$path?code=ABCD",
            "https://$host$path?code=ABCD#fragment",
            "https://$host/aiassistant-api/invite?code=ABCD",
            "https://$host$path?code=ABCD&invite=EFGH",
            "phoneagent-test://invite/?code=ABCD",
            "phoneagent-dev://invite?code=ABCD",
            "phoneagent-dev://invite/?code=A%20CD",
            "phoneagent-dev://invite/?code=A%C2%A0CD",
            "phoneagent-dev://invite/?code=ABC",
            "phoneagent-dev://invite/?code=%ZZCD"
        )) assertNull(url, parse(url))
    }
}
