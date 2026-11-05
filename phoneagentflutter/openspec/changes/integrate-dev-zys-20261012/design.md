# 合并设计

## Baseline
目标codex/dev 7a3e100b，来源origin/codex/dev_zys 1c608cb3；fetch后本地和远端一致。来源独有db51de55、ed4f9f8c、2242d424、7804da80、1c608cb3五项提交；git merge-tree预演无冲突。

## Decisions
- 在干净的当前codex/dev执行git merge --no-ff --no-commit origin/codex/dev_zys，保留双方提交历史；不切换其他工作树，不重放已合入提交，不使用force。
- 来源业务沿用既有proposal/design/specs；不因集成重构业务或扩大原验收结论。源分支无需更新。
- 新增集成记录与tasks/issue log；合并前后核对diff、锁文件、祖先和远端。若测试暴露集成问题，按单职责、每微批最多3手写文件最小修复。
- 本轮共享请求/启动/依赖锁跨模块，执行全量Flutter回归；Android配置与iOS启动资源均变化，编译Debug APK和iOS无签名产物。产物不作为正式升级交付，不安装、不触发真实服务。
- 工具链使用本机既有Flutter3.32.0、已验证Java和Xcode，不升级依赖以规避失败。故障先核对实际状态再有限重试，未验项如实记录。

## Completion
合并提交包含两方父提交，origin/codex/dev与本地一致，工作树干净。真实声音、SDK、后台、冷启动视觉和生产升级仍按来源change待验，不能由集成测试标通过。

## 集成回归修正
全量与独立复现均发现 Android settings_account_shell_test 账号卡片点击未命中：新增设置项后滚动布局尚未刷新。仅在测试 ensureVisible 后等待 UI 布局，并要求入口可命中，保留双端取消/确认注销完整断言；不修改产品行为。

## 2026-10-12 反向同步设计
当前codex/dev_zys ba2c946e合入origin/codex/dev 9975afe7；git merge-tree无冲突，采用no-ff三方合并。保留目标新增退出样式ba2c946e及Universal Link配置8e32e8c6，不重放源代码、不操作其他工作树。本轮仅带入7文件（文档及账号测试等待/命中断言），故静态分析、账号双端/退出样式/邀请环境定向测试、OpenSpec和diff校验；不重复全量或双端构建，不安装设备。完成后核验双方祖先、远端dev_zys和本地一致；dev保持9975afe7。
