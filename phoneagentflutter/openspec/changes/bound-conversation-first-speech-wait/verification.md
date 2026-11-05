## 本地验证

- RED：连续无标点 delta 从首个片段起 800 ms 的断言在旧实现下失败，`players.single` 仍为空。
- GREEN：`conversation_speech_controller_test.dart` 9/9 通过；直接调用方 `conversation_speech_integration_test.dart` 和 `speech_start_diagnostics_test.dart` 合计 10/10 通过。
- `flutter analyze --no-pub` 无问题；本 change 的 `openspec validate --strict` 有效。
- 用户指定的 test Debug 1.0.52 (45) 已成包：`com.vvtech.aiassistant.test`、`debuggable=true`，登记签名证书 MD5 为 `ebd4c931de412bf5d9c3716815389097`；三条 test HTTPS 路由嵌入 Debug kernel，邀请域名与 scheme 为 test；私有输入文件未混入 APK。ARM64 的 12 个工程内 AAR JNI 库与 APK 逐项 SHA256 一致。Debug 保留供应商库的其他 ABI；仅 ARM64 是现有 test Release 规格要求。
- 未安装或在测试手机试听。该本地结果仅证明客户端等待有界，不证明实际首声从 2 秒缩短到指定值；诊断中另有两次 Qwen 复用轮无首音，未由本改动解决。

## Push 前 Markdown 切段回归（2026-10-23）

- 原 800 ms 改动会使未闭合围栏、链接和强调提前入队。嵌套链接、平衡括号 URL、四反引号围栏、尾随空格关闭行、跨 delta 图片、普通 `!` 后方括号、未闭合强调与 64 KiB 缓冲上限均先由定向用例复现失败，再做局部修复。
- 普通流式正文在分句前过滤上述 Markdown 控制内容；强调切段清理不作用于最终结果、确认提示或开场。最终结果字面 `*123#` 的回归先失败后通过。旧的结果 Markdown 清理范围和 Qwen 复用轮无首音不属于此修复。
- 最终 7 个相关测试文件 70/70 通过，`flutter analyze --no-pub` 无问题，4 个 Dart 文件格式检查无变化，`git diff --check` 与本 change 的 OpenSpec strict 校验通过。
- 此前已构建的 test Debug 1.0.52（45）不包含本次 Push 前修复；本次修改尚未重新打包、安装或在测试手机试听，不能以旧包验证新代码。
