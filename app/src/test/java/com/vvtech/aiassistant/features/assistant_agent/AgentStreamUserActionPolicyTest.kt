package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AskQuestionItem
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.DocumentParseResult
import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionCandidateUi
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionGroupUi
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamUserActionPolicyTest {

    @Test
    fun optionSelectionBuildsEchoAndPayload() {
        val draft = AgentStreamUserActionPolicy.optionSelection(
            options = OptionsPayload(
                title = "请选择餐厅",
                items = listOf(
                    OptionItem(id = "a", label = "北海渔村", detail = "包间优先", phone = "123")
                )
            ),
            optionId = "a"
        )

        assertEquals("select_option", draft.actionId)
        assertEquals("北海渔村", draft.actionPayload["label"])
        assertEquals("包间优先", draft.actionPayload["detail"])
        assertEquals("123", draft.actionPayload["phone"])
        assertEquals("请选择餐厅\n已选：北海渔村（包间优先）", draft.echoText)
    }

    @Test
    fun answerSubmitRendersConfirmAndListAnswers() {
        val draft = AgentStreamUserActionPolicy.answerSubmit(
            questions = AskQuestionsPayload(
                title = "补充信息",
                items = listOf(
                    AskQuestionItem(id = "confirm", prompt = "是否需要包间", answerType = "confirm"),
                    AskQuestionItem(id = "tags", prompt = "偏好", answerType = "multi")
                )
            ),
            answers = mapOf(
                "confirm" to "yes",
                "tags" to listOf("安静", "靠窗")
            )
        )

        assertEquals("answer_questions", draft.actionId)
        assertEquals(mapOf("confirm" to "yes", "tags" to listOf("安静", "靠窗")), draft.actionPayload["answers"])
        assertEquals("补充信息\n• 是否需要包间：是\n• 偏好：安静、靠窗", draft.echoText)
    }

    @Test
    fun permissionResultFallsBackStatusAndBuildsPayload() {
        val draft = AgentStreamUserActionPolicy.permissionResult(
            permissionKey = "contacts",
            androidPermission = "android.permission.READ_CONTACTS",
            status = "",
            granted = false,
            message = "denied by user"
        )

        assertEquals("permission_result", draft.actionId)
        assertEquals("DENIED", draft.normalizedStatus)
        assertEquals("contacts", draft.actionPayload["permissionKey"])
        assertEquals(false, draft.actionPayload["granted"])
        assertEquals("未授权：contacts", draft.echoText)
    }

    @Test
    fun documentSubmitFallsBackStatusAndBuildsPayload() {
        val draft = AgentStreamUserActionPolicy.documentSubmit(
            DocumentParseResult(
                status = "",
                fileName = "menu.txt",
                mimeType = "text/plain",
                charCount = 12,
                truncated = true,
                content = "hello",
                message = "parse failed"
            )
        )

        assertEquals("submit_document", draft.actionId)
        assertEquals("PARSE_FAILED", draft.normalizedStatus)
        assertEquals("PARSE_FAILED", draft.actionPayload["status"])
        assertEquals("menu.txt", draft.actionPayload["fileName"])
        assertEquals(12, draft.actionPayload["charCount"])
        assertEquals(true, draft.actionPayload["truncated"])
        assertEquals("文件解析失败", draft.echoText)
    }

    @Test
    fun deviceContactSelectionBuildsResolvedAndCandidateResults() {
        val selection = DeviceContactSelectionUiState(
            pendingToolCallId = "tool-1",
            groups = listOf(
                DeviceContactSelectionGroupUi(
                    name = "小明",
                    candidates = listOf(
                        DeviceContactSelectionCandidateUi(
                            contactId = "1",
                            displayName = "小明A",
                            phoneNumber = "111",
                            label = "mobile"
                        )
                    )
                ),
                DeviceContactSelectionGroupUi(
                    name = "小红",
                    candidates = listOf(
                        DeviceContactSelectionCandidateUi(
                            contactId = "2",
                            displayName = "小红A",
                            phoneNumber = "222"
                        )
                    )
                )
            )
        )

        val results = AgentStreamUserActionPolicy.deviceContactSelectionResults(
            selection = selection,
            selectedByName = mapOf("小明" to selection.groups.first().candidates.first())
        )

        assertEquals("RESOLVED", results[0]["status"])
        assertEquals("小明A", results[0]["displayName"])
        assertEquals("user_selected", results[0]["matchType"])
        assertEquals("MULTIPLE_CANDIDATES", results[1]["status"])
        assertTrue(results[1]["candidates"] is List<*>)
    }

    @Test
    fun deviceContactVoiceSelectionParsesChineseAndDigitOrdinals() {
        val selection = multiCandidateSelection()

        val chinese = AgentStreamUserActionPolicy.deviceContactVoiceSelection(selection, "选第二个")
            as AgentDeviceContactVoiceSelectionResult.Selected
        val digit = AgentStreamUserActionPolicy.deviceContactVoiceSelection(selection, "2")
            as AgentDeviceContactVoiceSelectionResult.Selected

        assertEquals("小明B", chinese.selectedByName["小明"]?.displayName)
        assertEquals("小红B", chinese.selectedByName["小红"]?.displayName)
        assertEquals(chinese.selectedByName, digit.selectedByName)
    }

    @Test
    fun deviceContactVoiceSelectionParsesCancelAndInvalidInput() {
        val selection = multiCandidateSelection()

        val cancel = AgentStreamUserActionPolicy.deviceContactVoiceSelection(selection, "算了吧")
        val invalid = AgentStreamUserActionPolicy.deviceContactVoiceSelection(selection, "随便")

        assertTrue(cancel is AgentDeviceContactVoiceSelectionResult.Cancel)
        assertTrue(invalid is AgentDeviceContactVoiceSelectionResult.Invalid)
        assertTrue((invalid as AgentDeviceContactVoiceSelectionResult.Invalid).statusText.contains("没听清"))
    }

    @Test
    fun deviceContactVoiceSelectionReportsOutOfRangeCandidate() {
        val selection = multiCandidateSelection()

        val result = AgentStreamUserActionPolicy.deviceContactVoiceSelection(selection, "第三个")

        assertTrue(result is AgentDeviceContactVoiceSelectionResult.OutOfRange)
        assertEquals(
            "小明没有第3个候选，请重新选择",
            (result as AgentDeviceContactVoiceSelectionResult.OutOfRange).statusText
        )
    }

    @Test
    fun deviceContactSelectionConfirmBuildsSubmitResultAndEcho() {
        val selection = multiCandidateSelection()
        val selected = mapOf("小明" to selection.groups.first().candidates[1])

        val result = AgentStreamUserActionPolicy.deviceContactSelectionConfirm(
            selection = selection,
            selectedByName = selected,
            echoSelection = true
        )

        assertEquals("已选定：小明 → 小明B 112", result.echoText)
        assertEquals("RESOLVED", result.results[0]["status"])
        assertEquals("MULTIPLE_CANDIDATES", result.results[1]["status"])
    }

    @Test
    fun deviceContactSelectionCancelBuildsCancelledResultsAfterPreResolvedItems() {
        val selection = multiCandidateSelection(
            preResolvedResults = listOf(mapOf("name" to "已解析", "status" to "RESOLVED"))
        )

        val result = AgentStreamUserActionPolicy.deviceContactSelectionCancel(selection)

        assertEquals("用户取消了联系人选择", result.echoText)
        assertEquals("RESOLVED", result.results[0]["status"])
        assertEquals("CANCELLED", result.results[1]["status"])
        assertEquals("小明", result.results[1]["name"])
        assertEquals("CANCELLED", result.results[2]["status"])
        assertEquals("小红", result.results[2]["name"])
    }

    private fun multiCandidateSelection(
        preResolvedResults: List<Map<String, Any?>> = emptyList()
    ): DeviceContactSelectionUiState {
        return DeviceContactSelectionUiState(
            pendingToolCallId = "tool-1",
            preResolvedResults = preResolvedResults,
            groups = listOf(
                DeviceContactSelectionGroupUi(
                    name = "小明",
                    candidates = listOf(
                        DeviceContactSelectionCandidateUi(
                            contactId = "1",
                            displayName = "小明A",
                            phoneNumber = "111"
                        ),
                        DeviceContactSelectionCandidateUi(
                            contactId = "2",
                            displayName = "小明B",
                            phoneNumber = "112"
                        )
                    )
                ),
                DeviceContactSelectionGroupUi(
                    name = "小红",
                    candidates = listOf(
                        DeviceContactSelectionCandidateUi(
                            contactId = "3",
                            displayName = "小红A",
                            phoneNumber = "221"
                        ),
                        DeviceContactSelectionCandidateUi(
                            contactId = "4",
                            displayName = "小红B",
                            phoneNumber = "222"
                        )
                    )
                )
            )
        )
    }
}
