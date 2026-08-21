package com.vvtech.aiassistant.features.assistant_singleflow

import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.features.assistant.EffectiveTaskContact
import com.vvtech.aiassistant.features.assistant.SfInputMode
import com.vvtech.aiassistant.features.assistant.SfRestaurantOption
import com.vvtech.aiassistant.features.assistant.SfThreadItem
import com.vvtech.aiassistant.features.assistant.sfDefaultRestaurants
import com.vvtech.aiassistant.features.assistant.sfDefaultThinkingSteps
import com.vvtech.aiassistant.features.assistant.sfSplitRestaurantName
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import kotlinx.coroutines.delay

internal enum class SfPending {
    Task,
    Restaurant,
    Fallback,
    ConfirmCall,
    Done
}

internal class SingleFlowNativeStateHolder(
    val restaurants: List<SfRestaurantOption>,
    val listState: LazyListState,
    val callListState: LazyListState,
    receiptHintDismissedInitial: Boolean
) {
    val threadItems = mutableStateListOf<SfThreadItem>()
    val callTranscripts = mutableStateListOf<String>()
    val selectedDetailQuestionIds = mutableStateListOf<String>()

    var nextId by mutableStateOf(1L)
    var stage by mutableStateOf(1)
    var inputMode by mutableStateOf(SfInputMode.Text)
    var pending by mutableStateOf(SfPending.Task)
    var listening by mutableStateOf(false)
    var callRunning by mutableStateOf(false)
    var textInput by mutableStateOf("")

    var slotTime by mutableStateOf("今晚 7:00")
    var slotParty by mutableStateOf("2位")
    var slotRestaurant by mutableStateOf("")
    var slotFallback by mutableStateOf("")

    var callVisible by mutableStateOf(false)
    var callStatus by mutableStateOf(currentAppText("正在呼叫…", "Calling..."))
    var callSeconds by mutableStateOf(0)
    var callMuted by mutableStateOf(false)
    var callSpeaker by mutableStateOf(true)
    var callName by mutableStateOf("西堤牛排")
    var callSub by mutableStateOf("北京国贸店")
    var composerHeightPx by mutableStateOf(0)

    var supplementContact by mutableStateOf<EffectiveTaskContact?>(null)
    var manualContactMode by mutableStateOf(false)
    var contactInputError by mutableStateOf<String?>(null)
    var detailSupplementTaskId by mutableStateOf<String?>(null)
    var voiceContactPromptTaskId by mutableStateOf<String?>(null)
    var voiceDetailPromptTaskId by mutableStateOf<String?>(null)
    var voiceSummaryPromptSignature by mutableStateOf("")
    var handledVoiceContactEventId by mutableStateOf(0L)
    var handledVoiceUiCommandEventId by mutableStateOf(0L)

    var mockStep by mutableStateOf(0)
    var mockUserSpeaking by mutableStateOf(false)
    var mockAiSpeaking by mutableStateOf(false)

    var showReceiptOverlay by mutableStateOf(false)
    var showReceiptHint by mutableStateOf(false)
    var receiptHintDismissed by mutableStateOf(receiptHintDismissedInitial)

    fun newItemId(): Long {
        val value = nextId
        nextId += 1
        return value
    }

    fun addUserText(text: String) {
        threadItems.add(SfThreadItem.UserText(id = newItemId(), text = text))
    }

    fun addUserWave() {
        threadItems.add(SfThreadItem.UserWave(id = newItemId()))
    }

    fun addSummary(text: String) {
        threadItems.add(SfThreadItem.Summary(id = newItemId(), text = text))
    }

    fun addOptions(options: List<SfRestaurantOption>) {
        threadItems.add(SfThreadItem.Options(id = newItemId(), options = options))
    }

    fun addCta(text: String) {
        threadItems.add(SfThreadItem.AiCta(id = newItemId(), text = text))
    }

    fun replaceItemById(targetId: Long, newItem: SfThreadItem) {
        val index = threadItems.indexOfFirst { it.id == targetId }
        if (index >= 0) {
            threadItems[index] = newItem
        } else {
            threadItems.add(newItem)
        }
    }

    suspend fun aiReply(text: String, steps: List<String> = sfDefaultThinkingSteps(text)) {
        val thinkId = newItemId()
        threadItems.add(SfThreadItem.AiThinking(id = thinkId, steps = steps.take(4)))
        delay(2000)
        replaceItemById(
            targetId = thinkId,
            newItem = SfThreadItem.AiText(id = thinkId, text = text)
        )
    }

    fun openCallUi(restaurantName: String) {
        val (nameText, subText) = sfSplitRestaurantName(restaurantName)
        callName = nameText
        callSub = subText
        callStatus = currentAppText("正在呼叫…", "Calling...")
        callSeconds = 0
        callMuted = false
        callSpeaker = true
        callTranscripts.clear()
        callVisible = true
    }

    fun closeCallUi() {
        callVisible = false
    }

    fun confirmSupplementContact(contact: EffectiveTaskContact) {
        supplementContact = contact
        manualContactMode = false
        contactInputError = null
        selectedDetailQuestionIds.clear()
    }

    fun addCallTranscript(text: String) {
        callTranscripts.add(text)
    }

    fun resetForEntry(inputModeAfterReset: SfInputMode) {
        nextId = 1L
        stage = 1
        inputMode = inputModeAfterReset
        pending = SfPending.Task
        listening = false
        callRunning = false
        textInput = ""
        slotTime = "今晚 7:00"
        slotParty = "2位"
        slotRestaurant = ""
        slotFallback = ""
        callVisible = false
        callStatus = currentAppText("正在呼叫…", "Calling...")
        callSeconds = 0
        callMuted = false
        callSpeaker = true
        callName = "西堤牛排"
        callSub = "北京国贸店"
        threadItems.clear()
        callTranscripts.clear()
        clearDetailSupplementState()
        mockStep = 0
        mockUserSpeaking = false
        mockAiSpeaking = false
        showReceiptOverlay = false
        showReceiptHint = false
    }

    fun clearDetailSupplementState() {
        supplementContact = null
        manualContactMode = false
        contactInputError = null
        detailSupplementTaskId = null
        voiceContactPromptTaskId = null
        voiceDetailPromptTaskId = null
        voiceSummaryPromptSignature = ""
        handledVoiceContactEventId = 0L
        handledVoiceUiCommandEventId = 0L
        selectedDetailQuestionIds.clear()
    }

    fun resetLocalDemoFlow() {
        pending = SfPending.Task
        stage = 1
        listening = false
        callRunning = false
        closeCallUi()
        slotRestaurant = ""
        slotFallback = ""
        mockStep = 0
        mockUserSpeaking = false
        mockAiSpeaking = false
        showReceiptOverlay = false
        showReceiptHint = false
        threadItems.clear()
    }

    fun toggleDetailQuestion(questionId: String) {
        if (selectedDetailQuestionIds.contains(questionId)) {
            selectedDetailQuestionIds.remove(questionId)
        } else {
            selectedDetailQuestionIds.add(questionId)
        }
    }
}

@Composable
internal fun rememberSingleFlowNativeStateHolder(
    receiptHintDismissedInitial: Boolean
): SingleFlowNativeStateHolder {
    val restaurants = remember { sfDefaultRestaurants() }
    val listState = rememberLazyListState()
    val callListState = rememberLazyListState()
    return remember(restaurants, listState, callListState, receiptHintDismissedInitial) {
        SingleFlowNativeStateHolder(
            restaurants = restaurants,
            listState = listState,
            callListState = callListState,
            receiptHintDismissedInitial = receiptHintDismissedInitial
        )
    }
}
