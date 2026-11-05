# 设计

1. 三环境配置源固定在工程 .local 下，真实文件不提交。新增字段 TRUSTED_CALLER_APP_KEY/SECRET，不复用业务 SDK_API_KEY/SECRET。先安全核对旧三份 Kotlin 内容一致，再逐环境补入原值，已有同名字段冲突则停止，不覆盖。保留其他字段；当前 cloud-pro 实为测试配置，生产校验必须拒绝，不能推断生产地址或密钥。
2. 独立 Gradle 脚本读取 JSON，检查文件及工程内祖先非符号链接、APP_ENV 与构建环境一致（pro 对应 Dart 的 prod）、字段为非空单行字符串；错误不含值或解析异常原因。通过 BuildConfig 注入值和 SDK 环境。检查显式 Dart APP_ENV 与原生选择一致；不打包整个 JSON 为资源。文件每次配置时读取，使环境切换/凭据变更进入 BuildConfig 输入。
3. main/TrustedCallerLocalCredentials.kt 只读取当前构建字段，拒绝未知或不匹配的 SDK 标签，不再让 test/pro 标签读取同一个构建中的凭据。真实旧输入迁移完成后才删除 debug/profile/release 的私有重复文件；保留旧路径忽略保护，防止历史工具误生成时泄密。
4. 开发/测试/Docker入口校验可信字段并明确选择环境，直接 Gradle 也校验；隔离构建必须在自己的源码根下配置相应 cloud 文件，禁止回退父工作区。统一调度器的临时目录生命周期不改。旧工具 Android-only 改为校验选中 cloud 配置，不写源码、不读原生 Git；默认双端准备只保留 iOS 的原始生成逻辑和来源。
5. 每个实现微批不超过3个手写文件。用合成配置验证三环境不同值、缺失/空白/错误类型/换行/JSON错误/符号链接、Dart环境冲突、切换环境后刷新及安全错误。运行原生可信来电单测、Python/Flutter定向验证、analyze、OpenSpec和Android debug编译；真实SDK、Windows和生产发布验收独立报告。不生成正式交付包或安装。
