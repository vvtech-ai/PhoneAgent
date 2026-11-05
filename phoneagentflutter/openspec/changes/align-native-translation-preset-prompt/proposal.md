## Why
用户确认Flutter双端的预设自动提示与aiassistant_app一致：实时翻译关闭时普通呼叫不得因prompt偏好再次弹预设，不改UI。
## What Changes
仅修改统一拨号入口自动条件为enabled且prompt且尚未预设确认；保留手动入口及原有偏好。
## Impact
共享Dart一处条件及定向测试；号码、跨境、平台电话、SDK均不改。保留已有工作区改动，不提交推送，真实呼叫未授权。
