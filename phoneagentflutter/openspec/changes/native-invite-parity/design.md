## Context

依据NATIVE_FEATURE_PARITY_MATRIX及用户本轮确认，按共享协议、共享页面、Android、iOS四阶段实施，每个手写微批最多3文件。先规范后实现；新能力不归档旧台账change。

## Decisions

- feature-first：domain纯Dart模型/策略，data负责Dio/安全存储/平台，controller分别管理活动、注册待处理状态和奖励。UI不直接访问网络/存储/设备。
- 邀请接口沿用public/resolve、activity、me/code、me/records、me/events。受保护请求复用AccountApi的登录代际与Bearer刷新；结构化错误仅白名单展示。
- 登录增加registrationRequestId、invitationSource；同一手机号/码/来源重试复用请求ID，取消使旧回调失效；短信与challenge不持久化。普通旧邀请码保持兼容。
- 邀请入口按当前API环境校验host/path/scheme，不自动切换环境，不向链接附带token。已登录只提示奖励限新用户；恢复中的链接等会话状态明确后处理。
- 待处理邀请按环境隔离；奖励按环境/API/账号/operationId隔离并持久去重；确认通知不参与记账。复制/海报事件与奖励确认分开。
- 海报共享Flutter绘制、真实二维码；数据与复制/保存通过端口。Android使用MediaStore或系统创建文件，iOS使用PhotoKit追加权限；失败不能上报成功。
- 外部域名关联文件和签名授权独立验证，不因manifest/entitlements存在声称真实唤起成功。禁止卸载保留数据设备。

## Validation

OpenSpec、analyze、协议/状态/登录兼容/页面连续定向测试。仅平台修改阶段构建对应平台；后端/设备/域名关联未验明确记录，不把模拟等同端到端。关键批次提交推送，未验收不归档。

## 2026-10-11 邀请记录对齐修正

复核Android 0f8879e4b与iOS bf2b65245：两端均无邀请记录入口或页面；Android仅保留未接入UI的records API与模型。删除Flutter独有入口、页面及控制器分页状态；活动刷新仅请求activity和code，不依赖records成功。保留records领域模型、Repository/API和协议测试；积分流水、规则、复制及海报不变。当前Mac分支codex/dev_zys仅本地修改，不切换分支或自动提交推送。
