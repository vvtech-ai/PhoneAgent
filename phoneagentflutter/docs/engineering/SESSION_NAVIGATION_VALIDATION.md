# 登录失效与业务导航释放验证

日期：2026-09-20。正式共享代码修复；不是短信登录或真机音频验收。

## 问题与修复

完整App对话中直接signOut/rejectSession会使账号Provider先重建，而imperative push的对话仍订阅它，触发ApiFailure.signedOut。仅重建GoRouter、或在ConversationRoute入口检查登录，最小失败测试仍失败；没有保留这类页面级掩盖。首页对话/翻译跳转重复挂载同一容器也触发Riverpod的Only one task can be scheduled断言，已移除这两处冗余scope，继续继承App上方的原容器。

当前顺序：

1. SessionController执行既有持久写入/清除，失败保留页面并向调用方报失败。
2. 对旧signedIn身份关闭credentials，并通知释放监听器；此时真实AccountApi/异步归属检查不能继续使用旧身份。
3. SessionNavigationHost卸载App整个Router子树，包括其页面和弹层；帧末确认Widget订阅已经移除，宿主本身销毁也完成等待。不是固定毫秒延时；无UI监听器的纯控制器无需等待帧。
4. 发布新SessionState，loginEpoch改变后销毁旧GoRouter，挂载新认证状态。旧控制器正常dispose，取消本地流。后台已经建立的外呼不因此新增挂断操作。

同身份replaceToken不进入释放步骤，不更换路由或清空草稿。未改HTTP鉴权、后台接口、数据库、提示词或ASR/TTS协议；没有返回旧账号、假凭据或全局忽略异常。

## 自动证据

- `test/session_route_lifecycle_test.dart`：活跃在途文字对话显式退出/被拒绝、旧Controller销毁、晚到等待后不出现旧回复、重新登录不能返回旧页面、无短信；同代次刷新保留router/controller/草稿，实际模型sheet随失效关闭。
- `test/session_nested_routes_test.dart`：设置子页、联系人详情、联系人发起的在途对话、翻译拨号页四条真实共享入口清理。
- `test/features/auth/session_release_test.dart`：退出/账号替换/restore均等待释放且期间credentials为空；刷新不释放；移除监听器生效；清除存储失败不先移走导航。
- 调整原联系人工具测试的异步等待方式：先触发退出、pump帧完成真实释放，再await结果；没有移除错误/退出断言。
- 相关登录、首页、联系人、工具、翻译、回执、积分及通话Provider定向覆盖共93条（12新增），不是几千条全量回归。最终结果见本批issue记录。

## 浏览器实测

独立入口 `tool/previews/session_lifecycle_preview.dart`，启动：

```powershell
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8124 --no-pub -t tool/previews/session_lifecycle_preview.dart
```

2026-09-20浏览器实际打开共享首页→订餐厅→文字草稿→顶部“MOCK：刷新令牌”（草稿仍在）→真实模型sheet→“MOCK：登录失效”（sheet和对话移除，登录可见）→合成13800000000/1234登录→首页。没有点击获取验证码。浏览器error日志为空，仅DWDS registerExtension调试能力warn。

该入口复用ShellPreviewPage的内存账号、Agent和业务端口，只加独立工具栏；正式main不会导入工具入口。未访问8080真实登录、OS通讯录、音频、真实后台或用户手机数据。

## 边界与待验证

- 本批没有重新构建安装Android/iOS；这不是新版真机验收证据。移动端后续阶段验证同样的401/退出与后台恢复，尤其录音/SDK/系统弹窗及真实资源释放。
- App后台停止绘帧时，身份凭据已关闭，导航释放确认可等到恢复绘帧；不宣称后台UI仍在渲染。不新增后台自动登录或发送短信。
- 测试证明列出的共享路由，不证明所有嵌套导航组合、全部真实工具或外呼均通过。
- Android普通包恢复/真实登录仍是独立待办；iOS SSH/Xcode/VM已经复核可用。整个迁移、首次初始化与正式OTA交付仍未完成。
