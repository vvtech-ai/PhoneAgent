package com.vvtech.aiassistant.features.assistant_home.domain

internal object HomeConfigPolicy {
    fun isVersionSupported(currentVersion: String, minimumVersion: String?): Boolean {
        if (minimumVersion.isNullOrBlank()) return true
        val current = parseVersion(currentVersion) ?: return false
        val minimum = parseVersion(minimumVersion) ?: return false
        val size = maxOf(current.size, minimum.size)
        repeat(size) { index ->
            val left = current.getOrElse(index) { 0 }
            val right = minimum.getOrElse(index) { 0 }
            if (left != right) return left > right
        }
        return true
    }

    private fun parseVersion(value: String): List<Int>? {
        val core = value.trim().substringBefore('-')
        if (core.isEmpty()) return null
        return core.split('.').map { it.toIntOrNull() ?: return null }
    }
}
