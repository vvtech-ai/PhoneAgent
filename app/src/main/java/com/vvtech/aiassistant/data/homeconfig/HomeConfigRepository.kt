package com.vvtech.aiassistant.data.homeconfig

import android.content.Context
import com.vvtech.aiassistant.data.service.AssistantApiService
import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfigLoadResult
import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfigRepository
import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfigSource
import com.vvtech.aiassistant.network.NetworkModule
import kotlinx.coroutines.CancellationException

internal class DefaultHomeConfigRepository(
    private val apiService: AssistantApiService,
    private val local: HomeConfigLocalDataSource,
    private val mapper: HomeConfigMapper = HomeConfigMapper()
) : HomeConfigRepository {
    override suspend fun load(): HomeConfigLoadResult {
        val cached = local.read()
        return runCatching {
            val response = apiService.getPublishedHomeConfig(cached?.etag)
            if (response.code() == 304 && cached != null) {
                return HomeConfigLoadResult(mapper.map(cached.dto), HomeConfigSource.Cache)
            }
            require(response.isSuccessful) { "首页配置请求失败：${response.code()}" }
            val envelope = requireNotNull(response.body()) { "首页配置响应为空" }
            require(envelope.code == 0) { envelope.message }
            val dto = requireNotNull(envelope.data) { "首页配置数据为空" }
            val config = mapper.map(dto)
            local.write(dto, response.headers()["ETag"])
            HomeConfigLoadResult(config, HomeConfigSource.Network)
        }.getOrElse { error ->
            if (error is CancellationException) throw error
            HomeConfigFallbackPolicy.resolve(error.message)
        }
    }
}

internal object HomeConfigContainer {
    fun repository(context: Context): HomeConfigRepository = DefaultHomeConfigRepository(
        apiService = NetworkModule.assistantApiService,
        local = HomeConfigLocalDataSource(context.applicationContext)
    )
}
