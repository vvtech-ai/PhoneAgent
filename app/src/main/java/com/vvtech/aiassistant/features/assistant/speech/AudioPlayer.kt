package com.vvtech.aiassistant.features.assistant.speech

import com.vvtech.aiassistant.logging.AppFileLogger

import android.content.Context
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.vvtech.aiassistant.features.assistant_speech.AudioSegment
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

class AudioPlayer(
    private val context: Context
) {

    var onPlaybackComplete: (() -> Unit)? = null
    var onPlaybackStarted: (() -> Unit)? = null
    var onSegmentPlaybackStarting: (() -> Unit)? = null

    private val tag = "AudioPlayer"
    private val mainHandler = Handler(Looper.getMainLooper())
    private val queue = ConcurrentLinkedQueue<AudioSegment>()
    private val playbackExecutor = Executors.newSingleThreadExecutor()
    private val playing = AtomicBoolean(false)
    private val interrupted = AtomicBoolean(false)
    private val nextSegmentId = AtomicLong(0L)
    private var currentPlayer: MediaPlayer? = null
    @Volatile private var currentAudioTrack: AudioTrack? = null
    @Volatile private var reusablePcmAudioTrack: AudioTrack? = null
    @Volatile private var reusablePcmAudioTrackFormat: TtsAudioFormat? = null
    @Volatile private var reusablePcmTrackReleaseAtMs: Long = 0L
    private var currentTempFile: File? = null
    private var audioModeSession: TtsAudioModeSession? = null
    private val audioFocusController = TtsAudioFocusController(context)
    private val reusablePcmTrackGeneration = AtomicLong(0L)
    private val releaseReusablePcmTrackRunnable = Runnable { playbackExecutor.execute { releaseReusablePcmTrackIfIdle() } }

    fun enqueue(audioBytes: ByteArray, format: TtsAudioFormat = TtsAudioFormat.Mp3) {
        if (audioBytes.isEmpty()) return
        val segment = AudioSegment(
            id = nextSegmentId.incrementAndGet(),
            bytes = audioBytes,
            format = format,
            enqueuedAtMs = SystemClock.elapsedRealtime()
        )
        queue.add(segment)
        AppFileLogger.d(
            tag,
            "enqueue segmentId=${segment.id} bytes=${audioBytes.size} format=$format " +
                "queueSize=${queue.size} playing=${playing.get()}"
        )
        mainHandler.removeCallbacks(releaseReusablePcmTrackRunnable)
        if (playing.compareAndSet(false, true)) {
            interrupted.set(false)
            audioFocusController.acquire("enqueue_start:${segment.id}")
            acquireAudioMode("enqueue_start")
            playNext()
        }
    }

    fun interrupt() {
        AppFileLogger.i(tag, "TTS_DIAG playback completed reason=interrupt playing=${playing.get()} queueSize=${queue.size}")
        interrupted.set(true)
        queue.clear()
        mainHandler.post { stopCurrentPlayer() }
    }

    fun isPlaying(): Boolean = playing.get()

    fun release() {
        AppFileLogger.d(tag, "release")
        interrupted.set(true)
        queue.clear()
        mainHandler.post {
            stopCurrentPlayer()
            onPlaybackComplete = null
            onPlaybackStarted = null
            onSegmentPlaybackStarting = null
        }
    }

    private fun playNext() {
        if (interrupted.get()) {
            playing.set(false)
            cleanupTempFile()
            releaseAudioMode("interrupted_before_next")
            return
        }
        val segment = queue.poll()
        if (segment == null) {
            playing.set(false)
            cleanupTempFile()
            releaseAudioMode("queue_empty")
            AppFileLogger.i(tag, "TTS_DIAG playback completed queueSize=0")
            mainHandler.post { onPlaybackComplete?.invoke() }
            return
        }
        when (segment.format) {
            TtsAudioFormat.Mp3 -> mainHandler.post { startMediaPlayback(segment) }
            TtsAudioFormat.Pcm16k16BitMono,
            TtsAudioFormat.Pcm24k16BitMono -> startPcmPlayback(segment)
        }
    }

    private fun startMediaPlayback(segment: AudioSegment) {
        if (interrupted.get()) {
            playing.set(false)
            releaseAudioMode("media_interrupted_before_start")
            return
        }
        cleanupTempFile()
        val tempFile = writeTempFile(segment.bytes)
        if (tempFile == null) {
            AppFileLogger.w(tag, "failed to write temp file, skipping segment")
            playNext()
            return
        }
        currentTempFile = tempFile
        val player = MediaPlayer()
        currentPlayer = player
        try {
            AppFileLogger.i(tag, "TTS_DIAG player initialization type=MediaPlayer segmentId=${segment.id} bytes=${segment.bytes.size} format=${segment.format}")
            player.setAudioAttributes(TtsAudioAttributes.build())
            player.setDataSource(tempFile.absolutePath)
            player.setOnPreparedListener { mp ->
                if (interrupted.get()) {
                    releasePlayer(mp)
                    playing.set(false)
                    releaseAudioMode("media_interrupted_on_prepared")
                    return@setOnPreparedListener
                }
                mp.setVolume(1.0f, 1.0f)
                mp.start()
                runCatching { onPlaybackStarted?.invoke() }
                AppFileLogger.i(tag, "TTS_DIAG playback started type=MediaPlayer segmentId=${segment.id} durationMs=${mp.duration}")
            }
            player.setOnCompletionListener { mp ->
                AppFileLogger.d(tag, "segment complete, remaining=${queue.size}")
                releasePlayer(mp)
                playNext()
            }
            player.setOnErrorListener { mp, what, extra ->
                AppFileLogger.w(tag, "TTS_DIAG playback exception stage=media_error segmentId=${segment.id} what=$what extra=$extra")
                releasePlayer(mp)
                playNext()
                true
            }
            player.prepareAsync()
        } catch (e: Exception) {
            AppFileLogger.w(tag, "TTS_DIAG playback exception stage=media_start segmentId=${segment.id} message=${e.message}")
            releasePlayer(player)
            playNext()
        }
    }

    private fun startPcmPlayback(firstSegment: AudioSegment) {
        playbackExecutor.execute {
            if (interrupted.get()) {
                playing.set(false)
                releaseAudioMode("pcm_interrupted_before_start")
                return@execute
            }
            val policy = pcmPlaybackPolicyFor(firstSegment.format)
            val pcmStartGuardBytes = policy.bytesForMs(policy.startGuardMs)
            val pcmBetweenGuardBytes = policy.bytesForMs(policy.betweenSegmentGuardMs)
            val pcmEndPaddingBytes = policy.bytesForMs(policy.endPaddingMs)
            val minBuffer = AudioTrack.getMinBufferSize(
                policy.sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val bufferSize = maxOf(minBuffer, pcmStartGuardBytes + policy.frameBytes() * 4)
            val playbackId = firstSegment.id
            AppFileLogger.i(tag, "TTS_DIAG player initialization type=AudioTrack segmentId=${firstSegment.id} bytes=${firstSegment.bytes.size} format=${firstSegment.format} sampleRate=${policy.sampleRate} minBuffer=$minBuffer bufferSize=$bufferSize")
            val track = obtainPcmAudioTrack(
                format = firstSegment.format,
                policy = policy,
                bufferSize = bufferSize
            ) ?: run {
                playNext()
                return@execute
            }
            currentAudioTrack = track
            try {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                    track.setVolume(1.0f)
                } else {
                    @Suppress("DEPRECATION")
                    track.setStereoVolume(1.0f, 1.0f)
                }
                var writtenBytes = 0
                notifyPcmSegmentStarting(firstSegment)
                val prefilledStartGuard = writePcmSilence(
                    track = track,
                    byteCount = pcmStartGuardBytes,
                    format = firstSegment.format
                )
                writtenBytes += prefilledStartGuard
                track.play()
                runCatching { onPlaybackStarted?.invoke() }
                AppFileLogger.i(tag, "TTS_DIAG playback started type=AudioTrack segmentId=${firstSegment.id} format=${firstSegment.format} startGuardBytes=$prefilledStartGuard")
                if (prefilledStartGuard < pcmStartGuardBytes && !interrupted.get()) {
                    writtenBytes += writePcmSilence(
                        track = track,
                        byteCount = pcmStartGuardBytes - prefilledStartGuard,
                        format = firstSegment.format
                    )
                }
                writtenBytes += writePcmSegment(track, firstSegment)
                while (!interrupted.get()) {
                    val next = pollNextPcmSegmentWithGrace(firstSegment.format, policy.idleGraceMs) ?: break
                    AppFileLogger.d(
                        tag,
                        "pcm nextSegment playbackId=$playbackId segmentId=${next.id} " +
                            "bytes=${next.bytes.size} ageMs=${SystemClock.elapsedRealtime() - next.enqueuedAtMs}"
                    )
                    notifyPcmSegmentStarting(next)
                    writtenBytes += writePcmSilence(track, pcmBetweenGuardBytes, next.format)
                    writtenBytes += writePcmSegment(track, next)
                }
                writtenBytes += writePcmSilence(track, pcmEndPaddingBytes, firstSegment.format)
                waitForPcmDrain(track, writtenBytes, firstSegment.format)
                runCatching { track.stop() }
            } finally {
                if (interrupted.get()) {
                    releaseAudioTrack(track)
                } else {
                    keepPcmAudioTrackWarm(track, firstSegment.format)
                }
            }
            if (interrupted.get()) {
                playing.set(false)
                releaseAudioMode("pcm_interrupted")
            } else {
                playNext()
            }
        }
    }

    private fun notifyPcmSegmentStarting(segment: AudioSegment) {
        AppFileLogger.d(
            tag,
            "pcm segmentStarting segmentId=${segment.id} bytes=${segment.bytes.size} " +
                "queueSize=${queue.size}"
        )
        runCatching { onSegmentPlaybackStarting?.invoke() }
    }

    private fun pollNextPcmSegmentWithGrace(format: TtsAudioFormat, idleGraceMs: Long): AudioSegment? {
        val immediate = queue.peek()
        if (immediate != null && immediate.format != format) return null
        queue.poll()?.let { return it }
        val deadline = SystemClock.elapsedRealtime() + idleGraceMs
        while (!interrupted.get() && SystemClock.elapsedRealtime() < deadline) {
            val next = queue.peek()
            if (next != null && next.format != format) return null
            queue.poll()?.let { return it }
            Thread.sleep(PCM_IDLE_POLL_MS)
        }
        return null
    }

    private fun writePcmSilence(track: AudioTrack, byteCount: Int, format: TtsAudioFormat): Int {
        if (byteCount <= 0) return 0
        val silence = ByteArray(byteCount)
        var offset = 0
        val frameBytes = pcmPlaybackPolicyFor(format).frameBytes()
        while (!interrupted.get() && offset < silence.size) {
            val count = minOf(frameBytes, silence.size - offset)
            val written = runCatching { track.write(silence, offset, count) }.getOrDefault(0)
            if (written <= 0) break
            offset += written
        }
        return offset
    }

    private fun writePcmSegment(track: AudioTrack, segment: AudioSegment): Int {
        var offset = 0
        val bytes = segment.bytes
        val frameBytes = pcmPlaybackPolicyFor(segment.format).frameBytes()
        while (!interrupted.get() && offset < bytes.size) {
            val count = minOf(frameBytes, bytes.size - offset)
            val written = runCatching { track.write(bytes, offset, count) }.getOrDefault(0)
            if (written <= 0) break
            offset += written
        }
        return offset
    }

    private fun waitForPcmDrain(track: AudioTrack, writtenBytes: Int, format: TtsAudioFormat) {
        if (writtenBytes <= 0) return
        val policy = pcmPlaybackPolicyFor(format)
        val targetFrames = writtenBytes / policy.bytesPerFrame
        val playedFramesAtStart = runCatching { track.playbackHeadPosition.toLong() }.getOrDefault(-1L)
        val remainingFrames = if (playedFramesAtStart >= 0L) {
            (targetFrames - playedFramesAtStart).coerceAtLeast(0L)
        } else {
            targetFrames.toLong()
        }
        val remainingMs = remainingFrames * 1_000L / policy.sampleRate
        val waitMs = (remainingMs + policy.drainSafetyMs).coerceAtMost(policy.maxDrainWaitMs)
        val deadline = SystemClock.elapsedRealtime() + waitMs
        while (!interrupted.get() && SystemClock.elapsedRealtime() < deadline) {
            val playedFrames = runCatching { track.playbackHeadPosition.toLong() }.getOrDefault(-1L)
            if (playedFrames >= targetFrames) return
            Thread.sleep(PCM_DRAIN_POLL_MS)
        }
    }

    private fun obtainPcmAudioTrack(
        format: TtsAudioFormat,
        policy: PcmPlaybackPolicy,
        bufferSize: Int
    ): AudioTrack? {
        reusablePcmTrackGeneration.incrementAndGet()
        val reusable = reusablePcmAudioTrack
        if (reusable != null && reusablePcmAudioTrackFormat == format) {
            reusablePcmAudioTrack = null
            reusablePcmAudioTrackFormat = null
            runCatching { reusable.pause() }
            runCatching { reusable.flush() }
            AppFileLogger.d(tag, "pcm reuse warm AudioTrack format=$format")
            return reusable
        }
        releaseReusablePcmTrackNow()
        return runCatching {
            AudioTrack.Builder()
                .setAudioAttributes(TtsAudioAttributes.build())
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(policy.sampleRate)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
        }.getOrElse { throwable ->
            AppFileLogger.w(tag, "TTS_DIAG playback exception stage=pcm_create format=$format message=${throwable.message}")
            null
        }
    }

    private fun keepPcmAudioTrackWarm(track: AudioTrack, format: TtsAudioFormat) {
        runCatching {
            if (track.playState == AudioTrack.PLAYSTATE_PLAYING) {
                track.stop()
            }
        }
        runCatching { track.flush() }
        if (currentAudioTrack === track) {
            currentAudioTrack = null
        }
        reusablePcmAudioTrack = track
        reusablePcmAudioTrackFormat = format
        reusablePcmTrackReleaseAtMs = SystemClock.elapsedRealtime() + PCM_REUSABLE_TRACK_KEEP_ALIVE_MS
        val generation = reusablePcmTrackGeneration.incrementAndGet()
        mainHandler.removeCallbacks(releaseReusablePcmTrackRunnable)
        mainHandler.postDelayed(releaseReusablePcmTrackRunnable, PCM_REUSABLE_TRACK_KEEP_ALIVE_MS)
        AppFileLogger.d(tag, "pcm keep AudioTrack warm format=$format generation=$generation")
    }

    private fun releaseReusablePcmTrackIfIdle() {
        if (playing.get()) return
        val remainingMs = reusablePcmTrackReleaseAtMs - SystemClock.elapsedRealtime()
        if (remainingMs > 0L) {
            mainHandler.postDelayed(releaseReusablePcmTrackRunnable, remainingMs)
            return
        }
        releaseReusablePcmTrackNow()
    }

    private fun releaseReusablePcmTrackNow() {
        val track = reusablePcmAudioTrack ?: return
        reusablePcmAudioTrack = null
        reusablePcmAudioTrackFormat = null
        reusablePcmTrackReleaseAtMs = 0L
        releaseAudioTrack(track)
    }

    private fun releasePlayer(mp: MediaPlayer?) {
        if (mp == null) return
        try {
            if (mp.isPlaying) mp.stop()
        } catch (_: Exception) {
        }
        try {
            mp.reset()
            mp.release()
        } catch (_: Exception) {
        }
        if (currentPlayer === mp) {
            currentPlayer = null
        }
        cleanupTempFile()
    }

    private fun stopCurrentPlayer() {
        val mp = currentPlayer
        currentPlayer = null
        if (mp != null) {
            try {
                if (mp.isPlaying) mp.stop()
            } catch (_: Exception) {
            }
            try {
                mp.reset()
                mp.release()
            } catch (_: Exception) {
            }
        }
        releaseAudioTrack(currentAudioTrack)
        releaseReusablePcmTrackNow()
        cleanupTempFile()
        playing.set(false)
        releaseAudioMode("stop_current_player")
    }

    private fun acquireAudioMode(reason: String) {
        if (audioModeSession != null) {
            AppFileLogger.d(tag, "audio mode session already active reason=$reason")
            return
        }
        audioModeSession = TtsAudioModeController.enter(context)
    }

    private fun releaseAudioMode(reason: String = "unspecified") {
        audioFocusController.release(reason)
        val session = audioModeSession ?: return
        audioModeSession = null
        session.close()
    }

    private fun releaseAudioTrack(track: AudioTrack?) {
        if (track == null) return
        try {
            if (track.playState == AudioTrack.PLAYSTATE_PLAYING) {
                track.stop()
            }
        } catch (_: Exception) {
        }
        try {
            track.flush()
            track.release()
        } catch (_: Exception) {
        }
        if (currentAudioTrack === track) {
            currentAudioTrack = null
        }
        if (reusablePcmAudioTrack === track) {
            reusablePcmAudioTrack = null
            reusablePcmAudioTrackFormat = null
            reusablePcmTrackReleaseAtMs = 0L
        }
    }

    private fun writeTempFile(audioBytes: ByteArray): File? {
        return try {
            val dir = File(context.cacheDir, "tts_audio")
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, "tts_${UUID.randomUUID()}.mp3")
            file.writeBytes(audioBytes)
            file
        } catch (e: Exception) {
            AppFileLogger.w(tag, "writeTempFile failed: ${e.message}")
            null
        }
    }

    private fun cleanupTempFile() {
        currentTempFile?.let { file ->
            try {
                if (file.exists()) file.delete()
            } catch (_: Exception) {
            }
            currentTempFile = null
        }
    }

    private companion object {
        const val PCM_IDLE_POLL_MS = 12L
        const val PCM_DRAIN_POLL_MS = 20L
        const val PCM_REUSABLE_TRACK_KEEP_ALIVE_MS = 15_000L
    }
}
