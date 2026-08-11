package com.vvtech.aiassistant.contacts

import com.github.promeg.pinyinhelper.Pinyin
import java.util.Locale

data class PinyinContactEntry(
    val contactId: String? = null,
    val displayName: String,
    val phoneNumber: String,
    val label: String? = null,
    val namePinyin: List<String> = ContactPinyinTokenizer.toPinyinTokens(displayName)
)

data class PinyinSearchResult(
    val entry: PinyinContactEntry,
    val score: Double,
    val matchKind: String
)

object ContactPinyinTokenizer {
    fun toPinyinTokens(value: String, knownSyllables: Set<String> = emptySet()): List<String> {
        if (value.isBlank()) return emptyList()
        val result = mutableListOf<String>()
        val latinBuffer = StringBuilder()

        fun flushLatin() {
            if (latinBuffer.isEmpty()) return
            splitLatin(latinBuffer.toString(), knownSyllables).forEach(result::add)
            latinBuffer.setLength(0)
        }

        value.forEach { ch ->
            when {
                Pinyin.isChinese(ch) -> {
                    flushLatin()
                    val pinyin = Pinyin.toPinyin(ch).normalizePinyinToken()
                    if (pinyin.isNotBlank()) result.add(pinyin)
                }
                ch.isLetter() -> latinBuffer.append(ch)
                ch == '?' -> {
                    flushLatin()
                    result.add("?")
                }
                else -> flushLatin()
            }
        }
        flushLatin()
        return result
    }

    private fun splitLatin(value: String, knownSyllables: Set<String>): List<String> {
        val normalized = value.normalizePinyinToken()
        if (normalized.isBlank()) return emptyList()
        if (knownSyllables.isEmpty() || normalized in knownSyllables) return listOf(normalized)

        val result = mutableListOf<String>()
        var index = 0
        while (index < normalized.length) {
            val match = knownSyllables
                .asSequence()
                .filter { normalized.startsWith(it, startIndex = index) }
                .maxByOrNull { it.length }
            if (match == null || match.isBlank()) {
                return listOf(normalized)
            }
            result.add(match)
            index += match.length
        }
        return result
    }

    private fun String.normalizePinyinToken(): String =
        uppercase(Locale.US).filter { it in 'A'..'Z' || it == '?' }
}

class ContactPinyinSearchEngine {

    fun search(query: String, contacts: List<PinyinContactEntry>): List<PinyinSearchResult> {
        if (contacts.isEmpty()) return emptyList()
        val knownSyllables = contacts
            .flatMap { it.namePinyin }
            .filter { it.isNotBlank() && it != "?" }
            .toSet()
        val queryPinyin = ContactPinyinTokenizer.toPinyinTokens(query, knownSyllables)
        if (queryPinyin.isEmpty() || queryPinyin.size > MaxSearchSyllables) return emptyList()

        return contacts
            .asSequence()
            .mapNotNull { entry -> bestMatch(queryPinyin, entry) }
            .sortedWith(
                compareByDescending<PinyinSearchResult> { it.score }
                    .thenBy { it.entry.displayName.lowercase(Locale.US) }
                    .thenBy { it.entry.phoneNumber }
            )
            .toList()
    }

    private fun bestMatch(queryPinyin: List<String>, entry: PinyinContactEntry): PinyinSearchResult? {
        val target = entry.namePinyin
        if (target.isEmpty()) return null

        val fullScore = if (target.size >= queryPinyin.size) {
            matchAt(queryPinyin, target, 0)?.let { FullMatchBase * it }
        } else {
            null
        }
        val lastScore = if (queryPinyin.size >= 2 && target.size > 2) {
            val lastTwo = queryPinyin.takeLast(2)
            matchAt(lastTwo, target, target.size - 2)?.let { LastTwoMatchBase * it }
        } else {
            null
        }

        val bestFull = fullScore?.let { PinyinSearchResult(entry, it, "FULL_PINYIN") }
        val bestLast = lastScore?.let { PinyinSearchResult(entry, it, "LAST_TWO_PINYIN") }
        return listOfNotNull(bestFull, bestLast).maxByOrNull { it.score }
    }

