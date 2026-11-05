# 会员与积分购买升级

## Why

按已确认的1837 PDR v1.7，把会员、积分购买、订单恢复和开票迁移到当前Flutter工程。正式账户仅使用SDK服务的签名接口，客户端不产生支付或权益成功事实。

## What Changes

- 新增商业化domain/data/presentation，独立管理目录、报价、购买、订单恢复和发票生命周期。
- 首页积分入口进入单页会员与积分，保留积分流水/邀请能力；现金订单和用量分开。
- 原生支付使用中立端口，Android渠道代码仅在Android，iOS仅StoreKit。
- 恢复本人已付冲突订单需预览及确认；未知支付结果保留原单。
- 发票个人/企业及票种草稿隔离，下载复用受控账号接口。

## Impact

- 新能力：membership-commerce。
- 基线：origin/codex/dev 36f76ec0；独立分支codex/story1837-membership-commerce。
- Flutter 3.32.0/Dart3.8.0不升级。签名、SIP、ASR/TTS、克隆流程不重建。
- 真实支付、渠道配置、iOS编译、双端视觉与设备验收分别记录待验，不用模拟成功代替。
