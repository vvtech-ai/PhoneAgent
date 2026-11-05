## 任务
- [x] 阅读规则、需求基线、app-foundation 及相关既有 change，确认两处配置偏差。
- [x] 执行 OpenSpec 全量校验并修正 Runner Debug/Profile 两处 Bundle ID。
- [x] 验证工程语法、三个目标的三种配置与通知配置，检查 diff 并同步根记录。
- [ ] 后续测试包签名、实际设备安装运行验收（本次不打包安装）。

验证：OpenSpec 全量 195 项通过；plutil 语法通过；工程对象解析确认主 App/两个扩展共九个配置标识正确；现有通知配置 Python 3 项通过；git diff --check 通过。系统 Ruby 缺少 xcodeproj，未运行依赖该 gem 的 Ruby 脚本，使用 plutil 对象解析核验身份。未构建、签名或安装，无 UI 修改，不提交推送。
