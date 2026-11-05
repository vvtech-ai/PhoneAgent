## Why

Flutter codex/dev 仍按 v65 合并三套任务接口，缺少当前统一列表的分页、置顶、未读和删除限制；timeline 网络故障会误降级为空历史，通话进度事件未进入编排。用户批准将首页、统一对话、任务列表及直接详情/恢复入口一并对齐当前有效版本。

2026-10-08 用户进一步指定 Android `origin/test/v66.0.3` 为功能基线，要求补齐遗漏功能，并在 Flutter Android/iOS 上共同实现。此前任务流批次的通过记录仅证明该批范围，不证明 v66.0.3 全部有效功能已迁移。探索已完成，用户“没问题后就开始实施”批准进入 apply 与必要的最小 Java 提供方补齐。实现及验证进度见第6–11节与新的 v66 验证记录；未完成双端运行或现网联调时不宣称完整验收。

## What Changes

2026-10-09再次核对：以v66.0.3 a0bedb12完整OpenSpec索引筛选任务外呼及直接依赖，以最新独立App v71 146152a为功能/API快照。补齐模型modelId/activeModelId、appSubtitle与服务端名称，终态回执展示补全，以及SDK监听票据、Runtime签名WSS、物理接通/首PCM时序与音源预选。Java v71仍8ebd7db4，未找到新SDK监听接口；按用户最新要求后端保持只读，契约冲突仅出文档确认。

- 接入服务端统一任务列表，补齐分页、置顶、删除限制、已读及失败重试。
- 任务详情按资源身份展示结果并恢复原 session，保留翻译已有详情接线。
- 拆分对话事件处理职责，隔离账号、代际和通话尝试，分离物理结束与业务结果。
- 网络故障不再使用历史兼容降级，首页入口和跨页刷新防重。
- 功能对齐 v66.0.3 的正式可达入口：显示确认卡后等待用户明确确认，再拨打；支持确认阶段提问、等待、修改、取消及补充问答持久化。
- 补齐普通任务停止、批量停止确认与重试、未发送草稿恢复、任务产物下载、置顶折叠、首页卡片偏好、实际安装版本判断、任务 AI 播报开关及按住说话引导。
- 保留现有统一分页、ledger、账号隔离、迟到事件防重、明确无 ledger 才兼容、详情加载重试和终态原 session 恢复；不创建第二套任务状态机。
- 请求按当前后端的 sdk-api/agent-sse 契约适配。旧 Android v2 签名不得替代当前 SSE C1；Bearer 不替代请求签名。
- Android/iOS 分别列实现与运行验收，平台差异由文件保存、系统手势、键盘和生命周期适配处理。
- 排除 v66.0.3 的分享占位回调与被重定向的独立结果页按钮，不凭旧文件存在新增功能；不扩展记忆、翻译、克隆、积分及其他设置业务。

## Capabilities

### New Capabilities
- `task-list-and-details`: 当前统一任务分页、操作、详情与恢复。
- `conversation-task-orchestration`: 事件投递、恢复与通话终态展示。
- `home-conversation-entry`: 首页入口状态、防重与任务投影刷新。

### Modified Capabilities
- `migration-governance`: 按用户最新授权集成到 codex/dev，并在该分支继续开发；保护其他工作区和已有提交历史。

## Impact

客户端范围为 Flutter home、tasks、conversation、直接关联 calls/task_notifications、任务产物/本地偏好及必要设置入口、平台适配、测试和文档。任务播报只接开关/交互，保留已接 ASR/TTS；不重构翻译、克隆、积分、通用设置、SIP 或电话服务。

确认回复分类与补充记录在 v66.0.3 旧后端存在，在当前 Java `origin/feat/v70-parity` 的 `25e4f18e` 中未找到对应实现。完整功能对齐依赖最小后端迁移；用户2026-10-08批准仅补齐确认分类与补充ledger接口，在Java独立新分支实施；不改变其他后端、数据库或电话状态业务。不得用客户端假成功、仅本地记录或普通 Agent 轮次冒充接口完成。

不自动真实外呼、收费、部署、数据库迁移或清除设备数据。2026-10-10用户最新明确授权将 `codex/refactor-conversation-task-flow` 合入最新 `origin/codex/dev`，切换到本地 `codex/dev` 继续开发并非强制推送该分支；覆盖此前仅交付功能分支的限制，保留双方更新及其他工作区，未验收不归档。
## 2026-10-09 首页及任务tab登录阻断修复
用户明确取消初始化入口并优先恢复首页和任务tab。重新核对Flutter远端f9c1333f与Android origin/v71 0e960e2；旧v66.0.3和当前Android均不再从正式调用链挂载V61InitializationOverlay。AuthRoute仅移除InitializationHost包裹，不写初始化完成标记，保留现有账号/积分/更新会话所有者。
真实联调另发现当前发布首页HTTPS云素材与通话模型端点Bearer/modelId差异；纳入home-conversation-entry直接依赖，保留C1及已有失败/刷新/账号隔离，不扩大其他业务。实施及真机证据见tasks第12节；iOS实际环境和既有完整任务契约待验项不据此勾完。
