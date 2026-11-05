package com.vvtech.phone_agent

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** Read packaged deployment input only; never initializes a model or phone. */
class DomesticModelConfigurationChannel(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.vvtech.phone_agent/domestic_model_configuration")
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
            } else {
                val provider = call.argument<String>("provider")
                if (provider !in setOf("QWEN", "DOUBAO")) {
                    result.success(null)
                } else {
                    try {
                        val bytes = context.assets.open("domestic-model-configuration.json").use {
                            val buffer = ByteArray(16385)
                            var count = 0
                            while (count < buffer.size) {
                                val read = it.read(buffer, count, buffer.size - count)
                                if (read < 0) break
                                count += read
                            }
                            require(count <= 16384)
                            buffer.copyOf(count)
                        }
                        val root = JSONObject(String(bytes, Charsets.UTF_8))
                        require(root.getInt("version") == 1 && root.getString("platform") == "android")
                        val model = root.getJSONObject("models").getJSONObject(provider!!)
                        val headers = model.getJSONObject("headers")
                        result.success(mapOf(
                            "provider" to model.getString("provider"),
                            "uri" to model.getString("uri"),
                            "model" to model.getString("model"),
                            "voice" to model.getString("voice"),
                            "outputSampleRate" to model.getInt("outputSampleRate"),
                            "headers" to headers.keys().asSequence().associateWith { headers.getString(it) }
                        ))
                    } catch (_: Exception) {
                        result.success(null)
                    }
                }
            }
        }
    }
    fun close() { channel.setMethodCallHandler(null) }
}
