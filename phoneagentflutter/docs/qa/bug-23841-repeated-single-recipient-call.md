# Bug 23841 连续单人外呼回归

## 批准与候选

2026-10-29 用户批准所有相关 Skill 每次合法单人外呼进入原通话页，保留门禁和多人流程；要求独立测试后推送 test_v1.8.0_fix，再打测试签名包，不安装。沿用用户指定 1.0.54+47。

源：禅道 Bug 23841（Phone Agent 安卓），截图与 diagnostics (7).zip 已读取；无独立 Demo。起点 Flutter e02e4b208f300baa78bd3e7745dadebb21f673c3，与开始时 origin/test_v1.8.0_fix 一致。Java 仅作只读分析，没有服务端修改或部署。

## 现场与机制

日志中首批次有 75 次通话观察 GET，第二次确认后的新批次已有 SDK RINGING，却没有对应查询。后端规范化流不发送 makeBatchCalls toolStart；观察器原本仅借该事件清除旧命令/批次，而 finish 释放页面后保留身份，阻止下一批次建立观察。

产品修复仅在 BatchSingleCallController：先验证一人进度，只有前批次已 finish、命令和批次均为新身份时重置本轮观察；活动批次及停止保护不靠工具提示清空。已结束和多人批次集合保留。SDK launchReady/归属查询/物理闭合、批次停止、确认和拨号请求不变，无 Skill 白名单。

## 自验

- RED：修复前，控制器第二批次读取次数为 0；活动工具提示可错误替换原观察。跨三个 Skill 的连续页面用例也在第二轮未建立观察。
- GREEN：两份 batch_single_call 控制器/页面测试最终共 23 项通过；包含三个 Skill 各三次外呼、每次先不展示再 SDK ready 展示、历史进度不覆盖、结果后回原会话、停止后新执行、原同批重试/恢复/多人门禁。
- 独立挑战补齐：旧停止请求在批次 finish 后晚返回，不能吞下一合法执行的进度；新执行重置本轮停止在途标记，旧 finally 仅能释放原 observer 的标记。仓库新增该时序及旧请求不能解除新停止门禁的 RED→GREEN 回放。
- 扩大回归：calls 全目录，加 conversation 确认/停止/批次/回执，768 通过、27 失败；未把此轮标为全绿。完整日志 D:/Temp/phoneagent-bug23841-validation-20261029/regression.log。独立 agent 对全部 11 个失败文件在候选与 e02e4b20 基线各重跑，均 65 通过/27 失败；规范化完整失败用例名逐项比较，27/27 相同、差异 0，均为既有失败。
- 全工程 flutter analyze --no-pub：无问题。OpenSpec 严格校验通过，git diff --check 通过。

## 独立验收与交付

独立 agent 已重新读取禅道最新正文、历史、截图与诊断附件，重建验收项并给出代码层 APPROVE。原 3 项独立挑战保持原断言全部通过，连同控制器/页面、普通通话会话与拨号协调器共 58 项通过。独立全工程 analyze 无问题，diff --check 通过。报告：D:/Temp/phoneagent-bug23841-independent-20261029/independent-report.md。

已完成：源码与自动连续页面/竞态/门禁回归、推送及测试签名包核验。未通过：27 项已独立确认的基线失败，未在本修复内修改。缺证据：修复后真机通话画面/音频/真实外呼，按本次边界没有安装或拨打；自动页面测试不代表真机通过。

## 推送与测试签名包

- 修复提交：2d86279aaa0c187796519afa37be5762ce877d08，中文提交，已快进推送 origin/test_v1.8.0_fix；Java 未修改、无需部署后端。
- 从干净且已推送的上述提交构建。沿用注册构建计划，版本显式使用获准 1.0.54+47；Flutter 3.32.0/Dart 3.8.0/JDK17，先 Release --config-only --pub，再使用现有缓存同版本引擎离线 Gradle。BUILD SUCCESSFUL，477 项任务。
- APK：deliveries/bug23841-test-20261029_114734/Phone_Agent_TEST_1.0.54_47_test_20261029_114734.apk（仅规范化交付文件名，签名和哈希未变）。
- SHA256：28150c902b95626cc7b77bc0fd34e1ff79c599364efdea8db028db45c1c51154。
- 原项目证书 MD5：ebd4c931de412bf5d9c3716815389097；包名 com.vvtech.aiassistant.test；非 debuggable、仅 ARM64、Release AOT；AOT SHA256 a5d8c4c5166744d07b1482b60f8711c3cf6928b4ed3804f37f9faa23cc0c437a，与前包不同。
- Agent/SDK/Runtime 均为 chakenai-test.vvtech.tech 对应 aiassistant-api/aiassistant-sdk-api/aiassistant-runtime；邀请 host/scheme 也是 test。自验受控 JNI 12 项、assets 8 项字节一致，无私有签名/defines 文件混包。
- 本机产物与构建日志：D:/Temp/phoneagent-bug23841-validation-20261029。独立 agent 实际重新核验 APK 的包名/版本/证书/Release AOT/ARM64/test 路由/JNI 和 assets，全部通过；证据 D:/Temp/phoneagent-bug23841-independent-20261029/apk-independent-result.json 及 apk-*.log。不安装；包内静态路由与构建输入核验不代表真实网络请求或外呼通过。
