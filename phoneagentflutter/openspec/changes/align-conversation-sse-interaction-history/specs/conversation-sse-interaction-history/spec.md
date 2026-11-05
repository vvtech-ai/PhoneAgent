## ADDED Requirements

### Requirement: SSE 事件、业务类型、账本事实与展示消息必须分层
系统 MUST 将 `AgentEventKind` 视为实时传输事件类别，将事件的 `eventName` 或 `payload.type` 视为业务子类型，将 `LedgerEvent.type` 视为可恢复的服务端事实类型，将 `ConversationMessage` 视为由事实和实时覆盖投影出的展示对象。未知或字段不完整的事件 MUST 保持未知/失败状态，不得猜测为成功业务事实。

#### Scenario: 同一 SSE 流包含生命周期和业务事件
- **WHEN** 流依次收到 `thinking`、`signal`（含 `ASK_USER`）、`finalResponse`、`committed`、`done`
- **THEN** 客户端分别处理思考、业务请求、正文、账本事实和传输结束；不得把 `done` 当作新的助手正文或把 `signal` 直接当作 durable ledger 类型

#### Scenario: 未知事件或损坏字段
- **WHEN** `AgentEventKind.unknown`、未知 `payload.type` 或缺少必要身份字段的事件到达
- **THEN** 保留可诊断的未知/失败状态，不创建可恢复事实、不激活无身份选项卡，也不把原始未知内容伪装成成功回复

### Requirement: durable ledger 与实时 transient overlay 必须可区分并可合并
服务端 `USER_TURN_ACCEPTED`、`ASSISTANT_TURN_COMMITTED`、`TOOL_REQUESTED`、`TOOL_RESULT_RECORDED` 及既有运行终态事实 MUST 进入 durable 投影；实时正文、思考、工具进度、开场白、Consent 卡和用户操作回显 MUST 标记为 transient，除非收到同身份的权威 committed 事实。合并 MUST 优先使用 session、command/turn、toolCallId 或 callAttemptId 等真实身份，不能只用相同文字。

#### Scenario: 实时正文随后提交
- **WHEN** transient 正文先到达，随后收到匹配同一事实身份的 `ASSISTANT_TURN_COMMITTED`（仅同 command/turn 不足以判定匹配）
- **THEN** durable 正文替换同身份临时覆盖并保持时间线位置，不重复显示两份，也不删除其他工具或后续用户轮次内容

#### Scenario: 用户回显等待提交事实
- **WHEN** 用户点击选项后本地回显已显示，但服务端尚未提交新的 `USER_TURN_ACCEPTED` 或助手事实
- **THEN** 回显作为 transient overlay 保留在当前实时会话中；历史恢复时清除该 overlay，不能把未确认的点击伪装成 durable 事实

### Requirement: 交互选项必须按真实卡身份管理 active 与历史快照
每个选项/确认卡 MUST 具有稳定的消息身份，并尽可能绑定 `toolCallId`、`pendingToolCallId`、command/turn 或其他工具身份。一次选择 MUST 追加用户侧操作回显、使原卡失去操作权但保留其时间线快照，并只把新的 active 状态授予后续同一编排链产生的新卡。不同工具或不同用户轮次的同文案卡 MUST 分开。

#### Scenario: 选择后产生下一张卡
- **WHEN** 用户在任意 Skill 的选项卡中选择一个选项，SSE 随后产生新的助手提示或选项卡
- **THEN** 旧卡仍可回看但不可点击，用户选择回显位于旧卡之后，新卡获得唯一 active 状态；旧卡内容不得被新提示原位改写

#### Scenario: 道歉音色确认
- **WHEN** 用户选择“确认使用”或“不使用”
- **THEN** 道歉卡遵循与普通 Skill 相同的回显、失活、后续卡和语音停止规则；该 Skill 不得绕过公共会话投影

#### Scenario: 本地选择不能被当作原提问所属轮次的首条输入
- **WHEN** 点击或文本/语音选择旧卡后，客户端追加用户回答并收到下一条助手结果
- **THEN** MUST 保持原提问、原选项卡、用户回答、后续结果及新卡的顺序；本地回答不得复用原提问的 commandId 而被排序到提问之前；道歉本地选项的提问气泡与选项卡分别展示，普通选项保留卡内标题

#### Scenario: 后续任务的账本事实到达
- **WHEN** 本地交互之后提交了新轮次，该轮次的用户或助手 durable 事实到达
- **THEN** 本地交互 MUST 仍位于该轮次之前；以临时消息中的后续 command 对应事实作为插入位置，不改变 durable 事实自身的顺序；没有可用后续身份时不得按文本猜测位置

