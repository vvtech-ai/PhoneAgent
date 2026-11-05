# 设计
当前Flutter HEAD c10ad11c及已批准未提交align-native-translation-preparation改动作为本轮起点，保留原改动。aiassistant_app实际入口使用callerCountryIso和selectedCountryIso，跨境判断trim/uppercase；空国家/普通电话/同国不弹。模拟国家属于有效主叫位置。

纯Dart策略不访问UI；presentation用现有NativeConfirmationDialog标题“跨境通话质量提示”、正文“当前为跨境实时翻译通话，可能出现信号不稳定或延迟较大的情况。”、按钮“取消/仍要继续”。返回/遮罩视为取消。_call单入口在位置/模型/号码检查后、binding.create或国内create之前确认，_opening阻止重复。确认前后比较号码/国家/偏好/有效位置/选中模型快照，并再次校验页面账号和权限；失效不继续。

拨号页已493行，新增接线同时将两处重复预设确认收敛为同一方法，保持500行以下。不把UI布局/网络/计费迁移到弹窗。Flutter当前无原生号码格式警告弹窗，仅保留现有号码校验，不额外扩展产品。

每业务微批最多3手写文件，测试与format独立。定向规则、共用组件、两端页面入口及生命周期、翻译直接调用方/主流程冒烟，analyze/OpenSpec/diff。无需全仓回归或重打包；真实双端视觉及真实外呼待验。
