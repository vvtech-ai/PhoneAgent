package com.vvtech.aiassistant.callengine

internal object AssistantRtpTelephoneEventPacketizer {
    fun packetize(
        key: Char,
        payloadType: Int,
        startSequence: Int,
        startTimestamp: Long,
        ssrc: Long,
        durationMillis: Int
    ): List<ByteArray> {
        val eventCode = eventCodeFor(key) ?: return emptyList()
        val safeDurationMillis = durationMillis.coerceAtLeast(FrameMillis)
        val finalDuration = durationUnits(safeDurationMillis)
        val packets = mutableListOf<ByteArray>()
        var sequence = startSequence
        var elapsedMillis = FrameMillis
        var first = true
        while (elapsedMillis < safeDurationMillis) {
            packets += buildPacket(
                eventCode = eventCode,
                payloadType = payloadType,
                sequence = sequence,
                timestamp = startTimestamp,
                ssrc = ssrc,
                duration = durationUnits(elapsedMillis),
                end = false,
                marker = first
            )
            sequence = (sequence + 1) and 0xFFFF
            elapsedMillis += FrameMillis
            first = false
        }
        repeat(FinalPacketRepeats) {
            packets += buildPacket(
                eventCode = eventCode,
                payloadType = payloadType,
                sequence = sequence,
                timestamp = startTimestamp,
                ssrc = ssrc,
                duration = finalDuration,
                end = true,
                marker = first
            )
            sequence = (sequence + 1) and 0xFFFF
            first = false
        }
        return packets
    }

    private fun buildPacket(
        eventCode: Int,
        payloadType: Int,
        sequence: Int,
        timestamp: Long,
        ssrc: Long,
        duration: Int,
        end: Boolean,
        marker: Boolean
    ): ByteArray = AssistantRtpPacketCodec.build(
        payloadType = payloadType,
        sequenceNumber = sequence,
        timestamp = timestamp,
        ssrc = ssrc,
        payload = byteArrayOf(
            eventCode.toByte(),
            ((if (end) EndBit else 0) or Volume).toByte(),
            ((duration ushr 8) and 0xFF).toByte(),
            (duration and 0xFF).toByte()
        ),
        marker = marker
    )

    private fun durationUnits(durationMillis: Int): Int =
        (durationMillis.coerceAtMost(MaxDurationMillis) * SamplesPerMillisecond)
            .coerceIn(0, MaxDurationUnits)

    private fun eventCodeFor(key: Char): Int? = when (key) {
        in '0'..'9' -> key.digitToInt()
        '*' -> 10
        '#' -> 11
        else -> null
    }

    private const val FrameMillis = 20
    private const val FinalPacketRepeats = 3
    private const val SamplesPerMillisecond = 8
    private const val MaxDurationUnits = 0xFFFF
    private const val MaxDurationMillis = MaxDurationUnits / SamplesPerMillisecond
    private const val Volume = 10
    private const val EndBit = 0x80
}
