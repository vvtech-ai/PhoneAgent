package com.vvtech.aiassistant.features.assistant_pure_voice.ocr

import android.content.Context
import android.net.Uri
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

internal class MlKitPureVoiceOcrProcessor(
    context: Context
) : PureVoiceOcrProcessor {
    private val appContext = context.applicationContext
    private val recognizer = TextRecognition.getClient(
        ChineseTextRecognizerOptions.Builder().build()
    )

    override suspend fun recognize(imageUri: Uri): PureVoiceOcrRecognition {
        return withContext(Dispatchers.IO) {
            val image = InputImage.fromFilePath(appContext, imageUri)
            val recognized = recognizer.process(image).awaitResult()
            val segments = recognized.orderedSegments()
            PureVoiceOcrRecognition(
                rawSegments = segments,
                rawText = recognized.text.trim()
            )
        }
    }

    override fun close() {
        recognizer.close()
    }
}

private fun Text.orderedSegments(): List<String> {
    return textBlocks
        .flatMap { block -> block.lines }
        .map { line -> line.text.trim() }
        .filter(String::isNotBlank)
}

private suspend fun <T> Task<T>.awaitResult(): T {
    return suspendCancellableCoroutine { continuation ->
        addOnSuccessListener { result ->
            if (continuation.isActive) continuation.resume(result)
        }
        addOnFailureListener { throwable ->
            if (continuation.isActive) continuation.resumeWithException(throwable)
        }
        addOnCanceledListener {
            continuation.cancel()
        }
    }
}
