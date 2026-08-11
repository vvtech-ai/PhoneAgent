package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.features.assistant_agent.AgentStreamInteractiveResponsePolicy
import org.junit.Assert.assertEquals
import org.junit.Test

class AgentOptionsVoiceSummaryTest {

    @Test
    fun restaurantOptionsUseChineseOrdinalWithPlaceUnit() {
        val summary = AgentStreamInteractiveResponsePolicy.optionsVoiceSummary(
            OptionsPayload(
                title = "搜到的结果",
                items = listOf(
                    OptionItem(id = "r1", label = "琶洲万胜围店", address = "广州海珠区"),
                    OptionItem(id = "r2", label = "天河领展广场店", address = "广州天河区"),
                    OptionItem(id = "r3", label = "吉满家商业广场店", distanceMeters = 1200)
                )
            )
        )

        assertEquals("第一家，琶洲万胜围店。第二家，天河领展广场店。第三家，吉满家商业广场店", summary)
    }

    @Test
    fun genericOptionsKeepGenericUnit() {
        val summary = AgentStreamInteractiveResponsePolicy.optionsVoiceSummary(
            OptionsPayload(
                title = "请选择",
                items = listOf(
                    OptionItem(id = "o1", label = "普通选项A"),
                    OptionItem(id = "o2", label = "普通选项B")
                )
            )
        )

        assertEquals("第一个，普通选项A。第二个，普通选项B", summary)
    }

    @Test
    fun contactOptionsSpeakOrdinalAndPhoneDiscriminator() {
        val summary = AgentStreamInteractiveResponsePolicy.optionsVoiceSummary(
            OptionsPayload(
                title = "选择联系人",
                items = listOf(
                    OptionItem(
                        id = "contact_1",
                        label = "张三",
                        tags = listOf("contact"),
                        phone = "尾号 1234"
                    ),
                    OptionItem(
                        id = "contact_2",
                        label = "张三",
                        tags = listOf("contact"),
                        phone = "13900005678"
                    )
                )
            )
        )

        assertEquals("第一个，张三，尾号 1234。第二个，张三，13900005678", summary)
    }

    @Test
    fun voiceSummaryDoesNotDropOptionsAfterFifth() {
        val summary = AgentStreamInteractiveResponsePolicy.optionsVoiceSummary(
            OptionsPayload(
                title = "请选择",
                items = (1..6).map { index -> OptionItem(id = "o$index", label = "选项$index") }
            )
        )

        assertEquals(
            "第一个，选项1。第二个，选项2。第三个，选项3。第四个，选项4。第五个，选项5。第六个，选项6",
            summary
        )
    }
}
