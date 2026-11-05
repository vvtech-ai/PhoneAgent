- [x] 1 固定参考审计与规格。
- [x] 2 SDK页面生命周期对齐，移除启动gate及强制关闭。
- [x] 3 SIM/账号保留及权限/空值/写入对齐。
- [x] 4 JVM、Dart/analyze、构建与APK守卫。
- [x] 5 文档和进度已更新，限定本批中文提交推送；设备场景未验不归档。

验证：可信Dart109项、Android JVM7组21项、analyze9.3秒无问题，Debug构建12.3秒及APK SDK哈希/DEX/合并manifest守卫通过。移除旧launchGate/ownership生产实现及其旧契约测试，新增退出保留、只写计划槽位、权限OR与null/blank回退专项。真实首次/后续SDK返回、后台/锁屏来电、换账号和双卡设备对照仍待验，不归档。
