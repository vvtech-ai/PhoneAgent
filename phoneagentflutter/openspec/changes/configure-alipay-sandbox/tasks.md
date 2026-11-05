# 实施任务

- [x] 1. 补环境选择失败回归并观察旧行为 RED（编译安全旧 ONLINE/no-set 行为占位：6项中5失败，日志 D:/Temp/story1837-alipay-native-red.log）。
- [x] 2. 新增严格环境策略，桥在 payV2 前设置 SDK 环境，缺失或未知值拒绝启动；Android环境6项GREEN。
- [x] 3. 验证支付参数从真实 JSON 形状传至 MethodChannel；保留原单查询行为，Flutter直接调用方14项通过。
- [x] 4. 执行 Android JVM 定向、Flutter 定向/analyze、debug APK 编译和 OpenSpec，记录实际结果；6/14GREEN、analyze无问题、OpenSpec97项及本change strict通过，本地包2026101308重建成功。
- [x] 5. 主代理独立核验通过，按追加授权准备精准中文提交及指定分支推送；本批不安装、不执行真实支付。
- [ ] 6. 真实 SDK/原生沙箱支付及到账验收另行执行，不以自动测试/编译替代。
