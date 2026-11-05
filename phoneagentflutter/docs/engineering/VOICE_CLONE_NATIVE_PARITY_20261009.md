# 声音克隆原生对齐记录（2026-10-09）

## 参照与范围

Android固定提交0f8879e4baf1d56fe6d7f8f356101fdf61d602ed，路径`/Users/Eason/Desktop/Git/AIAssistant1/android`；iOS固定提交bb9ff34966f40a3c2794a9a8b8e935669a9faa12，路径`/Users/Eason/Desktop/Git/AIAssistant/iOS`。iOS工作区后来推进，音频策略仍按固定提交的`iOS/PhoneAgent/Core/Services/AIAliyunFaceAuthAdapter.m`核对。仅声音克隆，不修改设置其他业务。

## 功能矩阵

| 业务 | Flutter实现与本次处理 | 证据/边界 |
|---|---|---|
| 入口、模型和300积分提示 | 复用正式身份页、模型选择与钱包准入 | 共用页面测试；未真实扣费 |
| 授权、身份表单、人脸跟读 | 复用正式认证工厂、API与原生SDK端口 | 合成身份隔离操作；真实SDK待授权 |
| 生成、候选、状态恢复 | 保持服务端权威与未知结果只读恢复；新增失败原因映射，HTTP/供应商未知反馈转友好提示，处理中不暴露历史错误 | API/Controller定向测试 |
| 候选退出 | 任意来源未确认ready候选退出恢复系统声音；只在本次认证录音可保存且勾选保存时提示丢弃，成功退出去重 | 三种来源、勾选、重复退出及既有失败重试测试 |
| 试听、确认、保存复用 | 保留正式播放/确认/录音仓库；下一模型复用保存录音，不再次认证 | 隔离连续流程与账号/模型隔离测试；无真实音频 |
| 模型音色管理删除 | 保留取消和确认删除、当前模型隔离、页面刷新；不删除另一个模型或认证录音 | Android隔离连续流程及定向测试 |
| iOS认证音频 | 相机及麦克风授权后、verify前设置PlayAndRecord/Default/DefaultToSpeaker；注册/MetaInfo不配置，不调用setActive；SDK持有期间不重新配置，不恢复旧快照 | 原生注入session 10断言、iOS编译；真实录音待验 |
| SDK取消与后续播放 | 保持不可抢占共享租约，取消回执不视为实际释放；完成回调和容器关闭后交接，试听明确Playback | 延迟释放专项及播放器测试 |
| Android适配 | 沿用已有权限/SDK与共享媒体端口，无新增生产权限/依赖/构建基线 | 独立模拟器构建和流程；真机SDK待验 |

## 实际验证

- 第一轮相关clone/call_models/identity/钱包/Shell/audio集合564项通过；补充后最终相关集合322项通过。两轮重叠，不累计。最终analyze无问题。
- iOS真实生产目标Debug无签名编译通过。首次新增Objective-C源文件未进入已生成Pods导致链接失败，重新pod install后通过，无Podfile.lock变化。
- Android独立克隆stage编译及连续流程通过：选择、同意、合成认证、候选、试听状态、确认保存、第二模型复用、管理取消及删除。SDK/安全存储通道禁止调用，未发生上传/扣费/真实音频。独立包`com.vvtech.aiassistant.ui.clonestage`，仅本机VM网络权限；普通App未卸载或清数据。
- iOS独立模拟器`PhoneAgent-Clone-20261009`运行生产页面的合成Shell：选择、同意、身份表单、候选、退出警告、确认、录音复用及无警告退出已操作查看。
- Android固定原生纯结果组件已安装到独立模拟器查看；Flutter连续流程截图含演练外壳，不能声称整页像素一致。Android截图目录`.local/shared-stage/voice-clone/android/`；iOS选择/候选截图`.local/voice-clone/ios-picker.png`、`ios-candidate.png`。均本地忽略、不提交。
- 截图时发现最终删除图截到了退场弹层，已增加渲染/合成器等待并复验。正式业务断言不依赖截图。

## 待验与限制

