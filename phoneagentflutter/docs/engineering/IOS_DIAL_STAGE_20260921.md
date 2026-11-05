# iOS 拨号／翻译扩展阶段（2026-09-21）

代码基点 `f96a105` 加本批测试转场等待修正（正式lib未改）。这是共享页面的隔离MOCK阶段，不是真实电话、声音、后台归档或全迁移验收；Android本批没有安装。

## Preconditions

- Flutter 3.32.0、Xcode 15.2、iPhone iOS 16.7.16；仅测试包 `com.chaken.phoneagent.test`。
- 通过Mac主机名SSH、显式加载既有工具链、复用解锁screen；不修改Apple ID、钥匙串策略或全局Xcode选择。
- 新临时构建目录从Git提交导出的源码包展开；本机/Mac包SHA-256一致。三份关键文件按Git规范化换行后blob ID与提交一致，原普通App目录保留恢复保障。
- 复用`integration_test/shared_stage_test.dart`及`dial_translation_stage_pages.dart`，安全存储和原生拨号通道设失败防线，误触发仍判失败，不转发设备能力。

## Build / Install

- 测试入口Xcode编译158.2秒，严格深度签名验证通过；自动安装启动46.8秒，VM服务已建立。
- 用`tool/run_shared_stage.dart ios <device> <local-vm-url>`附加，固定`--use-existing-app`和`--keep-app-running`；不使用会卸载的默认drive，不记录调试认证URL。
- 首轮01–21通过后在clearNumber定位到两份按钮：iOS转场尚未完成，固定350ms等待不足。仅测试tap改为等待转场稳定，模拟媒体ready的主动等待除外；没有取first、放宽断言或修改页面。两尺寸Android/iOS主题共4预检通过，analyze无问题。
- 同一设备进程热重启1670ms加载修正；最终源码文件SHA-256与Windows相同。驱动再次附加，约126秒通过、`Leaving the application running.`。结果UTC `2026-09-20T16:38:23`，25张750×1334截图、26完成步骤、`completed=true`、`nativeStorageCalls=0`、`agentCommands=2`，原生拨号0调用断言通过，无新短信/真实电话。
- 首轮失败独立保存在Mac的`ios-first-failure`和失败日志；最终结果/截图在Windows `.local/dial-stage-20260921/ios/`，不提交调试认证URL或临时截图。
- 最后构建同一正式lib基点的普通`lib/main.dart`测试环境入口，Xcode38.5秒、严格签名通过，自动安装启动47.4秒。实时getVM返回`ios/main`、PID16152；普通截图确认登录页、无MOCK横幅（`.local/dial-stage-20260921/normal-restored.png`），不宣称已登录，未发送验证码。保留screen与普通Flutter调试进程，原备份目录未删。

## User Actions / 自动路径

原01–21沿用[上一阶段](EXTENDED_DEVICE_STAGE_20260920.md)。新增22区号搜索空态/美国、普通呼叫模拟；23语种及翻译模型；24确认取消重进、媒体就绪/接通/双语字幕、静音/扬声器/拨号盘及DTMF；25挂断后返回及最近记录。共享脚本先清除前一段联系人回填号码，小屏先滚动使操作可见。

实际查看01/04/20/22/23/24/25七张截图：对应首页、对话候选、音色、国家搜索及新增翻译状态。所见区域可读、通话底部按钮在安全区内；23/25保存的是滚动到配置/拨号盘后的视口，顶部号码/最近记录不在截图内，最近记录存在由脚本断言，不声称其视觉已查看。24打开键盘会压缩字幕区，未查看的长内容及系统键盘不能据截图数量判通过。MOCK横幅占据高度，视觉精校仍后置。

## Expected Logs / Forbidden Logs

- 期望：`All tests passed.`、`Leaving the application running.`、结果`completed=true`、`nativeStorageCalls=0`、`agentCommands=2`，01–25截图完整。
- 禁止：原生拨号零调用断言失败、存储访问断言失败、未处理异常、`RenderFlex overflow`、`[E]`、App崩溃、真实短信/电话/SDK采集；截图不是像素验收。

## Pass Criteria / Failure Follow-up

必须分别确认流程断言、截图内容、保留安装、普通测试环境包恢复及实时VM；任何缺项按未验报告。失败先检查同一运行进程和具体状态，不因观察超时重启；两轮无新证据停止盲重试。真实外部能力留[集中清单](MIGRATION_HANDOFF.md)由用户统一验收，Android普通包/登录恢复不从本报告推断。

本轮结论：上述iOS共享交互阶段及普通入口恢复通过；七张阶段截图检查范围如上，不扩展为25状态全视觉验收。未执行Android新增检查点、真实iOS登录或外部能力；整体迁移目标仍未完成。
