# codex/dev_zys合入codex/dev记录

## 授权与基线
用户2026-10-14明确要求合并。工作区/Users/Eason/Desktop/Git/PhoneAgent起始干净且在codex/dev；fetch后本地/远端均一致。
- 目标99daa3e0caaa98827ce99928143263bf9fbd87ee。
- 来源7c0bd25a6d71861a47e2976f440fa79aaa381162。
- origin为既有GitLab phoneagentflutter仓库（fetch重定向到同仓库.git地址）。不改配置，不改其他工作树。

## 合并策略及冲突
no-ff三方合并，保留双方历史。4处冲突：
1. Android TaskFileChannel：保留dev Save参数顺序/非空MIME和PDF/OFD/XML格式；新增zys exists读取。
2. AccountApi：采用独立AccountTransportPolicy，同时将commerce/membership加入保护路径；保留原协议元数据和新克隆诊断、价格/幂等处理。496行，不新增例外。
3. record_time_callers_test：保留dev已验证historySubtitle投影，不改日期业务。
4. flutter_record_time_reference：同上并移除自动合入但无用途的record_time import。

iOS TaskFileChannel自动合并保留双方；shell_route自动合并保留会员入口及clone目录刷新。两个追加文档自动合并保留各自104行。453个单侧新增/修改/删除的index blob与相应父版本一致；仅新AccountTransportPolicy为主动补commerce/membership的例外，共同修改8路径分别检查。

## 验证
本次为公共网络/编排/克隆/翻译/平台跨模块集成，执行一次全量回归，工具链保持Flutter3.32.0/Dart3.8.0。
- flutter analyze：通过，21.2秒；夹具修正后最终静态检查4.3秒无问题。
- openspec validate --all：127通过、0失败（含本轮change）。
- flutter build apk --debug：通过，Gradle91.9秒。
- flutter build ios --debug --no-codesign：通过，Pod install3.6秒、Xcode22.2秒。
- tool/verify_trusted_sdk.py：53文件及Android10个Activity/iOS竖屏声明通过。
- tool/check_trusted_caller_apk.py：runtime哈希、AAR重叠、19必需类及Manifest归属通过。
- flutter test全量：5140通过、1跳过、2失败，6分41秒。失败均为dev既有RecordingFileFixture在macOS混用/var与/private/var的词法包含检查；只修夹具返回已验证的规范目录，全部2个直接调用文件（domestic_recording_cleanup/session）8项复验通过，不改产品目录保护逻辑。首轮全量不记全绿，按增量策略不重复全量。
- git diff --cached --check：通过。原有Podfile/lock及pubspec.lock无额外未暂存变化。

## 工具恢复
初次单侧blob核验脚本把删除路径的rev-parse错误stdout当作blob比较；重新读取index确认两个旧SDK图片均按来源删除后，改为--verify失败返回None，453路径通过。未重放业务操作、未丢弃文件。

## 交付边界
未安装、卸载、清数据、认证、外呼、支付或部署。双端编译不等于真实设备/服务通过；各原有active change待验状态保留，不归档。合并提交5cb11364c3b495de5d92836531ee8d702be9994f已非强制推送origin/codex/dev；ls-remote核对同值，来源codex/dev_zys仍为7c0bd25a。合并两父版本分别为99daa3e0与7c0bd25a，双方祖先检查通过。随后仅追加本回执文档提交，不改产品；验收待办不归档。
