package com.vvtech.aiassistant.callengine

import java.security.MessageDigest
import java.util.Locale

internal enum class AssistantSipAudioCodec {
    PCMU,
    PCMA
}

internal data class AssistantSipRemoteAudioEndpoint(
    val address: String,
    val port: Int,
    val payloadType: Int,
    val codec: AssistantSipAudioCodec,
    val telephoneEventPayloadType: Int? = null
)

internal data class AssistantSipAuthChallenge(
    val realm: String,
    val nonce: String,
    val qop: String?,
    val proxy: Boolean,
    val opaque: String? = null
)

internal data class AssistantSipMessage(
    val statusCode: Int,
    val reasonPhrase: String,
    val headers: Map<String, List<String>>,
    val body: String,
    val startLine: String
) {
    fun header(name: String): String? = headers[normalizeSipHeader(name)]?.firstOrNull()
    fun headerValues(name: String): List<String> = headers[normalizeSipHeader(name)].orEmpty()
    fun requestMethod(): String =
        if (statusCode == 0) startLine.substringBefore(' ').uppercase(Locale.US) else ""
    fun cseqNumber(): Int? = cseqParts().firstOrNull()?.toIntOrNull()
    fun cseqMethod(): String = cseqParts().getOrNull(1)?.uppercase(Locale.US).orEmpty()

    private fun cseqParts(): List<String> =
        header("CSeq")?.trim()?.split(Regex("\\s+")).orEmpty()
}

internal object AssistantSipMessageParser {
    fun parse(raw: String): AssistantSipMessage {
        val normalized = raw.replace("\r\n", "\n")
        val separator = normalized.indexOf("\n\n")
        val head = if (separator >= 0) normalized.substring(0, separator) else normalized
        val body = if (separator >= 0) normalized.substring(separator + 2) else ""
        val lines = head.lines().filter(String::isNotBlank)
        val startLine = lines.firstOrNull().orEmpty()
        val statusParts = startLine.split(" ", limit = 3)
        val headers = linkedMapOf<String, MutableList<String>>()
        lines.drop(1).forEach { line ->
            val index = line.indexOf(':')
            if (index > 0) {
                val name = normalizeSipHeader(line.substring(0, index).trim())
                headers.getOrPut(name) { mutableListOf() }.add(line.substring(index + 1).trim())
            }
        }
        return AssistantSipMessage(
            statusCode = statusParts.getOrNull(1)?.toIntOrNull() ?: 0,
            reasonPhrase = statusParts.getOrNull(2).orEmpty(),
            headers = headers,
            body = body,
            startLine = startLine
        )
    }

    fun authChallenge(message: AssistantSipMessage): AssistantSipAuthChallenge? {
        val proxy = message.header("Proxy-Authenticate")
        val value = proxy ?: message.header("WWW-Authenticate") ?: return null
        val params = parseDigestParameters(value)
        return AssistantSipAuthChallenge(
            realm = params["realm"].orEmpty(),
            nonce = params["nonce"].orEmpty(),
            qop = params["qop"],
            proxy = proxy != null,
            opaque = params["opaque"]
        )
    }

    private fun parseDigestParameters(value: String): Map<String, String> {
        val result = mutableMapOf<String, String>()
        splitDigestParameters(value.removePrefix("Digest").trim()).forEach { part ->
            val index = part.indexOf('=')
            if (index > 0) {
                result[part.substring(0, index).trim().lowercase(Locale.US)] =
                    part.substring(index + 1).trim().trim('"')
            }
        }
        return result
    }

    private fun splitDigestParameters(payload: String): List<String> {
        val values = mutableListOf<String>()
        val current = StringBuilder()
        var quoted = false
        payload.forEach { char ->
            when {
                char == '"' -> {
                    quoted = !quoted
                    current.append(char)
                }
                char == ',' && !quoted -> {
                    values.add(current.toString())
                    current.clear()
                }
                else -> current.append(char)
            }
        }
        if (current.isNotEmpty()) values.add(current.toString())
        return values
    }
}

