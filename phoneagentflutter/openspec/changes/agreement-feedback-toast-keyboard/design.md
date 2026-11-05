## Context
参考当前iOS AILoginViewController.m的updateLoginAgreementAppearance、toggleLoginAgreement、requireLoginAgreement。用户纠正先前“只Toast”的遗漏，当前专项覆盖该反馈说明。
## Decisions
- 普通协议文字默认6B7280，错误E5484D；链接始终0A84FF。未选框边默认A8ADB8，错误E5484D，选中0A84FF。错误状态保持至用户切换勾选，不增加行内说明。
- 整个协议Row平移0→-3→3→0，240ms线性关键帧。重复拒绝重新播放；减少动态效果时仍显示错误颜色/Toast但不抖动。
- AuthPage仅管理错误标志/触发序号，LoginAgreement负责展示动画，不改变请求门禁。
- Toast在Overlay内部订阅MediaQuery指标；底部避让取max(viewPadding.bottom+96, viewInsets.bottom+16)；底部SafeArea不重复累计。显示期间指标变化立即重新布局，计时不重置。
## Validation
每批最多3手写文件；登录/通用Toast/直接调用方定向测试、analyze和OpenSpec。隔离运行不接触真实账号，设备效果未验如实记录。不重跑整App全量，不升级或重建平台链。

## 2026-10-09 共用Toast样式追加确认
白色98%、灰度0.82边框1、圆角10、黑色12%阴影半径8偏移(0,3)；文字灰度0.10/15/Semibold居中多行，上下10左右18，屏幕左右至少32。180ms淡入，完成后停留指定duration，再180ms淡出；默认1.8秒，登录协议2秒。保留替换/穿透/清理。
