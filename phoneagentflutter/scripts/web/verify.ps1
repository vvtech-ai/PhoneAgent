param([string]$Flutter = 'E:/dev/flutter/bin/flutter.bat')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$dart = Join-Path (Split-Path $Flutter) 'dart.bat'
& node --test scripts/web/dev-server.test.mjs
if ($LASTEXITCODE -ne 0) { throw 'Development proxy tests failed' }
& $dart test --platform chrome test/core/network/stream_client_web_test.dart test/core/network/account_download_web_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Browser stream tests failed' }
& $Flutter test test/mobile_preview_test.dart test/features/conversation test/features/auth test/features/contacts test/features/call_models test/features/points test/features/feedback test/features/dialer test/features/settings test/features/calls test/features/initialization test/features/translation test/features/attachments test/features/app_logs
if ($LASTEXITCODE -ne 0) { throw 'Viewport/conversation/auth/contacts/voice/wallet/feedback/dialer/settings tests failed' }
