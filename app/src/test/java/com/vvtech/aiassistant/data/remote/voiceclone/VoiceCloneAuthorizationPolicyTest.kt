package com.vvtech.aiassistant.data.remote.voiceclone

import okhttp3.OkHttpClient
import okhttp3.Interceptor
import okhttp3.Request
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

class VoiceCloneAuthorizationPolicyTest {
    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun `adds bearer token only to protected paths`() {
        val policy = VoiceCloneAuthorizationPolicy { "signed-token" }

        assertEquals(
            "Bearer signed-token",
            policy.authorizationHeader("/api/account/settings/voice-clone/verification/init")
        )
        assertEquals("Bearer signed-token", policy.authorizationHeader("/api/logs/upload"))
        assertEquals(
            "/gateway/api/auth/voice-clone/refresh",
            policy.refreshPath("/gateway/api/logs/upload")
        )
        assertEquals(
            "Bearer signed-token",
            policy.authorizationHeader(
                "/aiassistant-api/api/account/settings/voice-clone/verification/init"
            )
        )
        assertNull(policy.authorizationHeader("/api/account/settings/realtime-call-provider"))
        assertNull(policy.authorizationHeader("/api/tasks"))
        assertNull(policy.authorizationHeader("/api/account/settings/voice-clone-legacy"))
    }

    @Test
    fun `does not add blank token`() {
        val policy = VoiceCloneAuthorizationPolicy { "" }

        assertNull(policy.authorizationHeader("/api/account/settings/voice-clone"))
    }

    @Test
    fun `recovers missing token and retries voice clone request once`() {
        server.enqueue(
            MockResponse()
                .setResponseCode(401)
                .setBody("""{"code":401,"message":"missing"}""")
        )
        server.enqueue(
            MockResponse().setBody(
                """{"code":0,"message":"ok","data":{"voiceCloneAccessToken":"recovered-token"}}"""
            )
        )
        server.enqueue(MockResponse().setBody("""{"code":0}"""))
        var token = ""
        var updates = 0
        val client = OkHttpClient.Builder()
            .addInterceptor(
                VoiceCloneAuthInterceptor(
                    tokenProvider = { token },
                    tokenUpdater = {
                        token = it
                        updates += 1
                    },
                    refreshCallFactory = OkHttpClient()
                )
            )
            .build()

        client.newCall(
            Request.Builder()
                .url(server.url("/gateway/api/account/settings/voice-clone"))
                .build()
        ).execute().use { response ->
            assertEquals(200, response.code)
        }

        val first = server.takeRequest()
        val recovery = server.takeRequest()
        val retry = server.takeRequest()
        assertNull(first.getHeader("Authorization"))
        assertEquals("/gateway/api/auth/voice-clone/legacy-recovery", recovery.path)
        assertEquals("POST", recovery.method)
        assertNull(recovery.getHeader("Authorization"))
        assertEquals("Bearer recovered-token", retry.getHeader("Authorization"))
        assertEquals(1, updates)
        assertEquals("recovered-token", token)
    }

    @Test
    fun `refreshes expired token and retries voice clone request once`() {
        server.enqueue(
            MockResponse()
                .setResponseCode(401)
                .setBody("""{"code":401,"message":"expired"}""")
        )
        server.enqueue(
            MockResponse().setBody(
                """{"code":0,"message":"ok","data":{"voiceCloneAccessToken":"renewed-token"}}"""
            )
        )
        server.enqueue(MockResponse().setBody("""{"code":0}"""))
        var token = "expired-token"
        var updates = 0
        val client = OkHttpClient.Builder()
            .addInterceptor(
                VoiceCloneAuthInterceptor(
                    tokenProvider = { token },
                    tokenUpdater = {
                        token = it
                        updates += 1
                    },
                    refreshCallFactory = OkHttpClient()
                )
            )
            .build()

        client.newCall(
            Request.Builder()
                .url(server.url("/gateway/api/account/settings/voice-clone"))
                .build()
        ).execute().use { response ->
            assertEquals(200, response.code)
        }

        val first = server.takeRequest()
        val refresh = server.takeRequest()
        val retry = server.takeRequest()
        assertEquals("Bearer expired-token", first.getHeader("Authorization"))
        assertEquals("/gateway/api/auth/voice-clone/refresh", refresh.path)
        assertEquals("POST", refresh.method)
        assertEquals("Bearer expired-token", refresh.getHeader("Authorization"))
        assertEquals("Bearer renewed-token", retry.getHeader("Authorization"))
        assertEquals(1, updates)
        assertEquals("renewed-token", token)
    }

    @Test
    fun `uses a dedicated call factory instead of nesting refresh in original chain`() {
        server.enqueue(
            MockResponse()
                .setResponseCode(401)
                .setBody("""{"code":401,"message":"expired"}""")
        )
        server.enqueue(
            MockResponse().setBody(
                """{"code":0,"message":"ok","data":{"voiceCloneAccessToken":"renewed-token"}}"""
            )
        )
        server.enqueue(MockResponse().setBody("""{"code":0}"""))
        var token = "expired-token"
        val refreshClient = OkHttpClient.Builder().build()
        val rejectNestedRefresh = Interceptor { chain ->
            check(!chain.request().url.encodedPath.endsWith("/api/auth/voice-clone/refresh")) {
                "refresh request entered original interceptor chain"
            }
            chain.proceed(chain.request())
        }
        val client = OkHttpClient.Builder()
            .addInterceptor(
                VoiceCloneAuthInterceptor(
                    tokenProvider = { token },
                    tokenUpdater = { token = it },
                    refreshCallFactory = refreshClient
                )
            )
            .addInterceptor(rejectNestedRefresh)
            .build()

        client.newCall(
            Request.Builder()
                .url(server.url("/gateway/api/account/settings/voice-clone"))
                .build()
        ).execute().use { response ->
            assertEquals(200, response.code)
        }

        assertEquals("renewed-token", token)
        assertEquals(3, server.requestCount)
    }

    @Test
    fun `returns original 401 without retry loop when refresh transport fails`() {
        server.enqueue(
            MockResponse()
                .setResponseCode(401)
                .setBody("""{"code":401,"message":"expired"}""")
        )
        var updated = false
        val failingRefreshClient = OkHttpClient.Builder()
            .addInterceptor {
                throw IOException("refresh unavailable")
            }
            .build()
        val client = OkHttpClient.Builder()
            .addInterceptor(
                VoiceCloneAuthInterceptor(
                    tokenProvider = { "expired-token" },
                    tokenUpdater = { updated = true },
                    refreshCallFactory = failingRefreshClient
                )
            )
            .build()

        client.newCall(
            Request.Builder()
                .url(server.url("/api/account/settings/voice-clone"))
                .build()
        ).execute().use { response ->
            assertEquals(401, response.code)
        }

        assertEquals(1, server.requestCount)
        assertTrue(!updated)
    }

    @Test
    fun `does not refresh non voice clone 401`() {
        server.enqueue(MockResponse().setResponseCode(401))
        var updated = false
        val client = OkHttpClient.Builder()
            .addInterceptor(
                VoiceCloneAuthInterceptor(
                    tokenProvider = { "expired-token" },
                    tokenUpdater = { updated = true },
                    refreshCallFactory = OkHttpClient()
                )
            )
            .build()

        client.newCall(
            Request.Builder().url(server.url("/api/task/list")).build()
        ).execute().use { response ->
            assertEquals(401, response.code)
        }

        assertEquals(1, server.requestCount)
        assertTrue(!updated)
    }
}
