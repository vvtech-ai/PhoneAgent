package com.vvtech.aiassistant.features.translation_call.backend

import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class HttpBackendTranslationClientTest {
    private lateinit var server: MockWebServer
    private lateinit var client: HttpBackendTranslationClient

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
        client = HttpBackendTranslationClient(server.url("/").toString())
    }

    @Test
    fun `loads backend language catalog`() {
        server.enqueue(
            MockResponse().setBody(
                """{"languages":[{"code":"zh-CN","label":"Chinese"},{"code":"en-US","label":"English"}]}"""
            )
        )

        val result = client.loadLanguageCatalog()

        assertEquals(listOf("zh-CN", "en-US"), result.languages.map { it.code })
        assertEquals("/api/app-translation-calls/languages", server.takeRequest().path)
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun `creates livekit translation session with selected provider`() {
        server.enqueue(
            MockResponse().setBody(
                """
                {
                  "callSessionId":"call-1",
                  "status":"READY",
                  "mediaTransport":"livekit",
                  "voiceProvider":"twilio",
                  "realtimeProvider":"gemini",
                  "originalAudioEnabled":true,
                  "originalAudioPercent":30,
                  "originalAudioVolumePercent":70,
                  "livekit":{
                    "url":"wss://room.example",
                    "token":"token-1",
                    "roomName":"room-1",
                    "participantIdentity":"user-1"
                  },
                  "environment":{
                    "version":1,
                    "network":{"state":"available"},
                    "sip":{"state":"pending"},
                    "model":{"state":"available"}
                  }
                }
                """.trimIndent()
            )
        )

        val result = client.createSession(
            BackendCreateCallRequest(
                merchantPhone = "+14155550100",
                userLanguage = "zh",
                merchantLanguage = "en",
                userId = "user-1",
                realtimeProvider = "gemini",
                originalAudioEnabled = true,
                originalAudioPercent = 30,
                originalAudioVolumePercent = 70
            )
        )

        assertEquals("call-1", result.callSessionId)
        assertEquals("wss://room.example", result.liveKit?.url)
        assertEquals("gemini", result.realtimeProvider)
        val request = server.takeRequest()
        assertEquals("/api/app-translation-calls", request.path)
        val body = request.body.readUtf8()
        assertTrue(body.contains("\"mediaTransports\":[\"livekit\",\"websocket\"]"))
        assertTrue(body.contains("\"originalAudioEnabled\":true"))
        assertTrue(body.contains("\"originalAudioPercent\":30"))
        assertTrue(body.contains("\"originalAudioVolumePercent\":70"))
        assertTrue(result.originalAudioEnabled)
        assertEquals(30, result.originalAudioPercent)
        assertEquals(70, result.originalAudioVolumePercent)
    }

    @Test
    fun `preserves 409 environment for bounded merchant retry`() {
        server.enqueue(
            MockResponse()
                .setResponseCode(409)
                .setBody(
                    """
                    {
                      "code":"REALTIME_NOT_READY",
                      "message":"not ready",
                      "environment":{
                        "version":8,
                        "model":{"state":"pending"}
                      }
                    }
                    """.trimIndent()
                )
        )

        val error = runCatching {
            client.startMerchantCall(
                BackendStartMerchantCallRequest(
                    callSessionId = "call-1",
                    merchantPhone = "+14155550100",
                    voiceProvider = "twilio",
                    userId = "user-1"
                )
            )
        }.exceptionOrNull() as BackendTranslationHttpException

        assertEquals(409, error.statusCode)
        assertEquals(8L, error.environment?.version)
    }

    @Test
    fun `preserves unavailable and timeout status codes`() {
        listOf(503, 504).forEach { status ->
            server.enqueue(
                MockResponse()
                    .setResponseCode(status)
                    .setBody("""{"code":"BACKEND_$status","message":"unavailable"}""")
            )

            val error = runCatching {
                client.startMerchantCall(
                    BackendStartMerchantCallRequest(
                        callSessionId = "call-$status",
                        merchantPhone = "+14155550100",
                        voiceProvider = "twilio",
                        userId = "user-1"
                    )
                )
            }.exceptionOrNull() as BackendTranslationHttpException

            assertEquals(status, error.statusCode)
        }
    }

    @Test
    fun `retries session creation without capabilities for legacy service`() {
        server.enqueue(
            MockResponse().setResponseCode(400)
                .setBody("""{"code":"UNKNOWN_FIELD","message":"capabilities unsupported"}""")
        )
        server.enqueue(
            MockResponse().setBody(
                """{"callSessionId":"call-legacy","appAudioWsUrl":"wss://audio.example"}"""
            )
        )

        val result = client.createSession(
            BackendCreateCallRequest(
                merchantPhone = "+14155550100",
                userLanguage = "zh-CN",
                merchantLanguage = "en-US",
                userId = "mobile-app-user",
                realtimeProvider = "gemini"
            )
        )

        assertEquals("call-legacy", result.callSessionId)
        assertTrue(server.takeRequest().body.readUtf8().contains("capabilities"))
        assertFalse(server.takeRequest().body.readUtf8().contains("capabilities"))
    }
}
