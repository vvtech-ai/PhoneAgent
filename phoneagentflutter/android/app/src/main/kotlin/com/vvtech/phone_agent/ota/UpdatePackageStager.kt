package com.vvtech.phone_agent.ota

import java.io.File
import java.io.FileNotFoundException
import java.security.MessageDigest

/** Transfers an opaque download into the app-owned FileProvider directory. */
object UpdatePackageStager {
    fun stage(source: File, target: File): File {
        if (!source.isFile || source.length() <= 0) throw FileNotFoundException("Downloaded file unavailable")
        val temporary = File(target.parentFile, "${target.nameWithoutExtension}.part")
        try {
            source.inputStream().use { input ->
                temporary.outputStream().use { output -> input.copyTo(output) }
            }
            check(temporary.length() > 0 && temporary.length() == source.length())
            check(temporary.renameTo(target))
            return target
        } finally {
            temporary.delete()
        }
    }

    /** Completion tracking only; never compared to backend APK metadata. */
    fun fingerprint(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
