# 声音克隆诊断实施记录（2026-10-13）

## 实施范围
保持当前codex/dev_zys与其他未提交的翻译/iOS SDK工作。仅新增Dart日志及定向测试，不修改页面提示、原生SDK、接口字段、重试、认证、计费或权限时序；未提交推送。

- `voiceCloneRequest`：限定克隆接口静态别名，开始/结束、HTTP状态、耗时、白名单业务拒绝分类；签名时保留现有X-Reqid的UUID到traceId，未修改请求头。
- `voiceCloneFlow`：随机sessionId串联本次流程，平台及SDK准备/采集/取消/释放、身份读取/积分准入、生成/轮询、试听/停止、确认/激活查询、录音读取/准备/保存/清理、恢复音色和流程关闭。
- `voiceCloneVerificationDecode`：认证响应字段名称与JSON类型，生产流程同时携带sessionId。候选字段解析、生成供应商阶段等既有日志保留。
- SDK返回码/子码、认证状态与问题、轮询序号可用于区分取消、拒绝、同步失败和上限；SDK边界保留固定权限/音频准备/SDK准备失败分类。
- 认证录音下载包含HTTP返回后格式/大小等校验失败，后台保存失败不回滚已确认声音。

## 查看方式
使用包含本次修改的新包复现后，通过原有设置“日志上传”获取diagnostics.jsonl。优先按sessionId关联，再按cloneFlow.stage与result定位；traceId为实际签名请求UUID时，可和后端对照。初始化400已知原因记录为固定英文分类，例如identityReplacementRequired/submissionUnresolved；未识别消息统一serverRejected，具体供应商内部原因需后端日志，不能据未知分类认定根因。

示例（仅合成结构）：
```json
{"operation":"voiceCloneRequest","result":"failed","statusCode":400,"elapsedMs":92,"cloneFlow":{"stage":"verificationInit","platform":"iOS","reason":"identityReplacementRequired"}}
```

不得记录姓名、身份证、账号、token、API key、签名、完整路径/URL、metaInfo、certifyId、跟读文本、音频、receipt或原始异常/服务端消息。请求路径映射为静态别名，动态模型/认证/候选ID不记录。日志sink异常与业务隔离，无自动重发认证/收费。

## 实际验证
- `flutter analyze`：通过，无问题（最终3.8秒）。
- 克隆、音色、身份、日志上传/持久化、公共AccountApi及日志页面连续流程定向集合：707项通过。
- 末轮录音下载/原子保存/诊断专项：23项通过。
- 认证字段解析关联ID补测：9项通过。
- `openspec validate --all`：107项通过、0失败；`git diff --check`通过。
- 新增诊断专项包含HTTP400、200业务拒绝、超时、未知消息脱敏、请求关联ID与Journal重建、字段错误、完整克隆/确认未知结果/可选保存失败、SDK异常/取消、轮询失败/上限及sink故障。断言请求次数与业务结果保持。

初轮新增测试14通过1失败：SDK故障测试的清理阶段仍使用busy模拟返回；核对后只修正清理桩。后续扩大首轮703通过1失败：新增签名测试clientContext不是合法base64url；改为现有C1合成上下文e30后707通过，未修改签名实现或执行真实请求。初次analyze的括号lint、无效pattern/cast/未用测试import已修正。验证均使用固定Flutter3.32.0/Dart3.8.0，未升级依赖。

## 待验边界
- [ ] 包含此修改的Android/iOS真机复现并上传，确认实际日志归档。
- [ ] 原iOS初始化400与后端请求日志关联，确认现场根因。
- [ ] 真实SDK权限、跟读、取消/释放和克隆服务联调。

未运行真实身份认证、个人音频上传或收费操作；本次未改原生、依赖、配置或构建链，未打包安装。离线测试不等于设备验收。change未验收，不归档。

## diagnostics-11补丁及当前Android对比
现场15:19:30 SDK准备成功，init请求25ms返回400。前轮日志匹配只允许/api起始，漏掉当前/aiassistant-sdk-api/网关前缀，这是已确认实现缺陷；前轮根路径测试通过不代表实际网关覆盖。现ServiceRoutes.logicalPathOf从已配置且同源的最长base剥离网关后匹配，签名与发送URL保持原样。禁止任意indexOf截断。

新增初始化requestModelPresent布尔元数据，不存模型值；补模型缺失和AC0001/7/8/9签名拒绝固定分类。后端未知正文仍不记录，实际签名UUID可对照后端，不能据unknown分类认定根因。

当前参考Android HEAD a128130；2026-10-10的6b9aa34已增加初始化modelId并从selectedModelId传递。Flutter ApiCloneVerificationRepository初始化请求缺此字段，是确认的请求差异；前文“字段基本一致”不足以代表当前版本完全对齐。生成候选接口路径/幂等头基本相同，但Android另传X-Expected-Clone-Price-Points，目录/准入使用动态pricePoints及价格变更处理；Flutter未传该头、仍固定300。两项业务差异本补丁仅记录，不静默改认证/计费。当前本地后端InitRequest未包含modelId，不能把本地后端定义当作线上最终契约；现场400根因仍需错误分类/后端证据。

本批新增13项网关集成测试通过，覆盖iOS/Android、根路径/实际网关/多级网关、HTTP400缺模型、200业务拒绝、未知400、超时、签名拒绝、401刷新和最长base/跨源拒绝；断言真实签名头UUID、原wire URL、Bearer及请求次数不变。扩大voice_clone/call_models/identity/app_logs/core-network与日志页面连续流程736项通过，analyze8.5秒无问题。未跑全仓、未构建安装、未真实认证/上传/收费。AccountApi493行，主流程500行；源码2文件路由微批、3文件详情微批，测试独立1文件、格式化机械批。工作区其他修改保留，不提交推送。
