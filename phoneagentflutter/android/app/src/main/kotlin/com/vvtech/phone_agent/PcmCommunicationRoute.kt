package com.vvtech.phone_agent

import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build

/** Playback routing only. No AudioRecord, capture permission or call commands. */
internal class PcmCommunicationRoute(private val manager: AudioManager) {
    private val oldMode = manager.mode
    private var selected = "earpiece"
    private var active = false
    fun start() {
        active = true
        manager.mode = AudioManager.MODE_IN_COMMUNICATION
        select("earpiece")
    }
    private fun devices(): List<AudioDeviceInfo> =
        if (Build.VERSION.SDK_INT >= 31) manager.availableCommunicationDevices
        else manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList()
    private fun bluetooth(device: AudioDeviceInfo): Boolean =
        device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
        (Build.VERSION.SDK_INT >= 31 && device.type == AudioDeviceInfo.TYPE_BLE_HEADSET) ||
        device.type == AudioDeviceInfo.TYPE_HEARING_AID

    @Suppress("DEPRECATION")
    fun select(value: String) {
        check(active && value in listOf("earpiece", "speaker", "bluetooth"))
        if (Build.VERSION.SDK_INT >= 31) {
            val device = devices().firstOrNull {
                when (value) {
                    "earpiece" -> it.type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
                    "speaker" -> it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                    else -> bluetooth(it)
                }
            } ?: error("route_unavailable")
            check(manager.setCommunicationDevice(device))
        } else {
            if (value == "bluetooth") {
                check(devices().any(::bluetooth))
                manager.isSpeakerphoneOn = false
                manager.startBluetoothSco()
                manager.isBluetoothScoOn = true
            } else {
                manager.stopBluetoothSco()
                manager.isBluetoothScoOn = false
                manager.isSpeakerphoneOn = value == "speaker"
            }
        }
        selected = value
    }

    fun snapshot(): Map<String, Any> {
        check(active)
        val available = devices().any(::bluetooth)
        if (selected == "bluetooth" && !available) select("earpiece")
        if (Build.VERSION.SDK_INT >= 31) {
            manager.communicationDevice?.let {
                selected = when {
                    it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
                    bluetooth(it) -> "bluetooth"
                    else -> "earpiece"
                }
            }
        }
        return mapOf("selected" to selected, "bluetooth" to available)
    }

    @Suppress("DEPRECATION")
    fun stop() {
        if (!active) return
        if (Build.VERSION.SDK_INT >= 31) manager.clearCommunicationDevice()
        else {
            manager.stopBluetoothSco()
            manager.isBluetoothScoOn = false
            manager.isSpeakerphoneOn = false
        }
        manager.mode = oldMode
        active = false
    }
}