真实SDK权限拒绝/恢复、中断/蓝牙/其他媒体竞争、真实跟读音频质量、上传、收费/积分、双端真机及用户视觉验收未完成，不能用mock或编译替代。真实身份/音频和收费授权问题尚未得到答复；change保持active，不归档。没有新增任意音频导入或独立录音业务。

## 身份页导航反馈修正

用户运行反馈发现“身份→声音克隆”返回设置。此前合成验证只检查克隆模型出现，未断言身份来源仍在栈中，覆盖不足。Flutter原接线先pop身份再由Shell启动克隆，现改为在身份页上打开；取消、退出、完成均回身份，显式返回身份才回设置。新增iOS/Android身份保留、取消、退出和返回设置断言，既有连续认证/录音复用测试同步原生返回路径。最终相关80项通过；本批无真实SDK/上传/收费，其他并行改动不纳入提交。

本次导航修正analyze4.0秒通过；Android隔离stage九步51秒通过，模型选择截图已查看背景为“我的身份”。iOS仅本批平台路由回归，未做新的设备运行；普通包未更新安装。

## 真机目录错误反馈修正

设备确认XFeng iPhone15，Flutter包com.chaken.phoneagent.test，1.0.0(2026100913)；原生com.chaken.phoneagent 1.0.46同机存在。只读核对版本及诊断目录，未重装/清数据/读取身份或凭据。诊断为加密归档，现有通用accountRequest日志无目录请求归因及解析错误原因，本次未获得那次请求的HTTP状态/响应，因此现场根因仍未确认，不把协议修复当成真机已恢复。

已确认协议缺陷：iOS AIJSONDecodeGsonModel允许current/candidate空值，Flutter之前拒绝current空值；已映射为空资产。models空/缺省按原生空目录处理，非空资产归属、重复ID、available类型及候选状态仍严格校验。错误分类为网络/登录/会话变化/配置/数据/服务异常，界面不输出原始响应。Android/iOS原生picker都没有“重试加载”按钮或额外空态入口，已移除，保持关闭后重新进入加载。

iOS独立目录fixture使用生产ApiCloneCreationPort和CloneCreationSheet，HTTP adapter合成503以及current/candidate=null响应：失败提示可见且无重试按钮，关闭切换合法目录后两个模型正常显示。仅模拟器合成UI，不是真实服务恢复证明。截图.local/voice-clone/ios-catalog-null-current.png，工具入口tool/voice_clone/catalog_reference.dart；独立包com.vvtech.phoneagent.ui.clonecatalog，不注册SDK/存储，不运行认证/计费。

验证：相关320项通过，空目录补充后的最终定向40项/5秒通过（重叠不累计），analyze3.5秒无问题，OpenSpec52通过。未改平台/依赖，不重打生产双端包。原报错真机未更新安装，原请求响应证据与复测仍待验。

## 新包数据异常再次复现

用户明确同一真机已安装修复新包，出现分类提示“声音克隆模型数据异常，请稍后重新进入”，说明现场尚未恢复，前次空值修复不足。再次核对原生：Android VoiceCloneModelFlowMappers与iOS目录模型只读摘要，candidate状态/来源/计费为可缺省字符串，Gson兼容字符串布尔值和标量字符串。Flutter却将完整操作CloneCandidateMapper用于目录，导致缺省或未知摘要被整批拒绝。此次目录独立按摘要映射，READY严格按原生READY+CHARGED，未知/空字段不变ready；有候选选择仍只读恢复。非空跨模型摘要/重复ID/错误对象类型仍拒绝，完整候选和付费端口校验未改。

336项clone/Shell定向17秒通过，涵盖摘要缺省、未知状态、字符串Boolean、跨模型、既有完整候选/认证/确认保护。独立iOS模拟器生产目录解析与弹窗fixture实际显示两个“候选音色待确认”模型，截图.local/voice-clone/ios-catalog-summary.png。无真实服务/认证/上传/扣费。

尝试flutter attach到用户指定XFeng iPhone15的com.chaken.phoneagent.test，未建立VM连接；已请求用户保持前台和弹窗，但未获得调试连接，有限等待后取消未连接的本地attach，没有终止/重装/清理手机App。没有取得真实响应，因此无法确认该次具体拒绝字段，也不能宣称真机恢复；现场复测保持待验。

## 关闭模型选择闪动修正

