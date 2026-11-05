# 设计

## 来源与范围
原生固定a0bedb12，Flutter起点ed4f9f8c；已包含任务b005131b。最新用户批准覆盖旧记忆模块排除和保留身份设置入口的阶段边界。双端统一页面，仅原生音频端口遵守系统生命周期。

## 职责
任务音色domain枚举/Store，data安全存储，controller异步偏好及试听，provider注入回复factory。每条ReplySpeechPlayback首次非空文本入队时懒读取并固定speaker，分句不重新取值；单纯创建对象不触发原生存储或网络。试听复用签名TaskTtsSession与24k PCM、AudioPlaybackFocus；不使用通话试听资产、不修改通话选择。存储加载/保存失败显式提示，不显示假成功。前后台及离页停止试听。
记忆feature-first：domain模型/动作，data AccountApi严格DTO，controller账号epoch隔离及操作防重、开关乐观更新失败回滚，presentation管理/列表/编辑与范围选择。上限使用服务端快照；删除及清空二次确认，编辑显式保存，设置返回不出现丢弃确认。联系人记忆由Agent既有manageMemory工具处理，不新增客户端自动保存或联系人表单。
设置保持兼容构造参数，撤除身份展示与无谓加载；卡片管理复用现有provider且账号变化离页。
结果使用明确resultCode，不凭自然语言判断无需预订；保留账单、录音及服务端原因。

## 契约和验证
原生MemoryApi及当前本地MemoryController均为GET api/account/settings/memory、POST actions；动作ADD/UPDATE/DELETE/CLEAR/SET_ENABLED，scope ALL/SELECTED。复用C1/Bearer SDK路由。
原生任务TTS支持speaker Maia/Andre，但现网Runtime可能以TASK_TTS账号配置优先；客户端选项传输可测，真实音色生效需部署联调，不能称已验收。
每微批最多3手写文件；定向状态/账号迟到/失败/生命周期测试，flutter analyze；交付全量、双端构建按环境执行。无真实短信/身份/外呼/收费测试。

设置首页前三项固定为记忆、Skill 卡片、语音模型与音色；标题及副标题复用a0bedb12文本，仅调整展示，不改变导航目标。

## 语音页面UI纠偏
以a0bedb12 AssistantRealtimeProviderPage、TaskVoiceSettingsSection/Sheet/ChoiceRow为准。设置直接进入原模型页；通话AI语音及说明、克隆和模型卡片之后追加任务AI语音卡片。底部弹层20圆角、18内边距；选项14圆角、选中浅蓝/当前标记、32圆形试听按钮，Maia温柔女声/Andre沉稳男声。复用原Store及preview controller，异步保存成功才提示已选择，离页/关闭/后台/账号变化停止试听。首页快捷模型弹层不追加任务内容。

## 记忆UI纠偏
来源MemoryScreen/Components/Editor/SkillSheet/Contract/ViewModel。独立记忆视觉tokens（F7F8FB背景、24圆角卡片、64高居中标题），沿用AccountApi与账号隔离。列表容量取字符和条数比例最大值；添加居中、删除全部在更多菜单、单条删除在编辑页。任务选择使用临时selection，完成才应用、取消不改草稿，保留停用标签。保存失败记录原动作，重试原操作；编辑返回丢弃无额外确认，提交中阻止返回及重复操作。按domain草稿/选择、controller请求、presentation组件/页面职责拆分。

## Skill卡片UI纠偏
参考SkillCardSettingsRoute/ViewModel/RestoreDialog。页面职责拆为route接线、screen展示、row与restore dialog。使用ReorderableDragStartListener仅手柄即刻拖动，取消无提交，proxy8阴影；64最小行高适配大字体。controller串行保存desired快照，成功发布committed偏好，失败保留有效偏好并保留失败目标重试；旧读取不能覆盖新修改，账号销毁后未启动队列不再写入。首页继续订阅有效preferences。正常字体标题64高21字号，背景F7F8FB/18圆角列表；恢复按钮固定底部，确认24圆角。

Skill保存失败按原生仅显示行内错误文字，重复原操作重试；读取异常才提供重试入口，避免失败读取后覆盖未知偏好。自动化拖动采用连续指针移动验证，无长按等待。

## 记忆保存按钮文字修正（2026-10-13）
当前AIAssistant1 MemoryComponents.kt的MemoryTitleBar使用Compose Material Button：38dp高、最小64dp宽、默认水平16dp内边距、14sp Medium、无阴影、原生启禁用色。Flutter FilledButton默认水平24px内边距在76px操作槽内挤压文字。编辑页局部显式对齐水平16px、最小64px及右对齐，不修改共享主题或保存状态流。定向验证新增/编辑、启禁用及保存中实际文字布局和既有记忆交互，运行analyze/OpenSpec；保留主线程所有已有修改，不提交推送。
