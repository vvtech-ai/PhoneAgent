## 实施
- [x] 1 核对当前工作区、展示路径及用户批准范围，建立规格。
- [x] 2 独立Flutter展示入口、快照协议及平台端口。
- [x] 3 iOS SDK上方容器、当前owner校验、更新和资源释放。
- [x] 4 主应用展示协调及定向回归。
- [x] 5 analyze、OpenSpec、iOS编译检查并记录实际范围。
- [ ] 6 真机MCP页面来电、连续更新、关闭返回及前后台验收（需明确真实来电测试授权）。

- 微批1（3源码）：建立展示端口、内存快照协议和iOS通道适配；独立容器复用既有DTO校验，不触发SDK业务。

- 微批2（3源码）：增加串行展示协调、专用Dart入口和复用身份页的展示应用；支持更新、旧回调过滤、前台重试。

- 微批3（3源码）：新增iOS独立引擎容器与私有头登记；原生present完成和Flutter渲染回执共同确认可见，关闭仅移除详情。

- 微批4（3源码）：设置surface提供当前SDK导航与owner校验，SDK退出/释放时清理详情；SDK openSettings请求仍独立保持。

- 微批5（2源码）：主应用注入展示端口并连接协调host；Android端口直接fallback，不发平台请求。

- 微批6（3测试）：新增快照往返/非法输入、独立展示应用更新关闭、协调器竞态和前后台测试。首轮129通过/1加载失败为新增测试误await void，已按实际API修正，重新定向验证。首次analyze无问题；OpenSpec205项通过。

- 微批7（3源码加移除本轮临时host）：发现UIKit全屏覆盖会暂停主Flutter视图，改为Riverpod真实事件监听驱动独立controller，不依赖widget rebuild/帧。原生协调实际源码测试（UIKit/Flutter替身）已通过；首轮测试函数名与POSIX sync冲突已更名。

- 微批8（3源码/测试）：补真实UIApplication激活通知重试；原生更新不要求被覆盖SDK视图仍挂window，防止首个身份后无法更新。新增对应原生替身回归。

- 微批9（2测试）：可信模块+架构139项通过，analyze无问题；新增端口协议/Android不发请求及真实Provider在主Flutter暂停且无重建时转发事件的回归。真实iPhoneOS+Flutter3.32头文件clang -Werror语法检查通过。原生替身测试不代表UIKit或SDK运行验收。

- 微批10（3源码/测试）：详情按钮捕获当前渲染身份，旧闭包仍只发旧presentationId；Provider回归改用真实异步时钟避免fakeAsync流关闭等待，实际断言保持。
- 微批11（3源码/测试）：原生可见诊断追加真实Flutter首帧回调门禁，替身测试明确Dart布局完成仍不能单独报展示成功。

- 微批12（3源码/测试）：iOS无签名Debug已构建成功（Xcode28.5秒）。首轮pod install失败，核对状态后单独重试成功；本次重试集成后成功，未升级依赖。关闭详情不再发送会抢先重开的retry；动画中关闭等待transition结束再销毁引擎，新增原生竞态断言。

- 微批13（3源码）：最终架构复核将独立展示页中的MethodChannel移到data适配，通过纯Dart展示端口注入，UI仅消费快照和回调。前一轮143项/analyze/OpenSpec205已通过，本批补受影响验证。

- 微批14（2源码/测试）：专用入口装配data端口，独立展示应用回归沿真实通道适配执行；不引入主应用服务或SDK注册。

- 最终验证：可信来电全模块+架构143项通过（定向，非全仓）；flutter analyze无问题；OpenSpec全量205项通过、0失败；原生实际协调源码替身场景通过，真实iPhoneOS/Flutter3.32头文件clang -Werror通过；最终flutter build ios --debug --no-codesign --no-pub通过（Xcode11.9秒）。
- CocoaPods仅刷新本地podspec校验和，依赖版本无变化；Runner工程自动序列化经plutil结构核对后恢复原文，未改变工程配置。所有新增生产文件<500行。
- 未安装、未签名交付、未触发SDK授权或真实来电；UIKit实际层级、独立引擎性能和SDK返回状态保持仍须真机验收。仅本地修改，不切分支/提交/推送，不归档。

- 2026-10-19 用户追加授权Git提交并推送：仅提交本次iOS身份详情修复；已核对origin/codex/dev新增0abbcfa1，保留远端更新后非强制推送。真实来电待验和未归档状态保留。

- 提交前整合复验：保留远端0abbcfa1，两个共用记录按原文合并双方追加；29个其他文件与变基前完全一致。143项可信/架构定向测试、analyze及OpenSpec206项通过，diff检查通过。按用户追加授权正常推送codex/dev，不force；真实来电仍待验。
