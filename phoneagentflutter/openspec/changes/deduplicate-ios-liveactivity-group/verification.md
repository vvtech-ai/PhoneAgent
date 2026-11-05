# 验证记录：2026-11-03

本次为隔离检出内的阶段交付，未提交、推送、合并或回写主检出。源码基线为feature/test_v1.8.0@7d84c36290dd8d2a4f2eaf9d5a42c33d80338bc1，并复制用户当时未提交的pbxproj和Runner.xcscheme作为输入；这两项相对HEAD的既有差异不计为本任务修改。

## 本次增量与约束

- 最终pbxproj相对输入仅移除一个重复Live Activity组和五个冗余文件引用，并移除父组中的对应引用。其他对象及其属性完全相同；Target、sources、resources、base config、签名、最低系统、包身份、权限、Embed关系不变。
- 配置脚本按实际目录复用group、迁移已使用引用、合并同路径文件和构建引用。xcodeproj按内容比较对象，移除必须使用UUID定位的delete_at，以保留等值但身份不同的对象。
- Embed查找识别已有产品及两个既有阶段名称；验证脚本按真实嵌入产品识别唯一阶段。本轮当时未处理NSE重复目录；后续用户批准的修复与证据见../deduplicate-ios-notification-group/verification.md。
- 五项fixture覆盖重复group、path-only、连续执行字节一致、已激活重复引用与资源去重、重命名Embed阶段及验证器兼容，接入原生合同入口。
- 未改Android、Dart业务、Swift业务、资源、依赖或锁文件。主检出pbxproj及scheme的SHA-256与保存输入一致；隔离检出的scheme与输入逐字节一致。

## 实测

- 原实现四项fixture失败；修复后五项全部通过。
- Python iOS合同52+18+8+7=85项通过。
- 原生合同入口：1项APNs测试、5项接线fixture、扩展验证及四个Foundation程序均通过，无SDK/APNs业务请求。
- Xcode 27.2 (27B52)、iPhoneOS 27.2、Flutter 3.32.0：Debug/dev无签名编译通过，Xcode阶段36.4秒；Release/prod通过，53.7秒。按既有矩阵使用Debug测试包身份、Release生产包身份。
- Release主App和两个extension均为1.0.54(47)，最低iOS16.1；均有匹配UUID的dSYM。
- 构建过程中Flutter将升级标记改回1510、CocoaPods移除四个空路径数组并刷新预存旧锁文件；交付前恢复用户升级标记、scheme、空数组及本任务未涉及的锁文件。结构比较证明交付工程与已编译工程仅上述标记/空数组有差异，不影响业务编译内容。再次运行接线脚本字节不变。
- git diff --check通过。OpenSpec CLI当前不可用，未执行其命令校验。

日志及输入快照保存在本检出.local/liveactivity-group/，不包含在提交范围。

## 结论边界

实现者自验通过；当前未通过项：无。缺证据：独立测试角色、真机Live Activity/通知/SDK回归和Xcode导航画面验收。未签名、安装或验证真实业务，不声称完整真机验收通过。未改变主检出，用户当前打开主工程仍会看到旧重复组。

后续集成：用户已于2026-11-03明确授权Git提交与推送；本修复已复制到主检出feature/test_v1.8.0准备提交。上文“未回写/未提交”描述原阶段交付时状态。真机业务回归和独立验收缺口仍保留。
