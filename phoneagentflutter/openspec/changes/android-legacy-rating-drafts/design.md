## Context

固定4c781e3的TaskRatingDraftStore使用task_rating_drafts/task_rating_draft_SHA256(accountId+NUL+taskType+NUL+taskId)；TaskRatingViewModel按服务端资格返回的taskType/taskId读取，提交前保存submissionKey，编辑清空key。Flutter的SecureTaskRatingDraftStore没有旧源，只有实例内队列，clear删除新key。

## Goals / Non-Goals

Goals：保留有效未提交草稿和同一重试key；新值、清除和账号隔离不被旧导入覆盖。
Non-Goals：不恢复废弃评分入口，不修改奖励/服务端只读，不迁移其他旧状态、不自动提交或读取设备真实数据，不提供旧App安全降级保证。

## Decisions

- 原生LegacyRatingDraftChannel固定文件/哈希键，仅实际生产包、合法非guest账号和无NUL/控制字符的非空任务标识。通道只返回版本、精确作用域及单条原JSON，限制64KiB，不枚举/写入。Dart另限定非Web Android、prod、精确chaken.ai API。
- DeviceLegacyRatingDraft读取与严格校验，LegacyRatingDraftCodec纯Dart转换；保留nullable分数及未完成表单、原suggestion（含超过300字的未提交输入）和submissionKey，不使用当前资格猜任务ID。baseSubmissionVersion不成为本地已提交依据，正式控制器对服务端已提交不读草稿。
- SecureTaskRatingDraftStore新增可选旧源函数；新key不存在才读旧源，写新schema1信封后返回。无旧源数据写cleared标记，clear也写同槽cleared标记；新已有值、损坏值、未知schema均不回退旧源。读取错误/超限/损坏导入不写标记，保留重试机会。
- 当前队列改为按作用域跨实例串行（当前isolate内，不宣称多进程）；close阻止未开始和await旧读后写入，已交给存储的原槽写不能撤回。Provider按登录代次销毁旧store，新写排在先前导入后，不被覆盖。
- 不复制页面。共享评分控制器必须区分读取成功无草稿与读取失败；读取中或失败时禁止编辑、保存及提交，弹层显示加载/错误和显式重试。重试成功恢复原内容及submissionKey，关闭重开不抹掉失败状态。该保护同时适用于Android导入与三端现有安全草稿，不修改奖励/资格或服务端只读规则。

## Risks / Trade-offs

- 草稿含私人建议 -> 不打印原JSON/文字/key，数据仅转入当前账号安全存储；通道固定错误码。
- 源文件未删除 -> 不保证降级后不再看到旧草稿，生产回滚策略仍待独立确认。
- 64KiB为实现资源保护非v65业务上限 -> 超限失败不截断，集中验收覆盖长草稿。
- 真正覆盖升级需要生产身份/签名 -> 当前只合成与编译，发布保护保持不动。

## Migration Plan

先转换与通道测试，再存储导入/并发/清除，再正式接线与Android构建。每微批最多3文件，手写默认500行。旧文件不写不删；回退当前实现不改变旧文件，不能把这当完整跨版本数据降级支持。
