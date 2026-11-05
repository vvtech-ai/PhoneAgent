# 设计
当前codex/dev_zys有主线程翻译相关未提交修改，保持不动。KX SDK来源为用户指定可信被叫SDK/test与pro，目的地为ios/TrustedCallerSDK/Vendor相应环境。交付件公开头与现有完全相同，保留本地Pod静态链接、Debug/Profile=test和Release=pro；ASN1无新交付件，保持原字节。新trusted-call-reference.png随framework保留，不将参考图替换产品UI。

替换前保留临时可恢复副本及逐文件SHA，机械复制只涉及供应方产物。更新清单后运行独立哈希/环境门禁验证、可信模块定向测试和Debug/Release真机架构无签名构建；构建使用独立DerivedData，不安装App、不调用SDK业务。成功后复核源/目标逐文件一致及无源目录路径引用，再删除源目录；构建受阻时保留源目录。未验收不归档。

## 2026-10-13交付差异
版本仍1.8.0/18、公开头一致；二进制与部分Swift模块变化，framework图片由trusted-call-reference.png改为trusted-call-top.png。按环境完整替换，排除Finder .DS_Store；ASN1、Pod链接与业务桥接不改。保留工作区外临时旧副本，逐文件核对后执行无签名Debug/Release编译与SDK校验，成功后删除本次iOS可信被叫SDK源目录。

## 2026-10-13第三次交付差异
版本仍1.8.0/18；文件集合与上一批相同，变化限二进制、Swift模块和swiftsourceinfo。沿用完整副本、外部备份、独立Debug/Release无签名构建、无源目录依赖后清理流程，不改变业务桥接。

## 2026-10-19交付与兼容
执行起点codex/dev、4e0e8aed，除本次交付目录外工作区干净。test/pro各10个有效文件，四项变化分别为KXSDK、KXSSDK-Swift.h、swiftmodule、swiftsourceinfo；排除.DS_Store。替换前将旧framework备份到工作区外临时目录，保持ASN1和现有环境映射。

新生成头为KXIntroductionPageController及KXSetViewController初始化新增非空deviceToken参数。工程仅调用后者，公开现有TrustedCallerPushRegistration缓存token的只读访问，在创建SDK设置页面时读取最新token，未取得时使用空字符串；不新增通知申请、不记录token、不改变注册/账户绑定/退出解绑流程。其余Flutter界面和原生引导保持。先运行53文件哈希、环境门禁、可信模块定向测试及analyze，再顺序执行Debug/Release设备ARM64无签名编译，独立外部DerivedData，不保存额外构建报告；成功后复核完整副本及无源路径引用，删除且仅删除本次“可信来电被叫SDK”目录。真实推送及可信来电留待单独授权验收，不归档。
