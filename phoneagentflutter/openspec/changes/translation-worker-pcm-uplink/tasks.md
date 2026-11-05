# Tasks
- [x] 1. 独立PCM上行、混音与统一RTP标记。
- [x] 2. 媒体接线、完成边界及安全统计。
- [x] 3. 定向测试、静态分析、OpenSpec及双端构建。
- [x] 4. USB双端保留数据安装、中文提交推送。
- [ ] 5. 用户双方听感及日志验收。

## 验证与交付记录（2026-10-09）
- 53 项定向测试通过：PCM工作线程/媒体接线、UDP真实回环、主线程阻塞240ms仍发送真实音频、队列欠载恢复/短尾/混音/DTMF、协调器与会话工厂、提示音及诊断等。补充完成后14项重叠用例复验通过，不重复计总数。
- flutter analyze 无问题；Android debug 2026100923 构建9.4秒通过；iOS Debug22秒和补元数据后9.5秒通过，最终Profile/AOT33.8秒通过。plutil及codesign --verify --deep --strict通过。
- Android匹配原证书重新签名，USB install -r 成功；firstInstallTime保持2026-10-08 11:03:08，lastUpdateTime2026-10-09 19:09:23。启动截图确认保留登录首页。iPhone15测试身份com.chaken.phoneagent.test由2026100915覆盖更新至2026100923；最终Profile安装成功，独立启动后核实进程持续存在，正式com.chaken.phoneagent 1.0.46(11)保持。未卸载/清数据；iPhone登录状态未读屏验收。
- iOS首安装MIInstallerErrorDomain52：扩展缺CFBundleName；查旧应用仍为2026100915后补PRODUCT_NAME，重建安装成功。Debug单独启动未保持运行，按新状态改Profile最终验证。CLI初始不在PATH，使用bundled Node/pnpm恢复；OpenSpec1.2.0专项valid，全量54通过/3既有失败（incremental-validation-policy、login-presentation、native-feature-parity-audit的MODIFIED遗漏当前基线scenario），未改无关规格。初次lint一项括号已修复，最终analyze通过。
- 源码分<=3文件微批，格式化单独机械批；DomesticSipMedia497行，按职责拆出路由/工作线程队列，无新增超500行例外。无关pubspec.lock保持，不加入提交。
- 未真实外呼或执行全量Flutter回归，用户双方听感及新日志验收待完成，暂不归档。
