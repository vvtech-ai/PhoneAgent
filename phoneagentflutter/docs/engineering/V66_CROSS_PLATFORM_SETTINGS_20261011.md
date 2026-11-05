# 双端v66剩余设置与记忆能力

## 来源及工作区
Flutter ed4f9f8c/codex/dev_zys，任务分支b005131b已为祖先；Android a0bedb12固定只读。当前工作区开始时干净，不切换分支、不提交/推送、不操作真实短信/身份/外呼或收费。本change为complete-v66-cross-platform-settings，用户已确认双端实施，验收前保持active。

## 对照与实现
| 能力 | 本次修改 | 边界 |
| --- | --- | --- |
| 任务音色 | Maia默认/Andre、安全设备偏好、单回复分句快照、签名TTS试听 | 沿用24k PCM和全局音频租约；不覆盖通话/克隆，不携带preview绕过服务端选择 |
| 设置 | 语音模型与音色下分通话/任务；首页移除卡片管理按钮、设置增加入口；移除我的身份入口及无谓身份加载 | 身份组件及克隆认证/撤销保留 |
| 首页卡片 | 复用既有显隐/排序/账号偏好，恢复默认二次确认 | 账号变化不执行原账号reset |
| 记忆 | SDK GET memory/POST actions，Bearer/C1，开关即时提交回滚，管理/编辑/范围/删除/清空 | 后端Snapshot权威，容量来自服务端，失败不展示空成功；旧账号响应无效 |
| 订餐 | 复用已有Asked状态、自然回答、Agent manageMemory | 不增加本地联系人保存或表单；服务端部署规则需真联调 |
| 无需预订 | 明确metadata.resultCode映射完成，独立“无需预订，可直接到店” | 不凭文本推断，不改后端判定，实时/历史共用Receipt |

## 验证记录
- OpenSpec首轮78通过/0失败。
- 首批分析类型/风格问题及一次缺括号已有限修复；之后分析无问题，后续新增代码再做最终检查。
- 定向首轮221通过/11失败；第二轮234通过/1失败发现memory鉴权遗漏并修正；第三轮276通过/1旧reset断言，新增弹窗取消/确认专项已通过。
- 新页面专项12通过：两端主题、320宽、任务音色1x/2x、记忆键盘避让/新增/范围/删除取消；是组件证据，不是真机。
- 全量首轮诊断factory用例发现创建阶段读取原生存储，已改为首次文本入队懒读取且单回复只读一次；相关14项回归通过。不忽略失败或初始化真实设备代替隔离。
- 首轮Android ARM64 debug构建7.7秒通过；iOS设备debug无签名构建27.2秒通过，均为无私有运行配置的编译验证，不用于覆盖安装普通包。

## 保留待验
- 现网Runtime TASK_TTS/账号选择可能优先，speaker兼容字段不会绕过服务端权威；需服务提供方确认并联调真实Maia/Andre，不声明选择实际生效。
- 记忆接口本地源码和原生契约存在，但现网部署/容量错误/订餐保存复用及关闭提醒未以真实账号验证。
- 双端实际试听、系统中断、耳机/后台、生产数据升级及真实无需预订回执尚待设备/服务验收。
- flutter devices可见USB Android/iPhone；另一个无线iPhone code -27无连接，不扩大权限。未安装构建验证包、未启动或操作用户普通App。
- 最终完整回归、最终双端构建和diff结果待下方追加。

## 最终编译与静态检查
- flutter analyze --no-pub：无问题（14.8秒）。
- openspec validate --all：78通过/0失败。
- flutter build apk --debug --no-pub --target-platform android-arm64：14.9秒通过。
- flutter build ios --debug --no-codesign --no-pub：21.0秒通过。无签名产物不代表真机安装。
- git diff --check通过；未修改平台配置、插件或依赖。Android音频焦点与iOS中断/耳机移除/后台释放已有原生处理并被本次试听复用。
- 全量首轮中止，不取其部分计数为通过；冻结版本重新运行结果待记录。

## 收尾复核
- 局部试听错误优先级修正后，试听controller/两端页面/TTS stream专项15通过，analyze无问题16.9秒。全量与该收尾专项分别报告，测试集合不相加。
- 最终Android交付源码ARM64 debug编译11.2秒通过；iOS收尾构建进行中。
- 所有24个修改/新增Dart源码均不超过500行，AccountApi479行；无pubspec、锁文件或原生工程变更。

