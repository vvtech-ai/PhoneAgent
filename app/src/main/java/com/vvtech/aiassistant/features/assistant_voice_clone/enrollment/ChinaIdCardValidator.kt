package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException

internal object ChinaIdCardValidator {
    private val weights = intArrayOf(7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2)
    private val checks = charArrayOf('1', '0', 'X', '9', '8', '7', '6', '5', '4', '3', '2')

    fun isValid(value: String): Boolean {
        val normalized = value.trim().uppercase()
        if (!normalized.matches(Regex("\\d{17}[0-9X]"))) return false
        if (!hasValidBirthDate(normalized.substring(6, 14))) return false
        val sum = normalized.take(17).mapIndexed { index, char ->
            char.digitToInt() * weights[index]
        }.sum()
        return checks[sum % 11] == normalized.last()
    }

    private fun hasValidBirthDate(value: String): Boolean = try {
        LocalDate.parse(value, DateTimeFormatter.BASIC_ISO_DATE)
        true
    } catch (_: DateTimeParseException) {
        false
    }
}
