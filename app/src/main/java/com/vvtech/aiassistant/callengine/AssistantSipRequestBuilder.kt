package com.vvtech.aiassistant.callengine

internal object AssistantSipRequestBuilder {
    fun register(
        account: AssistantSipAccount,
        localIp: String,
        localSipPort: Int,
        callId: String,
        fromTag: String,
        branch: String,
        cseq: Int,
        authorization: String?
    ): String = request(
        mutableListOf(
            "REGISTER ${registerUri(account)} SIP/2.0",
            via(localIp, localSipPort, branch),
            "Max-Forwards: 70",
            "From: ${address(account, account.username)};tag=$fromTag",
            "To: ${address(account, account.username)}",
            "Call-ID: $callId",
            "CSeq: $cseq REGISTER",
            contact(account, localIp, localSipPort),
            "Expires: 300",
            "User-Agent: CHAKEN-AI-Android"
        ),
        authorization
    )

    fun invite(
        account: AssistantSipAccount,
        target: String,
        localIp: String,
        localSipPort: Int,
        localRtpPort: Int,
        callId: String,
        fromTag: String,
        branch: String,
        cseq: Int,
        authorization: String?
    ): String {
        val body = sdp(localIp, localRtpPort)
        val headers = mutableListOf(
            "INVITE ${inviteUri(account, target)} SIP/2.0",
            via(localIp, localSipPort, branch),
            "Max-Forwards: 70",
            "From: ${address(account, account.callerNumber)};tag=$fromTag",
            "To: ${targetAddress(account, target)}",
            "Call-ID: $callId",
            "CSeq: $cseq INVITE",
            contact(account, localIp, localSipPort),
            "Allow: INVITE, ACK, CANCEL, BYE, INFO, OPTIONS",
            "Supported: replaces, timer",
            "Content-Type: application/sdp"
        )
        authorization?.takeIf(String::isNotBlank)?.let(headers::add)
        headers.add("Content-Length: ${body.toByteArray(Charsets.UTF_8).size}")
        return headers.joinToString("\r\n") + "\r\n\r\n" + body
    }

    fun ack(
        dialog: AssistantSipDialog,
        branch: String,
        requestUri: String = dialog.requestUri
    ): String = dialogRequest(
        method = "ACK",
        dialog = dialog,
        branch = branch,
        cseq = dialog.inviteCseq,
        requestUri = requestUri
    )

    fun bye(dialog: AssistantSipDialog, branch: String, cseq: Int): String =
        dialogRequest("BYE", dialog, branch, cseq, dialog.requestUri)

    fun cancel(
        account: AssistantSipAccount,
        target: String,
        localIp: String,
        localSipPort: Int,
        callId: String,
        fromTag: String,
        branch: String,
        inviteCseq: Int
    ): String {
        val headers = mutableListOf(
            "CANCEL ${inviteUri(account, target)} SIP/2.0",
            via(localIp, localSipPort, branch),
            "Max-Forwards: 70",
            "From: ${address(account, account.callerNumber)};tag=$fromTag",
            "To: ${targetAddress(account, target)}",
            "Call-ID: $callId",
            "CSeq: $inviteCseq CANCEL",
            "Content-Length: 0"
        )
        return headers.joinToString("\r\n") + "\r\n\r\n"
    }

    fun info(
        dialog: AssistantSipDialog,
        branch: String,
        cseq: Int,
        key: Char
    ): String {
        val body = "Signal=$key\r\nDuration=160\r\n"
        val headers = dialogHeaders("INFO", dialog, branch, cseq, dialog.requestUri)
        headers.add("Content-Type: application/dtmf-relay")
        headers.add("Content-Length: ${body.toByteArray(Charsets.UTF_8).size}")
        return headers.joinToString("\r\n") + "\r\n\r\n" + body
    }

    fun ok(request: AssistantSipMessage): String {
        val headers = mutableListOf("SIP/2.0 200 OK")
        request.headerValues("Via").forEach { headers.add("Via: $it") }
        request.header("From")?.let { headers.add("From: $it") }
        request.header("To")?.let { headers.add("To: $it") }
        request.header("Call-ID")?.let { headers.add("Call-ID: $it") }
        request.header("CSeq")?.let { headers.add("CSeq: $it") }
        headers.add("Content-Length: 0")
        return headers.joinToString("\r\n") + "\r\n\r\n"
    }

