package com.vvtech.phone_agent.diagnostics

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class NativeCrashChannel(
    private val app: NativeCrashApplication,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "phone_agent/native_crash")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init { channel.setMethodCallHandler(::handle) }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in setOf("bind", "read", "acknowledge")) {
            result.notImplemented()
            return
        }
        val args = call.arguments as? Map<*, *>
        val scope = args?.get("scope") as? String
        if (scope == null && call.method == "bind" && args?.containsKey("scope") == true) {
            app.crashRecorder.bind(null)
            result.success(null)
            return
        }
        if (scope == null || !CrashSummary.SCOPE.matches(scope)) {
            result.error("invalid_scope", "Invalid diagnostics scope", null)
            return
        }
        // Binding is ordered on the platform thread, not behind disk work.
        if (call.method == "bind") {
            app.crashRecorder.bind(scope)
            result.success(null)
            return
        }
        val ids = (args["ids"] as? List<*>)?.mapNotNull { it as? String }
        if (call.method == "acknowledge" &&
            (ids == null || ids.size != (args["ids"] as List<*>).size ||
                ids.size > 32 || ids.any { !CrashSummary.ID.matches(it) })) {
            result.error("invalid_ids", "Invalid diagnostics identifiers", null)
            return
        }
        worker.execute {
            try {
                val value = if (call.method == "read") {
                    (app.crashStore.read(scope) + app.crashStore.readStartup())
                        .sortedBy { it.time }.map { it.payload(scope) }
                } else {
                    app.crashStore.acknowledge(scope, ids!!)
                    app.crashStore.acknowledgeStartup(ids)
                    null
                }
                main.post { result.success(value) }
            } catch (_: Throwable) {
                main.post { result.error("diagnostics_unavailable", "Diagnostics unavailable", null) }
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        app.crashRecorder.bind(null)
        worker.shutdown()
    }
}
