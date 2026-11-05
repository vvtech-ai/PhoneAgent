package com.vvtech.phone_agent

import android.app.Activity
import com.alipay.sdk.app.PayTask
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Android-only launch. Native outcome never claims server payment/fulfillment. */
class CommercePaymentChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/commerce_payment")
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var closed = false
    init { channel.setMethodCallHandler(::handle) }
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" -> result.success(!closed)
            "products", "restore" -> result.success(emptyList<Any>())
            "acknowledge" -> result.success(null)
            "launch" -> launch(call, result)
            else -> result.notImplemented()
        }
    }
    private fun launch(call: MethodCall, result: MethodChannel.Result) {
        val parameters = call.argument<Map<String, String>>("parameters")
        val signedOrder = parameters?.get("signedOrder")
        if (closed || pending != null || call.argument<String>("channel") != "ALIPAY" ||
            signedOrder.isNullOrBlank()) {
            result.error("CHANNEL_UNAVAILABLE", "支付暂不可用", null)
            return
        }
        val environment = try {
            AlipayPaymentEnvironment.select(parameters["environment"])
        } catch (_: IllegalArgumentException) {
            result.error("CHANNEL_UNAVAILABLE", "支付暂不可用", null)
            return
        }
        pending = result
        worker.execute {
            try {
                val sdkResult = AlipayPaymentEnvironment.launch(environment) {
                    PayTask(activity).payV2(signedOrder, true)
                }
                val safeResult = AlipayResultStatus.project(sdkResult)
                activity.runOnUiThread { finish(result, false, safeResult) }
            } catch (_: Exception) {
                activity.runOnUiThread { finish(result, true) }
            }
        }
    }
    private fun finish(result: MethodChannel.Result, failed: Boolean,
                       safeResult: Map<String, String> = emptyMap()) {
        if (pending !== result) return
        pending = null
        if (failed) result.error("PAYMENT_UNKNOWN", "请查询原订单确认支付结果", null)
        else result.success(safeResult)
    }
    fun close() {
        closed = true
        // Closing the engine cannot cancel an external payment or free its order.
        pending?.let { result -> finish(result, true) }
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