用户反馈打开模型选择后直接关闭，身份页短暂显示加载数据。已用双端widget回归复现：身份状态在关闭时出现[busy=true, busy=false]。根因为Shell无条件invalidate身份及刷新钱包/音色，原生closeFlow纯关闭并不调用onFlowChanged。路由现在仅在模型被选定并真正进入克隆流程时通知来源；未进入流程的关闭、重新认证取消后关闭不执行业务刷新，保留同一身份Controller与现有内容。实际克隆流程完成后的刷新保持。

80项定向/8秒通过：iOS/Android关闭时全部状态无新增loading且Controller实例相同；连续双模型认证/保存/复用/管理和身份模块通过。纯Dart路由改动，无平台/插件/依赖变化，不重打双端生产包、不安装真机，不声称真机视觉验收；其它并行修改不纳入本批。

## 2026-10-09 生成异常后完整流程复核

本轮用户批准执行重新对齐计划。Android仍为固定0f8879e；iOS工作区HEAD bf2b652，但`AIVoiceCloneModelFlowViewController.m`、`AIAccountSettingsService.m`、`AIVoiceCloneCompletionFailurePolicy.m`与固定bb9ff349比较无差异。参考工程只读，未修改。

| 环节 | 原生证据与本轮结果 |
|---|---|
| 模型/积分/来源页 | 复核原生picker及准入，保留既有300积分、目录摘要、取消不刷身份和来源栈；Shell连续回归 |
| 身份表单/替换 | Android EnrollmentContract失败回到IDENTITY并遮蔽草稿；Flutter保留页面内草稿，按首3末4/姓名首字遮蔽，编辑恢复；不持久化或输出 |
| SDK与音频 | 保留已有权限/PlayAndRecord配置和实际释放租约；本轮未改平台SDK代码或触发真实认证 |
| 认证后生成 | 对齐POST空JSON对象、幂等键、白名单stage；有效候选与可选录音授权分开，失效/跨认证授权不用于保存 |
| 创建失败 | iOS返回模型选择并显示模型层安全错误；Android认证失败回身份表单；录音复用/只读恢复入口失败返回picker；移除额外结果未知独立页，不自动重提 |
| 候选/轮询 | 处理中、失败和ready共用原生结果卡片；未就绪不可试听/设默认，处理中不可退出，保留录音勾选和重新录制；旧轮询不覆盖新流程 |
| 试听/确认 | 保留正式播放器、停止/生命周期和账号模型保护；确认异常在原卡片显示状态错误，原按钮只读核实，不重复确认 |
| 保存/复用 | 确认时开始准备下载，确认成功才提交原子替换，保存独立于路由完成；失败取消待保存事务，未勾选不下载，下次仍由有效存储复用 |
| 重新录制 | 新候选成功前保留旧候选及录音选项，取消/失败可恢复；接收到新候选才释放旧状态 |
| 删除/退出/积分 | 复核既有模型隔离删除、ready退出系统音色恢复、警告条件、重复退出去重及钱包服务端结算观察；保留严格操作归属与计费准入 |
| 诊断 | 区分HTTP、候选生成、候选读取、录音授权格式、录音保存；六种业务stage使用枚举，响应正文/姓名/身份证/授权/音频不输出 |

源码微批按职责推进，候选展示映射及替换快照拆分，主Controller499行，其他本轮手写文件均500以内。未改平台/插件/依赖，不重复构建双端包，不安装真机；外部pubspec.lock不纳入。

复核中修正：首次定向集合误指定不存在的test/app/shell_page_test.dart，核对rg文件清单后改为test/shell_clone_workbench_test.dart；展示映射提取时的state变量编译错误已改为current；新增用例在StateNotifier监听器内同步dispose造成并发迭代异常，按真实路由先失效、后dispose时序修正。全部属于本地验证，无设备/账号副作用。最终验证结果见下方记录。

真实认证、实际响应格式/收费和原生配对真机视觉仍待验。原diagnostics-6仅HTTP及音频生命周期，且截图15:33与日志北京时间19时不一致，不能据本补丁宣称现场根因已证实。

