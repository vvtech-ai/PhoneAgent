package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.DocumentParseResult
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionCandidateUi
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

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
            append(currentAppText("已选：", "Selected: "))
            append(selectedItem?.label ?: optionId)
            selectedItem?.detail?.takeIf { it.isNotBlank() }?.let {
                append(currentAppText("（", " (")).append(it).append(currentAppText("）", ")"))
            }
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
                        "yes" -> currentAppText("是", "Yes")
                        "no" -> currentAppText("否", "No")
                        else -> rendered
                    }
                } else {
                    rendered
                }
                append("• ").append(question.prompt).append(currentAppText("：", ": ")).append(readable).append('\n')
            }
        }.trimEnd('\n').ifBlank { currentAppText("（已提交）", "(Submitted)") }
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
            "OK" -> currentAppText("已授权：$permissionKey", "Authorized: $permissionKey")
            "SETTINGS_REQUIRED" -> currentAppText(
                "该权限需要到系统设置中开启：$permissionKey",
                "Enable this permission in system settings: $permissionKey"
            )
            else -> currentAppText("未授权：$permissionKey", "Not authorized: $permissionKey")
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
            "OK" -> currentAppText(
                "已上传并解析：${result.fileName ?: "文档"}",
                "Uploaded and parsed: ${result.fileName ?: "Document"}"
            )
            "USER_CANCELLED" -> currentAppText("已取消文件选择", "File selection canceled")
            "UNSUPPORTED_TYPE" -> currentAppText("文件类型暂不支持", "File type is not supported")
            "FILE_TOO_LARGE" -> currentAppText("文件过大，无法解析", "File is too large to parse")
            else -> currentAppText("文件解析失败", "File parsing failed")
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
            found && displayName.isNotBlank() -> currentAppText("通讯录已找到：$displayName", "Contact found: $displayName")
            reason == "PERMISSION_DENIED" -> currentAppText("未授权读取通讯录", "Contacts permission denied")
            else -> currentAppText("通讯录中未找到该号码", "Number not found in contacts")
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
            echoText = currentAppText("用户取消了联系人选择", "User canceled contact selection")
        )
    }

    fun deviceContactVoiceSelection(
        selection: DeviceContactSelectionUiState,
        rawText: String
    ): AgentDeviceContactVoiceSelectionResult {
        val text = rawText.trim()
        if (text.isBlank()) {
            return AgentDeviceContactVoiceSelectionResult.Invalid(
                statusText = currentAppText(
                    "没听清你选哪个联系人，请说第一个、第二个，或说取消",
                    "I did not catch which contact you chose. Say first, second, or cancel"
                )
            )
        }
        if (isCancelContactSelection(text)) {
            return AgentDeviceContactVoiceSelectionResult.Cancel
        }
        val index = parseContactSelectionIndex(text)
            ?: return AgentDeviceContactVoiceSelectionResult.Invalid(
                statusText = currentAppText(
                    "没听清你选哪个联系人，请说第一个、第二个，或说取消",
                    "I did not catch which contact you chose. Say first, second, or cancel"
                )
            )
        val missing = selection.groups.firstOrNull { group -> index !in group.candidates.indices }
        if (missing != null) {
            return AgentDeviceContactVoiceSelectionResult.OutOfRange(
                statusText = currentAppText(
                    "${missing.name}没有第${index + 1}个候选，请重新选择",
                    "${missing.name} does not have option ${index + 1}. Please choose again"
                )
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
        val echo = selectedByName.entries.joinToString(currentAppText("、", ", ")) { (name, candidate) ->
            "$name → ${candidate.displayName} ${candidate.phoneNumber}"
        }
        return if (echo.isNotBlank()) currentAppText("已选定：$echo", "Selected: $echo") else null
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
            is List<*> -> raw.filterNotNull().joinToString(currentAppText("、", ", ")).ifBlank { "—" }
            else -> raw.toString()
        }
    }

}
