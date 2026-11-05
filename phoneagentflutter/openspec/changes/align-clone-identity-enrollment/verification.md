# 2026-10-15 填写信息功能对齐验证

## 已实现
- certNoMasked通过IdentityProfile/API、CloneIdentityPrefill、流程状态到填写页，只在已认证且脱敏号非空时显示；意外完整号码不展示，不作为认证/保存参数。
- 已认证姓名首次脱敏锁定及说明；姓名去空格后2～32字符；保留大陆身份证输入规范化、日期/校验码校验。
- 失败返回的脱敏字段点击或键盘聚焦时清空后重新输入，锁定姓名不解锁。保留原认证SDK、候选、确认、录音复用和iOS创建失败返回规则。
- 重置入口复用NativeConfirmationDialog，明确身份与全部克隆音色删除；失败保留信息；成功清空表单、复用IdentityDeletionCleanup刷新模型/目录及账号绑定录音清理。
- 服务端删除已成功而本地清理失败时保留重试状态，不重复DELETE；当前填写流程清理未完成禁止认证。旧账号回调不清理新账号。
- 保留Flutter原卡片、文本字段、主按钮和弹窗，不复制示意图的新视觉。控制器从500行提取纯展示投影后498行，无新增超限例外。

## 自动验证
固定Flutter 3.32.0缓存：/Users/Eason/.cache/phoneagent-flutter-3.32.0/flutter/bin。
- flutter test --no-pub --reporter expanded test/features/voice_clone test/features/identity test/features/call_models test/features/points/clone_wallet_provider_test.dart：699项全部通过。
- flutter analyze --no-pub：No issues found。
- openspec validate --all：154通过，0失败。PATH无node，核对已有缓存运行时后显式执行，未安装或升级工具链。
- flutter test --no-pub --reporter expanded test/architecture_test.dart：4项通过（500行、纯domain依赖、平台边界）。
- git diff --check：通过。
- 首轮identity/clone范围523通过、1个旧断言冲突；旧断言要求恢复完整身份证，按已批准的清空重填规则更新，定向21项及最终699项均通过。
- 页面测试含Android/iOS主题、小屏320宽、2倍字号、确认取消/失败/成功、姓名锁定、脱敏提示清除、焦点重填；领域/provider测试含清理重试、删除去重、账号切换与DTO保存边界。

## 待验与交付边界
未调用真实身份认证、删除、摄像头/麦克风或积分收费；没有真机截图/运行验收。未改平台/插件/依赖/构建链，因此未重打Android/iOS包。保留active change待用户验收，不归档。
在当前codex/dev_zys本地修改，不切分支、不提交推送，参考仓库及后端只读。
