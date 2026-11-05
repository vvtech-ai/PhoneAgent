package com.vvtech.phone_agent

import java.net.URI
import java.net.URLDecoder

/** Exact environment entry contract; no credentials or arbitrary redirects. */
object InviteAppLinkPolicy {
    fun parse(url: String?, host: String, path: String, scheme: String): String? = runCatching {
        if (url == null || url.length > 4096 || host.isBlank()) return null
        val uri = URI(url)
        if (uri.rawUserInfo != null || uri.rawFragment != null) return null
        val https = uri.scheme == "https" && uri.host == host &&
            uri.port in listOf(-1, 443) && uri.rawPath == path
        val custom = scheme.isNotBlank() && uri.scheme == scheme && uri.host == "invite" &&
            uri.port == -1 && uri.rawPath == "/"
        if (!https && !custom) return null
        val values = uri.rawQuery.orEmpty().split("&").map { parameter ->
            val parts = parameter.split("=", limit = 2)
            URLDecoder.decode(parts[0], "UTF-8") to parts.getOrNull(1)
        }.filter { it.first == "code" || it.first == "invite" }
        if (values.isEmpty() || values.any { it.second == null }) return null
        values.map { URLDecoder.decode(it.second!!, "UTF-8") }.distinct()
            .singleOrNull()?.takeIf { code ->
                code.codePointCount(0, code.length) == 4 && code.codePoints().noneMatch {
                    Character.isWhitespace(it) || Character.isSpaceChar(it) || Character.isISOControl(it)
                }
            }
    }.getOrNull()
}
