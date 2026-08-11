package com.vvtech.aiassistant.data.remote.voiceclone

import org.junit.Assert.assertEquals
import org.junit.Test
import retrofit2.http.GET
import retrofit2.http.POST

class VoiceCloneVerificationApiContractTest {

    @Test
    fun `verification request uses backend identity card type`() {
        val request = VoiceCloneVerificationInitRequest(
            consentVersion = "v1",
            realName = "测试用户",
            certNo = "110101199001011234",
            metaInfo = "{}"
        )

        assertEquals("IDENTITY_CARD", request.certType)
    }

    @Test
    fun `verification endpoints match backend contract`() {
        val init = VoiceCloneVerificationApi::class.java.getMethod(
            "initialize",
            VoiceCloneVerificationInitRequest::class.java,
            kotlin.coroutines.Continuation::class.java
        )
        val status = VoiceCloneVerificationApi::class.java.getMethod(
            "status",
            String::class.java,
            kotlin.coroutines.Continuation::class.java
        )
        val replacementCheck = VoiceCloneVerificationApi::class.java.getMethod(
            "checkReplacement",
            VoiceCloneIdentityReplacementCheckRequest::class.java,
            kotlin.coroutines.Continuation::class.java
        )
        val collection = VoiceCloneVerificationApi::class.java.getMethod(
            "createCollection",
            VoiceCloneCollectionRequest::class.java,
            kotlin.coroutines.Continuation::class.java
        )

        assertEquals(
            "api/account/settings/voice-clone/verification/init",
            init.getAnnotation(POST::class.java).value
        )
        assertEquals(
            "api/account/settings/voice-clone/verification/{attemptId}",
            status.getAnnotation(GET::class.java).value
        )
        assertEquals(
            "api/account/settings/voice-clone/verification/replacement-check",
            replacementCheck.getAnnotation(POST::class.java).value
        )
        assertEquals(
            "api/account/settings/voice-clone/collection",
            collection.getAnnotation(POST::class.java).value
        )
    }
}
