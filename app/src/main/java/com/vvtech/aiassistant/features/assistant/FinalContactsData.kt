package com.vvtech.aiassistant.features.assistant

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
            val normalizedName = contact.name.trim().ifBlank { "未知联系人" }
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
                hint = "本机通讯录联系人"
            )
        }
        .toList()
}
