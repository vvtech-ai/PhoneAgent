package com.vvtech.phone_agent

import android.view.View
import com.dtf.face.ui.toyger.FaceLoadingFragment
import com.vvtech.aiassistant.R

class AliyunVoiceCloneLoadingFragment : FaceLoadingFragment() {
    private var authorizationShown = false

    override fun getLayoutID(): Int = R.layout.voice_clone_aliyun_face_loading

    override fun showAuthorizationView() {
        super.showAuthorizationView()
        authorizationShown = true
    }

    override fun showLoadingView() {
        super.showLoadingView()
        val hint = findViewById<View>(R.id.voice_clone_aliyun_loading_hint) ?: return
        hint.visibility = if (authorizationShown) View.VISIBLE else View.GONE
    }
}
