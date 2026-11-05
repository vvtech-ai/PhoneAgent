# 强制账号失效退出过渡验证

2026-11-02。基线feature/test_v1.8.0@ad0e99b2，进入时工作区干净。本批未打包安装、未部署或执行真实账号操作。

## 实现与UI规则
- 仅Flutter根层：新增SessionExitLoadingHost、PhoneAgentApp接线。复用NativePageBackground和NativeLoadingOverlay，覆盖异地注销/失效期间的慢存储、页面释放及草稿清理。
- 展示owner按账号/epoch/本地代次失效，不持有业务凭证、旧widget、验证码或业务资源，不访问服务/存储。signedOut后帧回调撤去覆盖，无固定延时；清理失败关闭加载并保留原AuthRoute重试。
- SessionController与SessionNavigationHost源码不变；真实旧页卸载、帧确认、资源清理及权限阻断顺序保持。主动注销CancellationExitHost和普通退出原行为不变。
- 执行D01-D06适用边界及C01/C16：公共浅色背景覆盖安全区外，加载复用已有组件，无新增页头、按钮、卡片规格，不改共享默认值或TooltipVisibility。

## 自动验证
- 先RED：新增慢退出用例在两平台期望不透明覆盖，实际0，均失败。
- 最终组合53项通过：forced_session_exit_loading、session_invalidation_shell、auth/session_invalidation与widget、主动注销cancellation_exit_loading、session_release、settings_account_shell、task_draft_cleanup及native_notice/queue。
- 新增8项（Android/iOS各4项）：普通退出不取得强制遮罩；失败/重复失效/重试；账号替换和旧凭证迟到；慢存储与旧页真实卸载后的慢草稿清理。最后补强逐帧断言“无覆盖即已有loginPhone”，独立8项通过。
- flutter analyze --no-pub无问题；git diff --check、改动文本UTF-8与OpenSpec文档结构检查通过。CLI未在PATH发现，未声称strict验证。

## 扩展用例未完成项
扩大到session_route_lifecycle_test的active conversation released on signout时，执行持续等待，已中止，未计入53项通过。在git archive提取的原始ad0e99b2独立源码、同一固定Flutter/依赖上运行同名用例（--timeout 15s），同样持续等待并中止，报告did not complete。当前只证明基线亦存在等待，不签收该用例根因；未修改原测试断言或通话实现。

本次新账号替换测试最初直接await accept导致帧确认无法推进，已按真实帧生命周期先发起、pump再等待，产品清理顺序未放宽。

## 边界
未取得Android/iOS真机逐帧画面；自动断言不能替代现场黑屏验证。无后端/原生/依赖/构建修改，不重打双端包。设计参数无新增待核，设备画面仍待验。

本地日志：/tmp/phoneagent-forced-exit-red.log、green.log、tests.log、final-frames.log、analyze.log、baseline.log。未纳入提交。

## 当前页面静态画面补充（2026-11-02）

用户批准当前页画面方案后，保留前批未提交内容，只扩展强制退出展示。新增SessionExitSnapshot内存owner，SessionExitLoadingHost监听失效状态同步发起根RepaintBoundary采集（早于路由重建），按约200万像素预算；只存一张，不写文件/缓存/网络，不持有业务权限。采集250ms后放弃，平台视图/Texture/未绘制/异常回退既有安全不透明底层；不延迟SessionController清理。登录首帧、失败、新身份、dispose均释放，晚到图像dispose；销毁后清除回调引用，不保留宿主。debugNeedsPaint仅在kDebugMode分支读取，避免Release读取debug-only属性。

双端先RED：原画面RawImage缺失；实现后最终组合57项通过（前批53项及新增4项图像owner测试）。8项生产根路由用例继续通过：慢存储/草稿、失败重试、新账号、普通退出；慢退出用例增加像素检查，断言采集中心为旧业务页专用颜色、尺寸预算和旧业务页真实卸载，登录就绪后image.debugDisposed为true。独立owner覆盖正常释放、清除后迟到、失败/超时、宿主销毁后迟到。主动注销原验证码页loading直接调用方回归通过。

flutter analyze无问题，diff/UTF-8检查通过；图像仅在运行时内存采集，测试未导出截图。实际Android/iOS画面和平台视图回退仍待真机验收，不将widget像素测试声称现场已验。源码未提交/部署，无后端或原生改动。本轮日志/tmp/phoneagent-exit-snapshot-{red,green,regression,analyze}.log。前批扩展通话页用例等待情况仍单列，本批未再次运行或计入通过。

## pull后提交前复验

用户2026-11-02授权Flutter当前分支提交并推送。pull后基线4fa57b13，fetch后HEAD与origin/feature/test_v1.8.0一致；保留远端共用UI规范更新。对当前组合重新执行flutter analyze --no-pub（无问题）及上述定向集合（57项通过），diff/UTF-8检查通过。本次未扩大到前述等待用例，不将其算通过。输出/tmp/phoneagent-exit-push-analyze.log与/tmp/phoneagent-exit-push-tests.log。实际提交/推送结果以Git记录及对话为准。
