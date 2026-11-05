## Tasks
- [x] 1. 确认现场日志、当前分支与用户批准范围
- [x] 2. 新尺寸回归在旧实现失败
- [x] 3. 固定像素与尺寸降级，保留整体预算行为
- [x] 4. 定向测试、Mac编译及匹配符号
- [ ] 5. 新构建真机同图锁屏/灵动岛验证

## Validation evidence
- 旧实现在新增固定像素回归中触发断言；修改后生产函数体Swift替身测试通过，覆盖全部九候选首次命中、提前退出、1536/1537边界、现场120像素失败大小降级、编码/输入失败和原整体预算回退。替身不证明实际JPEG大小或系统显示。
- Flutter头像诊断两项通过；flutter analyze无问题；OpenSpec strict通过；Mac unsigned iOS Debug编译通过12.7秒。
- 未安装新构建、未发推送/来电。用户提供的旧构建日志只作修复前证据，第5项保持待验。
- 构建自动生成的Podfile.lock和pbx空列表差异已保存后仅恢复本次构建前内容，不纳入头像修复。
- 本次二进制与匹配dSYM：/Users/Eason/.cache/phoneagent-avatar-diagnostics/resize_20261029_122358；Runner.debug.dylib UUID 62CB1EE6-F2E9-32EB-879C-3864EA2A035D。

## 真机结果与日志清理（2026-10-29）
- test 1.0.54(47)签名包已按用户指定版本覆盖安装并启动iPhone 15；用户回复“已经显示了头像”。未分别取得锁屏/灵动岛效果或新日志的选中尺寸/质量，因此不补造该证据。
- IPA SHA256 6382c2bfc3c16de9a6fa2eb23f5963e80f75ba93afddd7d3cebc3da98e44e509，源码快照2650b7504aae39f2f40a72a2d837d322e125733417af378709f1854fc659e54a。该IPA是移除日志前构建。
- 用户随后要求移除临时头像日志；已删除原生与Dart专用通道及其测试，保留tool/test_live_activity_avatar_sizing.py覆盖实际生产分支。旧日志change仅为排查历史，不再要求当前运行生成这些字段。
- 日志移除后：生产Swift九候选及预算回退测试通过，原生原有日志回归通过，Flutter诊断5项通过，analyze无问题、OpenSpec strict通过、iOS Debug无签名编译14.5秒通过。源码专用日志符号搜索无残留。未重装手机，手机仍为包含临时日志的已验签名包。
- 清理后匹配二进制/dSYM保留于/Users/Eason/.cache/phoneagent-avatar-diagnostics/logs_removed_20261029_134155；Runner.debug.dylib UUID 5A6469B2-B5A1-3AA7-8B63-60F41258AD3B。
