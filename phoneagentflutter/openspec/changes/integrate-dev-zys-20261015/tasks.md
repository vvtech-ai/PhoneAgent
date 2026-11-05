## 任务
- [x] 1. fetch与干净工作区、分支、来源规格核对
- [x] 2. 合并与冲突处理，保留双方文件/历史
- [x] 3. 定向回归、静态分析、OpenSpec与双端编译
- [x] 4. 中文合并提交、非强制推送及远端祖先核验
## 待验
真实设备邀请投递与注册奖励沿来源change保留，不因合并标为通过。

- 三方合并无冲突；37个来源单侧文件、64个目标单侧文件逐一blob校验一致；共同修改仅tasks.md和docs/codex_issue_log.md，双方记录自动保留。

- 验证：Flutter邀请/auth/notice/首页及连续Shell320项通过、analyze23.6秒无问题；Android Debug38.3秒、iOS Debug无签名30.7秒；原生邀请策略2项通过、Swift三个selector实际注册；OpenSpec151通过，diff通过。非全量、不安装、不触发真实业务。提交前远端仍目标543ee23c/来源1df878ff。

- 实际回执：合并683346be已普通推送，远端读回一致；父543ee23c/1df878ff均为祖先，来源1df878ff未动。

## 2026-10-15 codex/dev快进合入codex/dev_zys

用户明确要求反向同步。fetch后来源codex/dev和origin/codex/dev均a9312dfb，目标codex/dev_zys及远端均1df878ff，目标落后4提交且无独立提交。在ignored临时Git工作树执行merge --ff-only，目标快进a9312dfb，无冲突、无新增源码或合并提交；两分支HEAD及tree完全一致。普通push origin codex/dev_zys成功，ls-remote读回两个远端均a9312dfb33e8666fdc5cc3690965f4dffabecd8b。

主工作区仍codex/dev，其他既有工作树不动；三份原未提交测试包记录在操作前后SHA256一致，未stash/提交/丢弃；临时工作树干净核验后移除。仅同步已验证提交，不重复业务测试和构建；此前320项定向与双端编译、测试包1506证据保持各自边界。同步记录作为本地文档保留，不混入已有未提交记录创建提交。

## 2026-10-15 最新dev_zys修复快进合入dev

用户明确要求将codex/dev_zys合入codex/dev。fetch后来源c389acdb、目标a9312dfb，目标落后1提交且无独立提交；主工作区干净。临时Git工作树执行merge --ff-only后，目标与来源HEAD/tree完全一致，无冲突，包含邀请欢迎失败文案/诊断及OTA v2签名修复。固定源码/私有配置指纹与测试环境USB1507实际构建安装时一致；复用该轮Android/iOS构建、签名、安装/启动及来源既有定向测试/analyze证据，本次不重复无源码变化的业务测试或构建，不把自动证据当真实邀请/OTA验收。

本次OpenSpec152通过、0失败，diff检查通过；仅另加三份集成记录并中文提交到codex/dev，普通推送该目标，不force，不更改来源分支。主工作区继续codex/dev_zys，其他既有工作树、设备和私有材料保持原状态。实际远端回执另存ignored .local/merge-dev-zys-to-dev-20261015-c389/，不混入密钥或安装包，未验收change不归档。
