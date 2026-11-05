package com.vvtech.phone_agent

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.security.KeyStore
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Opaque encrypted blobs only. All account/recording rules live in Dart. */
class CertifiedRecordingChannel(context: Context, messenger: BinaryMessenger) {
    private val directory = File(context.noBackupFilesDir, "flutter_certified_recording_v1")
    private val channel = MethodChannel(messenger, "phone_agent/certified_recording",
        StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())
    @Volatile private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method !in setOf("read", "replace", "clear")) {
                result.notImplemented()
            } else try {
              synchronized(STORAGE_LOCK) {
                check(!closed)
                val slot = call.argument<String>("slot") ?: error("invalid")
                require(slot.matches(Regex("^[a-f0-9]{64}$")))
                check(directory.isDirectory || directory.mkdirs())
                val base = File(directory, "$slot.bin")
                val file = AtomicFile(base)
                when (call.method) {
                    "read" -> {
                        if (!base.exists() && !File(base.path + ".bak").exists()) {
                            result.success(null)
                        } else {
                            val encrypted = file.openRead().use { input ->
                                if (input.channel.size() !in 30..MAX_BYTES.toLong()) throw Corrupt()
                                input.readBytes()
                            }
                            val ivLength = encrypted[0].toInt() and 0xff
                            if (ivLength !in 12..16 || encrypted.size <= 1 + ivLength + 16) throw Corrupt()
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(Cipher.DECRYPT_MODE, key(false),
                                GCMParameterSpec(128, encrypted.copyOfRange(1, 1 + ivLength)))
                            cipher.updateAAD(slot.toByteArray(Charsets.UTF_8))
                            result.success(cipher.doFinal(encrypted, 1 + ivLength, encrypted.size - 1 - ivLength))
                        }
                    }
                    "replace" -> {
                        val plain = call.argument<ByteArray>("payload") ?: error("invalid")
                        require(plain.isNotEmpty() && plain.size <= MAX_BYTES - 64)
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        cipher.init(Cipher.ENCRYPT_MODE, key(true))
                        cipher.updateAAD(slot.toByteArray(Charsets.UTF_8))
                        val encrypted = byteArrayOf(cipher.iv.size.toByte()) + cipher.iv + cipher.doFinal(plain)
                        val stream = file.startWrite()
                        try {
                            stream.write(encrypted)
                            file.finishWrite(stream)
                        } catch (error: Exception) {
                            file.failWrite(stream)
                            throw error
                        }
                        result.success(null)
                    }
                    "clear" -> {
                        file.delete()
                        check(!base.exists() && !File(base.path + ".bak").exists())
                        result.success(null)
                    }
                }
              }
            } catch (_: Corrupt) {
                result.error("recording_corrupt", "Recording integrity unavailable", null)
            } catch (_: AEADBadTagException) {
                result.error("recording_corrupt", "Recording integrity unavailable", null)
            } catch (_: Exception) {
                result.error("recording_unavailable", "Private recording storage unavailable", null)
            }
        }
    }
    private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        if (!create) throw Corrupt()
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder(KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).build())
            generateKey()
        }
    }
    fun close() { closed = true; channel.setMethodCallHandler(null) }
    private class Corrupt : Exception()
    private companion object {
        val STORAGE_LOCK = Any()
        const val KEY_ALIAS = "phone_agent_flutter_certified_recording_v1"
        const val MAX_BYTES = 11 * 1024 * 1024
    }
}
