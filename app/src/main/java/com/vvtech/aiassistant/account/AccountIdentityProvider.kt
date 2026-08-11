package com.vvtech.aiassistant.account

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

object AccountIdentityProvider {

    private const val PrefsName = "account_identity"
    private const val KeyPhone = "phone"
    private const val KeyVoiceCloneAccessToken = "voice_clone_access_token"
    private const val SecurePrefsName = "account_auth_secure"
    private const val KeyAccessToken = "access_token"
    private const val KeyRefreshToken = "refresh_token"

    @Volatile
    private var cachedPhone: String? = null

    @Volatile
    private var cachedVoiceCloneAccessToken: String? = null

    @Volatile
    private var cachedAccessToken: String? = null

    @Volatile
    private var cachedRefreshToken: String? = null

    @Volatile
    private var cachedPreferences: SharedPreferences? = null

    @Volatile
    private var cachedSecurePreferences: SharedPreferences? = null

    val accountId: String
        get() = cachedPhone?.let(::accountIdFromPhone).orEmpty()

    val loggedInPhone: String
        get() = cachedPhone.orEmpty()

    val hasSignedInAccount: Boolean
        get() = accountId.isNotBlank()

    val voiceCloneAccessToken: String
        get() = cachedVoiceCloneAccessToken.orEmpty()

    val accessToken: String
        get() = cachedAccessToken.orEmpty()

    val refreshToken: String
        get() = cachedRefreshToken.orEmpty()

    fun initialize(context: Context) {
        val prefs = context.applicationContext.getSharedPreferences(PrefsName, Context.MODE_PRIVATE)
        cachedPreferences = prefs
        val securePrefs = securePreferences(context)
        cachedSecurePreferences = securePrefs
        cachedPhone = normalizePhone(prefs.getString(KeyPhone, null)).takeIf { it.isNotBlank() }
        cachedVoiceCloneAccessToken = prefs.getString(KeyVoiceCloneAccessToken, null)
            ?.trim()
            ?.takeIf { it.isNotBlank() }
        cachedAccessToken = securePrefs?.getString(KeyAccessToken, null)
            ?.trim()?.takeIf(String::isNotBlank)
        cachedRefreshToken = securePrefs?.getString(KeyRefreshToken, null)
            ?.trim()?.takeIf(String::isNotBlank)
    }

    fun signIn(
        context: Context,
        phone: String,
        accessToken: String,
        refreshToken: String,
        voiceCloneAccessToken: String = ""
    ) {
        val normalizedPhone = normalizePhone(phone)
        val normalizedToken = voiceCloneAccessToken.trim()
        val prefs = context.applicationContext.getSharedPreferences(PrefsName, Context.MODE_PRIVATE)
        val securePrefs = securePreferences(context)
            ?: throw IllegalStateException("设备安全存储不可用，无法保存登录会话")
        cachedPreferences = prefs
        cachedSecurePreferences = securePrefs
        cachedPhone = normalizedPhone.takeIf { it.isNotBlank() }
        cachedVoiceCloneAccessToken = normalizedToken.takeIf { it.isNotBlank() }
        cachedAccessToken = accessToken.trim().takeIf(String::isNotBlank)
        cachedRefreshToken = refreshToken.trim().takeIf(String::isNotBlank)
        prefs.edit()
            .putString(KeyPhone, normalizedPhone)
            .putString(KeyVoiceCloneAccessToken, normalizedToken)
            .apply()
        securePrefs.edit()
            .putString(KeyAccessToken, cachedAccessToken.orEmpty())
            .putString(KeyRefreshToken, cachedRefreshToken.orEmpty())
            .apply()
    }

    fun updateSessionTokens(accessToken: String, refreshToken: String) {
        val access = accessToken.trim()
        val refresh = refreshToken.trim()
        if (access.isBlank() || refresh.isBlank()) return
        cachedAccessToken = access
        cachedRefreshToken = refresh
        cachedSecurePreferences?.edit()
            ?.putString(KeyAccessToken, access)
            ?.putString(KeyRefreshToken, refresh)
            ?.apply()
    }

    fun updateVoiceCloneAccessToken(voiceCloneAccessToken: String) {
        val normalizedToken = voiceCloneAccessToken.trim()
        if (normalizedToken.isBlank()) return
        cachedVoiceCloneAccessToken = normalizedToken
        cachedPreferences?.edit()
            ?.putString(KeyVoiceCloneAccessToken, normalizedToken)
            ?.apply()
    }

    fun signOut(context: Context) {
        val prefs = context.applicationContext.getSharedPreferences(PrefsName, Context.MODE_PRIVATE)
        cachedPreferences = prefs
        cachedPhone = null
        cachedVoiceCloneAccessToken = null
        cachedAccessToken = null
        cachedRefreshToken = null
        prefs.edit()
            .remove(KeyPhone)
            .remove(KeyVoiceCloneAccessToken)
            .apply()
        (cachedSecurePreferences ?: securePreferences(context))?.edit()
            ?.remove(KeyAccessToken)
            ?.remove(KeyRefreshToken)
            ?.apply()
    }

    private fun accountIdFromPhone(phone: String): String {
        val normalized = normalizePhone(phone)
        return if (normalized.isBlank()) "" else "phone-$normalized"
    }

    private fun normalizePhone(raw: String?): String {
        var normalized = raw.orEmpty().trim()
            .replace(Regex("\\s+"), "")
            .replace("-", "")
        if (normalized.startsWith("+86")) {
            normalized = normalized.substring(3)
        } else if (normalized.startsWith("86")) {
            normalized = normalized.substring(2)
        }
        return normalized.takeIf { Regex("^1[3-9]\\d{9}$").matches(it) }.orEmpty()
    }

    private fun securePreferences(context: Context): SharedPreferences? = runCatching {
        val appContext = context.applicationContext
        val masterKey = MasterKey.Builder(appContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            appContext,
            SecurePrefsName,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }.getOrNull()
}
