# 设计

## 来源与边界
视觉：AIAssistant1/android/.../assistant_calls/AssistantDialerParts.kt的TranslationLanguageLine；内容：aiassistant_app/app/.../assistant_calls/AssistantCallsDialSheet.kt选中模型displayName/billingMultiplier与目录语言name。两仓库只读。用户只批准摘要区域，不修改任何弹层。

## 布局
保持7px状态点、6px间隔、13.5px半粗名称/语言、11px倍率、17px箭头和底部10px间隔。按实际文字测量预留语言入口及模型最低可读宽度；标准单行，空间不足受控分两行并留纵向间隔。文本单行省略且完整语义保留，倍率与箭头不被长名称挤走。关闭状态文案统一在共享组件处理。

## 数据与状态
模型名称保留服务端原文，倍率仅来自该选中模型，不按provider回退其他费率。摘要语言由现有controller目录列表解析，未知/缺失显示请选择，不改变偏好或选择规则。沿用既有点击、忙态、失败重试和返回更新。

## 验证
固定Flutter3.32，analyze与摘要、国内拨号、模型选择、跨页返回和壳拨号流程定向测试。离线渲染图仅用于几何核对，不冒充原生/手机运行验收。本次不重打包或安装，双端实机画面另标待验。
