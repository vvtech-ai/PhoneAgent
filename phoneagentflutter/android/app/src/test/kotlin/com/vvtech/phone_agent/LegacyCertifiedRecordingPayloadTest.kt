package com.vvtech.phone_agent

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import org.junit.Assert.*
import org.junit.Test

class LegacyCertifiedRecordingPayloadTest {
    private fun fixture(version: Int = 1, receipt: String = "合成\u0000😀",
                        length: Int = 3, audio: ByteArray = byteArrayOf(1, 2, 3)): ByteArray {
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { out ->
            out.writeInt(version)
            listOf("phone-synthetic", "fingerprint", "synthetic-hash", "script-v1", receipt)
                .forEach(out::writeUTF)
            out.writeInt(length)
            out.write(audio)
        }
        return bytes.toByteArray()
    }

    @Test fun decodesExactLegacyJavaModifiedUtfAndIndependentAudio() {
        val bytes = fixture()
        val decoded = LegacyCertifiedRecordingPayload.decode(bytes)
        bytes.fill(0)
        assertEquals(1, decoded["version"])
        assertEquals("phone-synthetic", decoded["accountRef"])
        assertEquals("fingerprint", decoded["personFingerprint"])
        assertEquals("synthetic-hash", decoded["audioSha256"])
        assertEquals("script-v1", decoded["scriptVersion"])
        assertEquals("合成\u0000😀", decoded["receipt"])
        assertArrayEquals(byteArrayOf(1, 2, 3), decoded["audio"] as ByteArray)
    }

    @Test fun unknownVersionRemainsRetryableUnsupported() {
        assertThrows(LegacyRecordingUnsupported::class.java) {
            LegacyCertifiedRecordingPayload.decode(fixture(version = 2))
        }
    }

    @Test fun rejectsBlankMetadata() {
        assertThrows(IllegalArgumentException::class.java) {
            LegacyCertifiedRecordingPayload.decode(fixture(receipt = " "))
        }
    }

    @Test fun rejectsEmptyNegativeOversizedOrInconsistentAudioLength() {
        listOf(0, -1, 2, 4, LegacyCertifiedRecordingPayload.MAX_AUDIO + 1).forEach {
            assertThrows(IllegalArgumentException::class.java) {
                LegacyCertifiedRecordingPayload.decode(fixture(length = it))
            }
        }
    }

    @Test fun rejectsTruncationAndTrailingBytes() {
        val bytes = fixture()
        assertThrows(IllegalArgumentException::class.java) {
            LegacyCertifiedRecordingPayload.decode(bytes.copyOf(bytes.size - 1))
        }
        assertThrows(IllegalArgumentException::class.java) {
            LegacyCertifiedRecordingPayload.decode(bytes + byteArrayOf(0))
        }
    }

    @Test fun rejectsOuterOversizeBeforeParsing() {
        assertThrows(IllegalArgumentException::class.java) {
            LegacyCertifiedRecordingPayload.decode(ByteArray(LegacyCertifiedRecordingPayload.MAX_ENCRYPTED + 1))
        }
    }
}
