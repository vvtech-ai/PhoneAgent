## Why
海外创建返回普通HTTP400时Flutter未执行原生aiassistant_app兼容重试。用户明确对齐处理且UI不变。
## What Changes
默认媒体能力创建遇HTTP或网络I/O失败，移除capabilities重试一次；解析失败不重建。
## Impact
仅HTTP backend数据层及定向测试；UI、文案、媒体及merchant规则不改。覆盖此前只允许UNKNOWN_FIELD明确拒绝的限制。