## 远端和连续脚本收尾
- 只读ls-remote核对：codex/refactor-conversation-task-flow b005131b、codex/dev_zys ed4f9f8c、codex/dev 7a3e100b。远端路径.git后缀差异已规范化核对；无fetch、切换、提交或推送。
- 完整回归一轮4417通过/1跳过/8失败：三个连续脚本仍依赖旧身份入口、新语音分组前的导航或懒列表离屏假设。已改为正式通话模型克隆/卡片偏好与滚动定位，并给workbench增加独立音色内存Store，继续断言零真实存储访问。
- 脚本调整时一次漏保留登录键盘SystemChannels导入，编译失败后恢复；受影响及直接调用方18项最终通过。未删除克隆/取消/数据保持覆盖。
- 最终flutter analyze --no-pub无问题4.8秒；运行最终完整回归中。
- 最终iOS收尾无签名设备构建16.6秒通过；对应Android11.2秒通过。后续仅改测试/演练端口/文档，正式main代码不变，不重复重打普通包。

## 最终完整结果
- flutter test --no-pub --concurrency=8 --reporter expanded：4425通过、1既有跳过、0失败；05:22，进程退出0。包含此前8项修正的连续脚本。日志/tmp/phoneagent-v66-full-delivery.log。
- analyze无问题；OpenSpec78通过；git diff --check通过；Android ARM64 debug和iOS设备debug无签名均编译通过。
- 已完成功能代码、双端共享页面和自动验证；真实服务音色/记忆、双端真机中断/后台、生产升级及用户验收仍待完成。
- 当前分支仍codex/dev_zys，HEAD仍ed4f9f8c；实现保持本地未提交，未向远端写入、未安装/覆盖用户普通App。

## 2026-10-11 语音模型与音色页面纠偏
- [x] 恢复设置直接进入原模型页；标题与通话AI语音说明对齐原生；列表底部追加任务AI语音当前音色卡片。
- [x] 任务AI音色改为底部弹层，Maia温柔女声/Andre沉稳男声、当前标记和独立试听；删除误加的中间分组和独立页面。
- [x] 149项定向、6项连续流程通过；增强弹层失败/系统返回/遮罩/后台停止专项4项复验通过，与前述集合重叠。
- [ ] 双端真机视觉/真实试听验收。本批不改平台或依赖、不重打包、不安装普通App、不提交推送，不归档。


来源：Android a0bedb12 AssistantRealtimeProviderPage.kt、TaskVoiceSettingsSection.kt、TaskVoiceSettingsSheet.kt、TaskVoiceChoiceRow.kt。此纠偏覆盖之前中间语音分组/独立任务音色页面的交付描述；此前全量及构建只属于当时版本，不代表本次设备显示验收。

## 2026-10-11 记忆页面UI与交互纠偏
- [x] 按Android a0bedb12还原记忆首页两卡片、记忆内容列表容量条/更多菜单/底部添加、编辑页标签和圆角输入区。
- [x] 任务选择底部弹层临时状态、取消/完成/全选三态及停用标签保留；单条删除移至编辑页，全部删除移至更多菜单，确认文案和按钮对齐。
- [x] 原动作重试、开关回滚、未保存返回丢弃、提交中防重复及禁止返回；最终41项定向/连续流程通过、analyze无问题。
- [ ] 双端真机视觉/真实服务验收。仅本地修改，未安装、提交或推送，不归档；未改平台或依赖，不重复构建/全量。


参考文件：MemoryScreen.kt、MemoryComponents.kt、MemoryEditor.kt、MemorySkillSheet.kt、MemoryContract.kt、MemoryViewModel.kt（a0bedb12）。本段覆盖此前自行设计的管理记忆/我的记忆/独立复选列表/行尾删除/底部清空展示描述；旧版全量与构建结果不代表本次真机视觉验收。最终日志：/tmp/phoneagent-memory-ui-final-test.log、/tmp/phoneagent-memory-ui-analyze.log、/tmp/phoneagent-memory-ui-spec.log。

## 2026-10-11 Skill卡片UI与交互纠偏
- [x] 对齐a0bedb12居中标题/说明、18圆角白色列表、六点直接拖动手柄、绿色显隐开关、即将提供状态、底部固定恢复默认与原生确认框。
- [x] 拖动取消不保存，显隐/排序/恢复成功持久化后发布首页有效偏好；失败保留原值并提示，重复原操作重试；串行写入及账号失效队列保护。
- [x] 最终68项定向/连续流程通过、analyze无问题、diff检查通过；双端主题、320宽/1x及2x字体、拖动/取消、显隐/排序/恢复失败、确认取消/遮罩/系统返回、账号切换覆盖。
- [ ] 双端真机视觉及手势验收。仅本地修改，未安装、提交或推送，不归档；未改平台/依赖，不重复全量或构建。


来源：SkillCardSettingsRoute.kt、SkillCardSettingsViewModel.kt、SkillCardRestoreDialog.kt（a0bedb12）。本段覆盖此前通用AppBar/SwitchListTile/默认长按排序/标题栏恢复及乐观发布偏好的实现描述。本次日志/tmp/phoneagent-skill-ui-{final-test,analyze,spec}.log；此前版本全量构建不代表本次真机验收。
