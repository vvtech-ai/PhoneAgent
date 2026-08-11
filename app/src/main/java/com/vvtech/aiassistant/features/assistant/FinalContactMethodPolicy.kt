package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.logging.AppFileLogger

import android.content.SharedPreferences
import androidx.compose.ui.graphics.Color
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.AssistantHistoryItem
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.model.ConversationDetail
import com.vvtech.aiassistant.model.ConversationListItem
import com.vvtech.aiassistant.model.ReservationSlot
import com.vvtech.aiassistant.model.TaskListItem
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import com.google.gson.Gson
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale


internal fun List<PersonalInfoEntry>.ensureSingleDefault(): List<PersonalInfoEntry> {
    if (isEmpty()) return emptyList()
    val currentDefault = firstOrNull { it.isDefault } ?: first()
    return listOf(currentDefault.copy(isDefault = true)) +
        filterNot { it.id == currentDefault.id }.map { it.copy(isDefault = false) }
}

internal fun loadFinalContactMethods(prefs: SharedPreferences): List<PersonalInfoEntry> {
    val raw = prefs.getString(FinalPersonalInfoListKey, "").orEmpty()
    if (raw.isBlank()) return emptyList()

    return runCatching {
        val array = JSONArray(raw)
        buildList {
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                add(
                    PersonalInfoEntry(
                        id = item.optString("id"),
                        name = item.optString("name"),
                        gender = item.optString("gender")
                            .takeIf { it == PersonalInfoGender.Ms.name }
                            ?.let { PersonalInfoGender.Ms }
                            ?: PersonalInfoGender.Mr,
                        phone = item.optString("phone"),
                        idCardNumber = item.optString("idCardNumber"),
                        isDefault = item.optBoolean("isDefault")
                    )
                )
            }
        }
    }.getOrDefault(emptyList())
        .take(FinalMaxPersonalInfoCount)
        .ensureSingleDefault()
}

internal fun saveFinalContactMethods(
    prefs: SharedPreferences,
    entries: List<PersonalInfoEntry>
) {
    val normalized = entries.take(FinalMaxPersonalInfoCount).ensureSingleDefault()
    val array = JSONArray()
    normalized.forEach { entry ->
        array.put(
            JSONObject().apply {
                put("id", entry.id)
                put("name", entry.name)
                put("gender", entry.gender.name)
                put("phone", entry.phone)
                put("idCardNumber", entry.idCardNumber)
                put("isDefault", entry.isDefault)
            }
        )
    }
    prefs.edit().putString(FinalPersonalInfoListKey, array.toString()).apply()
}

private val FinalContactMethodNameRegex = Regex("^[\\u4E00-\\u9FFF]{1,4}$")
private val FinalContactMethodNameAllowedCharRegex = Regex("[\\u4E00-\\u9FFF]")

internal fun sanitizeContactMethodNameInput(raw: String): String {
    return FinalContactMethodNameAllowedCharRegex
        .findAll(raw)
        .joinToString(separator = "") { it.value }
        .take(4)
}

internal fun validatePersonalInfoInput(name: String, phone: String): String? {
    val trimmedName = name.trim()
    if (trimmedName.isBlank()) return "请输入姓名"
    if (!FinalContactMethodNameRegex.matches(trimmedName)) {
        return "姓名仅支持 1-4 个汉字"
    }
    if (normalizeMainlandPhone(phone).isBlank()) {
        return "请输入正确的手机号码"
    }
    return null
}

internal fun normalizeMainlandPhone(value: String): String {
    val normalized = value
        .replace("\\s+".toRegex(), "")
        .replace("-", "")
        .removePrefix("+86")
        .removePrefix("86")
    return if (Regex("^1[3-9]\\d{9}$").matches(normalized)) normalized else ""
}

internal fun normalizeOutboundDialNumber(value: String): String {
    val normalized = buildString {
        value.trim().forEachIndexed { index, ch ->
            when {
                ch in '0'..'9' -> append(ch)
                ch in '０'..'９' -> append('0' + (ch - '０'))
                (ch == '+' || ch == '＋') && isEmpty() && index == 0 -> append('+')
                ch.isWhitespace() || ch in setOf('-', '－', '—', '–', '~', '.', '。', '·', '(', ')', '（', '）', '[', ']', '【', '】') -> Unit
            }
        }
    }
    return when {
        normalized.startsWith("+86") -> normalizeChinaCountryCodeDialNumber(normalized.removePrefix("+86"))
        normalized.startsWith("0086") -> normalizeChinaCountryCodeDialNumber(normalized.removePrefix("0086"))
        else -> normalized
    }
}

private fun normalizeChinaCountryCodeDialNumber(numberWithoutCountryCode: String): String {
    if (numberWithoutCountryCode.isBlank()) return ""
    return when {
        Regex("^1[3-9]\\d{9}$").matches(numberWithoutCountryCode) -> numberWithoutCountryCode
        numberWithoutCountryCode.startsWith("0") -> numberWithoutCountryCode
        else -> "0$numberWithoutCountryCode"
    }
}

internal fun normalizeLoginMainlandPhone(value: String): String {
    val normalized = value
        .trim()
        .replace("\\s+".toRegex(), "")
        .replace(Regex("[-－—–]"), "")
        .removePrefix("+86")
        .removePrefix("86")
    return if (Regex("^1[3-9]\\d{9}$").matches(normalized)) normalized else ""
}

internal fun sanitizeLoginPhoneInput(value: String, previous: String = ""): String {
    val normalized = normalizeLoginPhoneDigits(value)
    if (isLoginPhonePrefixAllowed(normalized)) {
        return normalized
    }
    val fallback = normalizeLoginPhoneDigits(previous)
    return if (isLoginPhonePrefixAllowed(fallback)) fallback else ""
}

private fun normalizeLoginPhoneDigits(value: String): String {
    val digits = buildString {
        value.forEach { ch ->
            when {
                ch in '0'..'9' -> append(ch)
                ch in '０'..'９' -> append('0' + (ch - '０'))
            }
        }
    }
    val normalized = when {
        digits.startsWith("0086") && digits.length > 4 -> digits.drop(4)
        digits.startsWith("86") && digits.length > 2 -> digits.drop(2)
        else -> digits
    }.take(11)
    return normalized
}

private fun isLoginPhonePrefixAllowed(value: String): Boolean {
    return when (value.length) {
        0 -> true
        1 -> value == "1"
        else -> value[0] == '1' && value[1] in '3'..'9' && value.all { it in '0'..'9' }
    }
}

internal fun maskPhone(phone: String): String {
    val normalized = normalizeMainlandPhone(phone)
    if (normalized.length != 11) return phone
    return normalized.replaceRange(3, 7, "****")
}

internal fun PersonalInfoGender.displayLabel(): String = when (this) {
    PersonalInfoGender.Mr -> "先生"
    PersonalInfoGender.Ms -> "女士"
}
