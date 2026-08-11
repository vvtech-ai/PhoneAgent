# Intentionally empty for the sample project.

-keep class com.squareup.okhttp.** { *; }
-keep interface com.squareup.okhttp.** { *; }
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn com.squareup.okhttp.**
-keep public class * extends android.os.IInterface
-keepattributes InnerClasses
-keep class com.weway.chaken.** { *; }
-dontshrink
-dontwarn cn.com.jit.**
-keep class cn.com.jit.** { *; }
-keep class hsic.com.** { *; }
-keep class com.fri.** { *; }
-keep class com.longmai.** { *; }
-keep class com.safekey.** { *; }
-keep class com.SKFInterface.** { *; }
-keep class com.xdja.** { *; }
-keep class org.bouncycastle.**{*;}
-keep class com.secneo.**{*;}
-keep class com.fort.andJni.**{*;}
-keep public class * extends android.content.ContentProvider
-keep class com.alibaba.fastjson.** { *; }
-keepclassmembers @com.alibaba.fastjson.annotation.JSONCreator class *
-keepclassmembers @com.alibaba.fastjson.annotation.JSONField class * {
<init>(...);
}
-keepclassmembers class okhttp3.internal.** {
private final okhttp3.OkHttpClient instance;
}
-keepnames class * implements okhttp3.Interceptor