    fun registerUri(account: AssistantSipAccount): String =
        "sip:${account.server}:${account.port};transport=udp"

    fun inviteUri(account: AssistantSipAccount, target: String): String =
        "sip:$target@${account.server}:${account.port};transport=udp;user=phone"

    fun dialogRequestUri(message: AssistantSipMessage): String? =
        message.header("Contact")?.let(::firstSipUri)

    fun dialogRouteSet(message: AssistantSipMessage): List<String> =
        message.headerValues("Record-Route").flatMap(::sipUris).asReversed()

    private fun request(headers: MutableList<String>, authorization: String?): String {
        authorization?.takeIf(String::isNotBlank)?.let(headers::add)
        headers.add("Content-Length: 0")
        return headers.joinToString("\r\n") + "\r\n\r\n"
    }

    private fun dialogRequest(
        method: String,
        dialog: AssistantSipDialog,
        branch: String,
        cseq: Int,
        requestUri: String
    ): String {
        val headers = dialogHeaders(method, dialog, branch, cseq, requestUri)
        headers.add("Content-Length: 0")
        return headers.joinToString("\r\n") + "\r\n\r\n"
    }

    private fun dialogHeaders(
        method: String,
        dialog: AssistantSipDialog,
        branch: String,
        cseq: Int,
        requestUri: String
    ): MutableList<String> {
        val headers = mutableListOf(
            "$method $requestUri SIP/2.0",
            via(dialog.localIp, dialog.localSipPort, branch),
            "Max-Forwards: 70",
            "From: ${address(dialog.account, dialog.account.callerNumber)};tag=${dialog.fromTag}",
            "To: ${dialog.toHeader}",
            "Call-ID: ${dialog.callId}",
            "CSeq: $cseq $method"
        )
        dialog.routeSet.forEach { headers.add("Route: <$it>") }
        headers.add(contact(dialog.account, dialog.localIp, dialog.localSipPort))
        return headers
    }

    private fun via(localIp: String, localSipPort: Int, branch: String): String =
        "Via: SIP/2.0/UDP $localIp:$localSipPort;branch=$branch;rport"

    private fun contact(account: AssistantSipAccount, localIp: String, localSipPort: Int): String =
        "Contact: <sip:${account.username}@$localIp:$localSipPort;transport=udp>"

    private fun address(account: AssistantSipAccount, user: String): String =
        "<sip:$user@${account.server}:${account.port}>"

    private fun targetAddress(account: AssistantSipAccount, target: String): String =
        "<sip:$target@${account.server}:${account.port};user=phone>"

    private fun firstSipUri(value: String): String? = sipUris(value).firstOrNull()

    private fun sipUris(value: String): List<String> {
        val angleUris = Regex("""<\s*((?:sip|sips):[^>\s]+)\s*>""", RegexOption.IGNORE_CASE)
            .findAll(value)
            .map { it.groupValues[1] }
            .toList()
        return angleUris.ifEmpty {
            Regex("""\b(?:sip|sips):[^,\s>]+""", RegexOption.IGNORE_CASE)
                .findAll(value)
                .map { it.value }
                .toList()
        }
    }

    private fun sdp(localIp: String, localRtpPort: Int): String = listOf(
        "v=0",
        "o=- 0 0 IN IP4 $localIp",
        "s=CHAKEN.AI",
        "c=IN IP4 $localIp",
        "t=0 0",
        "m=audio $localRtpPort RTP/AVP 0 8 101",
        "a=rtpmap:0 PCMU/8000",
        "a=rtpmap:8 PCMA/8000",
        "a=rtpmap:101 telephone-event/8000",
        "a=fmtp:101 0-15",
        "a=sendrecv"
    ).joinToString("\r\n") + "\r\n"
}

internal data class AssistantSipDialog(
    val account: AssistantSipAccount,
    val target: String,
    val localIp: String,
    val localSipPort: Int,
    val callId: String,
    val fromTag: String,
    val toHeader: String,
    val inviteCseq: Int,
    val requestUri: String,
    val routeSet: List<String>
)
