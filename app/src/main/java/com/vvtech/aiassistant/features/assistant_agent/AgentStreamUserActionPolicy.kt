package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.DocumentParseResult
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionCandidateUi
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState

internal data class AgentStreamActionDraft(
    val actionId: String,
    val actionPayload: Map<String, Any>,
    val echoText: String,
    val normalizedStatus: String? = null
)

internal data class AgentDeviceContactSelectionSubmitResult(
    val results: List<Map<String, Any?>>,
    val echoText: String?
)

internal sealed class AgentDeviceContactVoiceSelectionResult {
    object Cancel : AgentDeviceContactVoiceSelectionResult()

    data class Invalid(val statusText: String) : AgentDeviceContactVoiceSelectionResult()

    data class OutOfRange(val statusText: String) : AgentDeviceContactVoiceSelectionResult()

    data class Selected(
        val selectedByName: Map<String, DeviceContactSelectionCandidateUi>
    ) : AgentDeviceContactVoiceSelectionResult()
}

internal object AgentStreamUserActionPolicy {

    fun optionSelection(options: OptionsPayload?, optionId: String): AgentStreamActionDraft {
        val selectedItem = options?.items?.firstOrNull { it.id == optionId }
        val payload = buildMap<String, Any> {
            put("optionId", optionId)
            selectedItem?.label?.takeIf { it.isNotBlank() }?.let { put("label", it) }
            selectedItem?.detail?.takeIf { it.isNotBlank() }?.let { put("detail", it) }
            selectedItem?.phone?.takeIf { it.isNotBlank() }?.let { put("phone", it) }
        }
        val echoText = buildString {
            options?.title?.takeIf { it.isNotBlank() }?.let { append(it).append('\n') }
            append("已选：")
            append(selectedItem?.label ?: optionId)
            selectedItem?.detail?.takeIf { it.isNotBlank() }?.let { append("（").append(it).append("）") }
        }
        return AgentStreamActionDraft(
            actionId = "select_option",
            actionPayload = payload,
            echoText = echoText
        )
    }

    fun answerSubmit(
        questions: AskQuestionsPayload?,
        answers: Map<String, Any>
    ): AgentStreamActionDraft {
        val echoText = buildString {
            questions?.title?.takeIf { it.isNotBlank() }?.let { append(it).append('\n') }
            questions?.items?.forEach { question ->
                val rendered = renderAnswerValue(answers[question.id])
                val readable = if (question.answerType.equals("confirm", ignoreCase = true)) {
                    when (rendered.lowercase()) {
                        "yes" -> "是"
                        "no" -> "否"
                        else -> rendered
                    }
                } else {
                    rendered
                }
                append("• ").append(question.prompt).append("：").append(readable).append('\n')
            }
        }.trimEnd('\n').ifBlank { "（已提交）" }
        return AgentStreamActionDraft(
            actionId = "answer_questions",
            actionPayload = mapOf("answers" to answers),
            echoText = echoText
        )
    }

    fun permissionResult(
        permissionKey: String,
        androidPermission: String?,
        status: String,
        granted: Boolean,
        message: String?
    ): AgentStreamActionDraft {
        val normalizedStatus = status.ifBlank { if (granted) "OK" else "DENIED" }
        val echoText = when (normalizedStatus) {
            "OK" -> "已授权：$permissionKey"
            "SETTINGS_REQUIRED" -> "该权限需要到系统设置中开启：$permissionKey"
            else -> "未授权：$permissionKey"
        }
        val payload = buildMap<String, Any> {
            put("permissionKey", permissionKey)
            androidPermission?.takeIf { it.isNotBlank() }?.let { put("androidPermission", it) }
            put("status", normalizedStatus)
            put("granted", granted)
            message?.takeIf { it.isNotBlank() }?.let { put("message", it) }
        }
        return AgentStreamActionDraft(
            actionId = "permission_result",
            actionPayload = payload,
            echoText = echoText,
            normalizedStatus = normalizedStatus
        )
    }

    fun documentSubmit(result: DocumentParseResult): AgentStreamActionDraft {
        val normalizedStatus = result.status.ifBlank { "PARSE_FAILED" }
        val echoText = when (normalizedStatus) {
            "OK" -> "已上传并解析：${result.fileName ?: "文档"}"
            "USER_CANCELLED" -> "已取消文件选择"
            "UNSUPPORTED_TYPE" -> "文件类型暂不支持"
            "FILE_TOO_LARGE" -> "文件过大，无法解析"
            else -> "文件解析失败"
        }
        return AgentStreamActionDraft(
            actionId = "submit_document",
            actionPayload = mapOf(
                "status" to normalizedStatus,
                "fileName" to result.fileName.orEmpty(),
                "mimeType" to result.mimeType.orEmpty(),
                "charCount" to result.charCount,
                "truncated" to result.truncated,
                "content" to result.content.orEmpty(),
                "message" to result.message.orEmpty()
            ),
            echoText = echoText,
            normalizedStatus = normalizedStatus
        )
    }

    fun lookupContactEcho(payload: Map<String, Any?>): String {
        val found = payload["found"] as? Boolean == true
        val displayName = payload["displayName"]?.toString().orEmpty()
        val reason = payload["reason"]?.toString().orEmpty()
        return when {
            found && displayName.isNotBlank() -> "通讯录已找到：$displayName"
            reason == "PERMISSION_DENIED" -> "未授权读取通讯录"
            else -> "通讯录中未找到该号码"
        }
    }

