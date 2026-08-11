package com.vvtech.aiassistant.model

import com.google.gson.Gson
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class VoiceCloneUploadRequestContractTest {
    @Test
    fun `upload json binds verification collection and face summary`() {
        val request = VoiceCloneUploadRequest(
            verificationAttemptId = "attempt-a",
            collectionId = "collection-a",
            displayName = "我的声音",
            scriptVersion = "voice-clone-v5",
            facePresence = VoiceCloneFacePresenceUploadRequest(40, 38, 500, false, 750),
            samples = listOf(
                VoiceCloneSampleUploadRequest("script-a", "测试短句1", "UklGRg==", "wav", 8_000)
            )
        )

        val json = JsonParser().parse(Gson().toJson(request)).asJsonObject

        assertEquals("attempt-a", json["verificationAttemptId"].asString)
        assertEquals("collection-a", json["collectionId"].asString)
        assertEquals(40, json["facePresence"].asJsonObject["sampledFrames"].asInt)
        assertEquals(750, json["facePresence"].asJsonObject["maxFrameGapMs"].asLong)
        assertFalse(json["facePresence"].asJsonObject["multipleFaceDetected"].asBoolean)
    }
}
