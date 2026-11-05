# Web 优先研发基础验证（2026-09-16）

状态：共享 Web 开发入口和基础真实文字闭环已通过；全部 UI、复杂工具、音频和 iOS 本批验收尚未完成。不是整体验收报告。

登录/邀请码后续补充：独立合成入口复用正式页面与状态，浏览器错误/返回/成功、保存与恢复失败重试已验证，不重新发送短信。334项全量测试，现一键Web为174项认证/会话/视口+2 Chrome+1 Node。详细使用和边界见 [登录 Web 验收](AUTH_WEB_VALIDATION.md)；下文历史批次数字保留为当时证据。

## 使用

## 移动视口与连续交互补充验证

- `test/features/conversation/conversation_viewport_test.dart`：320/390/430 宽，568 高、300 键盘 inset、1.3 字体；空会话/中断/恢复失败共9例，另有长候选滚动选择。修改前空会话溢出92px，异常态最高184px；修改后无溢出，关闭和输入可达，恢复操作能滚动点击。
- `conversation_navigation_test.dart`：三种手机宽度下直接运行正式 PhoneAgentApp，使用合成 repository/gateway。任务列表→CLOSED会话恢复→同页文字→发送→候选→序号回复→关闭→恢复→系统返回→翻译失败重试→无session记录开新对话。恢复不增加命令，文字使用voice业务channel，仅发2条合成命令。
- `conversation_visual_contract_test.dart`：新增草稿在语音/文字切换及拒绝提交时保留、接受后清空。原Header尺寸/SVG契约继续通过。
- `scripts/web/verify.ps1` 从小范围controller测试扩展为整个conversation目录：122项布局/会话测试、2项Dart Chrome传输测试、1项Node代理测试通过。全量263项Flutter测试、analyze、Web debug build、16项OpenSpec通过。
- 实际浏览器普通入口刷新保登录；320×568进入订餐厅，切文字填写“布局回归草稿，不提交”，再以320×268验证窄高度；关闭和输入可见，无黄黑溢出条；文字→语音→文字后截图确认草稿仍在。最后关闭回首页，恢复浏览器默认视口。未发送草稿，未外呼/短信/保存账号设置。
- 浏览器可视高度调整是键盘压缩的布局近似，VM测试则直接设置viewInsets；二者均不能替代手机系统键盘/安全区验收。本次未重装Android/iOS，沿用总清单中的上次版本与安装限制记录。
- 这批仅修交互适配并扩大自动回归，不宣称完整UI还原；新卡片设计运行态来源仍缺可访问地址，四阶段业务推进/完整执行协调也未在本批实现。

## 身份与模型只读回归（2026-09-16 后续批次）

- 普通入口复用持久登录，设置→我的身份加载真实资料→编辑→取消→返回，全程不保存/删除。页面数据不抄入 fixture 或提交截图。
- 设置→语音大模型显示四个服务端模型；只打开已选 Seeduplex 的音色入口，显示清朗男声/沉稳男声与当前选中项。未点击其他模型或音色，不产生账号设置写入。返回模型→设置→首页→模型弹层正常。
- 共享代码更新后热重启/浏览器刷新仍保持登录，重新打开身份页。模型/身份展示属于真实接口；身份删除成功/失败/本地持久化失败仅用合成单元/Widget 验证，未对真实账号执行 DELETE。
- 229 项 Flutter 测试、analyze、Web debug build、15 项 OpenSpec 通过；未增加依赖或原生文件，此小批未重装双端，不把上一阶段设备启动证据算作本批身份验收。
- 自动化覆盖新增 8 项：删除副作用单次执行、服务端失败/销毁隔离、本地失败仍保留服务端成功、持久跳过跨实例/环境隔离/非法数据、生产 provider 失效旧音色并读取新默认模型。

## 启动命令

```powershell
powershell -NoProfile -File scripts/web/start.ps1
powershell -NoProfile -File scripts/web/verify.ps1
```

打开 `http://localhost:8080`。8090 为 Flutter 内部服务器，8080 为同源开发入口。脚本拒绝已有端口占用，不自动杀其他进程。Flutter 终端输入 R 后刷新浏览器；停止该启动脚本时清理它启动的代理。

- 与 Android/iOS 共用页面、Controller、Repository 和事件解码；只替换浏览器流式传输，未另建 HTML 业务页。
- 宽屏内容最大 430，窄屏铺满；Navigator 和弹层受同一视口约束。360/390/430/1280 四种宽度有 widget 断言。
- 代理只监听 loopback、固定测试环境上游，检查 Host/Origin/路径，不接受任意 URL，不转发 cookie，不缓存流，不打印请求体或认证信息。没有关闭浏览器安全机制。
- 普通 Web 入口已使用持久登录。一次性安卓会话复用过程及清理见 MIGRATION_ACCEPTANCE.md，后续不依赖临时入口。

## 自动验证

| 项目 | 结果 |
|---|---|
| flutter analyze | 无问题 |
| flutter test | 168 通过（浏览器专用测试另跑） |
| dart test --platform chrome test/core/network/stream_client_web_test.dart | 2 通过：POST 首段在 EOF 前交付、取消及响应头超时传播 |
| node --test scripts/web/dev-server.test.mjs | 通过：Host/Origin/路径、非 API 写入、首段流式、上游取消、cookie 隔离 |
| scripts/web/verify.ps1 | Node + Chrome + 15 项视口/对话回归通过 |
| flutter build web --debug --no-pub（dev + 本地同源 API） | 通过 |
| flutter build apk --debug --no-pub（dev + 测试 API） | 通过 |
| openspec validate --all | 15 通过 |

