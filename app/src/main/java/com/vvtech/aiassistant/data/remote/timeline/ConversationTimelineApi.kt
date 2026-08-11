package com.vvtech.aiassistant.data.remote.timeline

import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query

/** Retrofit boundary only; repositories consume mapped domain values, never these DTOs. */
interface ConversationTimelineApi {
    @GET("api/agent/conversations/{sessionId}/timeline")
    suspend fun getTimeline(
        @Path("sessionId") sessionId: String,
        @Query("afterSequence") afterSequence: Long? = null,
        @Query("limit") limit: Int? = null,
    ): ConversationTimelinePageDto
}
