## Tasks
- [x] 1. 正式 Android 工厂延迟回归 RED
- [x] 2. 双端主/备用提前采集接线
- [x] 3. 定向回归、analyze、OpenSpec、复核
- [ ] 4. Android APK 构建（当前工具链缺失）
- [ ] 5. Android 设备短句首字/再次按住听检（当前无 Android USB 设备）

- 初轮正式工厂RED为2通过2失败（Android未开麦及备用提前采集关闭）；修复后工厂/采集16项、语音与音频290项通过，analyze无问题，独立复核无阻塞。APK命令实际返回No Android SDK，java_home也无JDK，当前仅iPhone；4/5保持待验，不归档。

- 合并最新ae93e93a后最终324项相关测试通过、analyze无问题；用户明确保留原App松手最多2秒收尾，结束行为未改。
