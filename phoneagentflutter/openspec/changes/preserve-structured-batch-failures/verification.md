# 结构化批量失败解码验证

- 全仓扩大运行发现既有 `fresh_balance_admission_test` 的 batch=true 回放，钱包刷新期望 1、实际 0。task_failed 已携带 batchCallResult，但 guard 只排除单通 callResult，因此被提前解码为普通 error。
- 增补两项单通 / 批量结构结果解码守护；批量首轮 RED。guard 同时排除 batchCallResult 后 GREEN；无结构数据的未知失败仍保持普通 error。
- 联验 `call_event_decoder_test`、`fresh_balance_admission_test`、`membership_denial_reply_test`、`voice/membership_denial_speech_test`、`raw_final_interactive_contract_test` 五文件 32 项通过，覆盖真实 controller 的积分刷新和既有拒绝播报路径。
- 最终 36 文件 241 项定向集成包含上述五文件，全部通过；全仓静态分析无问题。当前 change strict 校验与 diff 检查在交付前执行。

这证明客户端解码、控制器和合成播放端口的接线，未进行真实扣费、电话、模型播放或设备音频验收；未知失败不改写为成功。
