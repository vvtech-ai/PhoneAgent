# 多路结果与思考提示验证记录

## 范围与源码
- 用户批准对齐原生 v1.6.0 并输出测试签名包，版本继续 1.0.52 (45)。Flutter 起点 d65c4c8d，原生对照 8f235920。
- 仅 conversation 展示、SSE 思考解析与测试；模型评价/任务评分复用既有挂载路径。无后端、数据库、SIP 或供应商状态机变更。
- 日志仅证实收到状态/最终结果/提交事件，无指定任务 ID 与完整消息内容，不宣称完成该任务的真机复现。

## 复现与修复
- 批次顺序测试 3 项先复现失败：历史重复回执移位、实时回执先于结果、多批次/模板混排；修复后与原有回执投影/下载联合 10 项通过。
- 阶段文字及真实思考内容测试先复现缺失。独立复核另发现 decoder 未承接 data.text/隐式 append，已使用真实 SseFrame 复现失败，再修复 raw/envelope 的连续 token 语义。
- 原生思考主标题为 AI 思考过程；Phone Agent 是完成后的品牌标识。该结论覆盖旧 align-conversation-feedback-prompts 对标题及实际思考 token 的过窄迁移假设。
- 回执样式测试先复现缺少文件/类型，再核验绿色操作、下载中、失败重试、已保存查看及打开次数。
- 扩大回归发现新增持续动画使旧等待辅助方法超时；辅助方法仅识别实际正在播放的已知思考 ticker，仍拦截未知持续动画。另修复大字体品牌换行溢出、闲置状态文字变化误触发滚动到底。

## 进行中的验证
定向测试、完整 conversation/feedback/calls 回归及 analyze 的最终结果在后续补记。OpenSpec 全量 166 项已通过。测试截图为合成数据组件渲染，不代表真实设备/外呼/下载验收。

## 运行边界
未安装、部署、操作真实账号、外呼或支付。服务端未持久化的思考内容不伪造历史记录。PMReport 已按内置 registry 核对真实仓库名称，不属于登记项目，不上报。

## 最终代码验证
- conversation/feedback/calls 共1365项通过（.local/batch-parity-regression-final.log），配置/登录及组件预检18项通过；失败后修复的15项定向复验通过。
- flutter analyze无问题；OpenSpec严格和全量166项通过；26个变更文件UTF-8及replacement-character/diff检查通过，中文源码回读正常。
- 独立代码复核P1整改后无Critical/Important；实际页面顺序和完成思考卡合成截图已人工查看。
- 本次测试截图导出首次被fake async文件读取阻塞，仅停止对应测试runner，改用runAsync后2项通过；未改产品行为绕过验证。
- test真实product/AOT探针通过，SDK/Agent合法签名AC0002、错误签名AC0009符合预期，无账号认证/外呼。

## 测试签名包交付
- 源码d39623f29bb9b82bc59fec1bd26db433ff1e9fcd已中文提交并普通推送codex/dev，构建前后Git干净且源码冻结。
- test Release 1.0.52(45)，JDK17/Flutter3.32/Dart3.8；登记入口PlanOnly校验与Release config-only --pub生成后，沿已校验精确引擎的离线Gradle构建成功。
- Phone_Agent_TEST_1.0.52_45_test_20261016_135920.apk，78974560字节；SHA256 22b35a95eb806bfa1b9d3866f7823bd03269880aa6b79678c2f2ce7b27a04fd0。
- 实际包名com.vvtech.aiassistant.test、原签名MD5 ebd4c931de412bf5d9c3716815389097、三个测试URL/邀请入口、仅ARM64/AOT/无debuggable与调试kernel/11项保护库字节一致全部通过。新AOT与上轮包不同。
- 交付回执/截图/完整校验记录：工作区deliveries/batch-parity-20261016-45/。本提交仅补交付文档，不改变打包源码；未安装或真实外呼，最后一项用户真机验收保持待办，不归档。
