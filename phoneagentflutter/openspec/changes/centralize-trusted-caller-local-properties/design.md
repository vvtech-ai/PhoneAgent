# 设计

1. 使用根目录local.properties，绝不读写android/local.properties；先将/local.properties加入忽略规则，再创建600权限私有文件。六个环境字段分别保存，允许供应商实际值相同。特殊字符按Java Properties规则转义，迁移前后对解码值核对，不输出实际值。
2. Gradle使用UTF-8 Reader和Java Properties解析根文件，Python入口使用与Java兼容的标准库解析模块；支持分隔符、空格、反斜杠、Unicode和续行。Windows/Docker入口先校验根文件存在且非链接，完整字段由实际Gradle统一验证，不引入额外Windows运行时。缺失/空白/换行/NUL/格式错误安全失败，无旧JSON或其他环境回退。
3. 保留原云业务文件APP_ENV校验及显式Dart/Android环境一致性检查，pro对应Dart prod。真实可信值只从根文件注入原有BuildConfig字段，Kotlin读取器不变。普通工程构建每次重新读取输入；隔离构建必须安全准备自身根文件，不回退父工作区。
4. 所选环境两个字段验证通过后，才能从原cloud文件删除可信字段。其余业务字段和原有android/local.properties、iOS私有文件保留字节/语义核对。更新当前说明、脱敏properties示例和上一变更的后续来源说明，不覆盖历史实现证据。
5. 每个手写实现微批最多3文件，验证Properties合成样本与实际Gradle解码一致、环境切换、值更新、缺文件/字段/非法格式/符号链接、禁止旧来源回退、Dart环境冲突。运行Python/原生/Flutter定向回归、analyze、OpenSpec和必要Debug编译；不重复全量业务测试，不生成正式交付或安装。Windows无pwsh则明确待验。
