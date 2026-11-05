# 设计
## 2026-10-19 中文输入法修复
输入框显式使用TextInputType.text及enableSuggestions:true，autocorrect:false保持。固定Flutter 3.32的Android TextInputPlugin在enableSuggestions:false时会加入NO_SUGGESTIONS和VISIBLE_PASSWORD标记，部分输入法因此限制中文模式。移除此诱因，不修改样式、控制器内容或IME composing。使用TextInput模拟拼音组合、中文选字与提交验证，配合原账号/设置/Shell定向测试及analyze；实际手机输入法仍单列待验，不打包安装或提交推送。

来源：固定iOS bb9ff349 AISettingsViewController.accountCard/openAccount、AIAccountViewController.m。首页账号/账号管理排在开发者后、退出footer前，账号页复用统一详情背景/标题/卡片。注销确认遮罩0f1218@.44，白卡最大322/水平24/半径30，顶部28左右22底20；标题22heavy，说明14行23.8，上距17；当前账号脱敏11位为前三后四，其余—。输入52高/半径26/左右17，精确trim确认注销且IME无composing才启用；左右取消/注销48高、间12/上18。启用e65353/按压cb4040，禁用f2f3f4/字f2a8a8。自动聚焦、键盘避让、短屏大字滚动、减少动画、遮罩/取消/返回安全关闭。
Route负责Session注入与账号代次检查；纯Page负责布局，Dialog负责输入与关闭单次。确认先关闭弹层，再调用现有退出清会话，成功回根登录；异步期间禁止重复和退出页返回，失败原页提示可重试。捕获原账号credentials，晚到确认不退出新账号。没有网络删除、SDK、权限或依赖变化，使用合成SessionStore验证，不操作普通App登录。
源码每微批<=3文件，均<=500；定向账号/设置/Shell及会话测试、analyze/OpenSpec，不进行全量及例行双端构建。设备/原生视觉配对与用户验收独立待验，不归档。
