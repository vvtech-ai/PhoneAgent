## Context
当前华为设备仍安装2026101504，上次交付2026101507尚未安装。此前克隆拦截依赖新增模型目录字段，入口没有读取既有当前会员快照；Flutter 缺少原生 ApologyVoiceCoordinator 对应模块。

## Decisions
克隆统一路由先读取当前会员的 cloneEntitlements.enabled，false 立即弹窗；不按 FREE 等级硬编码、不用营销展示配置授权，模型级门禁继续保留。未知会员配置沿既有模型目录检查，读取失败显示重试。

道歉新增独立 domain/data/controller/binding；确认前输入和确认拨号均不向 Agent 放行，确认后 callVoiceSelection 绑定当前会话，并在 confirm_call 的 actionPayload 同步该字段。只确认 READY/usable 的当前音色或 READY/CHARGED 候选，候选需 activate=false 确认后重查。每次模型变更失效旧查询、停止旧播报，重新生成独立选择卡；不把一次任务选择写为默认音色。

## Verification
先复现两个真实 Shell 按钮的无权益行为；道歉覆盖同意/拒绝/无音色/跨模型/过期结果/候选确认/请求字段/非道歉不受影响。运行定向测试、analyze、OpenSpec；最后串行构建并核验测试 Release 包及签名。

## Review corrections
恢复时读取服务端 pinnedSkillId/taskCallModelId，保留已有服务端音色选择，不猜测asset、不重播初始同意；仅用户实际选择模型后重查。模型目录首次加载、仅关闭模型面板均不触发切模。切模暂停现有确认倒计时，保留请求和可见卡身份；确认后可以再次提交。本地提示在任务提交时消费，缓存ASR输入保留来源。拒绝已开始的任务时先取消原流并失效代次，再以固定身份发送cancel；匹配task_cancelled确认才显示已停止。

主会话类只增加独立binding接线；原事件提交/状态回调提取到conversation_event_binding，最终仍满足原508行编排例外，不放宽架构阈值。

## 首屏初始化修正
1511手机道歉入口灰屏；正式Provider回归复现LateInitializationError：构造道歉本地确认卡触发_publish，再经OCR synchronize的isCurrent读取未赋值controller。修正在composition provider标记controllerReady，OCR仅在owner构造完成且账号有效时回调；不修改业务控制器、OCR算法或服务端。测试覆盖正式Provider而非仅独立Controller，保持首屏确认卡同步可见；既有OCR/会话回归验证构造完成后的工作与生命周期不受影响。

## Branch boundary
本轮误操作产生的本地340bf658从未推送，已逆向核对index tree与d1fc44b4完全相同后撤回本地提交。用户随后明确origin/codex/dev更新并授权拉取，已stash保存修复、ff-only到b29853ac后无冲突恢复；b29853ac自身包含其他会话已经合入的邀请/克隆身份变更，本轮不再次合并dev_zys。
