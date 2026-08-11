package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AliyunIdProSdkAdapterTest {

    @Test
    fun `sdk uses the app blue palette before verification starts`() {
        val config = AliyunIdProUiTheme.json

        listOf(
            "titleColor",
            "agrtTopTipsColor",
            "bannerImg",
            "agrtUnSelColor",
            "agrtSelBgColor",
            "agrtAgreeColor",
            "agrtColor",
            "agrtBotTipsColor",
            "startBtnColor",
            "startBtnBgColor",
            "startBtnDisColor",
            "startBtnDisBgColor",
            "exitBtnColor",
            "exitBtnBgColor",
            "elderBtnColor",
            "elderBtnDisColor",
            "elderBtnBgColor",
            "elderBtnDisBgColor",
            "rareFormEntBtnColor"
        ).forEach { key ->
            assertTrue("missing guideConfig field: $key", config.contains("\"$key\""))
        }
        assertTrue(config.contains("\"agrtSelBgColor\":\"#0A84FF\""))
        assertTrue(config.contains("\"agrtColor\":\"#0A84FF\""))
        assertTrue(config.contains("\"startBtnBgColor\":\"#0A84FF\""))
        assertTrue(config.contains("\"faceProgressStartColor\":\"#0A84FF\""))
        assertTrue(config.contains("\"faceProgressEndColor\":\"#60A5FA\""))
        assertTrue(config.contains("\"faceBgColor\":\"#F8FAFC\""))
        assertTrue(config.contains("\"faceTitleColor\":\"#111111\""))
        assertTrue(config.contains("\"dialogConfirmBgColor\":\"#0A84FF\""))
        assertTrue(config.contains("\"statusBarLightTxt\":\"false\""))

        val source = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/AliyunIdProSdkAdapter.kt"
        ).readText(Charsets.UTF_8)
        val themeIndex = source.indexOf("applyUiTheme(facade)")
        val verifyIndex = source.indexOf("\"verify\",")

        assertTrue(themeIndex >= 0)
        assertTrue(verifyIndex > themeIndex)
        assertTrue(source.contains("\"setCustomUIConfig\""))
        assertEquals(0, AliyunIdProUiTheme.CONFIG_TYPE_JSON)
    }

    @Test
    fun `mfvc sdk explicitly disables certification video evidence`() {
        val source = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/AliyunIdProSdkAdapter.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(source.contains("ext_params_key_use_video"))
        assertTrue(source.contains("VIDEO_EVIDENCE_EXT_PARAM_KEY to \"false\""))
        assertTrue(source.contains("buildExtParams()"))
        assertTrue(source.contains(".invoke(facade, certifyId, true, buildExtParams(), callbackProxy)"))
        assertTrue(source.contains("MfvcVerificationSession.tryStart()"))
        assertTrue(source.contains("finishSession(facade)"))
        assertTrue(source.contains("\"release\""))
    }

    @Test
    fun `sdk meta info preparation starts as soon as app consent is granted`() {
        val adapter = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/AliyunIdProSdkAdapter.kt"
        ).readText(Charsets.UTF_8)
        val coordinator = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/VoiceCloneEnrollmentCoordinator.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(adapter.contains("private var preparedMetaInfo"))
        assertTrue(adapter.contains("override fun prepare(context: Context)"))
        assertTrue(adapter.contains("override fun clearPreparedSession()"))
        assertTrue(coordinator.contains("fun setAgreement(accepted: Boolean)"))
        assertTrue(coordinator.contains("if (accepted) startPreparation(\"agreement\")"))
        assertTrue(coordinator.contains("else clearPreparation()"))
        assertTrue(coordinator.contains("fun continueAfterConsent()"))
        assertTrue(coordinator.contains("startPreparation(\"consent_continue\")"))
        assertTrue(coordinator.contains("scope.async(Dispatchers.Default)"))
        assertTrue(coordinator.contains("preparedMetaInfo()"))
        assertTrue(coordinator.contains("sdk.clearPreparedSession()"))
        assertTrue(coordinator.indexOf("dispatch(\n            VoiceCloneEnrollmentEvent.AgreementChanged") <
            coordinator.indexOf("if (accepted) startPreparation(\"agreement\")"))
    }

    @Test
    fun `mfvc start is gated by camera and microphone permissions`() {
        val source = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/VoiceCloneEnrollmentUi.kt"
        ).readText(Charsets.UTF_8)
        val permissionGate = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice_clone/enrollment/MfvcVerificationPermissionGate.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(source.contains("rememberMfvcVerificationPermissionGate"))
        assertTrue(source.contains("onVerificationPermissionDenied"))
        assertTrue(permissionGate.contains("Manifest.permission.CAMERA"))
        assertTrue(permissionGate.contains("Manifest.permission.RECORD_AUDIO"))
        assertTrue(!permissionGate.contains("FOREGROUND_SERVICE_MEDIA_PROJECTION"))
    }

    @Test
    fun `mfvc wish resources override the bundled orange palette with app blue`() {
        val colors = sourceFile(
            "src/main/res/values/aliyun_mfvc_colors.xml"
        ).readText(Charsets.UTF_8)

        assertTrue(colors.contains("<color name=\"dtf_color_fa6\">#0A84FF</color>"))
        assertTrue(colors.contains("<color name=\"dtf_color_fb5\">#60A5FA</color>"))
        assertTrue(colors.contains("<color name=\"dtf_color_ff6\">#0A84FF</color>"))
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(File(path), File("android/app/$path")).first { it.exists() }
        }
    }
}
