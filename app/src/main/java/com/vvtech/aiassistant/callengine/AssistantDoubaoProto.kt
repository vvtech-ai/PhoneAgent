package com.vvtech.aiassistant.callengine

import com.google.protobuf.CodedInputStream
import com.google.protobuf.CodedOutputStream
import com.google.protobuf.WireFormat
import java.io.ByteArrayOutputStream

internal data class AssistantDoubaoRequestMeta(
    val endpoint: String,
    val appKey: String,
    val resourceId: String,
    val connectionId: String,
    val sessionId: String,
    val sequence: Int
)

internal data class AssistantDoubaoAudio(
    val format: String = "",
    val codec: String = "",
    val language: String = "",
    val rate: Int = 0,
    val bits: Int = 0,
    val channel: Int = 0,
    val data: ByteArray = ByteArray(0)
)

internal data class AssistantDoubaoParameters(
    val mode: String,
    val sourceLanguage: String,
    val targetLanguage: String
)

internal data class AssistantDoubaoRequest(
    val meta: AssistantDoubaoRequestMeta?,
    val event: Int,
    val sourceAudio: AssistantDoubaoAudio?,
    val targetAudio: AssistantDoubaoAudio?,
    val parameters: AssistantDoubaoParameters?
)

internal data class AssistantDoubaoResponse(
    val event: Int = 0,
    val statusCode: Int = 0,
    val message: String = "",
    val data: ByteArray = ByteArray(0),
    val text: String = ""
)

internal object AssistantDoubaoProto {
    const val StartSession = 100
    const val FinishSession = 102
    const val TaskRequest = 200
    const val SessionStarted = 150
    const val SessionFailed = 153
    const val TtsResponse = 352
    const val SourceStart = 650
    const val SourceResponse = 651
    const val SourceEnd = 652
    const val TranslationStart = 653
    const val TranslationResponse = 654
    const val TranslationEnd = 655
    const val StatusSuccess = 20_000_000

    fun encode(request: AssistantDoubaoRequest): ByteArray {
        val output = ByteArrayOutputStream()
        val coded = CodedOutputStream.newInstance(output)
        request.meta?.let { writeMessage(coded, 1, encodeMeta(it)) }
        coded.writeInt32(2, request.event)
        request.sourceAudio?.let { writeMessage(coded, 4, encodeAudio(it)) }
        request.targetAudio?.let { writeMessage(coded, 5, encodeAudio(it)) }
        request.parameters?.let { writeMessage(coded, 6, encodeParameters(it)) }
        coded.flush()
        return output.toByteArray()
    }

    fun decode(bytes: ByteArray): AssistantDoubaoResponse {
        if (bytes.isEmpty()) return AssistantDoubaoResponse()
        val input = CodedInputStream.newInstance(bytes)
        var event = 0
        var status = 0
        var message = ""
        var data = ByteArray(0)
        var text = ""
        while (!input.isAtEnd) {
            val tag = input.readTag()
            if (tag == 0) break
            when (WireFormat.getTagFieldNumber(tag)) {
                1 -> {
                    val meta = decodeMeta(input.readByteArray())
                    status = meta.first
                    message = meta.second
                }
                2 -> event = input.readInt32()
                3 -> data = input.readByteArray()
                4 -> text = input.readString()
                else -> input.skipField(tag)
            }
        }
        return AssistantDoubaoResponse(event, status, message, data, text)
    }

    private fun encodeMeta(meta: AssistantDoubaoRequestMeta): ByteArray = encoded {
        writeStringIfPresent(this, 1, meta.endpoint)
        writeStringIfPresent(this, 2, meta.appKey)
        writeStringIfPresent(this, 4, meta.resourceId)
        writeStringIfPresent(this, 5, meta.connectionId)
        writeStringIfPresent(this, 6, meta.sessionId)
        writeInt32(7, meta.sequence)
    }

    private fun encodeAudio(audio: AssistantDoubaoAudio): ByteArray = encoded {
        writeStringIfPresent(this, 4, audio.format)
        writeStringIfPresent(this, 5, audio.codec)
        writeStringIfPresent(this, 6, audio.language)
        if (audio.rate > 0) writeInt32(7, audio.rate)
        if (audio.bits > 0) writeInt32(8, audio.bits)
        if (audio.channel > 0) writeInt32(9, audio.channel)
        if (audio.data.isNotEmpty()) writeByteArray(14, audio.data)
    }

    private fun encodeParameters(parameters: AssistantDoubaoParameters): ByteArray = encoded {
        writeStringIfPresent(this, 1, parameters.mode)
        writeStringIfPresent(this, 2, parameters.sourceLanguage)
        writeStringIfPresent(this, 3, parameters.targetLanguage)
    }

    private fun decodeMeta(bytes: ByteArray): Pair<Int, String> {
        val input = CodedInputStream.newInstance(bytes)
        var status = 0
        var message = ""
        while (!input.isAtEnd) {
            val tag = input.readTag()
            if (tag == 0) break
            when (WireFormat.getTagFieldNumber(tag)) {
                3 -> status = input.readInt32()
                4 -> message = input.readString()
                else -> input.skipField(tag)
            }
        }
        return status to message
    }

    private fun encoded(write: CodedOutputStream.() -> Unit): ByteArray {
        val output = ByteArrayOutputStream()
        CodedOutputStream.newInstance(output).apply {
            write()
            flush()
        }
        return output.toByteArray()
    }

    private fun writeMessage(output: CodedOutputStream, field: Int, bytes: ByteArray) {
        output.writeTag(field, WireFormat.WIRETYPE_LENGTH_DELIMITED)
        output.writeUInt32NoTag(bytes.size)
        output.writeRawBytes(bytes)
    }

    private fun writeStringIfPresent(
        output: CodedOutputStream,
        field: Int,
        value: String
    ) {
        if (value.isNotBlank()) output.writeString(field, value)
    }
}
