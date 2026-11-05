- [x] 1 真实崩溃/固定参考依赖/展示引用审计并建规格。
- [x] 2 补Glide4.15.0依赖，扩展15类APK守卫，旧APK RED。
- [x] 3 JVM/Dart/analyze、依赖解析、Debug构建及APK GREEN。
- [x] 4 USB同证书保留数据安装与版本核验2026101010，firstInstallTime不变，启动成功。
- [ ] 4a 用户真实来电确认身份浮窗/头像和无闪退，登录保持现场待确认。
- [x] 5 更新记录并限定本批中文提交推送，真实来电未验收不归档。

验证：旧APK缺15个Glide类RED，新APK含19个关键类GREEN；Glide依赖解析4.15.0、JVM21项、Dart109项、analyze11.7秒、Debug46.5秒通过。默认debug签名首次安装被UPDATE_INCOMPATIBLE拒绝，未卸载；原公司签名配置重新签名并比对证书后一次覆盖成功。真实来电未验不归档。
