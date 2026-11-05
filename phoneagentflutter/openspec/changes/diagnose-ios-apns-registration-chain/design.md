# 设计

注册层负责配置检查、调用边界、系统回调与20秒有界观察；SDK driver 仅增加初始化开始/结果和等待显式重试的事件，不改变状态转换。注册等待以独立代次隔离；成功或失败回调结束等待，重复同步不延长当前等待；观察到超时仅表示尚未收到回调，不表示 APNs 失败。token 类型与32字节校验维持现有规则，拒绝时只输出固定码。

原生 IncomingDiagnostics 与 Dart DiagnosticTrustedCallerDetails 同步白名单；沿用64条缓冲及账号 consumer 隔离。绑定前缺 owner/token/permission 使用固定码且仅在原因变化时输出。SDK 初始化、绑定回调保持原有单次消费。

验证实际注册源码的替身连续事件、原生 binding state/driver 与诊断安全过滤，Flutter 事件导出恢复、analyze 和 iOS 编译。设备启动、APNs 成功及真实 SDK 绑定分别报告；自动测试不代替真机证据。不主动认证、外呼或支付，不卸载清数据。