### 本轮最终验证
- `flutter test test/features/voice_clone test/shell_clone_workbench_test.dart test/core/network/account_api_test.dart test/features/app_logs/diagnostic_journal_test.dart test/features/app_logs/diagnostic_archive_test.dart test/features/call_models/clone_delete_controller_test.dart test/features/call_models/clone_voice_controller_test.dart test/features/calls/call_admission_data_test.dart test/features/conversation/history/api_history_test.dart`：最终418项，17秒，全部通过。包含双平台失败返回、遮蔽/编辑草稿、处理中卡片/门禁、替换恢复、下载准备/取消/确认后提交、路由关闭后保存、跨账号及诊断安全回归。
- `flutter analyze`：最终3.6秒无问题。OpenSpec全量58项通过，`git diff --check`通过。相关集合是定向验证，不是全量Flutter回归，之前重叠轮次不累计。
- HTTP状态补充保留到白名单stage异常，用于模型层5xx服务不可用与认证层具体阶段的区别；账号API新增可选白名单参数，不回传正文。refresh局部误替换编译问题已修复，账号刷新/准入/历史直接调用方测试通过。
- 本轮未改变平台/构建链，不重新构建或安装，不触发实际SDK/音频/收费。OpenSpec未归档，现场根因和真机视觉仍待验。

提交前最终OpenSpec59项通过；并发新增agreement变更仅被全量规格校验读取，不纳入本次声音克隆提交。

## 生成返回数据异常修复（diagnostics-7/8）
用户批准按两端原生操作DTO和业务门禁对齐。日志中北京时间20:32:40、20:33:36、20:34:27三次HTTP200后generation/format，没有recordingGrant事件，定位响应/候选解析前段；未取得现场响应字段，不能宣称线上具体值或计费结果。

已证实源码差异：
- iOS Core/Models/AISettingsModels.m:89候选DTO经AIJSONModel.m:21字符串/42 Long Gson兼容解码，支持标量字符串、空缺文本、整数数字字符串、signed Long。Android data/remote/voiceclone/VoiceCloneModelModels.kt采用对应Gson字段；状态/source/billing保持字符串。
- 本地只读PhoneAgentBackend VoiceCloneCandidateTransactionService.java:226以accountId + ":" + modelId生成candidateId。Flutter旧identifier正则禁止冒号，生成/读取及确认前都可能拒绝该合法不透明ID。该源码证实协议冲突，不代表线上部署版本已确认；只使用synthetic-account回归，无真实用户fixtures。
- iOS Features/Settings/AIVoiceCloneModelFlowViewController.m:1303仅拒绝明确跨模型，1730拒绝明确跨候选；AIRealtimeVoiceCoordinator.m:700确认以成功响应提交。Android coordinator completeCandidateConfirmation同样不要求CONFIRMED/供应商资产/source/billing完整回传。
- 原生ready=READY+CHARGED，processing仅PROCESSING；不另要求providerAssetId才能在模型级端点试听/确认。保留未知状态为unknown，不提升READY/CHARGED、不制造扣费成功。

实现：操作候选ID独立于attempt/幂等键规则；缺省modelId继承请求作用域、明确跨模型拒绝，非空跨候选拒绝。source为服务端状态，不额外拒绝来源字段变化；可选保存授权仍独立校验。确认端点成功与计费状态解耦，不发布虚构计费结算；未知确认的GET恢复仍需明确非空资产匹配，避免空资产误判激活。新增诊断仅枚举字段+JSON类型，不记录值。主Controller498行，无新增例外。

验证结果随后补充。没有平台/依赖修改，不构建安装，不自动重放真实认证/上传/收费；新包真机及用户视觉仍待验，不归档。

最终397项相关定向16秒全部通过（voice_clone、Shell克隆、诊断存储/打包、音色克隆/删除直接调用方），analyze5.7秒无问题，OpenSpec59通过，diff校验通过；此前集合重叠不累计，不称全量。新增缺省候选ID后轮询失败不误标创建未知的回归已包含。未构建安装，真实现场恢复/计费及视觉仍待新包，active不归档。

本次操作DTO/候选ID修复df5de468已成功推送origin/codex/dev_zys，397定向/analyze/OpenSpec59通过；仅外部pubspec.lock差异保留。新包真机、真实响应/计费和视觉待验，不归档。
