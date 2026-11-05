# 首次初始化正式接线：已确认两步

## 最新决策与已实现边界（2026-09-21）

用户先回复“三步”，随后明确纠正：初始化不需要设置国外翻译模型。最终采用「身份信息 → 通话模型 → 首页」，以下旧代码事实仅用于追溯，不再等待选择。

- 正式 `AuthRoute` 已接 `StartupUpdateHost → PointsSessionHost → InitializationHost → ShellRoute`；仅成功读取为空且未持久跳过时显示引导，错误可重试。
- 第二步按钮为“完成”，先保存通话模型，再保存非空姓名身份或空姓名跳过标记。第一步跳过不清草稿，返回仍保留输入；最终失败重试不重复已成功的模型写入。
- 复用身份/模型Repository和既有跳过Store；Provider绑定登录epoch，完成刷新身份/模型消费者。没有新增竞争状态或平台业务分支。
- 初始化翻译端口及第三步已移除；撤回临时翻译适配，原翻译控制器无差异。初始化不创建翻译设置Provider、不读写其偏好或请求权限。
- 8122目录新增“首次初始化→首页”，通过正式App宿主、仅替换内存外部端口。定向50项及analyze通过；浏览器已确认填写、返回保留、切模型、完成直接进入首页。双端安装/真实账号持久化另验。

## 以下为决策前代码复核记录（历史，不作为当前待办）

复核日期2026-09-21；Flutter基点a2611e9；Android行为基线4c781e3ccfcd148c1f205921534907ee0c5aa864。本文不是新增产品需求，不以旧未使用代码扩充功能。

## 已核实的行为

1. `AssistantInitializationPolicy.shouldShowAssistantInitialization`仅在身份已加载且姓名为空时判定需要引导；加载失败不能当空身份。跳过标记由宿主另行判断。
2. `V61InitializationOverlay`第一步“跳过”仅设置step=2，不立即关闭，也不清除已经输入的姓名。因此填过姓名再按跳过，最后仍按非空姓名保存，不能自行改成“跳过就丢弃草稿”。
3. 第二步下一步调用`onSelectCallProvider`，然后进入第三步。最终完成调用翻译选择，姓名非空则提交身份并等保存结束；姓名空才调用`onSkipIdentityForSession`。
4. `AssistantContactRuntimeController.skipInitialIdentityForSession`同时设置进程状态、写`identity_initialization_skipped=true`并关闭引导；虽然函数名带Session，实际标记不是仅当前登录。现有Flutter `IdentityInitializationStore`已按安装/环境范围保留，不应改为每账号重置。
5. 第三步的有效目录来自`V61TranslationProviderOptions`/`TranslationProviderUiCatalog`，原初始化国内Qwen/Doubao可选，海外OpenAI/Gemini禁用。不能把它描述为已经存在的国外初始化，也不能因此复活排除的国内App SIP。

## 决策前Flutter实现边界（已被上述实现替代）

- `InitializationController`已有加载失败重试、已有身份/跳过短路、第一步跳过、前后步草稿、模型保存、最终身份/跳过保存与关闭后的晚到保护。
- `RepositoryInitializationGateway`已经把身份和通话模型接到各自Repository，翻译目录明确要求传入`InitializationTranslationPort`，没有擅自默认写入。
- 当前仅`InitializationPreviewRoute`构造上述控制器；正式`AuthRoute`登录后仍是`StartupUpdateHost → PointsSessionHost → ShellRoute`，并未挂首次引导。独立演练完成不能作为正式引导已接入的证明。
- 现有Flutter会等待模型保存成功再前进，并记住已成功选择避免最终重试重复写入；不能直接复制旧UI异步回调写法而丢掉失败提示。
- 删除身份后的持久跳过、模型失效与认证录音清理已有独立实现；首次门禁应复用这套事实源，不另建竞争标记或重复DELETE。

## 曾提出的产品选择（已选择两步）

| 选择 | 需要实现的差异 |
|---|---|
| 两步：身份信息→通话模型（建议） | 第二步保存模型后完成身份/跳过，不调用翻译初始化端口；国外模型继续使用现有翻译设置入口 |
| 三步：身份信息→通话模型→国外翻译模型 | 增加第三步国外目录及现有海外偏好的显式适配，沿当前准入规则处理可选模型；不接国内SIP |

该问题已由本页顶部最新用户答复关闭，三步方案不实施。

## 确认后实施边界

共享Dart门禁/controller/provider负责条件判断、保存、重试和跨模块刷新；复用现有身份/模型Repository和跳过Store，不新增Android/iOS业务分支。正式宿主需要遵守现有账号释放屏障：切换身份先卸载旧业务页面，不能让旧初始化保存结果进入新账号。

验证需覆盖：已有身份/已跳过不弹、身份加载失败不假装空、无身份完整完成、姓名为空的最终跳过、模型或最终保存失败不重复前序成功写入、返回草稿、账号失效/晚到、删除身份后的既有跳过规则。用同源MOCK先走Web正式入口，再纳入设备阶段；无需为这些检查额外发送验证码或提交真实身份。