    fun deviceContactSelectionResults(
        selection: DeviceContactSelectionUiState,
        selectedByName: Map<String, DeviceContactSelectionCandidateUi>
    ): List<Map<String, Any?>> {
        return selection.groups.map { group ->
            val picked = selectedByName[group.name]
            if (picked != null) {
                mapOf(
                    "name" to group.name,
                    "requestedName" to group.name,
                    "status" to "RESOLVED",
                    "displayName" to picked.displayName,
                    "resolvedName" to picked.displayName,
                    "phoneNumber" to picked.phoneNumber,
                    "contactId" to picked.contactId,
                    "label" to picked.label,
                    "matchType" to "user_selected"
                )
            } else {
                mapOf(
                    "name" to group.name,
                    "requestedName" to group.name,
                    "status" to "MULTIPLE_CANDIDATES",
                    "candidates" to group.candidates.map { candidate ->
                        mapOf(
                            "displayName" to candidate.displayName,
                            "resolvedName" to candidate.displayName,
                            "phoneNumber" to candidate.phoneNumber,
                            "contactId" to candidate.contactId,
                            "label" to candidate.label
                        )
                    }
                )
            }
        }
    }

    fun deviceContactSelectionConfirm(
        selection: DeviceContactSelectionUiState,
        selectedByName: Map<String, DeviceContactSelectionCandidateUi>,
        echoSelection: Boolean
    ): AgentDeviceContactSelectionSubmitResult {
        return AgentDeviceContactSelectionSubmitResult(
            results = selection.preResolvedResults + deviceContactSelectionResults(selection, selectedByName),
            echoText = if (echoSelection) deviceContactSelectionConfirmEcho(selectedByName) else null
        )
    }

    fun deviceContactSelectionCancel(
        selection: DeviceContactSelectionUiState
    ): AgentDeviceContactSelectionSubmitResult {
        val cancelledResults = selection.groups.map { group ->
            mapOf(
                "name" to group.name,
                "status" to "CANCELLED"
            )
        }
        return AgentDeviceContactSelectionSubmitResult(
            results = selection.preResolvedResults + cancelledResults,
            echoText = "用户取消了联系人选择"
        )
    }

    fun deviceContactVoiceSelection(
        selection: DeviceContactSelectionUiState,
        rawText: String
    ): AgentDeviceContactVoiceSelectionResult {
        val text = rawText.trim()
        if (text.isBlank()) {
            return AgentDeviceContactVoiceSelectionResult.Invalid(
                statusText = "没听清你选哪个联系人，请说第一个、第二个，或说取消"
            )
        }
        if (isCancelContactSelection(text)) {
            return AgentDeviceContactVoiceSelectionResult.Cancel
        }
        val index = parseContactSelectionIndex(text)
            ?: return AgentDeviceContactVoiceSelectionResult.Invalid(
                statusText = "没听清你选哪个联系人，请说第一个、第二个，或说取消"
            )
        val missing = selection.groups.firstOrNull { group -> index !in group.candidates.indices }
        if (missing != null) {
            return AgentDeviceContactVoiceSelectionResult.OutOfRange(
                statusText = "${missing.name}没有第${index + 1}个候选，请重新选择"
            )
        }
        val selected = linkedMapOf<String, DeviceContactSelectionCandidateUi>()
        selection.groups.forEach { group ->
            selected[group.name] = group.candidates[index]
        }
        return AgentDeviceContactVoiceSelectionResult.Selected(selected)
    }

    private fun deviceContactSelectionConfirmEcho(
        selectedByName: Map<String, DeviceContactSelectionCandidateUi>
    ): String? {
        val echo = selectedByName.entries.joinToString("、") { (name, candidate) ->
            "$name → ${candidate.displayName} ${candidate.phoneNumber}"
        }
        return if (echo.isNotBlank()) "已选定：$echo" else null
    }

    private fun isCancelContactSelection(text: String): Boolean {
        val normalized = text.lowercase()
        return listOf("取消", "算了", "不用选", "不选", "cancel").any { normalized.contains(it) }
    }

    private fun parseContactSelectionIndex(text: String): Int? {
        val normalized = text
            .trim()
            .lowercase()
            .replace("第", "")
            .replace("个", "")
            .replace("位", "")
            .replace("项", "")
            .replace("号", "")
            .replace("候选", "")
            .replace("联系人", "")
            .replace("选择", "")
            .replace("选", "")
            .replace(" ", "")
        Regex("""\d+""").find(normalized)?.value?.toIntOrNull()?.let { number ->
            if (number > 0) return number - 1
        }
        val chineseNumbers = listOf(
            "一" to 0,
            "二" to 1,
            "两" to 1,
            "三" to 2,
            "四" to 3,
            "五" to 4,
            "六" to 5,
            "七" to 6,
            "八" to 7,
            "九" to 8,
            "十" to 9
        )
        return chineseNumbers.firstOrNull { normalized.contains(it.first) }?.second
    }

    private fun renderAnswerValue(raw: Any?): String {
        return when (raw) {
            null -> "—"
            is String -> raw.ifBlank { "—" }
            is List<*> -> raw.filterNotNull().joinToString("、").ifBlank { "—" }
            else -> raw.toString()
        }
    }

}
