## Why

dev APP 的豆包 Seeduplex（通话模型 ID `5`）系统音色 `xiaohe` 可见，却在点击试听后立即提示失败。该模型未配置克隆模型，当前音色弹层把克隆能力模型 ID 传给系统音色试听宿主，导致 ID 为空，客户端在访问音色目录前就拒绝请求。系统音色应始终归属正在展示的通话模型，而不受克隆能力是否可用影响。

## What Changes

- 通话音色弹层的系统音色试听使用当前展示的通话模型 ID。
- 保留已有统一音色目录、动态试听、CDN 下载、播放及克隆音色各自的流程；不改变音色选择。

## Capabilities

### New Capabilities

- `system-voice-preview-model-scope`: 系统音色试听始终按当前通话模型 ID 获取音色和试听地址，与克隆能力分离。

### Modified Capabilities

无。

## Impact

仅影响 Flutter 通话音色弹层接线及其定向测试；不改 SDK/Web/Netty 接口、数据库、音色归属或供应商配置。验证先覆盖无克隆能力的豆包音色，再运行相关 Flutter 测试、静态分析和 OpenSpec 校验；新包真机试听另作运行验收。
