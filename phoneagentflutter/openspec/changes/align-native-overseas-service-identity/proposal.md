## Why
原生海外HTTP使用mobile-app-user，Flutter传登录accountId。用户确认对齐服务用户标识且UI不改。该差异尚未被服务端证实为400根因。
## What Changes
仅海外HTTP适配层统一固定服务身份，保留内部真实账号归属和隔离；记录固定来源类别。
## Impact
海外backend和诊断白名单/测试，不改UI或国内接口。
