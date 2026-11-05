# 设计

## 事实来源
- 只读 1.6.0 `8f235920`：AssistantDialerPreferenceState.selectCountry 将国家 defaultLanguageCode 写入 otherLanguage；AssistantDialerStateHolder.prepareContactNumber/restoreHistoryTarget 复用国家选择。AssistantCallsDialSheet 的 preferredDialLanguageCode 先保留有效选择，只有无效值才避开我方默认语言；同语种在拨号前单独拦截。
- 只读旧业务基线 `a0bedb12`：android/.../AssistantDialerPreferenceState.kt 的 selectCountry 直接写 inferredLanguageForCountry；FinalOtaUpdateDialog.kt 与 1.6.0 一样只展示非空白 releaseNotes，正文左对齐、14sp/20sp，无额外字段拼接。
- 当前 country/restoreHistory 已取得国家默认 peer，但调用 _normalize(resetPeer: true) 又将它清空。国家 CN、caller zh、有效双向模型会回退 en。无模型的既有页面回归无法捕获该分支。
- 当前 NativeUpdateDialog 使用居中正文并继承 13/18，空白字符串未触发兜底；API 已只读取 releaseNotes。截图测试正文不能推断出其他发布字段。

## 文件与职责
1. TranslationSetupController：只修改国家与历史选择后的语言归一化，不修改通话执行流程。文件约 350 行，仍为单一偏好配置职责，不为两处参数修正拆类。
2. translation_language_alignment_test / translation_dialer_parity_test：分别覆盖配置支持约束和正式页面国家、联系人、历史连续交互。
3. NativeUpdateDialog 与专用回归：共享展示控件控制更新说明排版，继续复用现有 offer/install/iOS 接线。无需新业务抽象，不扩张大页面。

## 保持与扩展
国家/号码是明确重选，应用其有效默认语言；之后手选语言仍有效，目录刷新与定位不覆盖。未知或模型不支持的语种继续走原回退；同语种可以显示，拨号仍拦截。普通与翻译模式独立国家偏好不变。新增国家继续由目录提供，不增加 if/switch。

更新正文不拆行重写、不拼 version 或下载状态。空白内容才使用既有默认说明。用户进一步明确更新说明应该左排；只对齐正文，标题、版本、按钮、状态和强更/安装行为保持各自职责。

## 验证
先运行新增失败测试证明 CN 默认被覆盖、正文排版与空白兜底不符，再最小修复。固定 Flutter 3.32.0 --no-pub，定向语言/拨号/联系人/历史和更新 offer/install/iOS 回归，analyze、OpenSpec、UTF-8/diff 检查。已有全仓失败不扩修；不把自动回放代替设备或真实业务证据。
