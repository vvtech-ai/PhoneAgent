package com.vvtech.phone_agent

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import java.util.concurrent.CopyOnWriteArraySet

/** Explicit foreground translation owner only; never restarts a call. */
internal object TranslationCallAudioOwner {
    @Volatile var id: String? = null
    @Volatile var active = false
    var ready: ((Boolean) -> Unit)? = null
    var stopNow: (() -> Unit)? = null
    val lost = CopyOnWriteArraySet<() -> Unit>()
    fun matches(token: String?): Boolean = token != null && token == id && active
    fun clear() {
        active = false
        id = null
        stopNow = null
        ready?.invoke(false)
        ready = null
        lost.forEach { it() }
    }
}

class TranslationCallAudioService : Service() {
    private var wake: PowerManager.WakeLock? = null
    private var owned: String? = null
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val token = intent?.getStringExtra("callAudioId")
        if (token == null || token != TranslationCallAudioOwner.id || owned != null) {
            stopSelf(); return START_NOT_STICKY
        }
        owned = token
        try {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "translation_call_audio"
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel(channelId, "实时翻译通话", NotificationManager.IMPORTANCE_LOW))
            }
            val open = PendingIntent.getActivity(this, 0,
                Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
            val notification = builder.setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setContentTitle("实时翻译通话进行中").setContentText("点击返回通话")
                .setContentIntent(open).setOngoing(true).setCategory(Notification.CATEGORY_CALL).build()
            if (Build.VERSION.SDK_INT >= 29) startForeground(7041, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            else startForeground(7041, notification)
            wake = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:translation-call").apply {
                setReferenceCounted(false); acquire()
            }
            TranslationCallAudioOwner.active = true
            TranslationCallAudioOwner.stopNow = { stopOwned(); stopSelf() }
            TranslationCallAudioOwner.ready?.invoke(true)
            TranslationCallAudioOwner.ready = null
        } catch (_: Exception) { stopOwned(); stopSelf() }
        return START_NOT_STICKY
    }
    private fun stopOwned() {
        if (wake?.isHeld == true) wake?.release()
        wake = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        if (owned != null && owned == TranslationCallAudioOwner.id) TranslationCallAudioOwner.clear()
        owned = null
    }
    override fun onTaskRemoved(rootIntent: Intent?) { stopOwned(); stopSelf() }
    override fun onDestroy() { stopOwned(); super.onDestroy() }
}
