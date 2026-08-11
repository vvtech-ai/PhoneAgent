package com.vvtech.aiassistant.features.assistant_voice_clone.face

internal class FacePresenceTracker {
    var snapshot: FacePresenceSnapshot = FacePresenceSnapshot()
        private set

    private var lastSampleAtMs: Long? = null
    private var lastFrameAtMs: Long? = null
    private var missingSinceMs: Long? = null

    fun onCameraReady(): FacePresenceSnapshot = update(snapshot.copy(cameraReady = true))

    fun onCameraUnavailable(): FacePresenceSnapshot = update(
        snapshot.copy(cameraReady = false, failure = FacePresenceFailure.CAMERA_UNAVAILABLE)
    )

    fun onSample(timestampMs: Long, faceCount: Int): FacePresenceSnapshot {
        val safeFaceCount = faceCount.coerceAtLeast(0)
        val frameGapMs = lastFrameAtMs?.let { (timestampMs - it).coerceAtLeast(0) } ?: 0
        lastFrameAtMs = timestampMs
        update(snapshot.copy(currentFaceCount = safeFaceCount))
        if (!snapshot.recording || snapshot.failure != null || !shouldSample(timestampMs)) {
            return snapshot
        }
        lastSampleAtMs = timestampMs
        val sampled = snapshot.summary.sampledFrames + 1
        val single = snapshot.summary.singleFaceFrames + if (safeFaceCount == 1) 1 else 0
        val multipleDetected = snapshot.summary.multipleFaceDetected || safeFaceCount > 1
        val missingDuration = updateMissingDuration(timestampMs, safeFaceCount)
        val summary = snapshot.summary.copy(
            sampledFrames = sampled,
            singleFaceFrames = single,
            maxMissingDurationMs = maxOf(snapshot.summary.maxMissingDurationMs, missingDuration),
            maxFrameGapMs = maxOf(snapshot.summary.maxFrameGapMs, frameGapMs),
            multipleFaceDetected = multipleDetected
        )
        val failure = when {
            frameGapMs > FacePresencePolicy.MAX_MISSING_DURATION_MS ->
                FacePresenceFailure.ANALYSIS_STALLED
            multipleDetected -> FacePresenceFailure.MULTIPLE_FACES
            missingDuration > FacePresencePolicy.MAX_MISSING_DURATION_MS -> FacePresenceFailure.FACE_MISSING
            else -> null
        }
        return update(snapshot.copy(summary = summary, failure = failure))
    }

    fun startRecording(timestampMs: Long): Boolean {
        val lastFrame = lastFrameAtMs ?: return false
        if (!snapshot.readyToRecord || timestampMs - lastFrame > FacePresencePolicy.MAX_MISSING_DURATION_MS) {
            return false
        }
        lastSampleAtMs = null
        missingSinceMs = null
        update(snapshot.copy(recording = true, summary = FacePresenceSummary(), failure = null))
        return true
    }

    fun finish(timestampMs: Long): FacePresenceSnapshot {
        val missingDuration = missingSinceMs?.let { (timestampMs - it).coerceAtLeast(0) } ?: 0
        val frameGapMs = lastFrameAtMs?.let { (timestampMs - it).coerceAtLeast(0) }
            ?: Long.MAX_VALUE
        val summary = snapshot.summary.copy(
            maxMissingDurationMs = maxOf(snapshot.summary.maxMissingDurationMs, missingDuration),
            maxFrameGapMs = maxOf(snapshot.summary.maxFrameGapMs, frameGapMs)
        )
        val failure = snapshot.failure ?: when {
            frameGapMs > FacePresencePolicy.MAX_MISSING_DURATION_MS ->
                FacePresenceFailure.ANALYSIS_STALLED
            summary.singleFaceRatio < FacePresencePolicy.MIN_SINGLE_FACE_RATIO ->
                FacePresenceFailure.LOW_SINGLE_FACE_RATIO
            else -> null
        }
        return update(snapshot.copy(recording = false, summary = summary, failure = failure))
    }

    fun cancelRecording(): FacePresenceSnapshot = update(
        snapshot.copy(recording = false, summary = FacePresenceSummary(), failure = null)
    ).also {
        lastSampleAtMs = null
        missingSinceMs = null
    }

    fun onWatchdogTick(timestampMs: Long): FacePresenceSnapshot {
        if (!snapshot.recording || snapshot.failure != null) return snapshot
        val frameGapMs = lastFrameAtMs?.let { (timestampMs - it).coerceAtLeast(0) }
            ?: Long.MAX_VALUE
        val summary = snapshot.summary.copy(
            maxFrameGapMs = maxOf(snapshot.summary.maxFrameGapMs, frameGapMs)
        )
        val failure = if (frameGapMs > FacePresencePolicy.MAX_MISSING_DURATION_MS) {
            FacePresenceFailure.ANALYSIS_STALLED
        } else {
            null
        }
        return update(snapshot.copy(summary = summary, failure = failure))
    }

    fun prepareCollection(): FacePresenceSnapshot {
        lastSampleAtMs = null
        missingSinceMs = null
        return update(
            snapshot.copy(
                recording = false,
                summary = FacePresenceSummary(),
                failure = null
            )
        )
    }

    fun reset(): FacePresenceSnapshot {
        lastSampleAtMs = null
        lastFrameAtMs = null
        missingSinceMs = null
        return update(FacePresenceSnapshot())
    }

    private fun shouldSample(timestampMs: Long): Boolean = lastSampleAtMs?.let {
        timestampMs - it >= FacePresencePolicy.SAMPLE_INTERVAL_MS
    } ?: true

    private fun updateMissingDuration(timestampMs: Long, faceCount: Int): Long {
        if (faceCount == 1) {
            missingSinceMs = null
            return 0
        }
        val start = missingSinceMs ?: timestampMs.also { missingSinceMs = it }
        return (timestampMs - start).coerceAtLeast(0)
    }

    private fun update(value: FacePresenceSnapshot): FacePresenceSnapshot {
        snapshot = value
        return value
    }
}
