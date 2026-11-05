package com.vvtech.phone_agent

import com.alipay.sdk.app.EnvUtils

/** Only a server payment material can choose the SDK environment. */
internal object AlipayPaymentEnvironment {
    fun select(value: String?): EnvUtils.EnvEnum = when (value) {
        "SANDBOX" -> EnvUtils.EnvEnum.SANDBOX
        "PRODUCTION" -> EnvUtils.EnvEnum.ONLINE
        else -> throw IllegalArgumentException("Missing or invalid payment environment")
    }

    fun <T> launch(environment: EnvUtils.EnvEnum, payment: () -> T): T {
        EnvUtils.setEnv(environment)
        return payment()
    }
}
