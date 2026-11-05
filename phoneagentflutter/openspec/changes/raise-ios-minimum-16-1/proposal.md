## Why
用户2026-10-10明确要求Flutter iOS最低版本改为16.1，替代此前15.5基线。
## What Changes
统一Runner、Flutter framework声明、两类扩展、Pods及本地插件最低版本为iOS16.1；同步通知扩展生成器和配置守卫。Activity stale仍仅iOS16.2可用。
## Impact
iOS15.x与16.0不再可安装新版本；包名、Team和用户数据不改变。不升级Flutter或依赖版本。隔离原生参考工具保留其固定来源基线。
