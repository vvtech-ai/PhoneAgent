## Why

用户要求Android OTA无缝升级。固定v65认证录音使用旧私有目录、Keystore别名和DataOutputStream格式，Flutter新槽位无法直接读取，升级后会丢失复用入口。旧读取实现失败即删源，不适合直接迁入。

## What Changes

- 增加同生产Android/精确正式API作用域的只读旧录音桥接和格式校验。
- 新槽位为空时校验当前账号、摘要及元数据，写新加密格式后返回；旧文件、密钥不改不删。
- 新值优先，清理使用持久空标记阻止旧源复活；失败可重试，复用现有按槽位串行和账号代次门禁。
- 增加合成原生格式、Dart迁移/清理/并发测试与集中升级验收说明。

## Capabilities

### New Capabilities
- `android-legacy-recording`: 同包升级的认证录音只读导入和防复活边界。

### Modified Capabilities
无。

## Impact

Android旧格式读取薄端口、认证录音blob包装器和正式provider；不改后端、SIP、TTS、采集SDK或认证/付费请求。不操作真实音频、身份、登录或已安装App。定向测试、analyze/OpenSpec及Android Debug编译；iOS/Web不读取旧Android源。真实同签名升级、旧本机通话记录和降级策略不由此子项替代，不解除Release保护。
