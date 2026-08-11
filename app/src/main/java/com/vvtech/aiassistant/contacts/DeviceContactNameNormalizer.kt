package com.vvtech.aiassistant.contacts

import android.icu.text.Transliterator
import android.os.Build
import androidx.annotation.RequiresApi

internal class DeviceContactNameNormalizer {
    fun normalize(value: String): String {
        val trimmed = value.trim()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Api29.normalize(trimmed)
        } else {
            trimmed
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private object Api29 {
        private val traditionalToSimplified: Transliterator? by lazy {
            val availableIds = Transliterator.getAvailableIDs()
            while (availableIds.hasMoreElements()) {
                val id = availableIds.nextElement()
                if (id == "Traditional-Simplified" || id == "Hant-Hans") {
                    return@lazy Transliterator.getInstance(id)
                }
            }
            null
        }

        fun normalize(value: String): String = traditionalToSimplified?.transliterate(value) ?: value
    }
}

internal fun typedContactNamesMatch(
    requestedName: String,
    storedName: String,
    normalize: (String) -> String
): Boolean {
    return normalize(requestedName).equals(normalize(storedName), ignoreCase = true)
}
