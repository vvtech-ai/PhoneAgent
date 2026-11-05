## 来源与决策
Android /Users/Eason/Desktop/Git/AIAssistant1/android固定0f8879e4baf1d56fe6d7f8f356101fdf61d602ed；iOS /Users/Eason/Desktop/Git/AIAssistant/iOS固定bb9ff34966f40a3c2794a9a8b8e935669a9faa12。参考工作树可能更新，固定有效调用链继续为依据，用户最新扩展身份覆盖固定配置差异。现有trusted-caller-parity为依赖基础，不重做已完成接线，不将其历史pending当当前事实。

## 共用业务与UI
原生接事件/验证，Dart仅接安全白名单；owner为account/phone/loginEpoch/environment，事件去重及revision防迟到。凭据四状态与原生资源共用，授权与身份验签是不同事实。界面只消费所属当前事件，旧页面关闭不能关闭新事件或其他业务，切换账号和结束清理仅移除自身。大字号/短屏/返回可达，Android SDK自有来电UI是必要平台差异，不强行叠加Flutter窗口。

## Android
固定SDK公开PhoneStateReceiver、SimStateReceiver、PreciseCallReceiver和CallScreeningService。精确电话状态是系统限制，不能靠声明使普通App具备；逐项核实实际可用权限与角色。应用级账户驱动配置和SDK初始化，后台组件仅在有效当前账号/环境/配置及所需前置条件成立后启用，签出/换账号/失败先停旧组件，未知SDK授权仍显示可配置而非已授权。SDK配置/展示与后台生命周期独立，不在UI内请求权限；不逆向保护载荷。

Android补充：公开SDK receiver/service可继承或委托，保持原vendor入口禁用并注册账户门禁包装。组件启用状态跨进程持久化不能证明账号仍有效，因此Application启动清空运行准入、wrapper每次事件再次检查当前内存owner/权限/SIM，未恢复时电话筛选直接放行，不拦截普通电话。筛选组件先符合角色申请资格，实际事件还需系统roleHeld；电话receiver需现有电话权限及悬浮窗或筛选角色，精确电话状态始终禁用。SDK初始化由应用级唯一环境共享，避免设置重复初始化。

## iOS
Debug/Profile App为com.chaken.phoneagent.test，扩展后缀KXLiveActivityExtension及KXPushServiceExtension；Release App为com.chaken.phoneagent，扩展同后缀。两个Team跟对应App一致，版本共享，正确依赖和Embed。NSE参照原NotificationService：精确四字段识别通信通知，头像HTTPS/5秒/2MB限制、系统Intents转换、失败/即将超时返回原内容，回调仅一次；NSE只美化通知，不把字段存在当验签，也不初始化账户SDK。扩展APIOnly/独立依赖，不引入Runner/Flutter。通知mutable-content和后台Activity触发依赖真实APNS契约，不能由客户端假造；公开前台活动与后台push-to-start分开。来电结束UUID仅无歧义关联，不当号码验证。

iOS通知细节：前台已识别来电只保留声音，抑制重复系统banner，与固定原生一致；未知通知仍由原delegate决定。Plugin接UIApplication启动通知，仅送入既有25秒候选并在账号恢复后验证，不直接初始化SDK或显示已认证。

## 批次和验证
每手写微批至多3文件，>500评估拆分。先共同事件/父关闭竞态，再UI，接续Android、iOS双扩展。Dart analyze+定向可信及root调用方，原生Foundation/JVM/扩展工具专项；平台改动对应构建，跨模块里程碑及交付全量。合成UI与真实SDK/APNS/来电、签名安装分别记录；保留普通App数据，不卸载清数据。工具失败fresh状态有限重试并继续其他任务。

## 设置入口无中间页
入口使用附着设置页的presentation协调器，不push通用状态页。每次点击持有本次Controller订阅，准备/引导/SDK返回后释放surface，不持有账户后台。prepare返回iOS本地needsIntroduction，仅是guide事实，不调用readAuthorization；Android prepare仍是应用级已初始化环境的幂等校验，open内部SIM同步及首次/后续原生分支保持。授权刷新只在SDK返回后执行，不阻塞首次打开。iOS说明全屏present，不额外叠加状态route。等待保持原页、防连点，失败NativeNotice；旧owner/被覆盖/销毁不打开新页，不pop设置页。
