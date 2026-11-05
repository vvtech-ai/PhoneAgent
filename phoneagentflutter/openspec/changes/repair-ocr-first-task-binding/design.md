## Context

用户诊断包 (9)、视频及异常会话已只读核实：OCR 提交仅保存开场，恢复无条件 initialSent=true；模型 activateSkill(general_message_relay) 后 makeCall。标题生成失败，保留“上传了图片”。不在仓库保存原始图片、联系人、账号或诊断正文。

## Goals / Non-Goals

修复所有 Skill 的 OCR-first 创建/恢复及标题兜底；保持正常文字、文档、连续任务、原记忆与通话门禁。无业务 Skill 白名单，无旧异常任务自动改写或重拨。

## Decisions

- 新增独立 OCR 任务绑定服务：验证真实 Skill，锁定认证账号会话，只有未接受业务输入且未有绑定时初始化；原绑定幂等复用，已有任务不重绑。
- 同步现有 active/pinned 列与原运行快照字段，保留记忆、pending 等其他快照内容，不新增第二份状态机；运行恢复使用已有 codec。
- 上传意图在返回授权前持久化绑定，直接提交/兼容 multipart 也覆盖。可选字段保持旧客户端兼容。
- Flutter OcrUpload 和控制器只传入口上下文，现有账号与页面代次守卫保留；restore 仅在真实 USER_TURN_ACCEPTED/旧历史已初始化时抑制首轮参数。
- 元数据投影优先首次真实非附件用户输入，没有输入时才用上传占位；生成成功标题不改，标题失败不额外调用模型。
- 列表已有 publishedHome 标题映射继续复用；绑定修好即可显示对应首页名称，不添加静态别名。

## File Responsibilities

Java OCR DTO/command 仅传输，可选初始化服务独立负责绑定、校验、快照，现有上传服务只接线；SessionStore 仅补元数据-only 恢复缺口，标题投影仅改兜底优先级。Flutter domain 传字段、data 编码请求、providers 接线、controller 判定首轮。超过 300 行既有核心不扩职责，不重构邻近逻辑。

## Risks / Trade-offs

行锁和幂等防止重复绑定，既有已执行会话不可被迟到 OCR 覆盖；未提供 Skill 的旧请求不猜测原入口。无候选记忆维持原流程；确认仍由当前 pending 与服务端准入负责。

## Validation

先运行失败回放，再验证上传意图/提交、重复/失配/异账号、冷恢复、纯文字/文档/无 Skill、一人与多人原确认门禁、记忆有无候选/拒绝/恢复、标题模型失败与已成功标题。独立测试读取本轮用户材料与候选，不实施真实外呼。测试包沿用已批准 1.0.54+47，检查 test 三路域名、登记证书、ARM64 与 Release。
