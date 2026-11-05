## Context

已读AGENTS、知识库导航、迁移基线、当前Composer、文字dock/editor、OCR上传与账本恢复链路及相关active规格。旧规则同时限制canSend和canInterruptReply。语音停止按钮已优先调用onStopSpeech；文字只接任务onStop。首张图片在开场未计入账本时取锚点0；后端先提交initial-opening，再原样保存图片锚点，恢复时0被映射到开场前。

## Goals / Non-Goals

目标：生成与播报重叠时仍禁用，仅播报时恢复入口；文字停止只停TTS且保留草稿；旧OCR记录恢复开场在前。
范围外：放开生成中操作、改变发送与任务停止生命周期、重播播报、重写账本或图片锚点、改后端和并行翻译需求。

## Decisions

Composer只移除_canChangeContext中的canInterruptReply限制，canSend、onStop、stopping、预检和录音保护保留。文字dock的onStop在播报时优先采用现有voice.onStopSpeech，播报时不受任务停止等待状态限制，展开编辑器沿用已有动态回调。不增加公共控件分支。

ConversationOcrBoundary识别schema1的ASSISTANT_TURN_COMMITTED且commandId精确为initial-opening:<session>的账本事件。只让可见列表开头连续匹配的assistant开场成为最小显示边界；不按文字相同识别，不重排账本，不对所有图片锚点统一加一。无明确开场时原边界不变。已存0锚点兼容，后续源步计数仍按现有规则。

业务仅修改两个已有单一职责文件：Composer负责控件编排，Boundary负责坐标投影；不向Controller增加状态机。测试独立覆盖，后续同类规则继续在对应职责点处理。

## Risks / Trade-offs

误认普通回复为开场会挪动图片 -> 仅识别明确session/command/event身份且位于可见前缀。播放与生成重叠 -> 测试canSend=false仍锁定。文字展开时播放状态变化 -> 检查现有ValueNotifier动态回调与草稿保留。真实诊断包缺会话账本 -> 合成账本闭环和双端UI回放不替代真机验收。

Word/Excel通过document用户轮提交并由账本USER_TURN_ACCEPTED恢复，不属于OCR_IMAGE_COMMITTED；分别增加真实Controller首次文档提交后冷恢复及双端页面坐标断言。已有文档链路顺序正确时仅补保护测试，不改其上传与解析逻辑。
