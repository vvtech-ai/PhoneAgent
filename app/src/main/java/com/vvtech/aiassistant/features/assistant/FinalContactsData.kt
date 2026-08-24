package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal data class DevicePhoneContact(
    val name: String,
    val phone: String,
    val systemDialPhone: String = phone
)

internal fun mapDeviceContactsToFinalRecords(
    contacts: List<DevicePhoneContact>
): List<FinalContactRecord> {
    return contacts
        .asSequence()
        .mapNotNull { contact ->
            val rawName = contact.name.trim()
            val normalizedName = if (rawName.isBlank() || rawName == "未知联系人") {
                currentAppText("未知联系人", "Unknown contact")
            } else {
                rawName
            }
            val normalizedPhone = contact.phone.trim()
            val normalizedSystemDialPhone = contact.systemDialPhone.trim()
                .ifBlank { normalizedPhone }
            if (normalizedPhone.isBlank()) {
                null
            } else {
                DevicePhoneContact(
                    name = normalizedName,
                    phone = normalizedPhone,
                    systemDialPhone = normalizedSystemDialPhone
                )
            }
        }
        .distinctBy { "${it.name}\u0000${it.phone}" }
        .sortedWith(compareBy<DevicePhoneContact>({ it.name.lowercase() }, { it.phone }))
        .map { contact ->
            FinalContactRecord(
                name = contact.name,
                phone = contact.phone,
                systemDialPhone = contact.systemDialPhone,
                hint = currentAppText("本机通讯录联系人", "Device contact")
            )
        }
        .toList()
}

internal fun localizedFinalContactHint(hint: String): String =
    when (hint.trim()) {
        "本机通讯录联系人",
        "Device contact" -> currentAppText("本机通讯录联系人", "Device contact")
        else -> hint
    }
