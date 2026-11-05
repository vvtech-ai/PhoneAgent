# 拨号摘要验证记录

日期：2026-10-14；Flutter起点170b292f，codex/dev_zys本地修改。

## 修改范围
仅两个业务源码文件：native_translation_dial_summary.dart、translation_dialer_route.dart。未改配置/语言/模型弹层、选择策略、精确模型ID、网络契约或外呼。route现495行，共享组件188行。原有三份未提交记录保留，未提交推送。

## 来源及修复
UI参考AIAssistant1 a0bedb12a的AssistantDialerParts.kt。保留状态点、字体/字重/色彩、倍率和箭头；宽度充足左右单行，空间不足分行，长模型名省略但完整可访问语义保留。内容参考aiassistant_app b28fc06的AssistantCallsDialSheet.kt及AssistantModelBillingMultiplier.kt：服务器模型名称、同模型倍率、当前目录语言名称。关闭文案国内外统一；未知语言请选择。移除海外摘要provider费率回退；倍率不再一位小数舍入。

## 自动验证
- flutter analyze --no-pub：无问题。
- 定向flutter test：60项通过、0失败。摘要组件/目录语言、摘要返回流程、translation_access_pages、domestic_translation_dial、dialer/presets_return_guard及shell_translation_dial_boundary/workbench。
- 离线渲染4项通过：390/320宽度的改前和改后，合成名称/语言/倍率1.25；使用真实共享widget与HEAD原组件对照，本机字体仅用于测试。
- openspec validate --all：142项通过、0失败；git diff --check通过。

## 图片与验收限制
图片位于ignored .local/dial-summary-ui-20261014/{before,after}-{390,320}.png。属于Flutter离线局部渲染，不是手机、AIAssistant1运行截图，也不是实时服务器返回。390宽度验证左右单行，320长模型场景验证受控分行。双端实机画面对照仍待验；本轮未构建/安装或真实外呼，未改平台/依赖，无须本批重打双端包。用户验收前保持active。
