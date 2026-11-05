# 设计

## 决策
TranslationSetupController.restoreHistory 在一次 _change 中更新当前模式国家、有效历史 caller 和国家默认 peer。与 country() 共用默认语言方法：目录优先，无目录沿用 CN/zh、JP/ja、其他/en 的现有规则。历史 peer 不回填。同一国家再次选择也重置 peer。普通模式也执行该联动。

无效或无 caller 保留当前 caller；无法回填的号码继续由 DialerController 拒绝，不触发配置更新或拨号。保持翻译开关、提示、模型、另一模式国家和其他偏好。

## 范围
仅修改配置控制器及定向测试；无 UI 布局、共享控件、接口、权限、平台和依赖变更。业务微批最多三个文件；相关文件均低于500行。

## 验证
先运行新增测试复现旧逻辑失败；修复后运行相关 dialer、translation 配置及页面接线测试、flutter analyze 和 openspec validate --all。不打包、不安装、不触发真实通话；真机效果待用户验收。
