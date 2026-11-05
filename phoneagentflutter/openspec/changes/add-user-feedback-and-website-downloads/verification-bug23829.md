# 23829 验证记录（2026-10-27）

候选：`codex/story-1870-1872-support-downloads`，基线 `c7324850` 加本批差异；版本保持 1.0.53（46）。

- Picker 整批拒绝超选，文案说明本次选择超过可添加数量和实际剩余数；保留原表单、已有图片，不改变数量、格式和大小合同。
- 离页确认复用 `core/design/native_business_dialog.dart` 的 NativeBusinessDialog，遮罩/标准确认样式沿用设置退出弹窗，继续填写和放弃动作不变；忙碌禁止返回及重复弹窗保护保留。
- 先失败回放：剩余1/3/6张时旧提示与期望不同，双端找不到标准弹窗；修改后通过。
- 固定 Flutter 3.32.0：`flutter test --no-pub test/features/support_feedback --reporter expanded`，**41 项通过**，覆盖 Android/iOS 变体、取消后继续填写、确认放弃、重复返回及忙碌返回，既有重试/账号隔离/API/图片流程同批回归。
- `flutter analyze --no-pub lib/features/support_feedback test/features/support_feedback` 通过；OpenSpec 本变更 strict、diff、中文 UTF-8 读回通过。

## 独立回归

未参与实现角色 `bug23829_independent_review` 本次重新读取三条 Bug、四张图、原附件和 Git Demo；反馈模块41项、analyze独立通过。另以独立临时用例覆盖空/已有3图超选及取消保持原图片/描述/联系方式/日志、双端连续两次离页回调只出现一个标准弹窗且取消保留内容，共4项通过。测试中的第二次遮罩覆盖点击产生hit-test警告，已改为同步触发公开返回回调两次；最终双端12项Widget由双方复验通过，无该警告。未发现产品阻断。

独立截图/脚本及报告保存在工作区 `.local-data/bug-23829-23831-investigation-20261027/independent/`，不提交运行缓存。

## 未验证边界

Widget 双端变体不是 Android/iOS 真机验证。本轮未重新打包、安装或部署，未取得新版真实设备上的相册和弹窗画面，Windows 未执行 iOS 原生编译。原变更相关真机验收缺口继续保留，不使用旧 APK 画面冒充本批产物。
