# 统一对话确认卡计费快照

2026-09-21。普通单路/多路确认卡及后续扩展batch-plus共享实现已接，不是扣费接口改造，也不是整个迁移或真实生产升级验收完成。后续扩展证据见第6节。

最新阶段：[iOS确认卡六图](IOS_CONFIRMATION_STAGE_20260921.md)在ec643d5基点通过，包含普通历史100/10不随模型改写、扩展联系人展开和恢复文字确认。9相关预检/analyze及真机29秒通过；本节下方“未重建iOS”是实现批次当时的记录，不覆盖此后设备证据。Android、真实存储及生产升级仍待。

## 来源与缺口

固定Android `4c781e3ccfcd148c1f205921534907ee0c5aa864` 的有效路径为 `SingleFlowNativeMainSection → SingleFlowPureVoiceContent → PureVoiceStage → PureVoiceStreamingStageContent → PureVoiceThreadList`。其普通确认卡调用 `AgentCallConfirmBillingNotice`；扩展 `LargeTaskConfirmationCard` 也使用计费快照。虽然旧路径名称含PureVoice，它承载当前统一页，不能按已排除的旧独立页面删除。

原Flutter普通确认卡缺费率/余额提示，未保存确认时快照。d42099c补齐该分支；扩展batch-plus当时仍缺专用投影/展示，随后按第6节实现，不能用普通makeBatchCalls卡或通用工具卡替代。

## 实现

- `ConfirmationBillingSnapshot` 共享固定v65规则：默认/Qwen首分钟100、每6秒10；Doubao/Seeduplex110/11；V3为150/15。未知余额不显示不足提示；单双路按人数判断首分钟不足及预计不足两分钟。仅说明，不新增充值或执行按钮。
- `ConfirmationBillingRequest` 复用现有toolId/稳定alias，保留原始summary分隔与确认序号，避免显示格式化导致旧key失配。
- `SecureConfirmationBillingStore` 按环境/API/账号/会话/alias存储，当前isolate同scope串行。新快照优先于旧快照，旧快照优先于当前模型/余额；第一次缺失才捕获当前值。之后切模型/刷新余额/恢复任务不会重写历史值。
- Android `LegacyConfirmationBillingChannel` 只读固定`index9_native_screen`及`task_call_confirmation_billing_`前缀；只收哈希，不传确认正文。先旧account+session+alias形式，再旧account+alias形式。最多1024个哈希、每项4096字符，非生产包无旧源，旧文件不删除。
- 正式Provider另限制精确prod API与Android，绑定登录代次；Web/iOS/Dev不读旧Android源。新存储读写、旧响应解析或账号失效失败会显示重试，不把当前余额冒充历史。与旧Gson解析失败返回null相比，损坏记录明确失败，不静默重建。
- `ConfirmationBillingRoute`只组装共享卡片与加载/重试控件；现有准入、通知、呼叫命令和后台计费不变。Web工作台注入独立内存快照，不接真实安全存储、短信或电话。

## 自动验证

本轮未跑全量。核心四文件16项（13新增、3条连续App测试增强）约5秒退出0：

```text
flutter test --no-pub test/features/calls/confirmation_billing_store_test.dart test/features/calls/legacy_confirmation_billing_test.dart test/features/calls/confirmation_billing_presentation_test.dart test/shell_call_workbench_test.dart
```

覆盖新旧优先、双旧key、写失败/损坏/重试、换账号、跨实例重叠alias、费率边界、280/390窄卡片；连续App320/430宽验证换模型/任务恢复、确认命令不重复、短信/安全存储/原生模拟外泄调用为0。前一轮调用方集合有39项通过但一文件因测试select参数类型错误编译失败；修正后该文件及本轮核心集合通过，不把第一次运行报告成全通过。

`flutter analyze` 无问题（3.9秒）；Android Debug构建通过（9.9秒），新增原生桥接已编译。iOS没有原生变化，本批未重建或安装，不能据此声明双端新版本一致性通过。

## 浏览器实际连续验证

独立 `http://127.0.0.1:8122/` 重新编译并刷新：完整App → 订餐厅 → 切文字 → 输入“演练单路通话” → 模拟通话 → 挂断 → 结果 → 模型弹层选择Seeduplex → 关闭对话 → 任务列表恢复刚才会话。

