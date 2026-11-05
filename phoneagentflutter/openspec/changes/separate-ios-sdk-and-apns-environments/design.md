# 设计与偏差证据

| 输入 | APP_ENV / iOS | SDK | 根凭据字段 | 主包 ID | 签名/APNs |
| --- | --- | --- | --- | --- | --- |
| dev | dev | test | trustedCaller.ios.dev.* | com.chaken.phoneagent.test | Development/development |
| test | test | test | trustedCaller.ios.test.* | com.chaken.phoneagent.test | Development/development |
| pro | prod | pro | trustedCaller.ios.pro.* | com.chaken.phoneagent | Distribution/production |

参数仅从 .local/cloud-{dev,test,pro}/ios-device-defines.json 读取；可信凭据仅取根 local.properties。pro/prod 在入口规范化，App 与 native 使用 prod。pro 当前临时 test 配置由用户确认保留；正式构建因内容不匹配而失败。

两个扩展分别为主包 ID + .KXPushServiceExtension / .KXLiveActivityExtension，三个 Xcode configuration 均检查 Team/版本/依赖和嵌入；最终必须完整包含两者。profile 必须授权各自最终 ID，支持 Apple 已有合法通配开发 profile，不能将主包 profile 直接复用给扩展。主包 APNs 三处和交付策略一致；扩展不强行增加未声明的 APNs 权利。

运行时只接受 development/production 合法字符串；实际签名一致性由成包校验保证，不能通过 SDK test/pro 推导。缺失、非法、权限拒绝、系统失败和账号失效保留失败语义。SDK=test+APNs=production 的运行时单元场景可注册；本项目 test 交付策略仍拒绝 production 签名。

已核对基线 6f0fcec0 与未提交诊断修改。已有包 plist=production、签名=production、profile=production；机制定位在 PushRegistration synchronizeNotifications 的 SDK 推导判断，不据此宣称现场唯一根因。主包依赖/Embed 缺失与已有 verify_trusted_extensions.rb 合同不符，恢复已有接线。

## 防止配置反复出错的补充（用户确认）

GitLab CI 分为无私有输入的 Python 合同检查和 macOS 原生/真实 Xcode 扩展接线检查；失败不能忽略。远端 Runner 是否就绪、流水线是否触发与本地通过分别报告。

每次新构建在验证成功后生成严格白名单的 <IPA>.build.json，包含固定 schema、源码 HEAD/快照摘要、配置文件路径/文件摘要、SDK/凭据字段前缀、版本、签名/APNs、三个 Bundle ID、各 profile 摘要和 IPA SHA256。不得包含凭据、Token、号码、账号、完整描述文件或允许设备清单。旧包不补造源码来源。

清单与 IPA 作为同一次工作空间的成对产物校验并导出，全部 SHA256 一致后才清理。安装前必须核对显式目标环境、版本、IPA SHA256、清单、主包/扩展实际签名和指定 USB 设备授权，再固定这份临时副本覆盖安装。校验失败无安装副作用；verify-only 仅核验，不安装、不启动。清单用于可追溯与防误选，不能替代 codesign 和 provisioning profile 校验。
