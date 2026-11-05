# 音色试听按钮灰圈修复（2026-10-10）

## 问题与修改
用户截图对应音色选择弹层，共用NativeVoiceSelectionRow覆盖系统音色和克隆音色。原实现InkWell为48×48、中心x24；38×38圆形靠右、中心x29，相差5像素。Ink绘制在外层Material且被不透明圆形背景遮挡，露出偏左灰圈。

保留48热区与现有38视觉位置，改成圆形局部Material承载InkWell并antiAlias裁剪；按压/焦点/悬停为低透明蓝色。外层GestureDetector处理热区边缘，禁用时吸收点击，避免落到行选择。加载17、播放/停止19图标均保持同一中心，音频/选择/确认/计费端口不变。翻译录音播放控件结构独立，没有此48与38错位，不扩大修改。

## 原生来源
- Android固定0f8879e4baf1d56fe6d7f8f356101fdf61d602ed：AssistantRealtimeCallVoiceSelectionRow.kt，Surface38/CircleShape包住反馈，F2F7FF与19图标。
- iOS固定bb9ff34966f40a3c2794a9a8b8e935669a9faa12：iOS/PhoneAgent/PhoneAgent/Features/Settings/AISettingsRealtimeCallVoiceViewController.m，preview38、radius19及中心spinner。工作目录HEAD已是bf2b652，另用git show读取固定提交，参数一致；未修改原生项目。

## 自动验证
- OpenSpec全部63项通过。
- Flutter3.32.0/Dart3.8.0，flutter analyze --no-pub无问题。
- 定向134项通过：test/features/call_models、clone_management_page_test、clone_creation_page_test、clone_preview_semantics_test、shell_clone_workbench_test。未执行全量回归。
- 新绘制回归两端RED：按下后圆外白色变为0.949灰；修复后GREEN。先前首次采样未推进高亮动画，补齐按下后150+100ms帧后复现真实灰圈，未将计时不足当产品新缺陷。
- 最终显式加载MaterialIcons字体，绘制/2x滚动专项4项再通过。覆盖默认/按下/释放/取消/快速三连点/加载/播放/禁用、列表滚动取消及尾部可达；既有几何测试继续覆盖48热区四边及独立行选择。

复现绘制：
```sh
/Users/Eason/.cache/phoneagent-flutter-3.32.0/flutter/bin/flutter test --no-pub \
  --dart-define=VOICE_INK_CAPTURE=true \
  --dart-define=VOICE_INK_ICON_FONT=/Users/Eason/.cache/phoneagent-flutter-3.32.0/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf \
  test/features/call_models/voice_preview_ink_alignment_test.dart
```

## 隔离运行证据
参考入口tool/native_ui_reference/voice_preview_reference.dart直接使用正式控件；全部状态为内存合成，不注册播放端口，不访问账号/网络或输出音频。首行点击在默认/加载/播放间循环，用于UI检查，不代表真实播放。

- iOS：独立com.vvtech.phoneagent.ui.voicepreview、C1837C32-89DC-440D-B18F-3B06CC24EC8E，复用纯Flutter+NativeParagraph宿主（Frameworks仅这两项）。实际点击克隆试听→加载→停止图标，AX标签同步；截图已查看。执行脚本run_voice_preview_ios.py，构建目标为本fixture；普通业务App不替换。完成后关闭本次启动的UI模拟器，不干扰其他已启动sim。
- Android：独立com.vvtech.aiassistant.ui.flutterreference，init脚本只对本显式构建生效；固定JDK/Flutter、构建成功，-r保留安装到本次启动的PhoneAgent_Clone_20261009 emulator-5554。冷启动后默认/加载/播放/禁用同屏截图已查看。CUA应用清单未暴露Emulator，未使用其他UI输入绕过；实际点击状态转换保留待验，双平台widget事件测试通过不冒充Android设备触摸验收。
- 普通真机未操作、未卸载/清数据/授予权限；真实音频和完整业务弹层的真机用户视觉验收待验。

原始截图均在.local/ui-reference/voice-preview-ink：android-pressed.png、iOS-pressed.png、iOS-released.png、iOS-loading.png（已查看）；ios-runtime-loading.png、ios-runtime-playing.png与android-runtime-cold.png（运行图已查看）。绘制图文字用测试字体，图标显式加载，不作为整页字体验收。

## 故障恢复
1. 原PhoneAgent_UI_20261006 AVD指向已失效/tmp配置，报CPU Architecture arm不支持；读取.ini与设备状态后改用现有独立Clone AVD。
2. 首次Android参考截图出现System UI isn't responding；实际查看后关闭本次iOS UI模拟器释放资源，保留数据重启隔离AVD一次并禁用快照加载/保存。12秒启动完成，重新启动已安装参考包，截图无弹窗；故障旧截图保留，不作为通过证据。
3. CUA getApp(qemu-system-aarch64)无效，重新listApps没有Emulator；不再重复失败输入，继续ADB只读截图及widget验证。
4. 固定iOS git show首次缺少仓库iOS/前缀，按rev-parse --show-prefix读取实际路径后成功，无副作用。

## 提交边界
仅共用行1源码、专项1测试、隔离工具2文件及本次规格/记录。源码微批2文件、工具微批2文件、格式化独立。均小于500行。已有pubspec.lock差异保留，不提交、不自动更新依赖。OpenSpec active保持至用户验收。
