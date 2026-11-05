- [x] 1. 只读确认参考版本、日志局限、既有Application初始化和iOS边界。
- [x] 2. 统一Android凭据生成及环境读取，添加定向测试；仅重新生成Android私有输入。
- [x] 3. 完善原生准备失败分类及Android诊断，保留iOS返回行为。
- [x] 4. 运行凭据/原生/Flutter定向验证、analyze、OpenSpec和Android构建检查。
- [x] 5. 核对SDK与iOS字节、更新根任务和问题记录，报告验证局限。
- [ ] 6. 实际安装包及设备SDK设置/真实来电验收；未经授权不安装或外呼，未验收不归档。

## 当前验证
- Python凭据7项及iOS环境门禁1项，共8项通过；Android-only实际生成成功，debug/profile/release输入字节相同。
- flutter test test/features/trusted_caller：126项通过；flutter analyze：无问题。
- JDK17执行 :app:testDebugUnitTest --tests com.vvtech.phone_agent.TrustedCaller*：10套26项，失败/错误0。
- OpenSpec全量182通过；SDK清单53文件、10个Android Activity及iOS竖屏配置通过。
- iOS受控文件无diff，两个私有生成文件摘要前后一致；生成器单测另验证私有清单及iOS文件逐字节不变。
- JDK17执行 flutter build apk --debug：成功（assembleDebug 24.4秒），仅编译检查，不作为Release测试交付包；未改版本号。git diff --check通过。无需增加初始化入口，已有NativeCrashApplication调用initializeAtStartup。
- 用户随后授权提交并普通推送codex/dev；设备/真实服务验收未执行，未归档。
