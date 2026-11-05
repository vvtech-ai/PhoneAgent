package com.vvtech.phone_agent

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.DataInputStream
import java.io.File
import java.io.FileInputStream
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.AEADBadTagException

/** Fixed legacy source, read-only. Never generate a key or delete bad input. */
class LegacyCertifiedRecordingChannel(context: Context, messenger: BinaryMessenger) {
    private val app = context.applicationContext
    private val channel = MethodChannel(messenger, "phone_agent/legacy_certified_recording",
        StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())
    @Volatile private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
            } else try {
                check(!closed)
                val value = if (app.packageName == "com.vvtech.aiassistant") readLegacy() else null
                if (!closed) result.success(value)
            } catch (_: InvalidPayload) {
                if (!closed) result.error("recording_corrupt", "Legacy recording integrity unavailable", null)
            } catch (_: AEADBadTagException) {
                if (!closed) result.error("recording_corrupt", "Legacy recording integrity unavailable", null)
            } catch (_: Exception) {
                if (!closed) result.error("recording_unavailable", "Legacy recording unavailable", null)
            }
        }
    }

    private fun readLegacy(): Map<String, Any>? {
        val file = File(app.noBackupFilesDir, "voice_clone_certified/certified_recording.bin")
        if (!file.exists()) return null
        val encrypted = FileInputStream(file).use { stream ->
            val size = stream.channel.size()
            if (size !in 30..LegacyCertifiedRecordingPayload.MAX_ENCRYPTED.toLong()) throw InvalidPayload()
            ByteArray(size.toInt()).also { bytes ->
                val input = DataInputStream(stream)
                input.readFully(bytes)
                if (input.read() != -1) throw InvalidPayload()
            }
        }
        val ivSize = encrypted[0].toInt() and 0xff
        if (ivSize !in 12..16 || encrypted.size <= 1 + ivSize + 16) throw InvalidPayload()
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val key = store.getKey("voice_clone_certified_recording_v1", null) as? SecretKey
            ?: throw LegacyRecordingUnsupported()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key,
            GCMParameterSpec(128, encrypted.copyOfRange(1, 1 + ivSize)))
        // v65 uses no AAD. New storage independently encrypts with its slot AAD.
        val plain = cipher.doFinal(encrypted, 1 + ivSize, encrypted.size - 1 - ivSize)
        return try {
            LegacyCertifiedRecordingPayload.decode(plain)
        } catch (error: LegacyRecordingUnsupported) {
            throw error
        } catch (_: Exception) {
            throw InvalidPayload()
        } finally {
            plain.fill(0)
        }
    }

    fun close() { closed = true; channel.setMethodCallHandler(null) }
    private class InvalidPayload : Exception()
}