Flutter 3.32 Windows 的 `flutter test --platform chrome` 在本机加载 CanvasKit 路径失败并停在启动页，未记为通过；未修改 SDK。浏览器传输测试改用不依赖 CanvasKit 的 Dart Chrome runner，布局/Controller 由 Flutter VM 测试，普通 Flutter Web 实际浏览器另做端到端冒烟。

## 真实测试环境冒烟

用已授权测试账号，通过普通 Web 入口执行，不注入假 API：

1. 刷新后保持登录，真实首页动态入口和 Seeduplex 模型加载。
2. 新会话明确只讨论预订信息、不搜索或外呼；ASK_USER 显示实际“订哪家餐厅？”补问。
3. 文字续聊、退出到任务列表、恢复历史，再继续发送摘要请求。
4. 将人数改为三位，页面显示新的摘要。再次退出/恢复，持久历史保留全部测试轮次，默认重新显示语音输入入口。

只创建安全文字测试会话，未提交目标号码或发起真实外呼；模型回答不是固定断言数据。关键 UI 状态通过浏览器截图查看，协议日志仅含事件种类、序号、关联 ID 和字段名，不含凭据/正文。

### 本次真实联调发现并修复

- ASK_USER 的通用 text 曾遮住 questions.items；改为展示结构化补问，保留无问题时的 text fallback。
- SSE 仅收到后续持久事件时，原实现直接拒绝序号缺口。现只读补齐持久时间线，不重发用户 POST。
- 同一事件在 SSE 和 REST 的 occurredAt/committedAt 不同，原实现误判冲突。合并时仅这两个时间字段允许使用 REST 权威副本；内容、归属、身份、序号和其他元数据仍严格检查。历史内部重复仍使用完整指纹。
- 补了缺口补齐、退出时晚到、时间差及内容/归属冲突测试。并非放宽所有冲突或忽略历史错误。

## 平台与剩余工作

- Android 普通 debug 包覆盖安装成功；普通入口重启后仍登录，首页和模型加载，无清数据、无覆盖原正式 App。此处是启动/登录阶段冒烟，不是所有新页面的真机视觉验收。
- iOS 本批版本 8ae1fcb 已在 Mac 用固定 Flutter 3.32、锁文件及已解锁 phoneagent-build 会话编译签名，严格验签通过；iPhone 8 安装并由 Flutter 调试器自动启动成功，实际截图为新版登录页。截图 `.local/ios-web-stage.png` 不入 Git。设备没有本批账号登录态，未重发短信；登录后的全部页面仍需后续阶段验证。
- Mac 直接 GitLab clone 返回 403；没有索取或复制 GitLab 凭据。用当前已提交分支的 Git bundle 同步到独立 PhoneAgentFlutterGit 目录，HEAD 严格等于 8ae1fcb3c14a2982cd3bca36227de75871543b03，原 B0 目录保留。远端 origin 保持正式地址，直连鉴权待环境配置；bundle 为安全同步替代，不是未提交源码拷贝。
- 调试器继续运行在原持久 screen；自动化仅 Ctrl+A、D 分离自己的终端，没有退出或关闭已解锁 shell。此处不声称脱离调试器冷启动已解决。

## 2026-09-16 后续 iOS 同步：121015a

- 只读检查发现 PhoneAgentFlutterGit 有 CocoaPods 生成但未提交的 ios 配置、Podfile/lock；没有覆盖、清理、reset 或把这些改动混入上游。
- 从 Windows 已推送提交 121015a4a8c954a2f1c020fbb5c27de50633038e 生成 Git bundle，在 Mac 独立 `Development/PhoneAgentFlutterStage121015a` 克隆并核对 HEAD；origin 保持用户指定 GitLab。原 B0 与 Git 构建目录均保留。
- 接入原 phoneagent-build screen，只结束旧 Flutter 调试进程以安装新版，保留解锁 shell；source 固定 ios-toolchain/env.sh，Flutter 3.32.0、原 pubspec.lock 未变。新目录的 CocoaPods 依赖由 Flutter 正常生成，不改变系统 Xcode 选择或钥匙串策略。
- `flutter run -d 663ad7ad67c8361245b2a36bfc2d7aceafebbaef --debug --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=https://agent.vvtech.tech/aiassistant-api/`：Xcode build done 84.5s，安装/启动 33.9s，Dart VM 调试服务启动并同步完成。
- `/usr/bin/codesign --verify --deep --strict .../build/ios/iphoneos/Runner.app` 返回成功（SIGNATURE_VERIFIED）；测试 Bundle ID 与既定身份未变。没有采集密码、新验证码或修改签名 ACL。
- 本阶段证据是签名构建/真机安装/自动调试启动，不包含新的 iOS 截图、真实登录或回执全流程；旧登录页截图仍只对应 8ae1fcb。本次单路版本之后的批量快照增量尚未同步到 iOS。
- 自动化完成后 Ctrl+A、D 分离 SSH，screen 与最新 Flutter 调试器继续运行。后续可从该独立目录复用；若要合并任何 Mac 本地有意义改动，先审查并按里程碑规则保存。
- 统一页当前基础布局与设计仍有差异，工具卡、回执、附加内容、录放音等未完成；优先继续 Web 完善。联系人/拨号/翻译/设置等总范围见 MIGRATION_ACCEPTANCE.md。
- 浏览器中的手机能力后续以明确的 fixture/模拟适配供 UI 回归，真实能力仍必须实现并在对应平台验证；不能伪造认证、拨号或录音成功。
