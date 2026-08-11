package com.vvtech.aiassistant.callengine

import android.util.Log
import java.net.SocketTimeoutException
import java.util.UUID

internal data class AssistantSipEstablishedCall(
    val dialog: AssistantSipDialog,
    val endpoint: AssistantSipRemoteAudioEndpoint
)

internal class AssistantSipResponseException(
    val sipMethod: String,
    val statusCode: Int,
    reasonPhrase: String
) : IllegalStateException("SIP $sipMethod 失败：$statusCode $reasonPhrase")

internal class AssistantSipTransactions(
    private val account: AssistantSipAccount,
    private val target: String,
    private val socket: AssistantSipSocket,
    private val active: () -> Boolean,
    private val onPhase: (AssistantCallPhase) -> Unit
) {
    private val fromTag = token("tag")
    private val callId = "${UUID.randomUUID()}@chaken-ai"
    private var inviteCseq = 1
    private var activeInviteBranch = ""
    private var activeInviteCseq = 0
    private var dialog: AssistantSipDialog? = null
    private var cancelSent = false
    private var byeSent = false

    fun register() {
        onPhase(AssistantCallPhase.REGISTERING)
        val registerCallId = "${UUID.randomUUID()}@chaken-ai"
        val registerTag = token("reg")
        var cseq = 1
        socket.send(registerPayload(registerCallId, registerTag, cseq, null))
        var response = waitForFinal("REGISTER", 15_000)
        if (response.statusCode == 401 || response.statusCode == 407) {
            val challenge = AssistantSipMessageParser.authChallenge(response)
                ?: error("SIP REGISTER 鉴权信息缺失")
            cseq += 1
            val authorization = AssistantSipDigestAuthenticator.authorizationHeader(
                challenge = challenge,
                username = account.username,
                password = account.password,
                method = "REGISTER",
                uri = AssistantSipRequestBuilder.registerUri(account),
                cnonce = token("cn"),
                nonceCount = 1
            )
            socket.send(registerPayload(registerCallId, registerTag, cseq, authorization))
            response = waitForFinal("REGISTER", 15_000)
        }
        if (response.statusCode !in 200..299) {
            throw AssistantSipResponseException(
                sipMethod = "REGISTER",
                statusCode = response.statusCode,
                reasonPhrase = response.reasonPhrase
            )
        }
    }

    fun invite(): AssistantSipEstablishedCall {
        onPhase(AssistantCallPhase.DIALING)
        socket.send(invitePayload(null))
        var response = waitForInvite(inviteCseq)
        if (response.statusCode == 401 || response.statusCode == 407) {
            sendAck(response, success = false)
            val challenge = AssistantSipMessageParser.authChallenge(response)
                ?: error("SIP INVITE 鉴权信息缺失")
            inviteCseq += 1
            val authorization = AssistantSipDigestAuthenticator.authorizationHeader(
                challenge = challenge,
                username = account.username,
                password = account.password,
                method = "INVITE",
                uri = AssistantSipRequestBuilder.inviteUri(account, target),
                cnonce = token("cn"),
                nonceCount = 1
            )
            socket.send(invitePayload(authorization))
            response = waitForInvite(inviteCseq)
        }
        if (response.statusCode !in 200..299) {
            sendAck(response, success = false)
            throw AssistantSipResponseException(
                sipMethod = "INVITE",
                statusCode = response.statusCode,
                reasonPhrase = response.reasonPhrase
            )
        }
        val establishedDialog = dialogFrom(response)
        dialog = establishedDialog
        socket.send(AssistantSipRequestBuilder.ack(establishedDialog, branch()))
        if (!active()) {
            sendBye()
        }
        val endpoint = AssistantSipSdpParser.parseRemoteAudio(response.body)
        check(endpoint.address.isNotBlank() && endpoint.port > 0) {
            "SIP 应答未包含有效 RTP 地址"
        }
        return AssistantSipEstablishedCall(establishedDialog, endpoint)
    }

    @Synchronized
    fun sendBye() {
        val current = dialog
        if (current == null) {
            sendCancelForActiveInvite()
            return
        }
        if (byeSent) return
        byeSent = true
        inviteCseq += 1
        runCatching {
            socket.send(AssistantSipRequestBuilder.bye(current, branch(), inviteCseq))
            Log.i(Tag, "SIP_TERMINATE method=BYE callTail=${callId.takeLast(12)} cseq=$inviteCseq")
        }
    }

    @Synchronized
    fun sendDtmf(key: Char) {
        val current = dialog ?: return
        inviteCseq += 1
        socket.send(AssistantSipRequestBuilder.info(current, branch(), inviteCseq, key))
    }

    fun holdUntilEnded() {
        while (active()) {
            val message = socket.receive(1_000) ?: continue
            when {
                message.requestMethod() == "OPTIONS" ->
                    socket.send(AssistantSipRequestBuilder.ok(message))
                message.requestMethod() == "BYE" -> {
                    socket.send(AssistantSipRequestBuilder.ok(message))
                    byeSent = true
                    return
                }
                message.statusCode in 200..299 &&
                    message.cseqMethod() == "INVITE" &&
                    message.cseqNumber() == dialog?.inviteCseq ->
                    dialog?.let { socket.send(AssistantSipRequestBuilder.ack(it, branch())) }
            }
        }
    }

    private fun registerPayload(
        registerCallId: String,
        registerTag: String,
        cseq: Int,
        authorization: String?
    ): String = AssistantSipRequestBuilder.register(
        account = account,
        localIp = socket.localIp,
        localSipPort = socket.localSipPort,
        callId = registerCallId,
        fromTag = registerTag,
        branch = branch(),
        cseq = cseq,
        authorization = authorization
    )

    private fun invitePayload(authorization: String?): String {
        val inviteBranch = branch()
        activeInviteBranch = inviteBranch
        activeInviteCseq = inviteCseq
        return AssistantSipRequestBuilder.invite(
            account = account,
            target = target,
            localIp = socket.localIp,
            localSipPort = socket.localSipPort,
            localRtpPort = socket.localRtpPort,
            callId = callId,
            fromTag = fromTag,
            branch = inviteBranch,
            cseq = inviteCseq,
            authorization = authorization
        )
    }

    private fun sendCancelForActiveInvite() {
        if (cancelSent) return
        if (activeInviteBranch.isBlank() || activeInviteCseq <= 0) {
            Log.i(Tag, "SIP_TERMINATE method=NONE reason=no_active_invite callTail=${callId.takeLast(12)}")
            return
        }
        cancelSent = true
        runCatching {
            socket.send(
                AssistantSipRequestBuilder.cancel(
                    account = account,
                    target = target,
                    localIp = socket.localIp,
                    localSipPort = socket.localSipPort,
                    callId = callId,
                    fromTag = fromTag,
                    branch = activeInviteBranch,
                    inviteCseq = activeInviteCseq
                )
            )
            Log.i(
                Tag,
                "SIP_TERMINATE method=CANCEL callTail=${callId.takeLast(12)} cseq=$activeInviteCseq"
            )
        }
    }

    private fun waitForFinal(method: String, timeoutMillis: Long): AssistantSipMessage {
        val deadline = System.currentTimeMillis() + timeoutMillis
        while (active() && System.currentTimeMillis() < deadline) {
            val response = socket.receive() ?: continue
            if (response.requestMethod() == "OPTIONS") {
                socket.send(AssistantSipRequestBuilder.ok(response))
                continue
            }
            if (response.statusCode !in 100..199 && response.cseqMethod() == method) return response
        }
        throw SocketTimeoutException("SIP $method 响应超时")
    }

    private fun waitForInvite(expectedCseq: Int): AssistantSipMessage {
        val deadline = System.currentTimeMillis() + 65_000
        while (active() && System.currentTimeMillis() < deadline) {
            val response = socket.receive() ?: continue
            if (response.cseqMethod() != "INVITE" || response.cseqNumber() != expectedCseq) continue
            when (response.statusCode) {
                100 -> onPhase(AssistantCallPhase.DIALING)
                180, 181, 182, 183 -> onPhase(AssistantCallPhase.RINGING)
                in 200..699 -> return response
            }
        }
        throw SocketTimeoutException("SIP INVITE 响应超时")
    }

    private fun sendAck(response: AssistantSipMessage, success: Boolean) {
        val current = if (success) dialogFrom(response) else AssistantSipDialog(
            account = account,
            target = target,
            localIp = socket.localIp,
            localSipPort = socket.localSipPort,
            callId = callId,
            fromTag = fromTag,
            toHeader = response.header("To") ?: "<sip:$target@${account.server}>",
            inviteCseq = inviteCseq,
            requestUri = AssistantSipRequestBuilder.inviteUri(account, target),
            routeSet = emptyList()
        )
        val ackBranch = if (success) {
            branch()
        } else {
            activeInviteBranch.ifBlank { branch() }
        }
        socket.send(AssistantSipRequestBuilder.ack(current, ackBranch))
    }

    private fun dialogFrom(response: AssistantSipMessage): AssistantSipDialog =
        AssistantSipDialog(
            account = account,
            target = target,
            localIp = socket.localIp,
            localSipPort = socket.localSipPort,
            callId = callId,
            fromTag = fromTag,
            toHeader = response.header("To") ?: "<sip:$target@${account.server}>",
            inviteCseq = inviteCseq,
            requestUri = AssistantSipRequestBuilder.dialogRequestUri(response)
                ?: AssistantSipRequestBuilder.inviteUri(account, target),
            routeSet = AssistantSipRequestBuilder.dialogRouteSet(response)
        )

    private fun branch(): String = "z9hG4bK-${UUID.randomUUID().toString().replace("-", "")}"
    private fun token(prefix: String): String =
        "$prefix-${UUID.randomUUID().toString().replace("-", "")}"

    private companion object {
        const val Tag = "AssistantSipCall"
    }
}
