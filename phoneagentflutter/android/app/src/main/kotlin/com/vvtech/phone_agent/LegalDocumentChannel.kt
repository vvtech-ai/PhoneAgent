package com.vvtech.phone_agent

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Only fixed public documents. No account or backend parameters. */
class LegalDocumentChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/legal_documents")
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "openPublishedAgreement") {
                val uri = Uri.parse(call.arguments as? String ?: "")
                if (uri.scheme != "https" || uri.host.isNullOrBlank() || uri.userInfo != null) {
                    result.error("INVALID_DOCUMENT", "协议无效", null)
                } else {
                    try {
                        activity.startActivity(Intent(Intent.ACTION_VIEW, uri))
                        result.success(null)
                    } catch (_: Exception) { result.error("UNAVAILABLE", "暂时无法打开协议", null) }
                }
            } else if (call.method != "open") {
                result.notImplemented()
            } else {
                val paths = mapOf(
                    "userAgreement" to "Phone_Agent_user_agreement.html",
                    "privacyPolicy" to "Phone_Agent_privacy_policy.html",
                    "personalInformation" to "Phone_Agent_personal_Info.html"
                )
                val path = paths[call.arguments as? String]
                if (path == null) {
                    result.error("INVALID_DOCUMENT", "协议无效", null)
                } else {
                    try {
                        activity.startActivity(Intent(Intent.ACTION_VIEW,
                            Uri.parse("https://www.chaken.ai/agreements/$path")))
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("UNAVAILABLE", "暂时无法打开协议", null)
                    }
                }
            }
        }
    }
    fun close() { channel.setMethodCallHandler(null) }
}
