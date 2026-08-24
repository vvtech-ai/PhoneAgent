package com.vvtech.aiassistant.features.assistant_singleflow

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal class SingleFlowNativeMockFlowController(
    private val state: SingleFlowNativeStateHolder,
    private val scope: CoroutineScope,
    private val pureVoiceMode: Boolean
) {
    suspend fun runCallFlow() = with(state) {
        if (callRunning) return@with
        callRunning = true
        stage = 3
        val targetRestaurant = slotRestaurant.ifBlank { restaurants.first().name }
        aiReply(currentAppText("已确认，正在发起通话…", "Confirmed. Starting the call..."))
        addSummary(
            currentAppText(
                "正在呼叫门店：$targetRestaurant。本次将预留联系人：李先生，13812349999。",
                "Calling the restaurant: $targetRestaurant. The reserved contact will be Mr. Li, 13812349999."
            )
        )
        openCallUi(targetRestaurant)
        callStatus = currentAppText("正在呼叫…", "Calling...")
        delay(1500)
        callStatus = currentAppText("已接通", "Connected")
        addCallTranscript(
            currentAppText(
                "AI：您好，我这边帮用户预订晚餐，想订 $slotTime $slotParty，优先包间，请问现在有位置吗？",
                "AI: Hi, I am helping the user book dinner for $slotTime, $slotParty, preferably a private room. Do you have availability?"
            )
        )
        delay(1500)
        callStatus = currentAppText("沟通中", "In conversation")
        addCallTranscript(
            currentAppText(
                "店员：您好，包间今晚已经满了，大厅还有位置，可以安排。",
                "Staff: Hi, the private rooms are full tonight, but tables in the main dining area are available."
            )
        )
        delay(1300)
        addCallTranscript(
            currentAppText(
                "AI：可以，大厅也行。麻烦再确认一下，大厅是否有低消或用餐时长限制？",
                "AI: The main dining area is fine. Could you confirm whether there is a minimum spend or dining time limit?"
            )
        )
        delay(1300)
        addCallTranscript(
            currentAppText(
                "店员：大厅没有低消，用餐时长正常，帮您登记预留信息即可。",
                "Staff: There is no minimum spend, and the dining time is normal. I can register the reservation details for you."
            )
        )
        delay(1200)
        addCallTranscript(
            currentAppText(
                "AI：好的，请登记预留信息：李先生，13812349999。",
                "AI: Great. Please register the contact as Mr. Li, 13812349999."
            )
        )
        delay(1100)
        addCallTranscript(
            currentAppText(
                "店员：收到，已为您预留 $slotTime $slotParty，联系人李先生，13812349999。",
                "Staff: Got it. I have reserved a table for $slotTime, $slotParty, under Mr. Li, 13812349999."
            )
        )
        delay(900)
        addCallTranscript(
            currentAppText(
                "AI：好的，最后确认留您的联系方式：李先生，13812349999。辛苦了，谢谢。",
                "AI: Perfect. Final confirmation: the contact is Mr. Li, 13812349999. Thank you."
            )
        )
        delay(800)
        callStatus = currentAppText("已完成", "Completed")

        stage = 4
        addSummary(
            currentAppText(
                "执行结果：已预订大厅座；包间已满；低消信息：无低消；备注：门店已登记李先生，电话尾号9999。",
                "Result: main dining table booked; private rooms are full; no minimum spend; note: the restaurant registered Mr. Li, phone ending in 9999."
            )
        )
        aiReply(
            currentAppText(
                "任务已完成。你可以继续回复“继续跟进”发起下一轮。",
                "Task completed. You can reply \"follow up\" to start another round."
            )
        )
        closeCallUi()
        pending = SfPending.Done
        callRunning = false
        if (pureVoiceMode) {
            showReceiptOverlay = true
            mockStep = 5
        }
    }

    fun advanceMockStep() = with(state) {
        if (callRunning && mockStep < 4) return@with
        scope.launch {
            mockAiSpeaking = false
            mockUserSpeaking = false
            listening = false

            when (mockStep) {
                0 -> {
                    listening = true
                    delay(1200)
                    listening = false
                    mockAiSpeaking = true
                    addUserText("Book a private room at Beihai Fish Village for five people at 8:30 tonight.")
                    slotTime = "Tonight 8:30"
                    slotParty = "5 people"
                    stage = 2
                    delay(600)
                    aiReply("Got it. I found three candidate locations. Reply with the restaurant name or number.")
                    addOptions(restaurants)
                    pending = SfPending.Restaurant
                    mockStep = 1
                    delay(2000)
                    if (mockStep == 1) mockAiSpeaking = false
                }

                1 -> {
                    listening = true
                    delay(800)
                    listening = false
                    mockAiSpeaking = true
                    addUserText("The first one")
                    val selected = restaurants.first()
                    slotRestaurant = selected.name
                    delay(500)
                    aiReply("Okay, ${selected.name} selected. Do you need a private room?")
                    pending = SfPending.Fallback
                    mockStep = 2
                    delay(2000)
                    if (mockStep == 2) mockAiSpeaking = false
                }

                2 -> {
                    listening = true
                    delay(800)
                    listening = false
                    mockAiSpeaking = true
                    addUserText("No")
                    slotFallback = "No private room needed"
                    delay(500)
                    addSummary("I will contact $slotRestaurant to book $slotTime for $slotParty, no private room needed, and leave your phone number ending in 9999.")
                    addCta("Confirm Call")
                    pending = SfPending.ConfirmCall
                    mockStep = 3
                    delay(1500)
                    if (mockStep == 3) mockAiSpeaking = false
                }

                3 -> {
                    mockStep = 4
                    runCallFlow()
                }

                4 -> {
                    callRunning = false
                    closeCallUi()
                    stage = 4
                    mockAiSpeaking = true
                    addSummary(
                        currentAppText(
                            "执行结果：已预订大厅座 $slotTime $slotParty；包房：已满；低消信息：无低消；备注：门店已登记李先生，电话尾号9999。",
                            "Result: main dining table booked for $slotTime, $slotParty; private rooms are full; no minimum spend; note: the restaurant registered Mr. Li, phone ending in 9999."
                        )
                    )
                    aiReply(currentAppText("任务已完成。", "Task completed."))
                    pending = SfPending.Done
                    mockStep = 5
                    delay(1500)
                    mockAiSpeaking = false
                    showReceiptOverlay = true
                }
            }
        }
    }
}
