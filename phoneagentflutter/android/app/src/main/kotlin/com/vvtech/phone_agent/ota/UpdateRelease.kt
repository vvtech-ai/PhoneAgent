package com.vvtech.phone_agent.ota

import org.json.JSONObject

/** Only non-secret expected package metadata is persisted. */
data class UpdateRelease(
    val packageName: String,
    val versionName: String,
    val versionCode: Long?,
    val fileSize: Long?,
    val checksum: String,
) {
    fun json() = JSONObject().put("packageName", packageName).put("versionName", versionName)
        .put("versionCode", versionCode ?: JSONObject.NULL)
        .put("fileSize", fileSize ?: JSONObject.NULL).put("checksumSha256", checksum)

    companion object {
        fun parse(values: Map<*, *>, installedPackage: String): UpdateRelease {
            val name = values["packageName"] as? String ?: error("Missing package")
            val version = values["versionName"] as? String ?: error("Missing version")
            val checksum = (values["checksumSha256"] as? String ?: "").lowercase()
            fun number(key: String): Long? {
                val raw = values[key] ?: return null
                require(raw is Int || raw is Long)
                return (raw as Number).toLong().also { require(it > 0) }
            }
            require(name == installedPackage && version.isNotBlank() && version.length <= 200)
            require(checksum.isEmpty() || checksum.matches(Regex("[a-f0-9]{64}")))
            return UpdateRelease(name, version, number("versionCode"), number("fileSize"), checksum)
        }

        fun read(json: JSONObject, installedPackage: String): UpdateRelease = parse(
            listOf("packageName", "versionName", "versionCode", "fileSize", "checksumSha256")
                .associateWith { if (json.isNull(it)) null else json.get(it) }, installedPackage)
    }
}
