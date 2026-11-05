## 任务
- [x] 1. 读取规范及参考实现，记录用户新增脱敏展示要求
- [x] 2. 身份DTO及预填数据贯通
- [x] 3. 重置服务及账号绑定清理、流程投影拆分
- [x] 4. Flutter共用控件/弹窗接线与脱敏编辑规则
- [x] 5. 定向测试、analyze及OpenSpec验证
- [ ] 6. 实际设备/服务验收（未授权真实认证/删除，不代替验收）

微批1：IdentityProfile/API/CloneFlowServices（三文件）接入字段；微批2：账号绑定重置服务、provider、诊断装饰器（三文件）。OpenSpec154通过；终端PATH缺node，核对后使用已有缓存运行时，未安装工具。

微批3：流程控制器/状态/纯展示投影（三文件），原500行控制器提取投影后498行，无新增超限例外。
微批4：填写组件/页头/流程页（三文件），复用cloneCard、ClonePrimaryAction和NativeConfirmationDialog，加入脱敏提示与重置清理重试。
测试独立批：新增reset领域、正式provider、页面连续流程与键盘聚焦测试，更新旧明文姓名和旧解除脱敏断言；DTO保存不携带certNoMasked。
验证中：新增首轮10通过；identity/voice_clone首次523通过、1个旧断言冲突，更新后相关21项全通过；analyze无问题。正在做最终直接调用方回归。

最终验证：身份/克隆/通话模型及克隆积分直接调用方699项全部通过；analyze无问题；OpenSpec154通过；diff检查通过。详情见verification.md。真实服务/设备仍待验，不归档。

补充架构验证4项通过，确认500行约束及纯domain依赖。
