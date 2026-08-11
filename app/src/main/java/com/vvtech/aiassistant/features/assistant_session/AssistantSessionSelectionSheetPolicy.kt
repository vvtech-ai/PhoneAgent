package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.features.assistant.SelectionSheetData
import com.vvtech.aiassistant.features.assistant.SelectionSheetOption
import com.vvtech.aiassistant.features.assistant.VoiceLanguage

internal object AssistantSessionSelectionSheetPolicy {
    fun signature(sheet: SelectionSheetData): String {
        return sheet.options.joinToString(separator = "|") { option ->
            "${option.itemId}#${option.actionId}"
        }
    }

    fun shouldSuppressSelectionSheet(
        taskId: String,
        sheet: SelectionSheetData,
        consumedTaskId: String?,
        consumedSignature: String?
    ): Boolean {
        val normalizedTaskId = taskId.trim()
        if (normalizedTaskId.isBlank()) {
            return false
        }
        return normalizedTaskId == consumedTaskId && signature(sheet) == consumedSignature
    }

    fun shouldClearConsumedSelectionSheet(
        taskId: String,
        consumedTaskId: String?
    ): Boolean {
        val normalizedTaskId = taskId.trim()
        return normalizedTaskId.isBlank() ||
            (consumedTaskId != null && consumedTaskId != normalizedTaskId)
    }

    fun buildSelectionMeta(tags: List<String>, address: String?): String {
        val normalizedTags = tags.map { it.trim() }.filter { it.isNotEmpty() }
        val normalizedAddress = address?.trim().orEmpty()
        val firstLine = normalizedTags.joinToString(" · ")
        return when {
            firstLine.isNotEmpty() && normalizedAddress.isNotEmpty() ->
                "$firstLine\n$normalizedAddress"
            firstLine.isNotEmpty() -> firstLine
            normalizedAddress.isNotEmpty() -> normalizedAddress
            else -> ""
        }
    }

    fun resolveVoiceSelectionOption(text: String, sheet: SelectionSheetData): SelectionSheetOption? {
        val normalized = normalizeVoiceSelectionText(text)
        if (normalized.isBlank()) return null
        if (normalized.length >= 2) {
            sheet.options.firstOrNull { option ->
                val title = normalizeVoiceSelectionText(option.title)
                title.isNotBlank() && (normalized.contains(title) || title.contains(normalized))
            }?.let { return it }
        }
        val index = parseVoiceSelectionIndex(normalized, sheet.options.size) ?: return null
        return sheet.options.getOrNull(index - 1)
    }

    fun parseVoiceSelectionIndex(text: String, optionCount: Int): Int? {
        if (optionCount <= 0) return null
        Regex("""(?:第|选|选择|要|就|订|定|option|number|no)?([1-9]\d?)(?:st|nd|rd|th|个|家|项|号|位|番|番目)?""")
            .find(text)
            ?.groupValues
            ?.getOrNull(1)
            ?.toIntOrNull()
            ?.takeIf { it in 1..optionCount }
            ?.let { return it }

        val exactEnglishCardinals = listOf(
            1 to setOf("one"),
            2 to setOf("two"),
            3 to setOf("three"),
            4 to setOf("four"),
            5 to setOf("five"),
            6 to setOf("six"),
            7 to setOf("seven"),
            8 to setOf("eight"),
            9 to setOf("nine"),
            10 to setOf("ten")
        )
        exactEnglishCardinals.firstOrNull { (index, words) ->
            index <= optionCount && text in words
        }?.let { return it.first }

        val ordinalWords = listOf(
            1 to listOf(
                "一", "幺",
                "first", "firstone", "thefirst", "thefirstone", "optionone", "numberone", "chooseone", "pickone", "selectone",
                "一番", "一番目", "一つ目", "ひとつ目", "ひとつめ", "最初", "第一", "いちばん"
            ),
            2 to listOf(
                "二", "两",
                "second", "secondone", "thesecond", "thesecondone", "optiontwo", "numbertwo", "choosetwo", "picktwo", "selecttwo",
                "二番", "二番目", "二つ目", "ふたつ目", "ふたつめ", "第二", "にばん"
            ),
            3 to listOf(
                "三",
                "third", "thirdone", "thethird", "thethirdone", "optionthree", "numberthree", "choosethree", "pickthree", "selectthree",
                "三番", "三番目", "三つ目", "みっつ目", "みっつめ", "第三", "さんばん"
            ),
            4 to listOf("四", "fourth", "fourthone", "optionfour", "numberfour", "四番", "四番目", "四つ目", "第四"),
            5 to listOf("五", "fifth", "fifthone", "optionfive", "numberfive", "五番", "五番目", "五つ目", "第五"),
            6 to listOf("六", "sixth", "sixthone", "optionsix", "numbersix", "六番", "六番目", "六つ目", "第六"),
            7 to listOf("七", "seventh", "seventhone", "optionseven", "numberseven", "七番", "七番目", "七つ目", "第七"),
            8 to listOf("八", "eighth", "eighthone", "optioneight", "numbereight", "八番", "八番目", "八つ目", "第八"),
            9 to listOf("九", "ninth", "ninthone", "optionnine", "numbernine", "九番", "九番目", "九つ目", "第九"),
            10 to listOf("十", "tenth", "tenthone", "optionten", "numberten", "十番", "十番目", "十個目", "第十")
        )
        ordinalWords.forEach { (index, words) ->
            if (index > optionCount) return@forEach
            val tokens = words.flatMap { word ->
                listOf(
                    "第${word}个", "第${word}家", "第${word}项", "第${word}号", "第${word}位",
                    "${word}号", "选${word}", "选择${word}", "要${word}", "就${word}", "订${word}", "定${word}"
                )
            } + words
            if (tokens.any { token -> text == token || text.contains(token) }) return index
        }
        return null
    }

