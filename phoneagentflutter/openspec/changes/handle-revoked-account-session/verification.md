# 会话失效统一退出验证

2026-10-30；源码和本地测试交付，未提交/推送/部署。无数据库迁移、真实账号、短信、支付或外呼操作。

## 基线与实现
- Flutter feature/test_v1.8.0@2589ba3441b6439571af07b264e136903cf89d88；SDK/Agent后台HEAD857baa5e7b666d9e6bff0cb3f5d6feaeff71b246；进入时两仓工作区干净。
- 新增AC0010注销中、AC0011已注销、AC0012代次失效，HTTP403不变。普通停用、账号不匹配、权限不足仍AC0003；正常401仍先续期。已删除账号仅按签名验证后的账号ID只读查询注销状态作分类，不恢复访问。
- SDK/Agent shouldNotFilter及原路由鉴权条件与HEAD逐段比较完全一致；不扩大登录接口范围。未改变凭证格式或账号代次的推进规则。旧v1正常凭证及原过滤器回归通过。
- AccountApi统一覆盖JSON、SSE握手、下载/录音错误握手，错误JSON读取有界；已接受的流不重放。普通403、成功响应、网络失败不触发退出。
- SessionController按账号/登录epoch及实际请求token匹配；并发失效合并清理、释放和一次提示。token已被正常续期替换或新账号已登录时，旧响应无效。
- 清理失败保持业务屏障，仅显式重试；无自动重复清理或提示。强制失效单独重建原路由及观察器，清理等待期先移除旧页面/弹窗，失败后仍有重试入口。
- 注销提交/查询持有可释放的会话级延迟退出租约。未知结果继续使用原查询身份；已受理走注销自己的清理/提示；不重复申请、不自动撤销、不覆盖原业务正文。既有本机注销过渡UI保持原owner。
- 不增加主动通知、轮询或新接口；其他设备在下次受保护请求/续期识别失效后退出。离线/未请求设备不承诺立即跳转。

## 验证结果
- Flutter3.32.0/Dart3.8.0，flutter analyze --no-pub无问题。
- Flutter定向238项通过：新并发/迟到token/新账号/清理失败/注销仲裁、共用网络、会话释放、注销全模块、生产路由Android/iOS变体、支付订单/重试/已支付结果及通话控制器/策略/API。不是全量测试或真实设备证据。
- JDK17显式执行；SDK/Agent定向58项通过、0失败、0跳过，包含两模块LifecycleSessionErrorTest及旧token/鉴权/注销规则。Maven全模块-DskipTests compile通过。
- RED：实现前LifecycleSessionErrorTest复现注销中/逻辑删除仍无专用code。实现后新分类、过滤器返回和续期返回均通过。
- 新widget测试初版将释放Host放在Navigator内部，不能代表生产弹窗清理；改为与生产同结构的导航装配后通过，并另以实际PhoneAgentApp/GoRouter双平台变体验证弹窗移除、登录页、提示一次及消失。
- 新Mockito多错误循环初版用when重设已throw的方法触发桩错误，改用doThrow；没有修改产品逻辑来迁就该测试问题。
- UTF-8、diff空白、OpenSpec文件和6项SESSION场景结构检查通过。OpenSpec CLI strict未执行（PATH无可用CLI），不将结构检查当作strict结果。

## 未验证/交付边界
- 未部署；未用真实旧安装包、真实后端/多设备、真实支付/通话验证。旧版仅保证源码合同正常路径兼容，不承诺旧版识别新码后主动退出。
- 不主动通知，也不改变已建立连接的服务端逐帧协议。本端识别失效后复用原资源释放；服务端订单/结算/回调保留原owner。mock通过不证明真实渠道结果。
- 未修改注销期限/状态机、会员权益、退款规则、账号停用开关或数据库结构。
- 本地日志：/tmp/session-exit-final-flutter.log、/tmp/session-exit-analyze.log、/tmp/session-exit-java-tests.log、/tmp/session-exit-reactor-compile.log、/tmp/session-exit-java-red.log。
