## Why
用户确认每次历史回填都重新确定对方语言：历史对方语言有效时优先恢复，无效或为空时才使用国家目录默认语种。当前实现保留页面已有语言，且未传递历史 peer。

## What Changes
- 回填有效历史对方语言，按当前目录和模型支持范围校验。
- 无效或为空时依次回退到所选国家目录 defaultLanguage、当前可选语言首项；无可选项留空。
- 同国家重复选择、普通和翻译模式采用相同规则，保留 Flutter UI、共用控件和其他偏好。

## Impact
仅影响统一拨号历史恢复控制器与页面接线。覆盖 align-dial-history-peer-language 中禁止历史 peer 覆盖国家默认语种的旧决策，以及 fix-translation-peer-language-fallback 中保留当前 peer 的历史恢复决策；其他路径不变。不改接口、数据模型、平台或构建。
