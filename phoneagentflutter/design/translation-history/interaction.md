# translation-history interaction

Task REALTIME_TRANSLATION opens detail; close/system back returns list. Recording/play/save deferred by user sequencing, no fake playback. No old result-page route.
# 2026-09-18 录音交互接续

当前增量契约见 `recording-interaction-contract.json`：既有HTML录音区与v65状态规则驱动共享录音卡、控制器和五类隔离演练；5/5关键控件、3/3路由有入出边，保存弹窗可取消/返回，详情关闭释放播放器。原下方audio-deferred描述仍代表正式页尚未接入的能力，不代表MOCK交互缺失。

静态蓝色/22圆角/17标题/13副文案和治理后保存SVG复用；响应布局替代固定列宽。无seek，不把装饰波形当真实音频数据；波形及阴影等统一视觉校准后置。按钮绑定真实IconButton/TextButton，无坐标透明热区。纯展示组件不触发网络或设备。测试覆盖320/390/430宽和正常/处理中/三类失败、取消、离页；真实授权、文件缓存、声音及双端保存属于2.9b/2.10。
