## Context
已读工作区及仓库 AGENTS、知识库导航、迁移基线和上一轮 confirmed-feedback。基线同步 origin/codex/dev，保留远端翻译与定位修复。模型卡片直接调用 controller.select，音色入口已使用结果提示；默认 AlertDialog 叠加 CommerceCard 内边距；禁用按钮仍绘制固定颜色。

## Goals / Non-Goals
Goals: 同一切换结果提示、支付风格套餐弹窗、完整禁用与恢复。
Non-Goals: 修改业务数据、计价、支付状态、权限、ASR/TTS 或构建版本。

## Decisions
- shell 提取现有选择回调复用反馈，不增加第二套保存或提示状态机；490 行 shell 仍只负责页面编排，不增加新职责。
- 独立 MembershipPlanDetailsDialog 负责几何与关闭，原 sections 只负责权益数据展示，消除嵌套卡片阴影及留白。沿用支付 Dialog 白底、360 宽上限、16 外距、22 内距、22 圆角；分组标题及记录左对齐，内容可滚动，关闭固定可见。
- 使用已有 _canChangeContext 驱动 + 和模型的可点击及颜色状态。文字输入的 + 也采用实际回调是否为空；停止不受影响。不新增忙碌状态。

## Risks / Trade-offs
窄屏和大字必须测量弹窗内容与关闭按钮，并验证滚动。两种输入模式、思考/回复到空闲均需回归，避免仅改视觉而遗漏事件阻断。真机 UI 仍待验。
