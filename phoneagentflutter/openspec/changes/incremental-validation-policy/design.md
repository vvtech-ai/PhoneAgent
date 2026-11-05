## Decisions

按用户最新指令覆盖此前将flutter test理解为每批无参数全量的方式。日常lib变更运行analyze、受影响feature及直接调用方测试；跨页面变更追加一条完整App连续流程。失败先收窄复现，不反复跑全库定位。

共享鉴权、路由基础、状态框架、序列化或依赖升级须评估扩大范围；范围难以界定、跨模块阶段完成或交付前执行全量。纯文档仅OpenSpec及diff校验。平台编译和真机安装按平台变更及阶段验收执行，不以Widget代替。

## Validation

2026-09-20脚本落地：scripts/verify.ps1必须显式传-TestPaths（test内文件/子目录）或-FullRegression -Reason，互斥且不允许用test根目录绕过全量开关。默认不构建Android；-AndroidBuild才执行，保留-SkipAndroidBuild作为兼容但不能同时启用。默认依赖沿锁定现状，只有-RefreshDependencies才pub get --enforce-lockfile。-PlanOnly返回命令JSON不启动工具；PowerShell自测覆盖安全默认、范围/路径错误、全量理由、参数冲突和可选构建。真实定向运行验证命令编排，无产品/接口/设备副作用，不重复全量或平台构建。修改微批为scripts/verify.ps1及scripts/verify-policy.test.ps1，证据另批。

本规则批次仅校验OpenSpec；并在同期身份克隆子批采用定向回归。不删除用例、不放宽断言、不改历史证据。
