## Context

固定v65 CertifiedRecordingStore/CertifiedRecordingPayloadCodec：noBackupFilesDir/voice_clone_certified/certified_recording.bin；首字节IV长度、12–16字节IV、AES/GCM密文，旧别名voice_clone_certified_recording_v1，不使用AAD。明文为int版本、5个Java modified-UTF字符串(accountRef/personFingerprint/audioSha256/scriptVersion/receipt)、int音频长度及音频。账号来源AssistantVoiceCloneModelRuntime的AccountIdentityProvider.accountId，最大音频10MiB。

Flutter已有CertifiedRecordingRepository按槽位串行与账号代次校验，新blob加密且带slot AAD。原生只做私有IO/旧格式解码；账号、摘要、新格式校验与迁移编排继续在Dart。

## Goals / Non-Goals

Goals：保留可复用旧录音；新值优先；账号隔离；清除后不复活；失败可重试且旧源不动。
Non-Goals：旧本机通话记录、跨包读取、真实认证/音频、iOS OTA、自动降级或生产签名发布。

## Decisions

1. 新LegacyCertifiedRecordingChannel仅read，无任意path/key参数；生产包名强门禁，固定旧文件及旧key，只读取现有密钥，缺失不得生成。11MiB外层上限，旧纯codec按DataInputStream.readUTF恢复，不把modified UTF当标准UTF8。异常返回清洗类型，不输出录音或receipt；未知版本/密钥暂不可用返回unavailable保留重试，明确损坏返回corrupt但不删除源。
2. Dart DeviceLegacyCertifiedRecordingSource额外检查Android非Web+精确prod API，映射强类型字段。账号不符视为该账号无源，不能删另一个账号旧录音。摘要与格式通过现有CertifiedRecordingCodec验证。原生无业务账户/认证判断。
3. MigratingCertifiedRecordingStore包装现有加密blob，仅在新blob缺失时读取旧源；校验编码并原子replace成功后才返回。复用Repository串行，不再另建竞争队列。isCurrent在每个异步边界检查；新blob损坏/不可读时不回退旧文件。
4. clear不简单delete新文件，而是原子写入绑定槽位的空标记；read识别标记返回absent，避免清除后重导入。无旧源也写空标记，后续不反复解密。新replace覆盖标记。明确损坏经过既有Repository invalid清理路径写空标记；目标写失败不返回假成功。标记与内容同一原子对象，避免独立key与文件双写崩溃间隙。
5. 只在正式provider满足同生产Android门禁时包装；普通Dev/iOS/Web保持原逻辑。生产包迁移完成后继续用包装器解释空标记，不能撤去读取支持。旧源保留不等于允许安全降级；旧版不识别新清理标记。

## Risks / Trade-offs

- 数据敏感→仅合成fixture、无真实私有文件读取/日志/上传；加密明文仅进程内传输，不落临时文件。
- 同UID同签名与Keystore存续无法由debug包证明→生产升级独立人工验收，不解除Release门禁。
- 旧数据元信息大于新64KiB限制→显式无效/失败，不绕过新格式边界或截断receipt。
- 逻辑清理后旧加密源仍留磁盘→Flutter空标记阻止复活，不声称物理擦除旧源；后续生产回滚/清理策略必须单独批准。

## Migration Plan

每微批≤3文件：旧codec/channel/MainActivity；Dart源/包装器/provider；原生与Dart测试；文档/任务。仅新增JUnit测试依赖（若现有Gradle可复用则不添加运行依赖）。定向测试/analyze/OpenSpec、Android Debug编译，未改iOS不重打。原生测试验证旧Java UTF编码形状，Dart验证并发/失败/清理及正式门禁。真实升级通过前不归档。
