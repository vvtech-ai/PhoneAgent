package com.vvtech.phone_agent.diagnostics

import android.app.Application
import com.vvtech.phone_agent.TrustedCallerIncomingRuntime
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

class NativeCrashApplication : Application() {
    lateinit var crashStore: CrashSummaryStore
        private set
    lateinit var crashRecorder: NativeCrashRecorder
        private set

    override fun onCreate() {
        super.onCreate()
        crashStore = CrashSummaryStore(File(noBackupFilesDir, "native-diagnostics-v1"), ::key)
        crashRecorder = NativeCrashRecorder(
            crashStore::save, Thread.getDefaultUncaughtExceptionHandler(),
        ) { it === Looper.getMainLooper().thread }
        Thread.setDefaultUncaughtExceptionHandler(crashRecorder)
        TrustedCallerIncomingRuntime.shared(this).initializeAtStartup()
    }

    @Synchronized
    private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = store.getKey(KEY_ALIAS, null)
        if (existing != null) return existing as SecretKey
        check(create)
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(
                KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).build())
        }.generateKey()
    }

    companion object { private const val KEY_ALIAS = "phone_agent_native_diagnostics_v1" }
}
