package com.vvtech.phone_agent.ota

import java.io.File
import java.io.FileNotFoundException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class UpdatePackageStagerTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun opaqueFileIsHandedOverWithoutApkMetadataOrSignerParsing() {
        val source = temporary.newFile("download.apk")
        val bytes = "opaque bytes, not parseable APK metadata".toByteArray()
        source.writeBytes(bytes)
        val target = File(temporary.newFolder("private"), "owned.apk")
        assertEquals(target, UpdatePackageStager.stage(source, target))
        assertArrayEquals(bytes, target.readBytes())
        assertArrayEquals(bytes, source.readBytes())
        assertFalse(File(target.parentFile, "owned.part").exists())
    }

    @Test fun missingOrEmptyDownloadCannotBeHandedOver() {
        val target = File(temporary.newFolder("private"), "owned.apk")
        assertThrows(FileNotFoundException::class.java) {
            UpdatePackageStager.stage(File(temporary.root, "missing.apk"), target)
        }
        assertThrows(FileNotFoundException::class.java) {
            UpdatePackageStager.stage(temporary.newFile("empty.apk"), target)
        }
        assertFalse(target.exists())
    }

    @Test fun preparationFailureCleansTemporaryFileAndPreservesDownload() {
        val source = temporary.newFile("download.apk").apply { writeText("opaque") }
        val target = temporary.newFolder("target.apk")
        assertThrows(IllegalStateException::class.java) {
            UpdatePackageStager.stage(source, target)
        }
        assertEquals("opaque", source.readText())
        assertFalse(File(target.parentFile, "target.part").exists())
    }

    @Test fun fingerprintIsOnlyActualBytesForCompletionTracking() {
        val source = temporary.newFile("download.apk").apply { writeText("abc") }
        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", UpdatePackageStager.fingerprint(source))
    }
}
