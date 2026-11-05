## Why
diagnostics-9记录两次androidMainUnhandled，设备16:10:31身份查询成功但16:10:32悬浮窗加载Glide时NoClassDefFoundError。参考0f8879e4声明Glide4.15.0，FlutterAPK无Glide定义。
## What Changes
补齐参考Glide运行时/编译器依赖；审核SDK展示外部类，APK守卫覆盖实际引用的15个Glide类。构建并保留数据覆盖安装，真实来电由用户触发。
## Impact
仅AndroidGradle依赖与产物守卫，不改厂商二进制/账号/SIM/权限/iOS。pubspec.lock外部修改保留。
