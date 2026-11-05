# 实时翻译电话原生一致性执行

## Why
用户已批准在 codex/dev_zys 执行共享业务与实时翻译电话计划。现有国外翻译已经接入服务和媒体，但准备阶段事件流断开误走终止路径，绕过可用 AppAudio 回退；完整双端验收仍需测试授权。

## What Changes
- 区分媒体准备失败与拨号后连接丢失，准备失败释放旧媒体后回退，禁止重复外呼。
- 持续核对共享通话 UI、交互及平台配置，与既有 native-ui-interaction-parity、overseas-translation-ui 变更共同执行。
- 国内 SIP、后台持续通话和真实双向翻译作为独立待验项，不用模拟验证替代。

## Impact
涉及 translation domain、定向回归测试及执行记录；不升级工具链或修改生产签名。
