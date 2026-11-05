## Why
用户明确覆盖此前人民币锁价要求：Apple 按 StoreKit 各地区的本地价格和币种购买，不因与人民币后台价不同而额外拦截。仅移除原生检查会导致服务端继续拒单，需要同步实际支付数据模型与验签处理。

## What Changes
- 覆盖 preflight-storekit-locked-price 的 CNY/精确等价限制；保留商品、类型、账号绑定、交易验证和当次 StoreKit 展示价格变化需重新确认保护。
- 商品、普通购买及升级确认使用 StoreKit displayPrice；不解析展示文本或客户端换汇。
- 清理价格限制专用异常分支，保留通用安全错误、原单查询及可信已付优先。
- 服务端必须接受可信 JWS 当地币种和 milliunits 原值，和人民币业务计价基准分开；客户端按冻结的 platformPaidCurrency/platformPaidAmountMilliunits 接入订单历史与恢复展示。

## Impact
iOS 桥接、商业化购买展示/协调与测试。支付宝 CNY 服务端金额一致性、微信暂停、会员权益数量及折扣 SKU 匹配不变。Java 由主代理协调，不在本工作区修改或运行 Maven。
