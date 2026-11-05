# 本轮代码验证（2026-10-16）

## 实现范围
- Android登记`.test`包在Release使用test，启动与MethodChannel共用纯策略；未知身份拒绝。Dart环境校验保留。
- 私有凭据生成器在显式PHONEAGENT_ANDROID_ENV=test时生成test Release输入，默认dev仍生成pro Release输入；各variant不混入另一环境凭据。测试只用synthetic数据。本轮未读取/重写真实私有配置；后续test构建前必须在该环境下重新生成私有输入，不能沿用旧pro Release生成文件。
- Android首页使用独立domain/data/controller/host，全局seen/disabled与SDK首次记录分开。300ms、前台/首页/当前账号门禁，去授权共用设置入口，关闭/遮罩/返回转二次提醒，不再提示持久化；不写授权成功。
- UI使用公共NativeGradientAction/NativeBusinessDialog；引导图来自AIAssistant1，HOME_GUIDE_SOURCE.json记录来源和SHA256。设置页及SDK页面布局未改。
- Shell原499行，提取福利导航独立职责后495行，无新增超500例外。每个源码微批至多3文件；资产复制及格式化独立机械批。
- Android取消打开后立即授权刷新，并明确启动回复语义；iOS仍保持SDK退出后刷新，iOS业务源码未改。

## 实际通过
- OpenSpec初验与最终均169项通过、0失败。
- `flutter test --no-pub test/features/trusted_caller test/features/home/shell_navigation_test.dart test/shell_settings_platform_back_test.dart test/features/invite/v67_invite_entry_navigation_test.dart test/architecture_test.dart`：137项通过，约9秒。
- 后续只增加小屏大字测试，`flutter test --no-pub test/features/trusted_caller/trusted_caller_home_guide_host_test.dart`：8项通过，含320×568、2倍字体、首页延迟、前后台、返回/遮罩、离页/退出、账号变化、跨启动不重播、禁用、连续点击和iOS不加载引导。
- `flutter analyze --no-pub`：无问题，7秒；新增测试后最终复验仍无问题。
- JVM：使用缓存Kotlin2.0.21编译器和JDK17，对环境/guide/owner/surface/SIM三个策略编译执行JUnit，22项通过，无Android设备或SDK运行。
- Android生产源：Android35/Flutter现有flutter.jar、受控SDK及缓存AndroidX core编译14个TrustedCaller Kotlin文件和Java身份拦截器成功。使用临时目录，不生成APK，不执行SDK。
- Foundation：编译执行`trusted_caller_push_binding_driver_test.m`及`trusted_caller_push_binding_state_test.m`；初始化合并、token先到/登录先到、权限门禁、切账号迟到补偿、失败不盲重放和退出不重绑通过。无真实SDK/APNs。
- `python3 -m unittest discover -s tool -p test_trusted_caller_environment.py`：1项测试的4种宏配置通过。
- `python3 -m unittest discover -s tool -p test_prepare_trusted_caller_credentials.py`：5项通过，包括合成test Release隔离和非法环境拒绝。
- iOS恢复登录/新登录通过新增Dart两路径账号交付测试，均不依赖设置或引导；交付成功不等于远端绑定成功。

## 失败与恢复记录
- 新增测试首轮9通过/1失败，原因测试覆盖页无AppBar却调用pageBack；核对测试当前状态后补AppBar，复验通过，无产品导航回退。
- 可信全模块首轮119通过/2失败，原Android旧断言要求启动回复后立即授权刷新；按用户批准契约改为Android零次、iOS一次，137项集成复验通过。
- analyze首轮4项新lint（条件括号和async mounted识别）；修正后无问题。
- Android独立编译首次缺少工具classpath中的AndroidX ContextCompat，约17:06发现；读取缓存确认core1.13.1，加入真实依赖classes.jar后有限重试成功，不修改产品依赖或SDK。
- 一次测试补丁因格式化后行文不同未应用；重新读取相关行后准确应用，无部分写入。

## 未验边界
不构建/安装APK或iOS包，不操作系统权限，不触发短信/认证/真实来电/APNs。首次/后续SDK页面、服务开关、重启、无卡/双卡及远端推送绑定仍待设备验收；不能以编译、合成测试替代。保持当前分支，不提交推送，不归档。
