# 联系人共享 UI

使用 Flutter 3.32 / Riverpod 的现有工程配置，不新增原生 UI 框架。纯页面消费 ContactsState 和回调，Route 负责监听/导航，Controller 与 Repository 保持既有分层。Web 演练使用明确入口和持续 MOCK 标识；没有用户主动开启时不展示假通讯录。

设计输入与控件映射见 interaction-contract.md。此批为用户批准的静态设计优先实现，不声称像素级复刻或双端真机验收。实际验证结果集中更新到 docs/engineering/CONTACTS_VALIDATION.md。
