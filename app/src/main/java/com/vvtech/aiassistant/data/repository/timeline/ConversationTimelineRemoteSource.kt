package com.vvtech.aiassistant.data.repository.timeline

import com.vvtech.aiassistant.data.remote.timeline.ConversationTimelineApi
import com.vvtech.aiassistant.data.remote.timeline.ConversationTimelineWireMapper
import com.vvtech.aiassistant.domain.conversation.ConversationTimelinePage
import java.io.IOException
import retrofit2.HttpException

/** Maps the Retrofit response at the data boundary so DTOs cannot escape to callers. */
fun interface ConversationTimelineRemoteSource {
    suspend fun load(sessionId: String, afterSequence: Long?, limit: Int): ConversationTimelinePage
}

class RetrofitConversationTimelineRemoteSource(
    private val api: ConversationTimelineApi,
) : ConversationTimelineRemoteSource {
    override suspend fun load(sessionId: String, afterSequence: Long?, limit: Int): ConversationTimelinePage = try {
        ConversationTimelineWireMapper.toDomain(api.getTimeline(sessionId, afterSequence, limit))
    } catch (error: HttpException) {
        if (error.code() == 503) throw TimelineUnavailableException("timeline service unavailable", error)
        throw error
    } catch (error: IOException) {
        throw TimelineUnavailableException("timeline transport unavailable", error)
    }
}
