## Why
用户确认实时翻译拨号和通话失败在 Flutter 双端使用共用 Toast，文案及失败分类对齐 aiassistant_app，而非页面常驻文字。
## What Changes
- 拨号校验、权限、位置、模型、语言、积分准入通过现有 showNativeNotice 展示，沿用原生文案。
- 恢复原生五类通话失败及 SIP 状态分类，结束路由只展示一次 Toast，返回不重复显示。
- 清理未确认保留内部状态，不新增账单页、不展示合并技术文案，不把未确认伪装成功。
## Impact
Flutter 双端共享 Dart 的 translation/dialer 接线；原生项目只读，Toast 样式、平台权限、计费、资源释放算法保持，不打包、不安装、不真实外呼、不提交推送。
