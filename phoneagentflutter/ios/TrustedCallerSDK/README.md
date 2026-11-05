# 可信来电 SDK 工程依赖

测试/正式KXSDK1.8.0/18分别存Vendor/test和Vendor/pro；Android固定1.5 AAR存android/app/libs/trusted_caller。构建仅引用工程内副本，不引用提供的iOS_SDK或原生工程路径。SDK_MANIFEST.json记录每个vendor/资源文件SHA256；generated Swift头文件/模块/abi为供应方产物，不按本工程手写源计行。

KXSDK和固定ASN1均arm64真机静态库，不能当模拟器库；真实SDK链接按device条件和环境选择，不同时加载两套KXSDK。Resources为固定原生SDK图片、预览GIF和内置号码归属地库，不包含用户通信记录。ASN1仅复制有效SDK文件，不带_CodeSignature元数据或私有签名材料；最终应用由自己的构建签名。

部署配置/实际SDK端口和验证进度见../../openspec/changes/trusted-caller-parity/tasks.md；副本存在不代表SDK已初始化或授权完成。

2026-10-12按用户交付件更新test/pro KXSDK：版本仍1.8.0/18，二进制及部分Swift模块变更，公开头文件一致。新增trusted-call-reference.png随供应方framework完整保留，不替换产品UI；ASN1及固定依赖不变。清单共53个文件，构建继续仅使用工程内Vendor副本。验证记录见../../openspec/changes/refresh-ios-trusted-caller-sdk/verification.md。

2026-10-13再次按用户“iOS可信被叫SDK”交付替换test/pro；版本仍1.8.0/18，公开头一致，二进制及部分Swift模块更新。完整framework图片改为trusted-call-top.png，旧trusted-call-reference.png移除；Finder .DS_Store不纳入工程。清单仍53文件，ASN1、Android与环境链接不变。本次验证单独记录于上述change。

2026-10-13第三次交付再次更新test/pro二进制及Swift模块；版本、公开头和framework文件集合不变。最终字节以SDK_MANIFEST.json为准，验证记录见refresh-ios-trusted-caller-sdk本批记录。

## 2026-10-19交付更新
用户提供“可信来电被叫SDK”中test/pro完整framework，每套10文件，版本仍1.8.0/18。生成头、二进制及部分Swift模块更新；设置初始化新增deviceToken，桥接复用现有APNs注册缓存，未取得时传空字符串。保持ASN1、环境映射、推送绑定生命周期及Flutter UI。逐文件SHA256以SDK_MANIFEST.json为准；删除交付源目录以前须通过副本、环境与设备架构编译验证。
