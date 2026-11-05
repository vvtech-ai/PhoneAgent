# 2026-10-29 实现者验证

## 已完成

- 修复前真实repository/controller/HomePage失败：远端返回后当前首页仍builtin-1；修复后不切页即应用有效配置。
- 测试发布接口签名GET读取20261012.37，按9张卡片同步公共默认数据；6张enabled、挪车comingSoon、订酒店和旧会议邀请disabled。dev/prod原确认快照保持。
- 新增即时更新、慢缓存竞态、慢写入/写失败、304/错误保留、同版本内容变化、账号销毁与环境快照9项通过。首屏在缓存/网络等待时有完整可点击内容，不增加网络调用；原用户偏好投影不变。
- 首页及相邻餐厅卡片、选项版本、联系人入口、通话确认语义等139项通过。原VoiceHost回放仍验证已点旧卡开场与TTS只播放一次，同时当前首页接受新快照。
- 受影响首页生产/测试和业务provider静态分析无问题，OpenSpec校验通过。

## 基线失败与边界

全选回归发现3项iOS预览测试在组件销毁后仍有支付恢复定时器：home_model_multiplier_test的iOS confirmed selection，以及task_entry_semantics_test的iOS named entry普通/翻译两种。临时使用HEAD四份首页原生产文件运行同三项，全部复现同失败，finally已恢复候选源码。未修改支付或这些测试。它们单独记录，不计入139项通过。

本机证据：D:/Temp/phoneagent-home-restaurant-20261029/self-home.jsonl、self-frontend-green.jsonl、baseline-ios-three.jsonl。没有手机安装、iOS原生或真实电话验证。

## 独立源码验收

未参与实现的代理重新读取原图、工作区与目标检出规范、批准方案和32文件哈希；Java307项与独立26项检查通过。Flutter本轮119项通过，另3项支付Timer失败由代理在其独立HEAD副本再次复现为基线。代理重新签名读取真实测试发布，逐字段比较全部9张卡片（含默认可见、最低版本及非道歉开场），全部一致；独立并发/迟到缓存/销毁反例通过，静态与严格规格校验通过。结论APPROVE限候选源码，不冒充真机或部署验收。

完整本机报告：D:/Temp/phoneagent-home-restaurant-independent-20261029/independent-source-report.md。后续文档状态及源提交身份变化不改变已验产品文件字节。

## 联合源码复核及交付

Java快进保留远端ac7b3661a后，独立代理再次执行7组61条与26项补充检查，通过。Flutter已验产品文件未变化；源码提交3eb4330f674c77a2ea61624cceff3c459ca230dc已推送origin/test_v1.8.0_fix并读回同SHA。

1.0.54(47)测试Release ARM64原签名APK已构建并获独立静态产物APPROVE。代理实读包名/版本/双证书指纹/三路test与邀请配置，比对固定Flutter Release引擎、12个JNI与8个assets字节；新AOT含本次test快照，产品模式实际配置与SDK签名登录路由探针通过。产物路径、源码身份和SHA256按打包规范只在交付对话保留，不新增包验证回执文件。未安装，未做真实登录/音频/外呼；3项iOS基线失败与未部署后端的边界保持。

该收尾只记录联合源码回归及交付状态，不修改已验产品。独立报告同上，最终APK部分已追加；餐厅后续的历史工具包装兼容补充由Java变更记录单独追踪，不影响本APK身份。
