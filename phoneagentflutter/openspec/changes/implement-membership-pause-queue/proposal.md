# 会员暂停恢复与排队购买

## Why
旧版折价换时长与当前 SKU 拦截不符合已批准规则。引入 PAUSE_QUEUE_V1，保留历史订单/发票/资金事实。

## What Changes
- 四种购买仅由等级关系决定；全价、暂停保留、同低等级排队。
- 冻结协议2、共享 fixture、统一 core 时间推进和永久积分来源。
- 分离支付/履约/权益状态，新增审计退款处置；开发库重置须隔离演练。

## Impact
本仓角色：flutter。规范正文 `../story1837-java/docs/membership-v2/会员权益暂停恢复与排队购买_PDR.md` SHA256 `f59e0609768f15d3f827e7234a9405d35af45f3558e09cc56c6f115f67552fac`；共同 fixture `../story1837-java/docs/membership-v2/contracts/SHA256SUMS.json` SHA256 `686efd49686990b9ef2f363d59995a0bad8736a050a3ee3f819e644d855e388c`。客户端仅引用、不复制规则正文。历史 change 全部保留，新规则只用于新订单；旧规则不反向覆盖新契约。
