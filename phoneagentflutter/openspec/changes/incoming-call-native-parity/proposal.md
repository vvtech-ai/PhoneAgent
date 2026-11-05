## Why
用户2026-10-09确认执行来电完善计划，要求优先共用业务/UI，按指定两端有效原生实现及对应环境配置同步，并连续接续子任务。既有trusted-caller-parity已接账户/验证/凭据/Live Activity基础，但Android后台组件禁用，iOS通知服务扩展缺失、活动扩展身份不符最新指定，实际验收未闭环。

## What Changes
- 完善共同身份事件及凭据UI、连续导航/账号隔离，不引入AI自动接听或来电自动翻译。
- Android核实公开SDK/角色/权限，按账户和配置生命周期接入有效来电组件，保留必要SDK原生展示；不猜测SDK授权事实。
- iOS补通知服务扩展、指定测试/正式双扩展身份及同App Team，完善通知/身份/Live Activity/结束清理。
- 配置从固定参照读取，仅使用工程内副本与ignored私有输入；真机和真实业务结果独立验收。

## Impact
feature trusted_caller、薄原生端口、Android Manifest及iOS双扩展/工程配置/验证工具；固定Flutter3.32/Dart3.8、竖屏及App身份保持。分支codex/dev_zys，中文提交推送，不混入他方pubspec.lock。真实身份/电话/收费仍依已有明确测试条件，缺失时继续独立工作，不将待验标完成。

## 2026-10-10 设置入口修订
用户确认取消Flutter可见状态中间页，分别复刻两端打开链。设置页保持可见，iOS初始化和guide事实与授权查询分离，Android复用应用级初始化/SIM同步直接打开；失败原页提示，保留账号/覆盖/销毁保护。
