# 范围与状态所有权

仓库 PhoneAgent，基线 codex/dev@edbf251193afb08ac90f40c3a427ad4ed8a97845，进入时工作区干净。实现限 Flutter 商城控制与展示层；不改后端协议或原生 StoreKit。PurchaseController 持有页面状态及 revision，IosPaymentRuntime 持有账号内原生任务、持久尝试和交易恢复。

入口：会员、积分、继续原单、主动查询及前台/重启恢复。接口仍为原创建订单、支付材料、Apple验单、订单查询和取消补报；身份仍使用账号、订单、尝试、appAccountToken和交易ID。保留价格复核、成功后finish、幂等、账号隔离、到期原单不可再支付及迟到交易恢复。不得打印token、签名或认证内容。

文件职责：ios_payment_runtime 移除原生30秒边界，保留并发/存储/恢复边界；purchase_launch 单独限制材料获取，完整成功交易后才计时验单及订单结果；purchase_state/controller 投影等待阶段，允许等待阶段查询但阻止重复购买；共用PurchaseLoadingOverlay保留原Card、遮罩颜色、转圈及文案，并在会员与Apple积分页呈现。

覆盖 IOS-PHASE-01 长时间Apple操作/无回调、02 成功后核验超时、03 迟到成功与重复回调、04 取消/pending/异常、05 查询/离页/换账号、06 订单到期交错、ANDROID-UNCHANGED。调整旧 IOS-WAIT-01/02 的30秒原生超时期望，保留恢复、持久化、身份与隐私断言。

systematic-debugging、verification-before-completion、stuck-debugging-reset 技能在当前可访问技能目录中未找到；按日志复现、针对回归及完成前验证执行，不声称加载技能。实际运行安装包身份本轮未独立核对，日志仅作为旧故障证据。

取消补报仍由调起流程处理；运行时先持久取消意图并通知恢复。页面revision失效后，只要原账号有效仍补报原单。补报返回可信终态后立即交运行时observe，防止下一次restore从旧canceled尝试重新生成已清理待办；失败保留原错误及稳定请求身份。回归中保留原取消网络失败断言，未删减既有恢复合同。

PurchaseController本次524行，为保持账号/revision/展示状态在同一owner中的局部例外；网络调起与核验轮询仍在独立purchase_launch，未将新的平台调用揉入controller。

已有ios_payment_wait_test原495行，本次507行，保留同一组持久恢复/取消/账号回归及共享fixture，作为局部例外；新增阶段回归另建独立文件。

## UI决策修订
用户在真机截图后明确要求不能使用底部提示、只能使用原全屏加载遮罩，覆盖此前非阻塞展示约定。删除新增底部提示；原遮罩提取为共用PurchaseLoadingOverlay，颜色、Card、转圈和“支付处理中…”文案不变；会员与Apple积分等待时使用同一控件。Apple阶段仍不计入核验30秒，故Apple永不回调时遮罩继续等待，此前无回调锁屏问题不再声称已解决。程序层查询/账号隔离和恢复仍保留，等待遮罩不再新增查询入口。
