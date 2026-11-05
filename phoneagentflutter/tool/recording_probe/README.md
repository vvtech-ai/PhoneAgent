# 独立合成AAC编码验证

仅用于显式debug模拟器验证。输入为本地16k单声道PCM（一秒静音和一秒440Hz正弦波），直接调用生产Dart/原生录音编码端口，再用平台解码器检查AAC、16k、单声道、约两秒及静音/音调能量。没有麦克风采集、真实用户fixtures、账号、SIP、模型或上传。

Android包`com.vvtech.aiassistant.synthetic.recordingprobe`；iOS包`com.vvtech.phoneagent.synthetic.recordingprobe`。普通包不覆盖、不卸载、不清数据。产物/报告均在ignored `.local/recording-probe/`，合成音频留在独立演练私有目录。报告包含生产源码SHA，不能把模拟器合成编码当真机通话录音或后台听感验收。

```sh
python3 tool/recording_probe/run.py android --device emulator-5554
python3 tool/recording_probe/run.py ios --device <明确已启动的模拟器UDID>
```

固定Flutter3.32/Dart3.8、Android Studio JBR。Android仅支持显式assembleDebug并核验application id和业务权限移除；iOS只注册实际DomesticRecordingChannel及工具解码检查channel。不会因错误回退卸载。失败日志保留在ignored目录，先检查实际状态再有限重试。运行普通构建不带inject.gradle，恢复普通开发包产物。

2026-10-14新增真机隔离探针（仅显式指定设备运行）：
```sh
python3 tool/recording_probe/run_device.py --device <connected-iPhone-identifier>
```
只使用本机已有且覆盖目标设备的通配开发描述文件；不创建Apple签名资源。独立包为`com.vvtech.phoneagent.synthetic.recordingdeviceprobe`，不覆盖普通App、不使用麦克风/账号/真实音频。先以POSIX realpath模拟生产Dart目录，再调用实际生产编码通道，解码两秒AAC并验证四类非法输出/输入被拒绝；报告及签名产物仅在ignored `.local/recording-device-probe/`。普通App安装元数据前后必须相同。此验证不替代实际外呼、历史上传及播放全流程验收。
