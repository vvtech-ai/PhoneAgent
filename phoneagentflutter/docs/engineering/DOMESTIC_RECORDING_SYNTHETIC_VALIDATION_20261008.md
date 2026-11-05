# 国内录音合成编码验证（2026-10-08）

使用独立模拟器包运行实际 Flutter 编码端口及生产原生 AAC 编码器，仅输入一秒静音加一秒 440Hz、16k 单声道本地合成 PCM。未录制麦克风、登录业务账户、连接模型/SIP或上传。

| 项目 | Android | iOS |
| --- | --- | --- |
| 采样率 | 16000 | 16000 |
| 声道 | 1 | 1 |
| 解码时长（秒） | 1.984 | 2.0 |
| 解码帧数 | 31744 | 32000 |
| 静音 RMS | 0.0 | 0.0 |
| 音调 RMS | 0.23709005404791184 | 0.23732989626122755 |

Android：`emulator-5554`，独立包 `com.vvtech.aiassistant.synthetic.recordingprobe`；iOS：`C1837C32-89DC-440D-B18F-3B06CC24EC8E`，独立包 `com.vvtech.phoneagent.synthetic.recordingprobe`。两端普通开发包安装元数据前后相同。Android 验证演练 APK 无网络、麦克风、相机、电话、通讯录和位置业务权限；iOS 仅注册生产编码通道及合成解码检查通道。

两端产物均能实际解码为 AAC-LC。Android 短样本容器时长与物理输入相差 16ms，归档时长仍以物理通话窗口为准；48kbit/s 是编码目标，不以短样本文件大小推断平均码率。

## 可复现入口

参见 [独立演练说明](../../tool/recording_probe/README.md)。执行期间校验全部演练源及实际编码源 SHA256 前后相同；证据、音频和构建产物保存在 ignored `.local/recording-probe/`。Android 演练后重新构建普通 debug APK，避免共享构建输出保留演练包身份，不安装或替换普通 App。

## 源码及产物摘要

### Android

合成 M4A SHA256：`85592283e4e9e4d943f976f2d83eda5efb9388ecaba29c3154adfc1b4c1c3645`。

- `lib/features/translation/data/recording/device_domestic_recording_encoder.dart`：`e1b0d79664a57b7d7f1e5da197dd8110f2a5d0de7214b91874547717dcc733e0`
- `android/app/src/main/kotlin/com/vvtech/phone_agent/DomesticAacEncoder.kt`：`c75c809801773ebca7b7a64694dafeb9d8312e4e68e319eb489bcffe1adceac7`
- `android/app/src/main/kotlin/com/vvtech/phone_agent/DomesticRecordingChannel.kt`：`27308efc2f3aa56e71372412c41ef04906b50b6c901fb0c81d0d8066422d1040`

### iOS

合成 M4A SHA256：`03b859f859731c9b38a5e79bb4da5ddf8f21046ef6d9a80e7accf390779d5293`。

- `lib/features/translation/data/recording/device_domestic_recording_encoder.dart`：`e1b0d79664a57b7d7f1e5da197dd8110f2a5d0de7214b91874547717dcc733e0`
- `ios/Runner/DomesticRecordingChannel.swift`：`41c918570192735775a38e70b96743d4bdaa72790b002bbf248f825f4ff6b287`

本项只验证模拟器合成音频的实际编码、解码和文件格式，不代替真机通话录音、混音听感、锁屏中断、真实归档上传、服务端结算或整体验收。没有将真实设备验收任务勾选完成。
