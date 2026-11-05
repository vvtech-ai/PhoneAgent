# 首页录音入口与任务设置回读验证

本次修改属于Flutter导航入口、权限domain及UI适配层。原生APP只作行为依据，未修改参考仓库。`ShellTaskNavigation`复用既有页面/账号/点击代次，只添加授权门禁；`ConversationPermissionAccess`负责真实检查/申请/设置回读；`task_entry_permission_guard`负责弹层与入口生命周期；`ConversationRoute`持有当前任务的设置操作与输入代次。没有将设备请求塞入Shell大文件，没有新增HTTP或数据库状态。

## 实现

- 首页任务卡片、同导航owner的任务恢复入口及联系人正式技能入口先读麦克风状态，按需申请；拒绝留原页。翻译技能卡片复用同门禁；只读任务详情及系统拨号交接不受影响。真正后台、页面/账号失效、连续点击均不能迟到导航；系统权限临时inactive等待前台。Web沿既有入口语义，不使用手机权限端口；联系人离线preview不访问真实设备。
- 永久拒绝由用户确认“去设置”，等待系统返回后只读实际状态；打开设置不是授权。显式设置离开App与一般后台取消入口分别处理。
- 任务中的定位设置按钮仅由实时SETTINGS_REQUIRED notice提供；真实授权后提交新的“重新获取定位”用户意图，不重放旧工具或permission_result。设置期间用户已发起新轮次时，输入代次守卫丢弃旧结果。
- 导航测试显式提供合成权限source，演练Shell麦克风入口固定为合成已授权，其余权限场景仍交原假端口；没有在生产代码放宽授权。

## 证据

- 入口四项初始RED：`.local/task-entry-red.log`，实际均提前进入任务且无权限检查。
- 真后台RED：`.local/task-entry-background-red.log`，实际后台迟到进入任务。
- 修复后首页7项及domain3项合计10项通过：`.local/task-entry-final2.log`。
- 独立审查指出并已修复：初始已后台状态采样；inactive获准后转paused的最终复查；任务设置跨输入代次迟到。审查者重新读取并独立复验home/access/device合计16项通过。
- 任务实际ConversationRoute三个设置场景（成功、仍未授权、新轮次迟到不插入）与实际320首页道歉入口合计4项通过：`.local/task-settings-route-final.log`。播报假端口持续动画采用有限pump和实际状态断言，不把无穷动画误当系统失败。
- 全项目analyze无问题、OpenSpec168项通过。最终全量回归与APK证据见主verification及交付回执。
- 用户追加所有入口后，入口增补任务列表拒绝、联系人双平台拒绝/切号迟到合计12项通过；设置回读再次后台保护补验后首页9项、domain3项、任务实际路由3项合计15项通过（`.local/task-entry-settings-read-final.log`）。联系人全模块171项通过。每Route单次授权入口防止多个联系人技能并行请求；显式设置正常离开与回来仍允许授权成功进入。
- 设置回读期单独复用同入口生命周期，只在实际设置返回后安装；随后再次后台的晚回不能导航或插入新意图。设置返回和read不与旧权限工具回放混用。

## 边界

测试未申请真实系统权限、访问真实账号或外呼，不代表双端设备授权/定位/TTS验收。iOS编译等待Xcode环境；Android将在统一Release中编译核验。
