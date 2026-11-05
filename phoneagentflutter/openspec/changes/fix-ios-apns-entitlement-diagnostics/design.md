# 设计

## 事实与边界
当前检出 codex/dev@7beb059d，有其他任务未提交内容，原样保留且不切分支。Debug/Profile 使用 RunnerDebug.entitlements、development；Release 使用 Runner.entitlements、production。仅在缺失的文件中声明 $(TRUSTED_CALLER_APNS_ENVIRONMENT)。Apple 门户开启能力不等于最终签名带权利，需核对 profile 和成包。

## 安全诊断
保留 IOS_APNS_REGISTRATION_FAILED 原始失败语义。新增 errorDomain 与 errorCode，仅该 iOS pushRegistration/failed 事件有效。域白名单 NSCocoaErrorDomain、NSURLErrorDomain、NSPOSIXErrorDomain，其他归 other；错误码限制为有符号32位整数。原生和 Dart 序列化均校验，丢弃描述、userInfo 及任意自定义字段。域/码是诊断证据，不自动将错误判成成功或改变重试。

## 验证
先重现权限缺失及诊断丢失，再验证修复。Foundation 验证原生消费隔离、buffer、敏感字段清理及绑定状态/driver；Flutter 验证事件桥接、导出和非法元数据；Python 验证 Debug/Profile/Release entitlement 与环境接线。静态检查、OpenSpec、UTF-8、diff 必须通过。签名与真机验收单列，未执行不归档；不安装、不卸载、不清数据、不真实外呼。
