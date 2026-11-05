## Decision
两个请求入口显式向 _showError 传入各自兜底文案，避免从可变 busy 状态推断操作。已分类错误仍使用原映射；未分类错误不读取 message 或异常原文。网关、领域异常类型、诊断与共用 Toast 不变。

## Scope and evidence
当前源码 _showError 的默认分支调用 authExceptionMessage，会展示 AuthMessageFailure、StateError 等携带的原文；现有测试也确认这一现状。本次用户明确批准替换该展示行为，旧规范中的优先 message 场景由本 change 覆盖。根任务编排规则不变。

## Validation
控制器模拟两个入口的非空/空/空白服务器 message 和其他未知异常；验证已分类错误保持、busy 释放、发送失败不启动冷却及后续可重试。保留既有成功、邀请、保存重试、六位验证码测试，并运行网关等直接相关回归与定向 analyze。无需真实短信或平台构建。
