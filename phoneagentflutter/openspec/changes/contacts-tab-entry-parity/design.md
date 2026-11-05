## Context
固定Android0f8879e4/iOSbb9ff349。AndroidswitchAssistantMainTab未授权拦截；确认V88说明后系统申请，rationale=true拒绝只提示、false设置。iOSshouldSelect按权限策略拦截，有限视作可用，系统拒绝显示设置。
## Decisions
独立纯Dart授权契约和入口协调器，UI仅承接说明/设置弹窗与回调。薄通道authorization/requestAuthorization仅返回权限，不读通讯录；保留load契约供列表和其他调用方。Android返回canRequest，iOS有限/受限沿原状态。设置返回仅处理主动打开设置标记，恢复不重新申请。其他Tab/账号/销毁取消结果，不取消已发系统请求或盲目重放。已授权刷新由入口触发，Shell联系人禁止mount重复读取；Provider首次初始化与显式读取通过已有singleflight合并。普通Web仍显示现有不支持页；演练显式合成权限端口。
双平台权限相关弹窗分别遵循原生有效样式，正文随字号伸缩、短屏可滚动、按钮至少48热区保留无障碍边界。
## Validation
协调器状态/拒绝/设置/迟到测试、通道协议、双平台普通/大字弹窗与Shell导航定向冒烟；analyze/OpenSpec、平台改动双端构建。隔离参考合成流程不当真实系统授权，真实业务不执行。原有pubspec.lock保留，不混入主线程其他改动，不归档，已知HTTP403不无证据重试。
