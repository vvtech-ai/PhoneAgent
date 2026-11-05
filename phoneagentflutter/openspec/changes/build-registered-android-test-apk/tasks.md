# 任务
- [x] 添加脚本与Gradle环境/缺失配置/签名保护回归并确认RED。
- [x] 接入独立Debug test身份与固定证书校验，保持默认dev及Release门禁。
- [x] 实现test私有参数校验及临时环境变量恢复。
- [x] 执行不产APK的配置验证、架构与OpenSpec，记录构建待主代理执行。

脚本17项通过；Gradle默认dev及显式test只读变体配置成功，非法env/缺签名/错误证书拒绝；Release dry-run仍按原门禁拒绝。架构4项、OpenSpec145通过、本change strict通过；与只读原单SKU修正共同运行最终analyze，回执见商务审计文档。无真实APK构建或安装。最终私有参数必须使用主代理已核对id2的commerce-delivery-20261015/device-defines.test.json，旧cloud-test参数不能当作同一凭据。

## 2026-10-15 合并后双USB测试包1506

用户明确要求测试环境打包、导出并安装；后补提供Android登记keystore及local.properties，目录另有test-env-c1.json。当前codex/dev a9312dfb，固定Flutter3.32/Dart3.8，1.0.51+2026101506。Android显式test Debug/.test，证书MD5 ebd4c931de412bf5d9c3716815389097与手机旧测试版一致；使用用户提供的测试C1文件与批准test三地址，未使用同目录dev defines。只读签名GET测试SDK首页配置HTTP200/000000且有data；这不证明后台id2或支付范围变更，未改后台。iOS沿用已批准cloud-test独立私有配置、Profile/.test。

Android首次因Java Properties读取中文签名路径编码失败，核对文件存在和构建未安装后，将ignored临时路径属性转Unicode转义，一次重试16.2秒成功；源签名和配置未改，临时含密码属性构建后删除。iOS签名构建39.0秒成功，bundle/version/团队/目标设备/provision期限及codesign严格校验通过。Android APK包名/版本/新旧证书与SDK19类及Manifest通过。APK与设备签名IPA均导出至ignored .local/device-delivery-test-2026101506/，配置和源码哈希未变。

Android USB -r安装Success，读回1.0.51(2026101506)，firstInstallTime仍2026-09-01 09:30:22，启动Status ok/PID16593，截图为登录页，未索取短信。iOS有线覆盖安装成功，读回同版本，Runner PID7017持续存在；iOS登录态未独立验证。未卸载/清数据、未真实支付/开票/认证/外呼；测试环境登录及业务仍待用户验收。没有修改业务源码，不重复合并时已通过的320项回归，不提交推送。实际回执及SHA256见ignored receipt.json。

本批文档验证：OpenSpec151通过、0失败，git diff --check通过；工作区仅三份交付记录修改，无业务源码和Git分支/提交变更。

## 2026-10-15 邀请诊断与OTA修复双USB测试包1507

用户要求测试环境构建并USB安装。当前codex/dev_zys a9312dfb保留全部未提交邀请错误文案/诊断、OTA v2签名及原文档修改，构建包含这些修复；源码/双端私有配置哈希前后不变。固定Flutter3.32/Dart3.8、1.0.51+2026101507；双端test三服务均chakenai-test.vvtech.tech，Android沿用用户提供test-env-c1及登记签名，显式test Debug包com.vvtech.aiassistant.test；iOS独立cloud-test配置、Profile/com.chaken.phoneagent.test。关闭预览与协议诊断，不改业务源码、不切分支、不提交推送。

Android构建11.7秒，包名/版本、登记证书MD5 ebd4c931de412bf5d9c3716815389097及SDK19类/Manifest通过；USB -r安装Success，读回2026101507、firstInstallTime仍2026-09-01 09:30:22，启动Status ok/PID24131，截图确认已登录首页。iOS签名构建41.0秒，codesign严格校验、目标有线设备/provision期限/团队/bundle/version通过，覆盖安装成功，读回同版本、主Runner PID7047存在；iOS登录态未另核验。未卸载/清数据、未真实短信/注册/支付/开票/外呼，邀请真实打开及OTA实际点击/服务器签名结果仍待验，不因打包勾选业务验收。

APK与设备签名IPA、源码快照和receipt.json存ignored .local/device-delivery-test-2026101507/；临时含密码签名属性已删除，用户源keystore/properties未改。OpenSpec152通过、diff检查通过；沿用已有邀请354项与OTA205/14项定向及analyze回执，本次未重复业务回归、不冒称全量。

## 2026-10-15 邀请契约修复双USB测试包1508

用户要求测试环境构建并USB安装。当前codex/dev_zys c389acdb保留全部未提交harden-cross-platform-invite-contract源码/测试/规格及原记录，构建包含手工注册请求号、完整活动快照、刷新合并和提示修复；源码/双端私有配置哈希前后不变。固定Flutter3.32/Dart3.8、1.0.51+2026101508；双端test三服务均chakenai-test.vvtech.tech，Android沿用用户提供test-env-c1及登记签名，显式test Debug包com.vvtech.aiassistant.test；iOS独立cloud-test配置、Profile/com.chaken.phoneagent.test。关闭预览与协议诊断，不改业务源码、不切分支、不提交推送。

Android构建8.7秒，包名/版本、登记证书MD5 ebd4c931de412bf5d9c3716815389097及SDK19类/Manifest通过；USB -r安装Success，读回2026101508、firstInstallTime仍2026-09-01 09:30:22，启动Status ok/PID4280，截图为登录页，未发送短信。iOS签名构建34.7秒，codesign严格校验、目标有线设备/provision期限/团队/bundle/version通过，覆盖安装成功，读回同版本、主Runner PID7078存在；iOS登录态未另核验。未卸载/清数据、未真实短信/注册/支付/外呼，邀请真实链接、相册、注册奖励及手工丢响应后端重放仍待验，不因打包勾选业务验收。

APK与设备签名IPA、源码快照和receipt.json存ignored .local/device-delivery-test-2026101508/；临时含密码签名属性已删除，用户源keystore/properties未改。OpenSpec153通过、diff检查通过；沿用邀请/auth/architecture398项定向及analyze回执，本次未重复业务回归、不冒称全量。