    private fun matchAt(queryPinyin: List<String>, target: List<String>, start: Int): Double? {
        if (start < 0 || start + queryPinyin.size > target.size) return null
        var score = 1.0
        queryPinyin.forEachIndexed { index, query ->
            if (query == "?") return@forEachIndexed
            val targetToken = target[start + index]
            val tokenScore = variantsFor(query)[targetToken] ?: return null
            score *= tokenScore
        }
        return score
    }

    private fun variantsFor(token: String): Map<String, Double> {
        val normalized = token.uppercase(Locale.US)
        val variants = linkedMapOf(normalized to 1.0)

        YunmuRule.values().forEach { rule ->
            rule.switch(normalized)?.let { variants.mergeMax(it, rule.priority) }
        }

        ShengmuRule.values().forEach { shengmu ->
            val shengmuValue = shengmu.switch(normalized) ?: return@forEach
            variants.mergeMax(shengmuValue, shengmu.priority)
            YunmuRule.values().forEach { yunmu ->
                yunmu.switch(shengmuValue)?.let { variants.mergeMax(it, shengmu.priority * yunmu.priority) }
            }
        }

        SpecialRule.values().forEach { rule ->
            rule.switch(normalized)?.let { variants.mergeMax(it, rule.priority) }
        }

        return variants
    }

    private fun MutableMap<String, Double>.mergeMax(key: String, value: Double) {
        val normalized = key.uppercase(Locale.US)
        val current = this[normalized]
        if (current == null || value > current) {
            this[normalized] = value
        }
    }

    private enum class YunmuRule(
        private val key1: String,
        private val key2: String,
        val priority: Double
    ) {
        IN("IN", "ING", 0.95),
        AN("AN", "ANG", 0.95),
        EN("EN", "ENG", 0.95),
        ON("ON", "ONG", 0.95),
        UAN("UAN", "UANG", 0.95),
        UNO("UN", "ONG", 0.60),
        UNI("UN", "IONG", 0.60),
        EU("EN", "UN", 0.80);

        fun switch(value: String): String? {
            if (value.isBlank()) return null
            if (key2 == "UN" && !value.startsWith("C")) return null
            return when {
                value.endsWith(key1) -> value.dropLast(key1.length) + key2
                value.endsWith(key2) -> value.dropLast(key2.length) + key1
                else -> null
            }
        }
    }

    private enum class ShengmuRule(
        private val key1: String,
        private val key2: String,
        val priority: Double
    ) {
        Z("Z", "ZH", 0.90),
        C("C", "CH", 0.90),
        S("S", "SH", 0.90),
        HF("H", "F", 0.75),
        GK("G", "K", 0.75),
        LN("L", "N", 0.75),
        LR("L", "R", 0.75),
        CT("CH", "T", 0.75);

        fun switch(value: String): String? {
            if (key2 == "T" && !value.endsWith("ANG")) return null
            return when {
                value.startsWith(key2) -> key1 + value.removePrefix(key2)
                value.startsWith(key1) -> key2 + value.removePrefix(key1)
                else -> null
            }
        }
    }

    private enum class SpecialRule(
        private val key1: String,
        private val key2: String,
        val priority: Double
    ) {
        HW1("HUANG", "WANG", 0.80),
        HW2("HU", "WU", 0.80),
        HF("HUI", "FEI", 0.80),
        OU("CONG", "CHUN", 0.60);

        fun switch(value: String): String? = when (value) {
            key1 -> key2
            key2 -> key1
            else -> null
        }
    }

    private companion object {
        private const val MaxSearchSyllables = 4
        private const val FullMatchBase = 100.0
        private const val LastTwoMatchBase = 80.0
    }
}