恢复后底部模型Seeduplex，历史卡仍显示首分钟100/每6秒10，未重复进入通话页。截图实际查看确认说明与卡片正常换行；不是设计视觉精校。整个场景常驻MOCK标识，未使用8080真实账号。

## 集中人工验证及剩余工作

1. 用同生产包/兼容签名/高版本的最终候选覆盖真实旧App，保留数据；Dev不具备旧生产数据，不能代替此验证。
2. 旧App已有确认快照的会话，升级后从任务恢复，费率和余额提示保持旧值；切换当前模型/余额后再次恢复，历史值不变。不要为验证界面实际发起电话或充值。
3. 无旧快照的新确认按首次显示时的模型/余额保存；双端真实安全存储、冷启动重建和锁屏读失败/重试留集中验收。
4. 扩展batch-plus已按第6节补齐共享实现，真实生产会话/持久快照与同版本双端效果仍待集中验证；合成卡不证明真实后台实际执行或计费。
5. Android普通Dev仍为旧探针版本，2026-09-21只读安装更新时间为09-20 22:27:05。既有手动保留数据恢复尚无完成证据，不绕过安装限制，不再发验证码。

统一交接见[主清单](MIGRATION_HANDOFF.md)，旧状态分类见[台账](LEGACY_STATE_INVENTORY.md)。

## 6. 扩展batch-plus续接

固定来源：`LargeTaskTimelineProjection`、`ConversationTimelineReducer`、`BatchConfirmationTimelinePolicy`、`LargeTaskConfirmationCard`和`TaskCallConfirmationBillingSnapshotPolicy`。后台`BatchTaskConfirmationCoordinator`仍通过ASK_USER等待用户输入，客户端不新增确认执行按钮。

- 共享`BatchConfirmation`和独立投影读取schema1/displayPayloadVersion1的snapshotJson对象或JSON字符串；toolCallId和ordinal+1保持原身份/版本，结果按同ID更新原卡，保留原位置、内容、contactSummary及版本。未知/损坏请求不造卡；修订取消轮次沿既有过滤。
- 共享卡显示任务分区、原始/可拨/暂不执行三项统计、问题、默认4人及展开、执行规则和决策。无效状态按v65回退Pending；没有新增UI业务判断或电话操作。原五种通用补问文案按v65隐藏，有意义说明仍保留。
- 确认后的首个makeBatchCalls不再生成第二张普通确认卡，独立普通批量仍显示；有确认卡不应吞掉同轮后续真实流式文字。既有ASK_USER/pendingToolCallId负责回复和恢复，不改Controller/后端协议。
- 计费alias为`batch-plus:snapshotId:version`；Pending缺新旧快照才捕获当前值。已确认/待修改/已取消且无快照时，不补造当前费率、不写空占位；已有新/旧快照仍显示。旧源同前述Android生产门禁，业务共享Dart。
- 工作台仅增加文字“演练扩展批量确认”的合成服务响应，不加另一套页面。确认/取消/其他文本分别模拟CONFIRMED/CANCELLED/REVISION_REQUESTED，只写内存事件，不外呼。

验证：首次6个相关文件24项通过（9项新增，约6秒）；补五种通用提示隐藏后该投影文件7项再次通过。合计新增10项、去重相关25项，而非全量回归。涵盖对象/字符串、乱序与结果合并、身份/版本、坏数据、重复执行抑制、流式文字、Pending存储门禁，以及320/430宽完整App展开/收起→退出→任务恢复→文字确认→再次恢复。连续测试确认原pending ID、无actionId、无重复命令/短信/真实存储与拨号调用。

实际Web8122：大型会议入口→文字演练→查看全部5人/收起→关闭→任务恢复→输入“确认”，原卡显示已确认且无第二张普通卡；费率100/10及预计不足两分钟仍保留。顶部/底部截图均已查看，长卡可滚动且底部输入固定可达。当前阶段按原SingleFlowPolicy保持原规则，不能仅因卡出现就改成执行中。视觉精校仍后置。此子批仅Dart变化，不重复打双端包；Android/iOS当前版本真机阶段及真实后台/生产升级独立待验。