internal object AssistantSipDigestAuthenticator {
    fun authorizationHeader(
        challenge: AssistantSipAuthChallenge,
        username: String,
        password: String,
        method: String,
        uri: String,
        cnonce: String,
        nonceCount: Int
    ): String {
        val qop = challenge.qop?.split(',')?.map(String::trim)?.firstOrNull { it == "auth" }
        val nc = nonceCount.toString(16).padStart(8, '0')
        val ha1 = md5("$username:${challenge.realm}:$password")
        val ha2 = md5("${method.uppercase(Locale.US)}:$uri")
        val response = if (qop == null) {
            md5("$ha1:${challenge.nonce}:$ha2")
        } else {
            md5("$ha1:${challenge.nonce}:$nc:$cnonce:$qop:$ha2")
        }
        val name = if (challenge.proxy) "Proxy-Authorization" else "Authorization"
        val parts = mutableListOf(
            "username=\"$username\"",
            "realm=\"${challenge.realm}\"",
            "nonce=\"${challenge.nonce}\"",
            "uri=\"$uri\"",
            "response=\"$response\"",
            "algorithm=MD5"
        )
        challenge.opaque?.takeIf(String::isNotBlank)?.let { parts.add("opaque=\"$it\"") }
        if (qop != null) {
            parts.add("qop=$qop")
            parts.add("nc=$nc")
            parts.add("cnonce=\"$cnonce\"")
        }
        return "$name: Digest ${parts.joinToString(", ")}"
    }

    private fun md5(value: String): String =
        MessageDigest.getInstance("MD5")
            .digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
}

internal object AssistantSipSdpParser {
    fun parseRemoteAudio(sdp: String): AssistantSipRemoteAudioEndpoint {
        val lines = sdp.replace("\r\n", "\n").lines().map(String::trim)
        val address = lines.firstOrNull { it.startsWith("c=IN IP4 ") }
            ?.removePrefix("c=IN IP4 ")
            ?.trim()
            ?: lines.firstOrNull { it.startsWith("o=") }
                ?.substringAfter("IN IP4 ", "")
                ?.trim()
            .orEmpty()
        val media = lines.firstOrNull { it.startsWith("m=audio ") }
            ?.removePrefix("m=audio ")
            ?.split(Regex("\\s+"))
            .orEmpty()
        val payloads = media.drop(2).mapNotNull(String::toIntOrNull)
        val rtpMaps = lines.mapNotNull(::parseRtpMap).toMap()
        val telephoneEvent = payloads.firstOrNull {
            rtpMaps[it].equals("telephone-event", ignoreCase = true)
        }
        val payloadType = payloads.firstOrNull {
            it == 0 || it == 8 ||
                rtpMaps[it].equals("PCMU", ignoreCase = true) ||
                rtpMaps[it].equals("PCMA", ignoreCase = true)
        } ?: payloads.firstOrNull() ?: 0
        val codec = if (payloadType == 8 || rtpMaps[payloadType].equals("PCMA", true)) {
            AssistantSipAudioCodec.PCMA
        } else {
            AssistantSipAudioCodec.PCMU
        }
        return AssistantSipRemoteAudioEndpoint(
            address = address,
            port = media.firstOrNull()?.toIntOrNull() ?: 0,
            payloadType = payloadType,
            codec = codec,
            telephoneEventPayloadType = telephoneEvent
        )
    }

    private fun parseRtpMap(line: String): Pair<Int, String>? {
        if (!line.startsWith("a=rtpmap:", ignoreCase = true)) return null
        val payload = line.substringAfter("a=rtpmap:").substringBefore(' ').toIntOrNull()
            ?: return null
        val codec = line.substringAfter(' ', "").substringBefore('/').trim()
        return payload to codec
    }
}

private fun normalizeSipHeader(name: String): String = name.lowercase(Locale.US)
