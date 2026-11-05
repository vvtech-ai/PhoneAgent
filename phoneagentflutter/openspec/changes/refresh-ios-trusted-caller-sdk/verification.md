# iOS可信SDK更新记录（2026-10-12）

## 范围
用户指定的可信被叫SDK/test与pro替换工程内相应KXSDK.framework；两套版本仍为1.8.0/build18，公开头文件字节相同。每套变更为KXSDK静态archive、arm64 Swift模块和swiftsourceinfo，新增trusted-call-reference.png。完整副本各10文件。ASN1和Android产物未修改。

保留Pod静态链接及iphoneos条件，Debug/Profile=test、Release=pro，未修改业务桥接、权限、Flutter页面或依赖版本。源目录在编译和自包含检查成功前保留。当前codex/dev_zys主线程翻译修改不纳入本变更，不切分支、不提交推送。

## 当前验证
- OpenSpec：92项通过。
- SDK清单：53项SHA256通过；竖屏声明检查通过。
- 原生环境门禁：1个测试、4种宏配置通过（缺失/非法/test/pro），仅合成凭据。
- 可信模块定向Flutter测试：109项通过（18秒）。
- Debug真机架构无签名编译：BUILD SUCCEEDED，测试SDK。
- Release真机架构无签名编译：BUILD SUCCEEDED，正式SDK。
- 实际SDK授权、推送投递、可信来电和设备视觉：未运行，待用户授权条件和设备验收；编译不等于真实SDK功能验收。

## 新交付件二进制SHA256
- test：`48199fde03a1b6403493c0360368ae9eea82b790f1ab23385ecf46aa50dbcac1`
- pro：`9df18461ae887013c37e7dba5b0b5f436d4fda2083cb5e014e38ba9f839afc5c`

## 源目录清理及限制
Debug日志仅test搜索路径、Release仅pro，均包含KXSDK/ASN1链接。源与工程副本每套10文件逐文件SHA一致，Podfile/Podspec/Xcode工程无交付源目录路径引用。按用户授权已删除工程根可信被叫SDK目录，工程Vendor副本保留且再次校验。旧版本临时可恢复副本保存在工作区外，未加入Git。

构建日志的Debug Flutter脚本曾输出缺少NSBonjourServices/NSLocalNetworkUsageDescription键的非致命诊断，最终命令退出0且BUILD SUCCEEDED；本次未改动这些既有网络权限配置。当前Xcode26.3，未升级工具链。真实SDK初始化、认证、通知和来电未测试。

## 2026-10-13第二次交付
用户本次指定`iOS可信被叫SDK/test`与`pro`，分别完整替换工程内同环境framework。版本仍1.8.0/18；公开头一致，二进制和Swift模块变更，图片由trusted-call-reference.png改为trusted-call-top.png。排除Finder .DS_Store；每套有效文件10个，与源目录逐文件SHA256一致。ASN1、Android、Pod环境映射、业务桥接和UI未修改。旧工程SDK备份位于工作区外临时目录。

- 新test二进制：`8864eb5b70363363856ac7b94629391fa9c70045fbd3fcf89e937c7bcabaf316`
- 新pro二进制：`10eda6208dae70845876f78429436def6ce50947b222e55759524aaa0095a8b6`
- `python3 tool/verify_trusted_sdk.py`：53文件SHA256及竖屏声明通过。
- `python3 -m unittest tool/test_trusted_caller_environment.py`：1测试4种宏环境通过。
- 固定Flutter3.32可信被叫模块测试：109通过（6秒），非全量回归。
- OpenSpec：105项通过。
- Debug iphoneos/arm64无签名构建：BUILD SUCCEEDED；仅test搜索路径，KXSDK/ASN1链接，无交付源路径依赖。
- Release iphoneos/arm64无签名构建：BUILD SUCCEEDED；仅pro搜索路径，KXSDK/ASN1链接，无交付源路径依赖。
- 两套副本每套10文件一致；按用户授权已删除本次`iOS可信被叫SDK`目录，删除后工程SDK清单复核通过。

构建使用独立`/tmp/phoneagent-ios-trusted-sdk-20261013-derived`，没有安装App，没有实际SDK认证、通知或来电测试；真机功能与用户验收继续待验。未切分支、未提交推送，保留主线程翻译相关未提交修改。未验收不归档。

## 2026-10-13第三次交付
再次按用户新提供的`iOS可信被叫SDK/test`和`pro`替换两套framework。版本1.8.0/18、公开头与文件集合不变；二进制、Swift module及swiftsourceinfo再次变化。每套10个有效文件，排除Finder .DS_Store；ASN1、Android、桥接、UI及环境映射不改。

- test二进制SHA256：`f7b9c120126aff64b5e05adc565a64dce552e8c87c39ac4796c8e5aa54823013`
- pro二进制SHA256：`dec41eacb003c68bd9464d380b4894b9e995ac5e14dc8e6f2d7cb9f4793a91da`
- 53项SDK清单及竖屏声明通过；原生1测试4种环境门禁通过。
- 固定Flutter3.32可信模块109项通过（5秒），非全量回归。
- OpenSpec105项通过；diff检查通过。
- Debug iphoneos/arm64无签名BUILD SUCCEEDED，test路径及KXSDK/ASN1链接、无源路径依赖已核对。Flutter脚本仍有既有NSBonjourServices/NSLocalNetworkUsageDescription缺失诊断，最终构建成功；本次不改权限。
- Release iphoneos/arm64无签名BUILD SUCCEEDED；pro路径及KXSDK/ASN1链接、无源路径依赖通过。
- 两套副本每套10文件与交付SHA256完全一致，按本次授权已删除重新交付的`iOS可信被叫SDK`目录。删除后工程清单复核通过。

本次独立DerivedData为`/tmp/phoneagent-ios-trusted-sdk-20261013-r3-derived`，旧副本在工作区外临时目录。未安装App、未真实认证/通知/来电；真机功能待验，未提交推送，未验收不归档。
