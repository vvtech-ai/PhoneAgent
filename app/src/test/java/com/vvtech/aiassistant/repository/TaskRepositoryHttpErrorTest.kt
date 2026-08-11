package com.vvtech.aiassistant.repository

import kotlinx.coroutines.test.runTest
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test
import retrofit2.HttpException
import retrofit2.Response

class TaskRepositoryHttpErrorTest {

    @Test
    fun realtimeCallVoiceUpdateUsesBackendBusinessMessageForHttp400() = runTest {
        val httpFailure = HttpException(
            Response.error<Unit>(
                400,
                """{"code":400,"message":"当前克隆声音与通话模型不匹配，请重新录制"}"""
                    .toResponseBody()
            )
        )

        val failure = runCatching {
            mapTaskApiHttpError {
                throw httpFailure
            }
        }.exceptionOrNull()

        assertEquals(
            "当前克隆声音与通话模型不匹配，请重新录制",
            failure?.message
        )
        assertSame(httpFailure, failure?.cause)
    }
}
