## Context

v65 FinalCallRecordStorage/AssistantCallRecordState在index9_native_screen固定账号key保存JSON。DialRecentCallPolicy只投影所需元数据，最终最近列表为系统来源+App翻译；旧AGENT/普通详情不迁入。本期Flutter安全仓库已有scope、新信封、跨实例串行、账号代次及changes。

## Goals / Non-Goals

Goals：保留旧元数据及翻译最近入口；隔离账号；新数据优先；清理后不复活；失败不毁源。
Non-Goals：恢复旧Calls UI、导入全文字幕/媒体、回放电话/归档/后台任务、读取真实用户数据、iOS OTA。

## Decisions

1. Android增加固定只读channel，参数只允许非空有界accountId字符集（字母/数字/点/横线/下划线），拼接固定prefix；实际生产包名门禁，不接受任意路径/key、不fallback guest。后台队列执行，统一脱敏错误。读取JSON传给Dart，无写入/删除旧源方法。
2. Dart再校验非Web Android及精确prod API；返回信封version/accountId必须匹配。共享codec只留下id/kind/号码/姓名/时间/国家/双方语言，不落地旧全文字段。title/status/meta空的旧无效行沿v65跳过；未知kind沿旧AGENT，缺失/非正时间归0，ID用callId或phone:time:KIND，旧标题姓名按固定3前缀回退，不猜号码/时间。
3. 新仓库构造增加可选readLegacy闭包，_load仅raw==null时调用，仍在原串行队列内；校验新codec并写新信封后返回。无源也写空信封作为完成标记。clear与append走同一加载边界；新损坏/未知schema明确失败，不能用旧数据掩盖。
4. 目标写失败或旧读取/格式失败不返回空成功、保留重试；异步边界检查账号/close。已有新数据（含空信封）不合并旧源：它可能代表用户已清理，不能臆断回填。迁移保存发既有changes通知，消费者最多合并一次后续刷新。
5. 仅正式provider在符合门禁时注入来源；Dev/iOS/Web不动，系统CallLog独立，无权限变更。

## Risks / Trade-offs

- 旧JSON可能很大：最多16MiB UTF8，超过明确失败而非截断/部分导入；这不是旧版容量声明，正式升级需检查大历史测试样本。
- 损坏JSON旧版会静默空，本次明确错误避免新空信封永久遮蔽可恢复源；空白/null旧数据按旧行为为空。
- 旧字段仍保留原私有源：不宣称物理擦除/安全降级；不输出原JSON、号码、名称、字幕到日志或Git。
- 合成MethodChannel不证明生产UID/SharedPreferences/密钥同签名升级；真实验收前保持Release门禁，不归档。

## Migration Plan

≤3文件微批：原生channel+注册；Dartcodec/source；仓库/provider；定向测试；文档与规格。无新运行依赖，Android Debug/analyze/OpenSpec；无UI改变不逐页截图，不重复iOS构建。旧源不动，生产回滚另行审核。
