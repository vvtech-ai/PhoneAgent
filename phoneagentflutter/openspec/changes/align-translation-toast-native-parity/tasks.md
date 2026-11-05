# Tasks
- [x] 1. 核对现有规范、共用 Toast 与原生文案/失败分类。
- [x] 2. 纯 Dart 失败分类及国内、海外错误信息传递。
- [x] 3. 拨号前 Toast 及原生文案对齐。
- [x] 4. 通话终态跨页 Toast 去重及清理异常边界。
- [x] 5. 定向测试、analyze、OpenSpec 与 diff 校验，更新记录。
- [ ] 6. 用户及双端运行验收（不包含真实外呼、打包安装）。

## 实施批次
1. 失败策略、国内 controller/coordinator 三文件，保留 SIP 结构码和清理未确认。
2. 海外准备策略/coordinator、路线计划三文件，用户文案与诊断分离。
3. 拨号 actions/route、国内拨号绑定三文件，接入共用 Toast。
4. 终态 route/page、国内 factory 三文件，跨页单次提示。
5. 新增分类、双端终态、双端准入测试；同步直接受影响旧断言。现有手写修改文件均不超过500行。

首轮回归暴露旧文案断言和测试切页等待不足，已逐项修正；新增准入 fixture 在设置目录加载后明确选择英语，避免同语种校验先行拦截。没有改变正式语种规则。最终联合验证结果见下文。

## 最终验证
- Flutter 3.32.0 / Dart 3.8.0：flutter analyze 无问题。
- flutter test --no-pub：25个定向文件、189项全部通过。覆盖新增 translation_call_failure_test、translation_dial_toast_test、translation_terminal_toast_test，以及国内coordinator/controller/factory/拨号、海外coordinator/controller/准备流/诊断、拨号完整流程/返回防护/号码确认/摘要流程、共用Toast三文件、shell_unified_dialer、architecture_test。
- openspec validate --all：202项通过；git diff --check 通过。
- 双平台 Theme 的自动化 UI 验证不代表 Android/iOS 真机验收。未全量测试、打包、安装、真实外呼或收费；未提交推送，未归档。
- 工具恢复：node/openspec/flutter不在PATH，核对缓存后使用既有Flutter3.32和缓存CLI；无安装升级。前期不存在路径读取无副作用，已以实际文件继续核对。

## 2026-10-19 提交前影响复核与授权
- 用户在知悉影响分析后明确要求Git提交并推送远程；本次保存当前两项实现，不额外执行此前仅提出、尚未批准的范围收窄方案。
- 复核36ab5f3a..5b91fb7d后的有效38个测试文件：312项通过、3项失败。translation_pages_test的非法号码断言仍期待旧文案，尚未同步；translation_setup_test两项默认语种断言失败，控制器/依赖/测试与已提交HEAD相同，本轮未修改该逻辑。首次历史列表包含一个已删除测试文件，已排除后复验，不计业务失败。
- 已知间接影响保留并向用户说明：普通拨号非法号码也改共用Toast及中国手机号文案；共用PermissionChannel.resolve(location)读取合并的申请记录，可能更早返回blocked。未执行隔离普通模式或恢复任务对话旧判定。
- 后台模型语种过滤、默认语种算法、位置未确认入口仍保留；不把源码保留等同全部场景验收。用户/真机验收与上述失败待处理，OpenSpec不归档。

## 推送前集成验证
- fetch发现origin/codex/dev新增d677f258，保存本地修改后将未发布提交rebase到该远端版本；保留远端对话输入、会员套餐、认证限额和国内扣分反馈。
- 冲突仅根任务/问题记录及TranslationSessionRoute；文档保留双方新增段落。路由保留失败Toast和服务端确认的结算Toast，共用队列分别展示；controller保留远端settlementNotice生成规则。
- 新增正常结束/失败结束同时带结算回执的路由回归，验证退出后仍显示、重复终态不重复入队。
- 集成后19个定向文件150项通过；flutter analyze无问题，openspec validate --all 204项通过，diff检查通过。包含远端对话/会员/认证测试和本轮翻译/权限/共用Toast/架构测试。
- 前述38文件补测中的3项失败及两项间接影响仍待处理，未纳入额外修复；本次未全量回归、重新打包、安装或真实外呼。此前Debug验证属于集成前记录。
