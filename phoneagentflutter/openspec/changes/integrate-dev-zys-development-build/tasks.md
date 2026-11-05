## 1. 基线与合并
- [x] 1.1 fetch、干净工作树、远端HEAD、祖先及预合并冲突核对；记录用户授权覆盖旧dev_zys排除。
- [x] 1.2 no-ff三方合并，逐处解决12个冲突，保留双方有效逻辑及历史文档。
- [x] 1.3 同步分支边界、迁移记录与知识索引，核对UTF8、凭据和来源文件白名单。

## 2. 验证与交付
- [x] 2.1 固定3.32 analyze、全量Flutter测试、受影响原生规则和OpenSpec校验，修复合并引入问题。两项Dart及两项原生Windows宿主限制保留失败，见交付记录。
- [x] 2.2 构建直连开发域名Android包，核对版本、三个基址、SHA并保存交付副本。48包含原私有签名配置。
- [x] 2.3 中文合并提交仅推codex/refactor-conversation-task-flow，核对codex/dev保持原提交；报告未验证的真实服务与iOS环境，不归档。75d44da4已推送，dev仍9a8d4e64。
- [x] 2.4 保留数据安装当前手机；因47遗漏C1签名配置，改用现有私有define重打48并核对模型读取。完整重启后首页QwenOmniPlus ×1.0、模型目录无错误。
- [x] 2.5 最终df5e7097可信与诊断255项、Android可信36项通过，analyze无问题；49安装后首页模型读取成功。
- [x] 2.6 用户追加图标：复制Android App正式自适应/圆形资源及历史iOS同品牌尺寸资源，核对来源SHA、PNG尺寸和iOS无alpha；不重绘图案。
- [x] 2.7 用私有签名配置构建最终50，保留数据安装，核对图标资源与模型读取；最终推送并记录远端。手机任务页QwenOmniPlus ×1.0，首次安装时间不变，APK与凭据未提交。

## 2026-10-15 邀请契约修复双USB开发包1509

用户明确改要开发环境打包及USB安装。当前codex/dev_zys c389acdb保留全部未提交邀请契约修复及原文档；源码和双端私有配置哈希前后不变。固定Flutter3.32/Dart3.8、1.0.51+2026101509，双端分别cloud-dev配置，APP_ENV=dev且三个服务均chakenai-dev.vvtech.tech，四签名字段存在且不输出。Android显式dev/.dev，iOS Profile仍沿既有com.chaken.phoneagent.test非生产身份但网络为dev；没有误用test配置。关闭预览/协议诊断，不改源码、分支或提交推送。

Android默认Debug构建12.2秒通过；安装前新旧APK证书比较发现默认debug证书与现装开发版不同，assert安全停止，没有安装。随后读取用户此前提供的登记keystore/properties，通过密码环境变量仅对导出APK重新签名，最终证书SHA256与手机现装.dev完全一致、MD5 ebd4c931de412bf5d9c3716815389097；包名/版本/SDK19类/Manifest均通过。不改Gradle签名基线、不修改用户签名文件、不复制密码或使用卸载回退。一次安装前ready文件检查因签名步骤尚未完成提前退出，核对构建状态与无安装日志后再按最终验证产物安装。初始zsh未匹配目录glob只影响只读目录查询，已改Python显式路径核对；Python临时正则转义warning随后改raw string。

Android USB -r安装Success，读回2026101509，firstInstallTime仍2026-10-10 15:14:38，启动Status ok/PID9293，截图显示首页，登录有效性未另发认证验证。iOS签名构建34.7秒，codesign严格校验、目标有线设备/provision期限/团队/bundle/version通过，覆盖安装成功，读回同版本、主Runner PID7089存在；iOS从test切dev可能需重登，登录态未另核验。没有卸载/清数据/真实短信/注册/支付/外呼，真实邀请/OTA/业务继续独立待验。

APK与设备签名IPA、源码快照和receipt.json存ignored .local/device-delivery-2026101509/；OpenSpec153通过、diff检查通过。沿用最新邀请/auth/architecture398项定向及analyze回执，本轮只构建/签名/安装/启动，不重复业务回归或声称全量通过，未验收不归档。

## 2026-10-15 克隆身份信息修复双USB开发包1510

用户要求开发环境打包及USB安装。当前codex/dev_zys 91e7e555保留全部未提交align-clone-identity-enrollment实现/测试/规格及原记录，构建包含认证信息脱敏展示、姓名编辑约束及重置身份流程；源码和双端私有配置哈希前后不变。固定Flutter3.32/Dart3.8、1.0.51+2026101510；分别cloud-dev配置，APP_ENV=dev且三个服务均chakenai-dev.vvtech.tech，四签名字段存在且不输出。Android显式dev/.dev，iOS Profile沿既有com.chaken.phoneagent.test非生产身份但服务为dev；关闭预览/协议诊断，不改业务源码、不切分支、不提交推送。

Android构建8.0秒；使用用户此前提供的登记证书对导出APK签名，通过密码环境变量读取、不复制密码或修改签名源文件。最终新旧APK证书SHA256一致，包名/版本/SDK19类及Manifest均通过；USB -r安装Success，读回2026101510、firstInstallTime仍2026-10-10 15:14:38，启动Status ok/PID24736，截图显示首页，登录有效性未另发认证验证。iOS签名构建34.7秒，codesign严格校验、目标有线设备/provision期限/团队/bundle/version通过；覆盖安装成功，读回同版本、主Runner PID7203存在；iOS登录态未另核验。未卸载/清数据，未执行真实认证、删除身份、录音或外呼/收费；打包与启动不代替克隆/身份真实业务验收，不勾选该change第6项。

APK与设备签名IPA、源码快照和receipt.json存ignored .local/device-delivery-2026101510/。OpenSpec154通过、diff检查通过；沿用此前身份/克隆/模型/积分699项、架构4项及analyze回执，本轮不重复业务回归或声称全量，未验收不归档。
