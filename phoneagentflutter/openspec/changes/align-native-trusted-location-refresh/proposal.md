## Why
真机日志证实已有CN可信位置刷新中因locating被拒绝，与原生Android不一致。
## What Changes
可信位置刷新保持resolved及可拨打；独立刷新标志维持单飞，失败保留可信缓存；无可信位置仍等待。
## Impact
共享Dart位置状态、国内预检、访问判断和诊断，不改平台或接口。
