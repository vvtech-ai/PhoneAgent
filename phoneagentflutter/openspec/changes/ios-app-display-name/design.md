# 设计

Info.plist的CFBundleDisplayName使用$(PHONEAGENT_DISPLAY_NAME)。Runner的Debug/Profile配置PhoneAgent test，Release配置PhoneAgent，与现有Bundle ID逐一对应。保留PRODUCT_NAME以避免影响产物路径和扩展依赖。

验证：OpenSpec全量校验、plist/pbxproj语法与三个配置的Bundle ID/显示名称映射检查、git diff --check。仅元数据调整，不运行Flutter业务测试、不安装设备；实际新包桌面名称待后续构建验收。当前侧会话保留codex/dev_zys，不提交推送。
