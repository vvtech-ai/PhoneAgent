## 实现
DialerPage目前把state.message.isNotEmpty作为compact分支条件。移除该条件，提示仍放在配置上方，通过压缩历史可用高度呈现；短屏、大字体及演练分支保持原有行为。
## 验证
用真实DialerController和禁止外呼的替身输入解锁码，验证iOS/Android开启前后历史独立滚动，拖动历史不移动配置/键盘/底部操作；补充普通错误提示。运行拨号模块及翻译页面定向测试、analyze和OpenSpec校验。真机待验，不归档，不操作主线程设备。
