# 验证记录（2026-10-12）

## 实际范围
- Flutter 3.32.0 / Dart 3.8.0，未升级工具链、依赖或平台配置。
- 主定向批次 292 tests passed：完整 test/features/settings，加拨号权限 Controller/UI、translation_access_pages、translation_location_pages、domestic_translation_dial、translation_model_identity、domestic_translation_settings_controller、translation_preferences_persistence、translation_persistence_pages、domestic_model_sheet_lifecycle、translation_location_dial_loading、shell_developer_workbench。
- 隐藏模拟时被叫国家当前位置快捷项后：41 tests passed（相关设置/地区/访问/权限 UI）。
- 国家选择排版/2 倍字体搜索选择及账号调试最终复测：16 tests passed；与上述批次重叠，不累计冒充独立测试总数。
- flutter analyze：No issues found。
- openspec validate --all：93 passed, 0 failed。
- git diff --check 通过。

## 行为证据
- 国家搜索、自动定位/返回、保存失败重试、跨 Provider 重建恢复模拟国家、真实缓存不受污染。
- 模拟国内/海外影响目录模型 transport；恢复自动定位重新取真实位置。
- 生产账户设置 Provider 在模拟 JP 后从 DOMESTIC 切换 OVERSEAS，PUT 带相同 region，旧 Controller 回调失效。
- 账号偏好更新不改变拨号模型 ID/provider；成功提示和刷新可操作。
- 模拟状态跳过定位权限但保留通话记录权限链；国家选择页隐藏当前位置快捷项。
- 正式页移除旧固定节点/模型和 MOCK 入口；独立预览仍通过设置测试。
- Android/iOS 主题下 320px / 2 倍字体可滚动操作模拟国家搜索/选择及网络模拟。

## 微批与边界
偏好领域/Codec/Controller；有效地区与账户 Provider；国内拨号/权限 Controller/Host；独立操作行/国家页/控件；账号调试页；正式 route/Section/重置控件；列表/网络/固定号码文案接线；直接位置调用方；测试分别小批修改。格式化作为机械批次。新增手写文件均未超过 500 行，无新增例外。
未修改并行 iOS SDK 更新，保留既有 translation model identity 改动；当前分支 codex/dev_zys，未切分支、提交或推送。

## 失败及修复
初轮测试包含旧 WebRTC 正式页断言及新依赖导致的定位预览生命周期失败；重新读取状态并更新现行行为断言，隔离预览保持真实位置 Provider。账号页临时括号解析错误经源文件定位修复。一次测试命令引用不存在的 domestic_model_controller_test.dart，实际改用 domestic_translation_settings_controller_test.dart；该无效命令不计通过。中间 analyze 格式/unused import 信息均修复，以上最终批次通过。

## 待验
未连接设备执行视觉截图比对或系统授权弹窗验收；未发短信、认证请求、真实外呼或计费。未改平台/构建链，不重新打包。源码与 widget tests 不等同真机验收，change 不归档。
