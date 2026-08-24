package com.vvtech.aiassistant.features.assistant_pure_voice.ocr

internal object PureVoiceOcrFieldExtractor {
    private data class FieldDefinition(
        val key: String,
        val label: String,
        val priority: Int,
        val aliases: Set<String>
    )

    private data class Candidate(
        val field: PureVoiceOcrField,
        val priority: Int,
        val ordinal: Int
    )

    private val definitions = listOf(
        FieldDefinition(
            key = "phone",
            label = "Phone",
            priority = 0,
            aliases = setOf("电话", "手机", "联系电话", "tel", "phone", "mobile")
        ),
        FieldDefinition(
            key = "name",
            label = "Name",
            priority = 1,
            aliases = setOf("姓名", "联系人", "name", "contact")
        ),
        FieldDefinition(
            key = "organization",
            label = "Organization",
            priority = 2,
            aliases = setOf(
                "机构",
                "公司",
                "单位",
                "组织",
                "餐厅",
                "酒店",
                "门店",
                "organization",
                "company"
            )
        ),
        FieldDefinition(
            key = "time",
            label = "Time",
            priority = 3,
            aliases = setOf("时间", "日期", "date", "time")
        ),
        FieldDefinition(
            key = "place",
            label = "Address",
            priority = 4,
            aliases = setOf("地址", "地点", "会场", "address", "location")
        )
    )

    private val labeledValuePattern = Regex("""^\s*([^:：]{1,16})\s*[:：]\s*(.+?)\s*$""")
    private val phonePattern = Regex(
        """(?<!\d)(?:(?:\+?86[-\s]?)?1[3-9]\d{9}|(?:0\d{2,3}[-\s]?)?\d{7,8})(?!\d)"""
    )
    private val datePattern = Regex(
        """(?<!\d)(?:20\d{2}[-/.年]\d{1,2}[-/.月]\d{1,2}日?|\d{1,2}月\d{1,2}日)(?!\d)"""
    )
    private val timePattern = Regex("""(?<!\d)(?:[01]?\d|2[0-3])[:：][0-5]\d(?!\d)""")
    private val organizationSuffixPattern = Regex(
        """.*(?:公司|集团|中心|医院|学校|大学|餐厅|酒店|门店|工作室|委员会|研究院)$"""
    )

    fun extract(segments: List<String>): List<PureVoiceOcrField> {
        val lines = segments
            .flatMap { it.lineSequence().toList() }
            .map(String::trim)
            .filter(String::isNotBlank)
        val candidates = mutableListOf<Candidate>()
        var ordinal = 0

        lines.forEach { line ->
            val labeled = labeledValuePattern.matchEntire(line)
            if (labeled != null) {
                val sourceLabel = labeled.groupValues[1].trim()
                val value = labeled.groupValues[2].trim()
                val definition = definitionFor(sourceLabel)
                val field = if (definition != null) {
                    PureVoiceOcrField(definition.key, definition.label, value)
                } else {
                    PureVoiceOcrField(
                        key = "other_${normalizeLabel(sourceLabel)}",
                        label = "Other",
                        value = value
                    )
                }
                candidates += Candidate(field, definition?.priority ?: 5, ordinal++)
            }

            phonePattern.findAll(line).forEach { match ->
                candidates += Candidate(
                    PureVoiceOcrField("phone", "Phone", match.value.trim()),
                    priority = 0,
                    ordinal = ordinal++
                )
            }

            val temporalValue = listOfNotNull(
                datePattern.find(line)?.value,
                timePattern.find(line)?.value
            ).joinToString(" ").trim()
            if (temporalValue.isNotBlank()) {
                candidates += Candidate(
                    PureVoiceOcrField("time", "Time", temporalValue),
                    priority = 3,
                    ordinal = ordinal++
                )
            }

            if (line.length <= 40 && organizationSuffixPattern.matches(line)) {
                candidates += Candidate(
                    PureVoiceOcrField("organization", "Organization", line),
                    priority = 2,
                    ordinal = ordinal++
                )
            }
        }

        val seen = mutableSetOf<String>()
        return candidates
            .sortedWith(compareBy<Candidate> { it.priority }.thenBy { it.ordinal })
            .map { it.field }
            .filter { field ->
                field.value.isNotBlank() &&
                    seen.add("${field.key}:${normalizeValue(field.value)}")
            }
    }

    private fun definitionFor(sourceLabel: String): FieldDefinition? {
        val normalized = normalizeLabel(sourceLabel)
        return definitions.firstOrNull { definition ->
            definition.aliases.any { normalizeLabel(it) == normalized }
        }
    }

    private fun normalizeLabel(value: String): String {
        return value.lowercase().replace(Regex("""[\s_\-]"""), "")
    }

    private fun normalizeValue(value: String): String {
        return value.lowercase().replace(Regex("""\s"""), "")
    }
}
