# 1.0.52(45)交付

用户明确指定1.0.52(45)，确认当前手机Release安装号2026101512高于45后，用户最终选择“严格使用45，只交付APK，暂不安装”。本轮不操作安装、卸载、数据或真实业务。该明确版本要求覆盖本次默认递增号选择，不改包名或签名绕过Android保护。

源码2e155b9c955ed06d0d78444e3acf85df971d409e已普通推送origin/codex/dev，远端读回一致。仅pubspec改1.0.52+45、测试入口版本名同步；参数测试先RED再18项通过，PlanOnly/OpenSpec161/diff/UTF-8通过。不重跑无变化业务全量；保留1512道歉首帧、联系人回传路由、多路TTS显示等已有修复。

冻结干净源码后，固定Flutter3.32/Dart3.8/JDK17，Release --config-only --pub生成注册器无integration_test，再用已批准离线Gradle assembleRelease成功。成包实际读取com.vvtech.aiassistant.test、versionName1.0.52/versionCode45、登记签名MD5 ebd4c931de412bf5d9c3716815389097；三test URL/四私有配置值/邀请host及scheme核验通过，不输出凭据。仅ARM64、有AOT、无debuggable/调试kernel/Vulkan校验层、11受保护原生库与来源字节一致，未夹带私钥或defines文件。

APK：D:/work/04phoneAgent/deliveries/version-1.0.52-45-20261015/Phone_Agent_TEST_1.0.52_45_test_20261015_200223.apk；78,909,024字节；SHA256 87a781c62c65c078110d1052ff47ad2553b73dff302697220c267b2f30e7254c。同目录README、test-release-verification.json、build-receipt.json和SHA256SUMS.txt提供回执。Java/Web及运行配置未修改或部署，未声称设备安装或业务验收。

用户后续明确已自行卸载并授权安装，重新枚举实体KOZ-AL00/AEUN9X1507G02040、pm核实目标.test不存在后安装Success；版本读回1.0.52/45，firstInstallTime2026-10-15 20:06:12，启动Status ok/PID17790、前台MainActivity。系统本次安装确认按新截图操作，未改全局安全设置。观察到登录页及用户自主登录过程，为隐私不保留带短信信息的界面；agent不采集或填写验证码、不代发短信/登录。此次新装无旧数据保留结论，agent没有卸载或清数据。安装JSON随包，不冒称后续业务验收。

后续任务页加载只读证据：20:06:50登录/随后SDK积分、首页配置和任务分页HTTP200；Agent会话列表和模型延迟HTTP502，Nginx连接38080拒绝。Agent SSE多次退出码1、重启计数23，20:01新包安装前已有同类拒绝连接；该运行态故障不是安装版本45导致的证据。SDK另有499请求取消，未确定全部同因，服务启动异常具体原因未确认。没有因此重打包、重装或改动/重启服务；不能用签名/登录成功宣称所有业务接口可用。
