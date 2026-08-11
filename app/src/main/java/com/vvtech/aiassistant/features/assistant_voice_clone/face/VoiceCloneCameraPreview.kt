package com.vvtech.aiassistant.features.assistant_voice_clone.face

import android.Manifest
import android.content.pm.PackageManager
import android.os.SystemClock
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import java.util.concurrent.Executors

internal data class VoiceCloneCameraCallbacks(
    val onCameraReady: () -> Unit,
    val onFaceSample: (Long, Int) -> Unit,
    val onCameraFailure: () -> Unit
)

internal data class VoiceCloneFaceUiArgs(
    val snapshot: FacePresenceSnapshot,
    val callbacks: VoiceCloneCameraCallbacks
)

@Composable
internal fun VoiceCloneCameraPreview(
    callbacks: VoiceCloneCameraCallbacks,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var permissionGranted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED
        )
    }
    var permissionRequested by remember { mutableStateOf(false) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        permissionGranted = granted
        if (!granted) callbacks.onCameraFailure()
    }

    LaunchedEffect(permissionGranted, permissionRequested) {
        if (!permissionGranted && !permissionRequested) {
            permissionRequested = true
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    if (!permissionGranted) {
        Box(modifier = modifier.fillMaxWidth().height(220.dp), contentAlignment = Alignment.Center) {
            Text("请允许相机权限后重新进入声音采集", color = Color(0xFF6E6E73))
        }
        return
    }

    val previewView = remember {
        PreviewView(context).apply {
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
    }
    val analysisExecutor = remember { Executors.newSingleThreadExecutor() }
    val detector = remember {
        FaceDetection.getClient(
            FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_NONE)
                .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_NONE)
                .build()
        )
    }

    DisposableEffect(lifecycleOwner, previewView) {
        val providerFuture = ProcessCameraProvider.getInstance(context)
        var provider: ProcessCameraProvider? = null
        var preview: Preview? = null
        var analysis: ImageAnalysis? = null
        providerFuture.addListener({
            runCatching {
                provider = providerFuture.get()
                preview = Preview.Builder().build().also { it.setSurfaceProvider(previewView.surfaceProvider) }
                analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .also { useCase ->
                        useCase.setAnalyzer(
                            analysisExecutor,
                            FaceCountAnalyzer(
                                detector = detector,
                                onFaceSample = callbacks.onFaceSample,
                                onAnalysisFailure = callbacks.onCameraFailure
                            )
                        )
                    }
                provider?.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_FRONT_CAMERA,
                    preview,
                    analysis
                )
                callbacks.onCameraReady()
            }.onFailure { callbacks.onCameraFailure() }
        }, ContextCompat.getMainExecutor(context))

        onDispose {
            preview?.let { provider?.unbind(it) }
            analysis?.let { provider?.unbind(it) }
            detector.close()
            analysisExecutor.shutdown()
        }
    }

    AndroidView(
        factory = { previewView },
        modifier = modifier.fillMaxWidth().height(220.dp)
    )
}

private class FaceCountAnalyzer(
    private val detector: com.google.mlkit.vision.face.FaceDetector,
    private val onFaceSample: (Long, Int) -> Unit,
    private val onAnalysisFailure: () -> Unit
) : ImageAnalysis.Analyzer {
    private var lastAnalysisAtMs: Long = Long.MIN_VALUE

    override fun analyze(imageProxy: ImageProxy) {
        val now = SystemClock.elapsedRealtime()
        if (lastAnalysisAtMs != Long.MIN_VALUE &&
            now - lastAnalysisAtMs < FacePresencePolicy.SAMPLE_INTERVAL_MS
        ) {
            imageProxy.close()
            return
        }
        lastAnalysisAtMs = now
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return
        }
        val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
        detector.process(image)
            .addOnSuccessListener { faces -> onFaceSample(now, faces.size) }
            .addOnFailureListener { onAnalysisFailure() }
            .addOnCompleteListener { imageProxy.close() }
    }
}
