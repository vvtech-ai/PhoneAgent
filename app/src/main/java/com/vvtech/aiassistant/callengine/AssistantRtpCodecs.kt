package com.vvtech.aiassistant.callengine

import java.nio.ByteBuffer
import java.nio.ByteOrder

internal data class AssistantRtpPacket(
    val payloadType: Int,
    val sequenceNumber: Int,
    val timestamp: Long,
    val ssrc: Long,
    val payload: ByteArray
)

internal object AssistantRtpPacketCodec {
    private const val HeaderSize = 12

    fun build(
        payloadType: Int,
        sequenceNumber: Int,
        timestamp: Long,
        ssrc: Long,
        payload: ByteArray,
        marker: Boolean = false
    ): ByteArray = ByteBuffer.allocate(HeaderSize + payload.size)
        .order(ByteOrder.BIG_ENDIAN)
        .apply {
            put(0x80.toByte())
            put(((if (marker) 0x80 else 0) or (payloadType and 0x7F)).toByte())
            putShort((sequenceNumber and 0xFFFF).toShort())
            putInt((timestamp and 0xFFFFFFFFL).toInt())
            putInt((ssrc and 0xFFFFFFFFL).toInt())
            put(payload)
        }
        .array()

    fun parse(packet: ByteArray, length: Int): AssistantRtpPacket? {
        if (length < HeaderSize) return null
        val buffer = ByteBuffer.wrap(packet, 0, length).order(ByteOrder.BIG_ENDIAN)
        val first = buffer.get().toInt() and 0xFF
        val csrcCount = first and 0x0F
        val payloadType = buffer.get().toInt() and 0x7F
        val sequence = buffer.short.toInt() and 0xFFFF
        val timestamp = buffer.int.toLong() and 0xFFFFFFFFL
        val ssrc = buffer.int.toLong() and 0xFFFFFFFFL
        var headerSize = HeaderSize + csrcCount * 4
        if ((first and 0x10) != 0) {
            if (length < headerSize + 4) return null
            val extensionWords = ByteBuffer.wrap(packet, headerSize + 2, 2)
                .order(ByteOrder.BIG_ENDIAN)
                .short
                .toInt() and 0xFFFF
            headerSize += 4 + extensionWords * 4
        }
        if (headerSize > length) return null
        return AssistantRtpPacket(
            payloadType = payloadType,
            sequenceNumber = sequence,
            timestamp = timestamp,
            ssrc = ssrc,
            payload = packet.copyOfRange(headerSize, length)
        )
    }
}

internal object AssistantG711Codec {
    private const val SegShift = 4
    private const val SegMask = 0x70
    private const val SignBit = 0x80
    private const val QuantMask = 0x0F
    private const val Bias = 0x84
    private val segmentEnds =
        intArrayOf(0xFF, 0x1FF, 0x3FF, 0x7FF, 0xFFF, 0x1FFF, 0x3FFF, 0x7FFF)

    fun encode(codec: AssistantSipAudioCodec, pcm: ShortArray): ByteArray =
        if (codec == AssistantSipAudioCodec.PCMA) {
            ByteArray(pcm.size) { linearToAlaw(pcm[it]) }
        } else {
            ByteArray(pcm.size) { linearToUlaw(pcm[it]) }
        }

    fun decode(codec: AssistantSipAudioCodec, payload: ByteArray): ShortArray =
        if (codec == AssistantSipAudioCodec.PCMA) {
            ShortArray(payload.size) { alawToLinear(payload[it]) }
        } else {
            ShortArray(payload.size) { ulawToLinear(payload[it]) }
        }

    private fun linearToAlaw(pcm: Short): Byte {
        var value = pcm.toInt()
        val mask = if (value >= 0) 0xD5 else 0x55
        if (value < 0) value = -value - 8
        val segment = search(value)
        if (segment >= 8) return (0x7F xor mask).toByte()
        var encoded = segment shl SegShift
        encoded = encoded or if (segment < 2) {
            (value shr 4) and QuantMask
        } else {
            (value shr (segment + 3)) and QuantMask
        }
        return (encoded xor mask).toByte()
    }

    private fun alawToLinear(encoded: Byte): Short {
        val value = encoded.toInt() xor 0x55
        var sample = (value and QuantMask) shl 4
        when ((value and SegMask) shr SegShift) {
            0 -> sample += 8
            1 -> sample += 0x108
            else -> {
                sample += 0x108
                sample = sample shl (((value and SegMask) shr SegShift) - 1)
            }
        }
        return (if ((value and SignBit) != 0) sample else -sample).toShort()
    }

    private fun linearToUlaw(pcm: Short): Byte {
        var value = pcm.toInt()
        val mask = if (value < 0) 0x7F else 0xFF
        value = if (value < 0) Bias - value else value + Bias
        val segment = search(value)
        if (segment >= 8) return (0x7F xor mask).toByte()
        return (((segment shl 4) or ((value shr (segment + 3)) and QuantMask)) xor mask).toByte()
    }

    private fun ulawToLinear(encoded: Byte): Short {
        val value = encoded.toInt().inv() and 0xFF
        var sample = ((value and QuantMask) shl 3) + Bias
        sample = sample shl ((value and SegMask) shr SegShift)
        return (if ((value and SignBit) != 0) Bias - sample else sample - Bias).toShort()
    }

    private fun search(value: Int): Int =
        segmentEnds.indexOfFirst { value <= it }.takeIf { it >= 0 } ?: segmentEnds.size
}
