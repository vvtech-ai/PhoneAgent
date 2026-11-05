## 证据
系统日志16:10:31.903 getIdentityToken code1/成功/非空ticket，16:10:32.095在DraggableFloatView.dealDoubleHead→setCover→initView崩溃，缺com.bumptech.glide.Glide；JSON主线程崩溃摘要时间吻合。原始日志/身份数据只在本机，不提交。
## 方案
固定参考Android0f8879e4 app/build.gradle469–470使用glide4.15.0与annotationProcessor compiler4.15.0。SDK已编译，Glide API调用不依赖宿主生成的GlideApp；保留同源compiler配置，不引入kapt或版本升级。审计两个AAR字节码得到15个Glide外部类，全部加实际DEX定义守卫，继续校验SDK哈希/重复类/原组件。
## 验证
扩展守卫在旧APK必须RED；依赖解析与新APK GREEN。Android可信JVM、Dart可信定向/analyze。Debug测试包2026101010，安装前后核对包名、version、firstInstallTime，adb install -r不卸载清数据，安装失败不卸载回退。真实来电展示/头像及无崩溃需用户现场触发确认，未验不归档。
