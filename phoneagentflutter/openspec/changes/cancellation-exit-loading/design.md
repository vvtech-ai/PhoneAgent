# 设计

- 共用NativeLoadingOverlay沿用现有支付遮罩视觉，支持可选文本；原支付wrapper保留原文案，注销不传文本。
- CancellationExitController只持有本地临时展示状态（账号、登录代次、操作token、验证码页静态外观、是否已受理/加载中），不发API，不保存验证码、不持久化。
- 根级CancellationExitHost在原页面上绘制同样的无交互验证码页面外观和一个loading，跨越旧导航卸载及router重建。展示快照有独立UI控制器，无旧账号provider/订阅/业务回调，不截图或保存图片。
- SessionNavigationHost保留先卸载再清理的顺序，仅为注销提供不透明释放背景；普通退出默认路径不变。
- 最终确认后开始；申请失败/未受理/未知转可操作反馈时停止；已受理清理失败停止并保留现有退出重试。重试只清理，不重新申请。
- 登录页完成首帧构建后撤去展示层，原成功notice随后可见，不加入固定延时。账号/代次变化及旧回调按token隔离。
- 受影响文件：共用loading与原支付wrapper、临时展示controller/host及provider、AccountRoute、PhoneAgentApp/SessionNavigationHost、退出失败重试接线。单批手写逻辑至多3文件；不改原生/依赖/后端。
- 验证DEL-02-04/05、DEL-05-01，邻接账号切换ENTRY-03/08；逐帧断言原页外观/唯一spinner/无阶段文本、释放前旧页面已dispose、慢存储及慢草稿清理、失败后重试、正常退出与原支付loading回归。静态检查和定向测试，真机画面另列未验证。
