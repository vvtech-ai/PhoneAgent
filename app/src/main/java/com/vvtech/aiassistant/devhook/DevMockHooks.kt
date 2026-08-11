package com.vvtech.aiassistant.devhook

import com.vvtech.aiassistant.contacts.DeviceContactsLookupItem
import com.vvtech.aiassistant.contacts.PhoneLookupResult
import com.vvtech.aiassistant.features.assistant.DevicePhoneContact

/**
 * 业务代码访问"本地调试桩"的统一入口。每个方法对应一个独立 hook，
 * 任意 hook 缺失时静默返回 null/false，业务代码无需感知。
 *
 * 真正的实现位于同包 [DevMockHooksImpl]，该文件不入仓；编译期没有该类
 * 时反射会拿不到 method，所有 hook 自然 disable。
 */
internal object DevMockHooks {

    fun mockFindContactByPhone(query: String): PhoneLookupResult? =
        invokeNullable("mockFindContactByPhone", arrayOf(String::class.java), arrayOf<Any?>(query))

    fun mockLoadAllContacts(): List<DevicePhoneContact>? =
        invokeNullable("mockLoadAllContacts", emptyArray(), emptyArray())

    fun mockLookupCandidatesByName(name: String): DeviceContactsLookupItem? =
        invokeNullable("mockLookupCandidatesByName", arrayOf(String::class.java), arrayOf<Any?>(name))

    fun bypassContactsPermission(): Boolean =
        invokeNullable<Boolean>("bypassContactsPermission", emptyArray(), emptyArray()) ?: false

    fun mockResultPageFallbackCallId(): String? =
        invokeNullable("mockResultPageFallbackCallId", emptyArray(), emptyArray())

    private val implClass: Class<*>? by lazy {
        runCatching { Class.forName("com.vvtech.aiassistant.devhook.DevMockHooksImpl") }.getOrNull()
    }

    @Suppress("UNCHECKED_CAST")
    private fun <T> invokeNullable(
        method: String,
        argTypes: Array<Class<*>>,
        args: Array<Any?>
    ): T? {
        val cls = implClass ?: return null
        val m = runCatching { cls.getMethod(method, *argTypes) }.getOrNull() ?: return null
        return runCatching { m.invoke(null, *args) as? T }.getOrNull()
    }
}
