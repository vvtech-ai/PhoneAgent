package com.vvtech.aiassistant.features.assistant_singleflow

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
        aiReply("已确认，正在发起通话…")
        addSummary("正在呼叫门店：$targetRestaurant。本次将预留联系人：李先生，13812349999。")
        openCallUi(targetRestaurant)
        callStatus = "正在呼叫…"
        delay(1500)
        callStatus = "已接通"
        addCallTranscript("AI：您好，我这边帮用户预订晚餐，想订 $slotTime $slotParty，优先包间，请问现在有位置吗？")
        delay(1500)
        callStatus = "沟通中"
        addCallTranscript("店员：您好，包间今晚已经满了，大厅还有位置，可以安排。")
        delay(1300)
        addCallTranscript("AI：可以，大厅也行。麻烦再确认一下，大厅是否有低消或用餐时长限制？")
        delay(1300)
        addCallTranscript("店员：大厅没有低消，用餐时长正常，帮您登记预留信息即可。")
        delay(1200)
        addCallTranscript("AI：好的，请登记预留信息：李先生，13812349999。")
        delay(1100)
        addCallTranscript("店员：收到，已为您预留 $slotTime $slotParty，联系人李先生，13812349999。")
        delay(900)
        addCallTranscript("AI：好的，最后确认留您的联系方式：李先生，13812349999。辛苦了，谢谢。")
        delay(800)
        callStatus = "已完成"

        stage = 4
        addSummary("执行结果：已预订大厅座；包间已满；低消信息：无低消；备注：门店已登记李先生，电话尾号9999。")
        aiReply("任务已完成。你可以继续回复“继续跟进”发起下一轮。")
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
                    addUserText("预订北海渔村包房，今晚8点半，五个人")
                    slotTime = "今晚 8:30"
                    slotParty = "5位"
                    stage = 2
                    delay(600)
                    aiReply("收到。我先给你三个候选门店。可以回复餐厅名称或第几个。")
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
                    addUserText("第一个")
                    val selected = restaurants.first()
                    slotRestaurant = selected.name
                    delay(500)
                    aiReply("好的，已选 ${selected.name}。请问是否需要包房？")
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
                    addUserText("不需要")
                    slotFallback = "不需要包房"
                    delay(500)
                    addSummary("我将联系 $slotRestaurant，预订 $slotTime $slotParty，不需要包房；留您的联系方式，尾号9999。")
                    addCta("确认拨打")
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
                    addSummary("执行结果：已预订大厅座 $slotTime $slotParty；包房：已满；低消信息：无低消；备注：门店已登记李先生，电话尾号9999。")
                    aiReply("任务已完成。")
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