#### Scenario: 查询音色没有额外对话正文
- **WHEN** 道歉选择触发异步查询音色
- **THEN** MUST 关闭旧卡操作权并保留旧卡；Checking 只管理查询状态，不追加或播报“正在查询您的克隆音色”正文；成功或失败结果才追加到用户回答之后

#### Scenario: 确认音色后就绪提示同时显示文字和提供播报
- **WHEN** 用户确认使用且当前模型已有可用克隆音色
- **THEN** MUST 将与语音 prompt 相同的就绪文字追加在用户确认之后；后续 initial-opening 回填仍只显示一份，旧卡顺序和选中状态保留

#### Scenario: 初始开场事实先于首次用户事实回填
- **WHEN** 道歉本地选卡完成，initial-opening 的提问、选择或就绪事实先于首次用户事实逐条到达，之后到达最终回复
- **THEN** MUST 保持原提问、选中旧卡、用户选择及就绪结果的原始顺序；初始事实只能在对应本地记录的位置接管正文，不能把前面的旧卡移动到就绪结果或最终回复之后；旧卡的选中索引和禁用状态继续保留

#### Scenario: 本地道歉确认覆盖后台欢迎语
- **WHEN** 新会话的道歉入口开始，首页配置同时携带 opening
- **THEN** MUST 使用本地固定 Consent 提问与选项卡覆盖后台配置 opening；道歉不另显示或播报后台欢迎语，普通 Skill 仍使用各自配置 opening，已展示的确认不得因选择、首次提交或 done 被删除

#### Scenario: 同文案跨轮或跨工具
- **WHEN** 不同 command/turn 或不同 `toolCallId` 的选项文字完全相同
- **THEN** 各卡分别展示和管理 active 状态，不因文字相同合并或覆盖

### Requirement: 开场白、临时卡和工具轨迹的消失时机必须确定
实时会话中已展示的开场白、Consent 和历史选项快照 MUST 保留到当前投影生命周期结束或被同身份的展示归一化明确替换；选择后它们只失去操作资格，不得被无条件删除。思考占位动画、普通工具进度和批处理进度 MUST 在对应 turn 完成、失败或取消时收起或结束处理状态；真实思考卡 MUST 停止动画并保留已收到的结束内容，不得仅因其属于 transient 而删除。持久账本事实和用户操作回显的实时快照 MUST 遵循各自的 overlay 规则。`heartbeat`、`done` 和历史恢复本身 MUST NOT 产生新的开场白或用户确认。

#### Scenario: 当前会话继续流转
- **WHEN** 开场白或 Consent 已显示，用户完成选择并收到后续 assistant prompt
- **THEN** 原卡继续留在时间线并变为不可操作；后续卡追加到时间线，只有同身份归一化或终态清理允许移除临时进度

#### Scenario: 真实终态
- **WHEN** 当前 turn 收到匹配的工具完成、最终响应、错误或取消
- **THEN** 对应 transient 工具轨迹按生命周期收起或转为 durable 结果，思考占位结束且真实思考内容留在本轮原位置；已确认的历史消息和用户回显快照不被无关终态删除

### Requirement: 历史恢复必须只恢复 durable 事实并保持实时规则一致
恢复流程 MUST 先清除旧进程未落账的 transient overlay，再以 session 对应的 durable ledger 重建消息、工具结果和可恢复 pending 状态。已落账的开场、确认提示和业务正文 MUST 保留；不得将清理 overlay 扩展为删除其权威内容。恢复不得重播语音、开场白或历史点击，也不得自动拨号；实时投影、任务列表恢复与只读详情 MUST 共用身份、去重、原位更新及结果 / 评分语义。

#### Scenario: 重启后恢复已提交会话
- **WHEN** 会话重新打开，ledger 包含用户轮次、助手提交、工具请求和工具结果
- **THEN** 只从 ledger 重建时间线，保留已提交业务正文和有效 pending 工具身份；不重造上次进程未落账的 opening、Consent 或点击，不自动激活旧卡、播报或执行

#### Scenario: 恢复与实时副本同时存在
- **WHEN** REST ledger 与 SSE committed 事件描述同一事实但到达顺序不同
- **THEN** 按事件身份和内容指纹合并为一份，并保持首次有效时间线位置；不同身份或冲突事实不得静默覆盖
