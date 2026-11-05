# 验证

实体手机1511当前会议会话截图保存至D:/Temp/contacts-current-session-20261015.png；只读dumpsys核实READ_CONTACTS granted=true。测试主机access.log只输出时间/方法/路径/状态，不读或输出通讯录和凭据：19:42:05 POST /aiassistant-sdk-api/api/assistant/agent/device-contacts-lookup-result 404，与客户端错误归属一致。没有重放当前任务、外呼或修改运行配置。

Java只读核对两个Controller位于aiassistant-agent-sse；SDK无对应端点。独立API/SDK前缀测试先复现2失败（URL落SDK，C1服务为sdk）；精确加入两路径后2通过。联合AccountApi/路由、联系人API、按姓名/号码lookup、权限、会话、道歉、OCR、钱包和架构22文件150项通过（44.6秒）。analyze无问题（17.5秒）、OpenSpec161通过。生产仅Flutter service_routes.dart增加两条精确归属，不改请求体或后端/Web；同时集成独立道歉Provider首屏修复。

用户补充诊断zip含992条结构记录，时间北京时间14:03至16:51，早于1511构建；16:33:42收到lookupDeviceContactsByNames，16:33:44回传404，与只读网关16:33:44路径吻合。不含原始TTS/显示全文，不能据此声明新包界面验收。多路提示额外8项通过，其中实际ConversationPage渲染断言确认显示句与SpeechPromptPolicy完全一致，旧前言不可见。未改这一项生产逻辑。

1512测试签名包、安装与现场复验完成后追加；已有真实权限已授权，不为测试拒绝而更改用户授权。禁止把模拟请求成功或首页启动表述为联系人业务现场通过。

实际交付：源码1195b991已推送codex/dev，原登记签名test Release ARM64 1.0.51+2026101512构建及签名/包名/版本/AOT/三服务/邀请/11项原生库检查通过。D:/work/04phoneAgent/deliveries/apology-entry-fix-20261015/Phone_Agent_TEST_1.0.51_2026101512_test_20261015_195411.apk，SHA256 8dfbe692238dfc339c5faa277702dd88fe8728ef00cebb0b388f8cf72c1e9fab。实体手机覆盖安装Success，首次安装时间保持；1512和前台进程已读回，READ_CONTACTS仍granted=true。道歉入口确认卡已实际可见；通讯录会议任务没有自动重放，真实续跑待用户复测。没有把路由/签名单测当成现场续跑成功；Java/Web仅只读，未改服务或DB。脱敏路由证据、测试与安装JSON随包。
