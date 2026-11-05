# 实施与验证记录（2026-10-12）

## 基线及实施范围
Flutter 基线 `0d0e7480`，参考 `aiassistant_app` 的 `d183fdf`。当前 `codex/dev_zys` 本地修改，未提交、未推送。参考仓库和后端只读。

| 范围 | 已实施行为 |
| --- | --- |
| 账户网络 | 补齐账户保护前缀，包含 `api/task/list` 和 `api/task/call-history`；保留现有401刷新一次及失败上抛规则 |
| OCR | 意图申请、独立无账户凭据对象PUT、complete；complete失败重试复用已上传对象及提交身份 |
| 邀请 | 持久化明确邀请来源；手工输入不推断为邀请，编辑清除旧归因及提交身份 |
| 实时翻译电话 | 服务端国家/语言/模型目录、可用性及费率展示；国家号码规则；SDK runtime即时获取；国内协议参数、海外节点与逐模型诊断；欢迎语SDK下载。保留当前正式外呼流程 |
| AI代办电话 | command/call/attempt身份匹配；挂断接受后等待实际终态；历史恢复只观察；电话状态与业务结果分离；SSE和轮询按片段及出现次数合并，保留真实重复发言 |
| 样音 | 优先服务端样音URL，无URL再申请生成；独立有界下载，保留播放器停止与generation机制 |
| 钱包 | 按发布费率估算；缺有效费率时展示暂无估算 |
| 下载、评分、停止、普通ASR/TTS | 核对调用和现有回归，未确认需独立重写的协议缺陷；公共鉴权补齐覆盖相关账户路径 |

UI沿用现有布局与风格，调整配置展示、动态选项和等待挂断状态。登录失效后的统一清理、跳转与提示按用户要求暂缓。

## 自动验证
固定 Flutter 3.32.0 / Dart 3.8.0，未升级依赖、平台或构建链。
- `flutter analyze`：通过，无问题。
- 最终跨模块定向：163项通过；后续修正专项92项通过。
- 阶段预览与协议/状态回归：19项通过，属于离线widget测试。
- 最后补充模型ID与欢迎语测试：9项通过。
- 最终全量 `flutter test --reporter expanded --concurrency=8`：4516项通过、1项跳过、0失败（6分08秒）；末轮补测9项另行通过。
- `openspec validate --all`：91项通过、0失败。
- `git diff --check`：通过；本次修改的手写lib源码均不超过500行。

首轮全量4500通过、1跳过、13失败。失败来自旧鉴权断言以及新增目录未注入离线预览；已修正并复跑，不将失败轮次计为通过。

## 设备和服务待验
以下尚未执行，不以源码、离线测试或widget预检替代验收：
- [ ] Android/iOS配置页面视觉、动态国家语言与无旗帜资源展示。
- [ ] 授权测试账号的SDK options/runtime/欢迎语及对象上传实际联调。
- [ ] 国内SIP与海外WebRTC实时翻译音频、节点切换和模型诊断实际可用性。
- [ ] AI代办真实通话挂断、断线重进、字幕交错及迟到业务结果。
- [ ] 真机样音试听切换/停止、下载播放和钱包实际费率展示。

原因：本轮未提供真实认证、外呼或收费测试授权，未进行真机安装/媒体验收；未改平台、插件、依赖或构建链，按增量验证规则未重打双端包。后续真机必须保留现有App与登录数据；本change未验收，不归档。


## 2026-10-12 实时翻译模型选择修复
用户批准本侧会话计划后执行；不是对上一轮4516项全量结果的重复声明。

### 调用链复核与修正
正式参考路径为 `AssistantCallRuntimeControllers.selectedTranslationModelCode`：本地精确模型ID、匹配协议的国家绑定模型、首个可适配国家绑定模型。正式拨号不依赖账号模型设置接口成功。此前分析把账号设置作为唯一来源不完整，本轮按实际入口修正。

- 国内/海外保存独立模型ID，保留旧协议偏好迁移回退；目录按当前位置绑定过滤transport和客户端协议支持。
- 国内摘要与模型面板取消旧账号catalog门禁，模型ID唯一而非引擎唯一。目录失败明确提示并支持重试。
- 国内plan冻结模型ID及协议；runtime严格按精确ID获取，缺失不能回落其他同协议模型；计费提交相同modelId。
- 海外快照冻结精确ID并在新调用时核对国家绑定、语言、节点和协议；按Android正式backend请求只发送既有realtimeProvider，不擅自增加modelId字段，不改变create→media ready→merchant-call。
- 独立账号设置适配补DOMESTIC/OVERSEAS region，保留任意合法模型ID、服务端名称，按ID判重；不作为正式选模前置条件。
- 弹层重新检查账号epoch、地区和当前路由；旧回调不能修改选择或关闭新页面。刷新期间保留当前选中模型，账号依赖重载隐藏旧目录。

### 验证范围与待验
末轮身份/UI专项38项通过；最终 `flutter test test/features/translation test/features/translation_history test/extended_device_stage_test.dart test/migration_increment_device_stage_test.dart test/shell_developer_workbench_test.dart --reporter expanded --concurrency=8` 共840项通过、0失败（2分02秒，含专项重叠，不累加）。`flutter analyze` 无问题；`openspec validate --all` 92项通过；`git diff --check` 通过。此为模块定向和离线页面预检，不是本轮全App回归或真机验收。
手写修改源码不超过500行。未改平台/插件/依赖/构建链，按规则未重打双端包。设备视觉、真实SDK目录/runtime/计费联调及国内/海外音频外呼仍未验证：无本轮真实认证、外呼、收费测试授权，不以离线widget预检代替真机。登录失效统一处理仍暂缓。本地修改，不提交、推送或归档。工作过程中出现的其他未跟踪SDK目录不属于本批，不作修改。
