package com.vvtech.aiassistant.features.assistant

import org.junit.Assert.assertEquals
import org.junit.Test

class FinalContactsDataTest {

    @Test
    fun mapsDeviceContactsToCurrentCardShapeAndRemovesDuplicates() {
        val records = mapDeviceContactsToFinalRecords(
            listOf(
                DevicePhoneContact(name = "张三", phone = "13800138000"),
                DevicePhoneContact(name = "张三", phone = "13800138000"),
                DevicePhoneContact(name = "", phone = "02188886666"),
                DevicePhoneContact(name = "李四", phone = "")
            )
        )

        assertEquals(2, records.size)
        assertEquals("张三", records[0].name)
        assertEquals("13800138000", records[0].phone)
        assertEquals("本机通讯录联系人", records[0].hint)
        assertEquals("未知联系人", records[1].name)
        assertEquals("02188886666", records[1].phone)
    }

    @Test
    fun keepsMainlandNumberNationalAndForeignNumberInternational() {
        val records = mapDeviceContactsToFinalRecords(
            listOf(
                DevicePhoneContact(name = "张三", phone = "13800138000"),
                DevicePhoneContact(name = "田中", phone = "+819012345678"),
                DevicePhoneContact(
                    name = "前台",
                    phone = "01088886666",
                    systemDialPhone = "010-8888-6666"
                )
            )
        )

        assertEquals("13800138000", records.first { it.name == "张三" }.phone)
        assertEquals("+819012345678", records.first { it.name == "田中" }.phone)
        assertEquals(
            "010-8888-6666",
            records.first { it.name == "前台" }.systemDialPhone
        )
    }
}
