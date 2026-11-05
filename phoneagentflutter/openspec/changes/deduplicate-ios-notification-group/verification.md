# 通知扩展重复目录修复验证

日期：2026-11-03。工作检出：/Users/Eason/.codex/worktrees/ios-liveactivity-group/PhoneAgent，基线7d84c36290dd8d2a4f2eaf9d5a42c33d80338bc1，继续保留上一轮LiveActivity修复及用户当时未提交的Xcode设置。未回写主检出，未提交、推送或合并。

## 本轮修改

通知扩展配置脚本复用TrustedExtensionReferences，按真实路径合并group/文件引用，使用已有产品定位Embed阶段，按引用身份去重source和embed构建项。公共helper及Swift业务源码不变。新增通知扩展fixture并接入既有原生检查入口。

与本轮输入比较，pbxproj严格只有：移除一个重复通知扩展group、五个冗余PBXFileReference及父group对应child；其他对象与属性完全一致。原三个Swift源文件、所有配置及真实文件未删除，Target、配置路径、依赖、签名、权限、包身份、最低系统与嵌入关系保持不变。LiveActivity和通知扩展最终各一个group、一个Target。

## 已执行验证

- NSE-WIRING-01：重复组合并，全部Target的settings/config路径/sources/resources/dependencies/Embed及真实文件hash保持。
- NSE-WIRING-02：仅含path的既有单组复用。
- NSE-WIRING-03：重复组的已使用config/source引用迁移，重复source消除。
- NSE-WIRING-04：连续及与LiveActivity脚本交错执行逐字节不变。
- NSE-WIRING-05：重命名Embed阶段保留且验证器通过。
- 原脚本五项fixture均失败；修复后五项全部通过。原生合同入口也执行两种扩展共10项fixture、1项APNs合同、扩展检查和四个Foundation程序，均通过，无SDK/APNs业务请求。
- Python既有iOS合同52+18+8+7=85项通过。
- Xcode27.2(27B52)、Flutter3.32.0：Debug/dev测试包身份、Release/prod生产包身份无签名设备构建均通过，Xcode构建阶段分别8.0秒与8.3秒。为复用缓存的增量构建，未声称clean build。
- Release主App及两个扩展均为1.0.54(47)、最低iOS16.1；各自UUID与dSYM匹配。
- Flutter/CocoaPods自动改变的升级标记、scheme、空路径数组及锁文件已恢复；结构比较确认交付工程与编译工程只差升级标记及空数组。最终两个配置脚本交错执行字节不变，扩展验证通过。
- 主检出保存文件hash未变；Android/Dart及依赖无差异，iOS非工程配置、业务源码、资源与HEAD逐文件相同。git diff --check通过。

日志、输入与修复快照保存在本检出.local/notification-group/（忽略目录）。OpenSpec CLI不可用，未运行其命令校验。

## 阶段结论

实现及实现者自验通过。未通过项：无。缺证据：独立测试角色、真机通知/LiveActivity/SDK流程及Xcode导航画面验收；未安装、签名或执行真实业务，不声称完整验收通过。主检出未回写，因此当前主工程仍显示原重复目录。

后续集成：用户已于2026-11-03明确授权Git提交与推送；本修复已复制到主检出feature/test_v1.8.0准备提交。上文“未回写/未提交”描述原阶段交付时状态。真机业务回归和独立验收缺口仍保留。
