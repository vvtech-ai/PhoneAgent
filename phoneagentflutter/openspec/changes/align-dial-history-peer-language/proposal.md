# 历史号码选择语言对齐

## Why
Flutter 选择历史号码后保留当前对方语言，与 aiassistant_app 的国家默认语言联动不一致。

## What Changes
- 回填号码成功后，恢复有效历史我方语言，并以有效国家的当前目录默认语言配置对方语言。
- 复用现有国家语言规则，单次更新配置；保留当前模式、模型、提示及 Flutter 页面和共用控件。
- 增加控制器、持久化和页面回归；不修改接口、平台或构建。

## Impact
影响 unified-dialer 历史选择配置；参考 aiassistant_app 8f23592 的 AssistantDialerStateHolder.restoreHistoryTarget 与 AssistantDialerPreferenceState.selectCountry。
