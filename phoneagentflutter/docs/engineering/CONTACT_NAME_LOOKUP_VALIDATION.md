# 统一对话姓名联系人查询（2026-09-17）

## 范围和事实源

固定 Android v65 `4c781e3` 的 `DeviceContactCandidateLookupUseCase`、`ContactPinyinSearchEngine`、`AssistantAgentContactLookupEffects` 和接口契约。只接现有姓名工具及 SHOW_OPTIONS，不迁移旧本地候选弹窗，不增加外呼按钮。HTML/CSS和已有组件先用于交互；本批不声称视觉校准完成。

## 共享实现

| 环节 | 文件/职责 |
|---|---|
| 输入来源 | `ConversationController.send(source: ...)`；键盘始终 typed，不从语音按钮显示推断 ASR |
| 匹配规则 | `contacts/domain/contact_name_matcher.dart`；繁简、大小写、精确/包含/拼音、姓名号码去重和候选状态 |
| 拼音评分 | `contacts/domain/contact_pinyin_search.dart`；声韵母变体、权重、末两音节、通配符和四音节上限 |
| 字典端口 | domain `ContactNameDictionary`；data `LpinyinContactDictionary` 固定 lpinyin 2.0.3，三端共用，无原生拼音库 |
| 工具执行 | `conversation/domain/tools/name_contact_lookup.dart`；权限/读取、逐名结果、退出保护 |
| HTTP | `api_name_contact_lookup_continuation.dart`；复用账号隔离 API，POST `api/assistant/agent/device-contacts-lookup-result` |
| 续接 | `ConversationToolCoordinator`；去重、嵌套/平铺参数、HTTP后ledger同步；Controller仍是消息事实唯一持有者 |
| 设备 | Android/iOS ContactsChannel 只补系统 contactId；业务匹配与候选不放原生层 |

请求保留 sessionId、pendingToolCallId、userId、results、channel=voice。结果按请求名包含 name/requestedName/status/inputSource、可选matchType和candidates；RESOLVED才附唯一候选字段。拒权返回PERMISSION_DENIED，不可用返回UNAVAILABLE，不冒充NOT_FOUND。仅回传匹配结果，不上传整本通讯录。

typed/unknown仅繁简归一和忽略大小写精确匹配。asr先精确，无精确才包含匹配，再追加评分后的拼音候选。多号码全部保留；仅拼音命中即便只有一项也返回MULTIPLE_CANDIDATES。后台SHOW_OPTIONS沿用“第 N 个”继续，不自动选首项。

## 本批自动验证

- 新增25项：12匹配、8执行生命周期、2HTTP契约、3控制器；已有候选Widget回归扩展为选择第二项并继续。
- `flutter analyze` 无问题；全量 `flutter test` **531项通过**。首次全量因domain直接依赖lpinyin失败，改为字典端口注入后重新全量通过，未修改架构门禁。
- Web Debug、Android Debug 构建通过；Mac独立源码目录 `PhoneAgentFlutterNames.KS0MGU` 的iOS Debug无签名构建通过。依赖锁定未升级Flutter、Dart或其他包；未关闭已解锁会话。
- 浏览器实际操作：联系人 → 进入联系人交互演练（MOCK） → 演示联系人 → 发起任务 → 订餐厅 → 文字输入 → 合成查询 → 两号码候选 → 第2项 → 显示“第 2 个”和续接回复。
- 此演练使用同一匹配/工具/页面，但网关和回传完全内存隔离；不读取真实通讯录、不请求后端、不拨号、不创建真实任务、不改变登录。
- 两端本批未重新安装。上述构建不是权限、真机或真实Agent回传的通过证据。

## 集中人工验收

1. 使用专用测试账号/环境及合成系统联系人：同名两号码、繁简姓名、英文大小写、同音不同字；不要用真实私人通讯录做自动回传测试。
2. 键盘输入触发姓名工具。预期typed只精确匹配；同名两号码需后台候选确认，选择第二个继续同一session，不新建对话、不自动外呼。
3. 分别允许/拒绝系统权限、撤销授权、离线。预期拒权/不可用不显示“没有联系人”；回传失败进入历史恢复，不自动重复POST。查询过程中退出/切账号，晚到结果不得回到新页面。
4. 在后续真实ASR接入后对相同姓名录音。预期来源asr，纯拼音单项仍要求确认。当前只证明规则和参数传递，不证明录音、识别或语音入口已接通。
5. 核对sessionId、pendingToolCallId、返回候选和后台接口处理；客户端故障关键字`conversation_failure`，不把联系人姓名/号码写入通用日志。核对每tool仅一次POST，不出现跨账号结果或重放用户输入。

## 未完成和风险

- lpinyin与Android ICU/TinyPinyin字库不保证罕见字、多音字和繁简异体字完全一致；当前按逐字首读音转换，需真实目标姓名样本比较，不宣称字库逐字等价。
- 历史pending按v65恢复标识和时间线，不自动重放联系人查询；后续核验见下节。附件/权限live工具、真实ASR及外呼协调继续独立实现。本批live工具通过不代表统一页全功能完成。
- 真实设备权限/有限授权、真实后台回传及视觉差异留集中校验。主目标与OpenSpec保持未完成，验收前不归档。

## 历史恢复补充核验

v65 `AssistantConversationRestoreSnapshotMapper` 按完整工具身份排除已有结果，仅在continuable、pendingRestorable且非CLOSED时恢复未完成工具标识；`AssistantConversationRestoreUiStateReducer`清空临时权限/文档/候选状态，保留时间线，不自动发起查询。Flutter已有实现沿此边界，无需新增“打开历史就自动申请权限”的逻辑。

`pending_tool_restore_test.dart`新增12项回归：恢复候选选第二项仍发第2个/voice/原session和pendingToolCallId；已解决候选只展示；不同modelTurn/ordinal/toolName结果不错误消除请求；仅最新未解决项可选；三种pending门禁不封普通输入；四类工具恢复不访问设备/POST；退出晚到不重激活。它们是合成历史回归，不代表真实后端恢复、附件或权限live工具完整验收。

补充验证：analyze与全量543项通过。此补充仅测试和文档，无生产源码变化；三端产物沿用14ec577构建，不虚报新设备或新编译结果。
