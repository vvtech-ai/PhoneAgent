# 验证与交付记录

## 范围
2026-10-13用户批准执行。Flutter基线92ad00fe，aiassistant_app a87c95b，UI参考AIAssistant1 a0bedb12a；当前codex/dev_zys，仅本地修改。源仓库及后端未改，未提交推送。

## 实现
- 公共普通请求90秒读写、20秒连接；SSE握手90秒有界、流内不限空闲，取消/owner失效仍终止，不重放任务。安全白名单握手业务错误。
- 空文案进度、phase/版本/attempt顺序，批量停止后原流与只读恢复；只认持久回执完成。明确逐路业务终态齐备后进入等待总回执，不再以物理状态冒充可停止工作。
- 挂断丢失响应只读核实ENDING/CANCELLING/ENDED/FAILED；NOT_FOUND不作为挂断证明，旧非终态不回退，长等待降频核实。
- 旧确认跨pending失效，task_cancelled/任务结果不明协议，当前最终字幕，tool_terminal同事件总结一次播报及恢复关联。
- 300ms长按复用既有停止按钮；无任务占用时启动ASR，短按仅停止，释放/取消成对。零音频TTS新连接最多重试一次，多句failure不覆盖。
- 保存后原按钮查看模板/回执，Android使用正确MIME；双平台文件exists、前台/打开前检查，删除允许重新下载；拒绝伪装CSV的JSON/HTML。
- 最后恢复补可选activeBatchId/activeCommandId，重进活动批次只读恢复，原命令缺失不伪造服务器命令，显式停止对真实batch。
- 已同步克隆价格、准入、模型音色、翻译、评价等保持；124条声明及正式调用链台账见interface_inventory.tsv、parity-matrix.md。

## 自动验证
固定Flutter3.32.0 / Dart3.8.0，现有Android Studio JBR21用于本Flutter工程，Xcode26.3；未升级工具链。

| 范围 | 结果 |
|---|---|
| 第一次进度tracker/双端既有卡片定向 | 19通过 |
| 第一轮通话/对话/公共网络扩大定向 | 1140通过 |
| 更新后的通话/对话/公共网络定向 | 1153通过 |
| 新增批次恢复/确认代次与通话 | 18通过 |
| 第一次全量 | 4746通过、1跳过、7失败，已记录并逐项修复/复验 |
| 稳定快照完整flutter test | 4755通过、1既有跳过、0失败，6分21秒 |
| 末批恢复：conversation/calls/tasks/core-network及连续Shell | 1236通过 |
| 恢复HTTP映射与业务接线专项 | 6通过 |
| 逐路证据收敛/停止/连续页面冒烟 | 22通过 |
| 播报长按与有效语音引导交接 | 10通过 |

各轮存在重叠，不累加。全量通过后新增活动批次恢复、停止入口收敛与长按引导交接，按影响范围定向复验；未重复第三次全量。

最终analyze、Android Debug、iOS Debug无签名、OpenSpec与diff校验结果在本记录末尾补充。编译仅证明构建，不代表安装或真实功能通过。

## 故障与恢复
- PATH无Flutter/OpenSpec：重新核对目录，使用本地缓存固定SDK及Node/npm已有CLI；无安装升级。
- 新只读回读使旧测试Completer未完成：读取进程及日志后终止该次测试，补齐读回桩与NOT_FOUND拒绝断言后复验。
- 独立恢复回调形成推断循环：显式类型消除，复验通过。手势recognizer级联作用域误绑定及括号lint按当前源码修正。
- 全量旧日期fixture缺少现有翻译summary契约：补测试/可视fixture输入，不改日期/任务产品实现；33项复验通过。
- 全量运行中新增协议断言与旧编译快照不一致：完成首轮后在稳定快照重新全量通过；不把首轮失败记为全绿。
- 只读探索路径/通配不存在均用rg重新定位，没有设备/服务副作用。

## 待验
Android/iOS设备实际ASR/TTS听感、字幕时序、停止/挂断与服务部署、SDK、文件选择器/预览/删除后的恢复、实际计费及生产升级均未验。未安装/卸载/清数据，未发送真实短信/认证/外呼/收费请求，不归档。

## 最后交接补充
长按手势将已由recognizer证实的300ms相对时间交给既有guide，释放/取消后保留有效输入完成引导的规则；Android/iOS手势及偏好10项通过。最后一批仅复用既有引导回调，不改样式或业务请求。

## 最终校验结果
- flutter analyze：无问题，5.0秒。
- flutter build apk --debug：通过，Gradle7.8秒。
- flutter build ios --debug --no-codesign：通过，Xcode10.3秒。
- openspec validate --all：112通过、0失败。git diff --check通过；全部本轮修改的手写源码/测试不超过500行。
- 参考aiassistant_app与AIAssistant1工作区均干净；当前codex/dev_zys仅本地修改，无提交推送。自动实施完成，7.1设备/服务验收保留待验，不归档。
