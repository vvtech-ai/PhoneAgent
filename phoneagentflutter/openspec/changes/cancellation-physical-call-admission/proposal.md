# 注销通话提示收敛

用户于2026-10-28授权：注销不判断任务或已取消支付，只检查真实未结束通话。原 SDK 错误为“通话、任务或支付”，本次客户端只调整安全错误映射与提示。服务端设计与回放见相邻 PhoneAgent_server 仓库同名 OpenSpec change。

范围：account_cancellation domain 为提示 owner，API gateway 为业务错误映射 owner，既有测试验证。保留设置入口、输入确认、短信验证后的最终确认、协议内联链接、共用弹窗/Toast、15天恢复选择和账号隔离；无原生/UI布局变化。
