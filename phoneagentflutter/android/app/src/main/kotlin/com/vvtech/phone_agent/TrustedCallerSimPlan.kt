package com.vvtech.phone_agent

/** Pure fixed-native SIM policy. A login fallback is not a read SIM number. */
internal data class TrustedCallerSimWrite(val slot: Int, val number: String, val fallback: Boolean)

internal object TrustedCallerSimPlan {
    fun normalize(raw: String?): String {
        var value = raw.orEmpty().trim().replace(Regex("\\s+"), "")
            .replace("-", "").replace("(", "").replace(")", "")
        value = when {
            value.startsWith("+86") -> value.substring(3)
            value.startsWith("0086") -> value.substring(4)
            value.startsWith("86") && value.length == 13 -> value.substring(2)
            else -> value
        }
        val digits = value.filter(Char::isDigit)
        return digits.takeIf { Regex("^1[3-9]\\d{9}$").matches(it) }.orEmpty()
    }

    fun writes(loginPhone: String, activeSlots: List<Int>, actualNumbers: Map<Int, String>): List<TrustedCallerSimWrite> {
        val login = normalize(loginPhone)
        if (login.isEmpty()) return emptyList()
        val slots = activeSlots.filter { it >= 0 }.distinct().sorted()
        if (slots.isEmpty()) return emptyList()
        val numbers = slots.associateWith { normalize(actualNumbers[it]) }
        if (slots.size == 1) {
            val slot = slots.first()
            val actual = numbers.getValue(slot)
            return listOf(TrustedCallerSimWrite(slot, actual.ifEmpty { login }, actual.isEmpty()))
        }
        val writes = numbers.filterValues { it.isNotEmpty() }
            .map { (slot, number) -> TrustedCallerSimWrite(slot, number, false) }
            .toMutableList()
        val fallbackSlot = slots.firstOrNull { it == 1 } ?: slots.last()
        if (numbers.getValue(fallbackSlot).isEmpty()) {
            writes += TrustedCallerSimWrite(fallbackSlot, login, true)
        }
        return writes.toList()
    }
}
