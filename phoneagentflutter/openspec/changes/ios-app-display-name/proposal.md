# iOS 正式与测试 App 显示名称

## Why
用户于2026-10-11指定iOS名称随包身份区分；当前两类包均显示Phone Agent。

## What Changes
- com.chaken.phoneagent 显示 PhoneAgent。
- com.chaken.phoneagent.test 显示 PhoneAgent test。
- Info.plist读取构建配置提供的显示名称，Debug/Profile与Release分别配置。

## Impact
仅Runner显示名称与Xcode配置；不变更Bundle ID、扩展、签名或业务逻辑。
