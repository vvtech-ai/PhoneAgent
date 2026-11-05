## 1. 证据与规格

- [x] 1.1 定点核对 v65 客户端及后端委托协议，记录隔离边界。
- [x] 1.2 建立并校验 voice-protocol 规格。

## 2. 纯 Dart 基础

- [x] 2.1 类型化事件、控制消息 codec 与 synthetic 协议测试。
- [x] 2.2 CaptureTurnGate：ready、松手 late final、取消、旧轮隔离及测试。
- [x] 2.3 独占音频租约与过期释放测试。
- [x] 2.4 有界播放记账、complete/drain 分离与取消测试。

## 3. 验证与交付

- [x] 3.1 扩充领域依赖边界检查，运行 OpenSpec、analyze、全部测试。
- [x] 3.2 更新总任务和 B1 证据，完成里程碑交付门禁检查；按授权 commit/push，未验收不归档。

后续独立批次：WebSocket transport/超时、PcmCapture/Output 平台适配、真机语音/路由/中断、页面接入。本 change 完成不代表 B1 全部完成。

## 4. 网关传输接续

- [x] 4.1 ASR/TTS独立连接、真实IO socket、地址/取消/超时与清洗错误；v65控制、ASR late final及TTS预缓冲/软完成。
- [x] 4.2 合成时序与真实回环WebSocket、Web隔离演练；22新增/1797全量、analyze、832文件格式和Web/Android Debug/Mac iOS无签名构建、8109浏览器连续操作通过，人工验收证据已更新。
- [ ] 4.3 PCM采集/播放真实端口、生产按住说话/文字切换/发送/TTS编排、共享音频占用及双端集中验收；不得用4.1/4.2替代。
- [x] 4.3g 按v65补后端转写单次回退、账号/语言地址、旧采集释放和取消隔离；69条定向协议/输入/页面/回环与正式工厂测试、analyze及8122浏览器成功/失败两路径通过。集中步骤见ASR_FALLBACK_VALIDATION，不接原生识别SDK、不重放PCM、未验证真实声音，不勾4.3父项。
- [x] 4.3f 普通VOICE网络失败完整业务句冻结、权威ledger核对、原句/补充/修订与同页输入前缀；共享正式接线及隔离Web恢复演练，19新增/2034全量、analyze/919格式/OpenSpec19项、Web/Android构建及8120浏览器合并和已完成去重通过。见VOICE_TURN_RECOVERY_VALIDATION.md；不自动重放或替代SDK/真机验证，本批iOS未构建，不勾父项。
- [x] 4.3e 通话结果终态/持久回复/已应用投影关联，重复与历史抑制、单路返回接续及晚到排空；20新增/1928全量、analyze/893文件格式/OpenSpec19项、三端构建及8114浏览器单路/批量/失败/恢复静默通过，见RESULT_SPEECH_VALIDATION.md；未真实出声/安装，不勾父项。
- [x] 4.3e-1 结果 TTS 同步入队失败不再清除待播正文；底层明确返回入队接受状态，仅在尚无活动音频时有限重试一次。单路、批量、打断、历史静默和 TTS 接口定向回归通过；真实 test 设备的漏播样本尚未复验，不勾 4.3 父项。
- [x] 4.3d 正式统一页普通回复delta/final及交互提示的共享分句/Markdown/固定音色/流水播放、手势和页面取消；23新增/1908全量、analyze/888文件格式/OpenSpec19项及三端构建、8113同页Web合成闭环通过，键盘仍属VOICE且不静音。见REPLY_SPEECH_VALIDATION.md。通话结果持久事件播报、SDK回退及实际设备仍单列，不勾选父项。
- [x] 4.3c 双端真实PCM输出、共享有界实际排空/占用及TaskTtsSession播放组合，23新增/1885全量、analyze/格式/OpenSpec与Web/Android Debug/Mac iOS无签名构建、8112合成输出四路径及ASR交接通过；见PCM_OUTPUT_VALIDATION.md。生产对话分句/完整TTS交互/回退及真机仍属4.3，不勾选父项。
- [x] 4.3b 核对v65手势收尾并纠正文档，正式统一页ASR按住/上滑/切文字/权限与文本提交装配，同页Web合成及22项专项回归、三端构建/浏览器续聊通过；TTS/回退/真实设备仍另验，见VOICE_INPUT_VALIDATION.md，不勾选父项4.3。
- [x] 4.3a 双端PCM采集薄端口、共享ASR ready/采集/松手/取消与独占释放编排；22新增/1819全量、analyze、841文件格式与三端构建、8109共享编排合成浏览器通过。集中人工步骤见PCM_CAPTURE_VALIDATION.md；未使用真实麦克风，不替代4.3生产页面/输出/真机验收。
