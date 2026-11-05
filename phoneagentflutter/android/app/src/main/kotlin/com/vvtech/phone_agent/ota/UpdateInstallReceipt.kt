package com.vvtech.phone_agent.ota

/** An installer handoff alone is never proof that installation completed. */
data class UpdateInstallReceipt(val previousUpdateTime: Long, val sha256: String) {
    fun completed(installedUpdateTime: Long, installedHash: String): Boolean =
        previousUpdateTime > 0 && installedUpdateTime > previousUpdateTime &&
            sha256.matches(Regex("[a-f0-9]{64}")) && sha256 == installedHash
}