    fun resolveSelectionSheetFromSession(
        session: AssistantSessionResponse,
        language: VoiceLanguage = VoiceLanguage.Chinese
    ): SelectionSheetData? {
        val boundaryIndex = session.messages.indexOfLast {
            it.callConfirmCard != null || it.resultSummary != null
        }
        val trailingMessages = session.messages.drop(boundaryIndex + 1)
        return when (session.session.sceneType) {
            "FOOD_ORDERING" -> {
                val options = trailingMessages.mapNotNull { message ->
                    val card = message.restaurantCard ?: return@mapNotNull null
                    val primary = card.actions.firstOrNull { it.kind == "primary" }
                        ?: card.actions.firstOrNull()
                        ?: return@mapNotNull null
                    SelectionSheetOption(
                        itemId = card.itemId,
                        title = card.name,
                        phone = card.phone,
                        meta = buildSelectionMeta(
                            tags = listOfNotNull(
                                card.cuisine?.takeIf { it.isNotBlank() },
                                card.area?.takeIf { it.isNotBlank() }
                            ),
                            address = card.address
                        ),
                        actionId = primary.actionId,
                        actionLabel = primary.label
                    )
                }
                if (options.isEmpty()) null else SelectionSheetData(
                    title = localizedSelectionTitle("FOOD_ORDERING", language),
                    subtitle = localizedSelectionSubtitle("FOOD_ORDERING", language),
                    targetLabel = localizedSelectionTargetLabel("FOOD_ORDERING", language),
                    options = options
                )
            }

            "HOTEL_BOOKING" -> {
                val options = trailingMessages.mapNotNull { message ->
                    val card = message.hotelCard ?: return@mapNotNull null
                    val primary = card.actions.firstOrNull { it.kind == "primary" }
                        ?: card.actions.firstOrNull()
                        ?: return@mapNotNull null
                    SelectionSheetOption(
                        itemId = card.itemId,
                        title = card.name,
                        phone = "",
                        meta = buildSelectionMeta(
                            tags = listOfNotNull(
                                card.city.takeIf { it.isNotBlank() },
                                card.roomType.takeIf { it.isNotBlank() },
                                card.priceHint.takeIf { it.isNotBlank() }
                            ),
                            address = card.address
                        ),
                        actionId = primary.actionId,
                        actionLabel = primary.label
                    )
                }
                if (options.isEmpty()) null else SelectionSheetData(
                    title = localizedSelectionTitle("HOTEL_BOOKING", language),
                    subtitle = localizedSelectionSubtitle("HOTEL_BOOKING", language),
                    targetLabel = localizedSelectionTargetLabel("HOTEL_BOOKING", language),
                    options = options
                )
            }

            else -> null
        }
    }

    private fun normalizeVoiceSelectionText(text: String): String {
        return text.trim().lowercase()
            .replace(Regex("""[\s，。,.！？!?:：、；;（）()\[\]【】"'`“”‘’]"""), "")
    }

    private fun localizedSelectionTitle(sceneType: String, language: VoiceLanguage): String {
        return when (language) {
            VoiceLanguage.English -> when (sceneType) {
                "HOTEL_BOOKING" -> "Choose a hotel"
                else -> "Choose a restaurant"
            }
            VoiceLanguage.Japanese -> when (sceneType) {
                "HOTEL_BOOKING" -> "ホテルを選択"
                else -> "レストランを選択"
            }
            VoiceLanguage.Chinese -> when (sceneType) {
                "HOTEL_BOOKING" -> "请选择酒店"
                else -> "请选择餐厅"
            }
        }
    }

    private fun localizedSelectionSubtitle(sceneType: String, language: VoiceLanguage): String {
        return when (language) {
            VoiceLanguage.English -> when (sceneType) {
                "HOTEL_BOOKING" -> "I found a few hotel options based on the current details. Choose one to continue."
                else -> "I found a few restaurant options based on the current details. Choose one to continue."
            }
            VoiceLanguage.Japanese -> when (sceneType) {
                "HOTEL_BOOKING" -> "現在の条件でホテル候補をいくつか整理しました。1つ選んで続けてください。"
                else -> "現在の条件で候補をいくつか見つけました。1つ選んで続けてください。"
            }
            VoiceLanguage.Chinese -> when (sceneType) {
                "HOTEL_BOOKING" -> "我先按当前条件整理了几家，你先选一个继续。"
                else -> "我先按当前条件找了几家，你先选一个继续。"
            }
        }
    }

    private fun localizedSelectionTargetLabel(sceneType: String, language: VoiceLanguage): String {
        return when (language) {
            VoiceLanguage.English -> when (sceneType) {
                "HOTEL_BOOKING" -> "hotel"
                else -> "restaurant"
            }
            VoiceLanguage.Japanese -> when (sceneType) {
                "HOTEL_BOOKING" -> "ホテル"
                else -> "レストラン"
            }
            VoiceLanguage.Chinese -> when (sceneType) {
                "HOTEL_BOOKING" -> "酒店"
                else -> "餐厅"
            }
        }
    }
}
