## 原生依据与差异
固定/Users/Eason/Desktop/Git/AIAssistant提交bb9ff34966f40a3c2794a9a8b8e935669a9faa12的AppDelegate.m、AIKXSDKService.m、AITrustedIdentityCredentialsViewController.swift、AITrustedIdentityLiveActivityManager.swift及KXPushServiceExtension。当前HEAD只读，不混用。日志diagnostics-6共943条，74条可信设置事件，无法证明APNS/SDK解析/展示成功，真实日志不提交。
前台：精确四字段→账号匹配→待验证预览→SDK解析→当前页面更新，返回首页不干扰覆盖路由。失败保留preview但不得认证；type6为警示，不出证书。点击可显式再展示当前事件，重复后台投递只去重。冷启动25秒单候选无token落盘，四字段有效即可候选；缺callTime仅禁止Activity，不阻止验证/凭据；nil owner/超时/换引擎仍清除。
诊断使用固定stage/result/code，不含号码、姓名、SDK message、token或URL。native环形缓冲仅内存，EventChannel安全诊断封套，Dart写既有账号journal；NSE独立进程用固定os_log事件，不假称进入App journal。生命周期/延迟/拒绝有固定码；设置accountSync只说明交付。
事件流错误清显示、有限重连并读原生最后快照；不无限重试、不重放真实SDK业务。源共享取消归属保持，owner变更时旧事件不进入新账号日志。
Activity与原生一样调用公开request（后台最多尝试一次并记录实际失败，恢复前台最多重试两次，不保证后台成功）；pending/failed或owner结束清理，verified/SDK-confirmed type6可活动，未认证文案显著。当前已创建同事件保持，不在resume销毁重建；失败不永久标记attempted，按前台恢复有限重试。映射使用与凭据一致别名。头像仅安全HTTPS、<=2MB/5秒本机下载、压缩显示数据，原URL不进Dart。任何异步结果按事件归属拒绝迟到。
后台：Apple公开request要求前台（https://developer.apple.com/documentation/activitykit/activity）；参考原生后台尝试不等于可靠成功，原生观察pushToStartToken但未见本仓库可用服务端绑定契约。本批对齐原生的有界后台公开请求尝试，不能将接受普通通知或调用request记为后台创建成功；NSE头像下载失败保留无头像通信外观（与原生一致）、转换或整体超时仍交付原通知，真实后台Activity需服务端另提供契约。非本批能力如AppIntents不能冒充远程推送。
## 验证
每源码微批<=3，源文件<500，工具及测试另批。纯Foundation生命周期/解析/恢复/诊断，Swift Activity规则及NSE专项，Flutter feature/诊断/root定向和analyze，iOS无签名App/双扩展检查，隔离原生/Flutter配对。真实账号设备推送条件单独询问，缺少不越界。跨模块交付可跑一次全量，既有失败按实际分列，不归档。
