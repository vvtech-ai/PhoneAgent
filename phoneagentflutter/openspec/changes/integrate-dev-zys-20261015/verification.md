# 2026-10-15 分支合并验证

- 用户明确要求codex/dev_zys合入codex/dev。目标543ee23c、来源1df878ff，共同祖先40551384；两边各2提交，本地与fetch后远端一致，起始工作区干净。
- no-ff三方合并无冲突。产品路径不重叠；37来源/64目标单侧文件逐一blob一致，tasks与issue日志双方新增行均核对保留。
- Flutter3.32.0/Dart3.8.0：邀请/auth/notice/首页导航与连续Shell320项通过，analyze23.6秒无问题；本次影响可界定，不重复无关全量。
- Android Debug38.3秒、iOS Debug无签名30.7秒构建通过；Android既有JBR21，InviteAppLinkPolicyTest 2项通过（0失败/错误）。固定Flutter SDK实际Swift编译验证cold/openURL/continue三个selector注册，near-match=false。
- OpenSpec151通过0失败，工作区与暂存diff检查通过；没有修改其他工作树、来源分支、后端或设备，没有注册/短信/收费。
- 来源设备邀请投递/注册奖励等待验项保留；本次构建不代表设备验收，不归档。
- 提交前ls-remote再次确认目标543ee23c、来源1df878ff。合并提交与推送回执在实际完成后追加。
- 工具恢复：读取原生JUnit XML时先按Android默认build路径查找失败；核对Git状态与BUILD SUCCESSFUL后rg定位到Flutter重定向的build/app/test-results，读取2项0失败；失败发生在文档写入前，无重复测试或业务副作用。

## 合并与推送回执
合并提交683346be544e8f6d7ee0858b4d32da60ab871340，父提交543ee23c和1df878ff，两方祖先关系核验通过。普通push成功后ls-remote读回codex/dev为683346be，codex/dev_zys仍1df878ff；工作区干净。此后仅提交本回执文档，不改产品源码或重跑业务测试；最终仍保留设备/真实邀请业务待验，不归档。
