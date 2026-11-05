# 声音克隆入口价格修正（2026-10-13）

## 实施
参考当前aiassistant_app的VoiceClonePointsLabel：根据当前公开modelId匹配pricePoints，未知时显示—。上一轮克隆流程改价漏掉共享按钮，本轮补齐主页面与音色子页。

- 主入口：cloneCatalogProvider复用原CloneCreationPort.models读取，cloneReadinessProvider及cloneEntryPriceProvider派生同一结果；公开模型ID匹配，不使用其他模型或全局价兜底。
- 音色子页：CloneVoiceSnapshot携带nullable pricePoints，直接从既有ApiCloneVoiceRepository.load响应解析，无新增价格请求；缺失/非正/非法只显示—，不破坏原音色状态。
- ClonePointsButton及两处Semantics标签移除固定300；缺价仍保持原可点击性，点击只进入模型选择；付费准入沿用前轮已实现规则。
- 加载/刷新/失败优先隐藏旧价；账号epoch切换和旧结果丢弃；克隆完成、删除/身份删除刷新目录，页面重进自动重读。
- 样式、字号、导航和点击守卫保留。离线Shell报价改为650/900，避免300合成数据掩盖漏接线。

## 实际验证
- 最终定向654项通过（call_models/voice_clone/identity、Shell克隆与开发者连续流程、extended/migration阶段离线预检），非全仓。
- 新增17项包含共享目录请求数、不同模型报价、刷新/失败/旧账号返回/页面重进；双端视觉数字及无障碍、未知价格点击；子页响应解析单次请求；完整Shell650→900及音色子页900。
- 新测试首轮4条SemanticsHandle清理时机失败，改finally释放后通过；完整Shell首轮2条ListView离屏元素查找失败，核对页面后滚动定位复验通过。没有扩大权限或真实业务调用。
- flutter analyze：无问题（9.4秒）；git diff --check及修改手写源码500行上限通过。OpenSpec109项通过、0失败。
- 手写源码批：目录Provider/domain/DTO3文件，共用按钮/两入口3文件，主页面/Shell/失效接线3文件；离线fixture1文件，测试独立批，format机械批。

## 待验及边界
- [ ] 新包真机Android/iOS入口显示、模型切换、读屏。
- [ ] 实际服务目录与刷新联调。

本轮未构建或安装App、未真实认证/个人音频上传/收费，未提交推送。保持codex/dev_zys并保留所有其他工作区修改，不改后端/参考工程/原生或依赖。离线widget预检不等于设备验收；change未验收不归档。
