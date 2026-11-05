# 合并设计

## Baseline
当前干净工作树codex/refactor-conversation-task-flow，HEAD ba80b6b95cc8322965645011cc91fcdc5f798f31；fetch后origin/codex/dev_zys 06eba01472bc3fae408ee7b61db3a50616bfbe07；共同祖先及保留远端codex/dev均9a8d4e642ec1e892df4128992b84e8686233e732。两边分别29与245个独有提交，27个改动文件重叠，预合并12个冲突。

交付前fetch新增四项提交，继续合入7a99013c05a7a554f3022b774f9859bd073db2c9；冲突仅为两份追加记录，双方保留。

最终追加可信流程快照df5e7097并定向复验，来源冻结于本次fetch。用户追加应用图标替换：Android直接复制App v71正式资源、增加roundIcon引用；iOS只读复制历史正式iOS同品牌按尺寸图标，复用现有Contents，不修改或重画品牌图案。图标资产为机械复制批次，PNG尺寸与来源SHA验证；构建最终50并保留数据安装。

## Decisions
- 当前新分支执行no-ff/no-commit三方合并；合并前提交已有远端可恢复，不reset/stash其他工作区。
- 请求层保留任务分支的接口路由/错误映射及dev_zys的账户和可信来电生命周期；展示层组合双方入口与已有任务分页、回执及复合间距。
- iOS工程保留当前来源设置与incoming插件、资源、扩展目标；公共资源依赖使用上游现有版本，不升级Flutter。
- 文档追加历史两边记录，不整页ours/theirs丢弃；规则只按用户本次授权放开dev_zys，不改变codex/dev保护。
- 手写冲突解决每微批最多3文件，其余自动三方合并为机械集成；只修合并造成的编译/测试问题。
- 固定3.32分析、全量Flutter测试和Android构建；SDK原生定向规则可用时补充。开发HTTPS三基址为chakenai-dev.vvtech.tech的aiassistant-api、aiassistant-sdk-api、aiassistant-runtime。
- 构建必须使用被忽略的现有.local/cloud-dev/device-defines.json，包含四个非空C1签名配置；只核对字段存在和APK包含布尔值，不输出值或提交私有文件。47遗漏签名导致模型读取不可用，纠正后交付48，保留失败记录。

## Responsibilities
account_api/session保留请求和账号边界；将错误元数据白名单映射抽到account_error_mapping，避免请求文件超过500行。现有Provider组合依赖，Widget只组合已有显示与导航，原生工程只负责平台注册/构建。录音路径沿用既有隐私边界，使用path.join消除Windows分隔符差异。未来同类集成继续在既有扩展点接线，不把翻译/可信来电并入任务控制器。

## Validation and rollback
先检查冲突标记、UTF8、未提交文件及合并祖先，再analyze、全量测试、构建和包配置核验。合并提交保留双方祖先，失败可在提交前abort；交付只推本次新分支，不force。原始日志、APK、凭据和构建缓存不入Git。真实iOS/macOS及生产升级独立待验。
