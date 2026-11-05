# 秒配置实施验证（2026-10-28）

## 实际结果

- Flutter：锁定Flutter3.32.0/Dart3.8.0，analyze --no-pub无问题。定向128项通过：注销模块、单位/兼容解析、最终弹窗、双确认、自动验证码和设置整链路。不是全量测试或真机验收。
- SDK：显式JDK17，mvn -pl aiassistant-sdk-api -am本地构建及定向72项通过，0失败/错误/跳过。覆盖Cancellation*Test及鉴权、固定码/短信登录直接调用方；包含主线程当前共享工作区的通话测试，不表示本次修改或单独签收其业务逻辑。
- 真正Spring RefreshScope/ConfigurationProperties容器测试：同一Service在刷新后创建新期限确认；旧确认对象及持久SMS/VERIFIED快照不变；非法0/负数/超限/小数/非数字绑定被拒绝，恢复有效配置后可继续。
- 默认1296000秒及300秒流程、途中切7200/30/60秒、同操作重放、旧未受理无快照拒绝、旧已受理无快照仍返回原截止都有业务回放。
- Flutter严格阈值：86400秒=24小时、3600秒=60分钟、60秒=60秒；90000秒=1天（完整单位向下取整）。缺字段只显示通用冷静期；null/非正/非整数/字符串字段拒绝。绝对预计时间和原控件保持。

## 源码/迁移与兼容

- 新字段仅在现有Confirmation响应中返回；请求仍不允许客户端设定时长。协议URL/版本固定合同不改，enabled开关仍按原启动绑定；只有新冷静期配置支持刷新。
- 默认和合法范围为1..1296000，保护现有固定16/17天恢复清理窗口；不跟随短测试期限缩短记录保留。
- 独立补列V202610280001，保留NULL给旧未受理挑战，不回填历史申请；旧20261026脚本未修改。新库与SDK测试schema同步。
- 已受理查询/重放优先返回原effectiveAt；配置刷新不更新历史申请。
- dev模板及host-220片段只改本地文件，公开协议1.0保持15天正式承诺，短期限仅供测试环境验证。

## 并行工作边界

两仓均保持原检出，不切换/重置/提交/推送。后端实施期间存在主线程的通话停止/准入调整，包括CancellationService与CancellationServiceTest的其他差异。本次只增补秒配置、快照和相关测试，不恢复旧门禁、不改主线程文件或删除其新增文件。最终git diff的通话差异不能全部归属于本次秒配置。

## 未执行

未发布Nacos、修改共享数据库、运行DDL、重启部署、发送短信或操作真实账号。未做真实Nacos事件链、MySQL并发/字段读回和Android/iOS真机验证。OpenSpec CLI当前PATH未发现，本地结构检查不冒充strict验证。

本地输出：/tmp/phoneagent-cooling-seconds-java-regression.log、/tmp/phoneagent-cooling-seconds-flutter-regression.log、/tmp/phoneagent-cooling-seconds-analyze.log。
