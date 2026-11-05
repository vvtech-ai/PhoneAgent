## Decisions
检测busy进入sendingCode边沿，post-frame确认mounted、当前路由、非邀请码页及仍处发送状态，再通过FocusNode.requestFocus与TextInput.show聚焦并显示键盘。验证码发送时保持enabled以建立输入连接，允许更新验证码；登录提交时仍禁用。其他输入和请求门禁不变。
## Validation
双端发送/失败/重建/遮盖/销毁定向测试、已有auth回归、analyze/OpenSpec；设备键盘待验，不构建安装。
