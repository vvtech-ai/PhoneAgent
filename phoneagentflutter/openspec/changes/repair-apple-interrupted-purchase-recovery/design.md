# 设计
复用 CommerceFailure 和 DiagnosticCommerceDetails；通过白名单保留业务码，支持持久化往返，禁止异常原文与凭据。后台已找到原单，Flutter 不新增订单映射、不把拒绝改为成功。保留本工作区前轮原生诊断改动，不切分支或覆盖其他内容。

验证：日志隐私/序列化、原单恢复、取消/等待、幂等 finish 定向测试与 analyze、OpenSpec；1.0.52(45) dev Profile 覆盖安装，真实新购买由用户操作。

## 后续 Git 授权
用户明确要求本次 Flutter 项目提交并推送；按当前 codex/dev 保留远程新增修改，提交本侧支付诊断与 deliveries 忽略规则后正常推送，不 force，不包含安装包或私有配置。此前不提交/推送的记录为当时事实。
