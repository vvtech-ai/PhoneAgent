# 实时翻译任务卡片标题、时长与第二行时间对齐

## Why
用户要求对齐aiassistant_app的标题、时长与第二行时间来源。现有Flutter缺少callId匹配历史展示及缺失时长兜底。

## What Changes
- 仅匹配当前分页中的翻译callId，补充历史标题、时长与第二行时间。
- 时长优先durationMillis、已有合法时长文本、起止时间差。
- 第二行优先匹配历史生成的通话时间，无历史时沿用任务detail；颜色不调整。

## Impact
任务data/domain/presentation及定向测试。本地修改，不提交、不推送、不动其他工作区改动。
