package com.vvtech.aiassistant.features.assistant_calls

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DialCountryFlagAssetTest {

    @Test
    fun allSupportedWorldCallFlagsAreBundledAsUniformFourByThreePngs() {
        val drawableDirectory = File("src/main/res/drawable-nodpi")
        val expectedFiles = DialCountries
            .map { country -> "flag_dial_${country.iso.lowercase()}.png" }
            .toSet()

        val actualFiles = drawableDirectory
            .listFiles()
            .orEmpty()
            .filter { it.name.startsWith("flag_dial_") && it.extension == "png" }
            .map(File::getName)
            .toSet()

        assertEquals(expectedFiles, actualFiles)
        expectedFiles.forEach { fileName ->
            val bytes = File(drawableDirectory, fileName).readBytes()
            assertTrue("Flag must be a PNG: $fileName", bytes.startsWith(PngSignature))
            assertEquals("Flag width: $fileName", 96, pngDimension(bytes, 16))
            assertEquals("Flag height: $fileName", 72, pngDimension(bytes, 20))
        }
    }

    private fun pngDimension(bytes: ByteArray, offset: Int): Int =
        ByteBuffer.wrap(bytes, offset, Int.SIZE_BYTES)
            .order(ByteOrder.BIG_ENDIAN)
            .int

    private fun ByteArray.startsWith(prefix: ByteArray): Boolean =
        size >= prefix.size && prefix.indices.all { index -> this[index] == prefix[index] }

    private companion object {
        val PngSignature = byteArrayOf(
            0x89.toByte(),
            0x50,
            0x4E,
            0x47,
            0x0D,
            0x0A,
            0x1A,
            0x0A
        )
    }
}
