# iOS 购买校验失败诊断

## Why
用户提供的 diagnostics.jsonl 6/7 中，本地购买统一报 verification，无法判断 Apple 验证、商品、账号 token 或交易类型哪项不符。

## What Changes
- 拆分 iOS 本地校验失败阶段；关联脱敏交易和商品标识。
- 复用现有 JSONL 上传及恢复交易标识，不增加 UI 或改变取消、验单、finish 行为。

## Impact
仅 iOS 交易失败元数据和公共诊断白名单；Android 业务不变。不部署、不打包、不触发真实支付。
