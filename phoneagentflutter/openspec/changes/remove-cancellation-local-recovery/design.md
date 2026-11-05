# 设计与职责

- 仓库/层：PhoneAgent，Flutter account_cancellation presentation/domain/data及设置页接线。状态owner：服务端持有申请事实，CancellationController仅持有当前页面操作身份与查询凭证。
- 基线：feature/test_v1.8.0_zys，HEAD ab8922066882bfc1fd94da936790080d0f976eb8，开始时工作区干净。仅有截图和代码触发路径证据，未确认现场lookup具体失败原因。
- 入口：设置→关于PhoneAgent→账号管理→注销账号。入口确认后直接取得服务端confirmation并发送短信，不读本地恢复记录、不查询旧operation。
- 接口与身份：保留confirmation、sms/send、sms/verify、applications及当前操作lookup；operationId与queryToken只在当前controller内存中使用。提交失败仍lookup同一operationId，不重新提交未知操作。
- 文件职责：coordinator仅准备服务端确认与创建controller；controller删除提交前持久化依赖；providers删除存储provider；domain/data删除恢复端口和实现；route删除恢复成功分支及恢复记录清理调用，保留session退出清理。
- 生命周期：页面销毁后不恢复旧操作；重新进入按服务端接口校验账号状态。服务端已受理但客户端未收到时，仍由服务端拒绝普通业务或登录时提示待注销状态，客户端不能将未知改成功。
- 保留规则：入口/最终确认、协议、验证码自动验证及频控、冷静期快照、受理后退出、旧账号迟到响应隔离保持；无UI风格或共用控件变化。
- 回放范围：DEL-01-01/02/03/04/05、DEL-02-03/04/05、DEL-03-01/02/03、DEL-05-01、DEL-UI-01/02/03及账号替换/离页。跨页面本地恢复按用户本次决定移除，当前页面未知结果查询保持。
- 验证：旧存储存在/不可读也不阻止入口，提交零恢复存储调用，同页响应丢失只查原操作，受理退出和账号隔离；模块analyze与注销/设置调用方定向测试。未改平台和依赖，不打包、不请求真实短信、不部署。
