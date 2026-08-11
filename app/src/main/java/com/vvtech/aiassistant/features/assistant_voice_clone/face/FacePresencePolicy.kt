package com.vvtech.aiassistant.features.assistant_voice_clone.face

internal object FacePresencePolicy {
    const val SAMPLE_INTERVAL_MS = 250L
    const val MAX_MISSING_DURATION_MS = 1_000L
    const val MIN_SINGLE_FACE_RATIO = 0.80
}

internal enum class FacePresenceFailure {
    MULTIPLE_FACES,
    FACE_MISSING,
    LOW_SINGLE_FACE_RATIO,
    ANALYSIS_STALLED,
    CAMERA_UNAVAILABLE
}

internal data class FacePresenceSummary(
    val sampledFrames: Int = 0,
    val singleFaceFrames: Int = 0,
    val maxMissingDurationMs: Long = 0,
    val maxFrameGapMs: Long = 0,
    val multipleFaceDetected: Boolean = false
) {
    val singleFaceRatio: Double
        get() = if (sampledFrames == 0) 0.0 else singleFaceFrames.toDouble() / sampledFrames
}

internal data class FacePresenceSnapshot(
    val cameraReady: Boolean = false,
    val currentFaceCount: Int = 0,
    val recording: Boolean = false,
    val summary: FacePresenceSummary = FacePresenceSummary(),
    val failure: FacePresenceFailure? = null
) {
    val readyToRecord: Boolean
        get() = cameraReady && currentFaceCount == 1 && failure == null
}
