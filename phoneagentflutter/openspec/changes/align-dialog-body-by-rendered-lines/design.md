# 设计
基线feature/test_v1.8.0@26ce44a09f9a7b1f6ebffd562d7c8b8722b19505。支付任务已有未提交修改，本批不触碰。

core/design拥有共享正文布局：TextPainter按实际约束、继承字体、TextScaler、方向、locale测量，单行center，多行left。自定义协议内容通过同一布局的builder接收对齐，保持TextButton与点击处理；不推测任意非文字content。NativeBusinessDialog的message使用共享正文，注销自定义正文与入口正文显式接入；入口标题center。错误提示、手机号和输入框保持。

验证：共用控件短/长/显式换行、缩放及窄屏；危险/普通/说明确认、注销入口标题/IME/布局、协议点击及冷静期关闭/撤销直接调用方。涉及DEL确认展示和CONFIRM-02身份不变，不改变共享任务合同或后端。无原生修改，不打包/部署。
