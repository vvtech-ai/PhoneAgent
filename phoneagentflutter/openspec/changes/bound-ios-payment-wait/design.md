# 设计与改动登记

基线 codex/dev@6689ec49；保留上一轮未提交的取消恢复修改。诊断29中 8a75ef8ff8168f27 在11:28:10启动支付，重启前没有结果记录，11:30/11:31恢复成功仍 PROCESSING；截图为 Flutter busy 遮罩。

状态 owner 为 PurchaseController，账号生命周期由 provider/outbox 校验。新增 iOS PaymentLauncher 装饰器负责调起前持久记录、30秒界面等待边界及迟到原生结果；不改 Android launcher。记录按环境/API/账号隔离，包含原单、尝试ID、绑定token及阶段，不保存签名交易正文。先保存成功才调起，存储失败不偷偷购买。

成功凭据仍由 AppleTransactionVerifier 交后端校验，后端成功后 finish。迟到结果只按原尝试持久化，成功通过交易更新通知触发原恢复，取消保存原请求ID并补报。未知/超时不触发取消。生产原生等待和调起流程边界30秒；恢复整体15秒，原生发现最多5秒，存储单次最多3秒，原生发现失败仍尝试查询服务器。恢复超时失活旧 UI revision；真实交易处理仍按账号边界继续。无 Apple 凭据不等于未付款。

入口包括会员及积分购买、继续原单、启动、前台、网络恢复、主动查询。复用会员“处理待购买事项”、反馈“查询支付结果/返回会员页面”和原取消入口，不改 widget 外观，不增加启动弹窗。

验证：IOS-WAIT-01 原生不返回30秒释放；02迟到成功/取消；03等待期间杀进程；04恢复无反馈及查询超时；05重复/账号切换；ANDROID-UNCHANGED 原路径无deadline/持久化。测试注入短时间边界，另校验生产30秒默认值。真实沙盒、安装包与截图复验独立待验。

文件职责：apple_payment_attempt 为纯记录协议；secure_apple_payment_attempt_store 负责账号/环境存储与稳定代次清理；ios_payment_runtime 负责等待、迟到结果、发现和持久恢复；purchase_launch 提取既有调起流程并限定 iOS 的调起等待，Android 不设置期限；PurchaseController 仍持有展示状态与 revision，去除重复 preview 转发后496行；provider 仅 iOS 注入运行时，目录仍使用原 launcher，原页面/控件及原生文件未修改。

取消结果先保存尝试，再记原取消待办；重启可从 canceled 尝试重建被中断的 outbox 写入。服务器可信终态同时清理原取消待办，防止恢复查单中再次重建已处理待办。记录/超时/恢复/取消补报有独立封闭诊断阶段，仅记录摘要与阶段，不打印绑定token或签名正文。

systematic-debugging/verification-before-completion 技能目录未找到；实际依据日志/截图复现、增加连续回放并在完成前验证，不声称已加载技能。
