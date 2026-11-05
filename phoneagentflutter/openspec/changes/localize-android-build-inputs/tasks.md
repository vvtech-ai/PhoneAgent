# 任务
- [x] 阅读工程约定及相关规格，核对有效来源与当前源码状态。
- [x] 创建并校验本变更规格。
- [x] 复制私有输入并验证字节一致、权限、忽略规则和环境。
- [x] 迁移 Windows/Gradle/dev 入口并增加 macOS 测试入口。
- [x] 完成 Python 6组、Flutter 配置/登录27项及真实 product/AOT 配置守卫测试；Gradle 实际执行3项路径拒绝通过（外部属性/外部keystore/链接逃逸）；Windows PowerShell 当前不可用，待跨平台复验。
- [x] 更新当前工程文档及研发问题记录。
- [ ] 用户验收（验收前不归档）。

## 用户纠正：复用既有环境配置
- [x] 核对 cloud-dev/cloud-test 与新增 dev/test 副本完整内容一致。
- [x] 调整构建入口与测试，复用 cloud-dev/cloud-test，保留独立签名目录。
- [x] 验证新入口后删除重复配置，更新当前约定及研发记录。
- [x] 本次路径纠正：Python 7组通过、真实私有输入 plan-only 指向 cloud-test、shell语法及差异检查通过；未修改配置值或签名材料。
