param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$BuildNumber
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$flutter = 'D:\tools\flutter-3.32.0\bin\flutter.bat'
$trustedProperties = Join-Path $repo 'local.properties'
if (!(Test-Path -LiteralPath $trustedProperties -PathType Leaf) -or
    ((Get-Item -LiteralPath $trustedProperties -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw '缺少根目录 local.properties 或路径为符号链接；可信字段由 Gradle 完整校验。'
}
$defines = Join-Path $repo '.local\cloud-dev\device-defines.json'
if (!(Test-Path -LiteralPath $defines)) {
    throw '缺少本机开发构建配置，不可仅带接口地址打包。'
}
$component = $defines
while ($component -and $component -ne $repo) {
    if ((Get-Item -LiteralPath $component -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw '开发构建私有输入不允许符号链接或目录联接。'
    }
    $component = Split-Path -Parent $component
}
try {
    $config = Get-Content -LiteralPath $defines -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
} catch { throw 'dev 环境配置无法解析，不输出私有内容。' }
if ($config -isnot [pscustomobject]) { throw 'dev 环境配置必须为 JSON 对象。' }
foreach ($name in @('SDK_API_KEY', 'SDK_API_SECRET', 'AGENT_API_KEY', 'AGENT_API_SECRET')) {
    if ($config.$name -isnot [string] -or [string]::IsNullOrWhiteSpace($config.$name) -or $config.$name -match '[\r\n\x00]') {
        throw "开发构建配置缺少 $name；请补齐本地配置，不要将凭据写入源码。"
    }
}
$expected = @{
    APP_ENV = 'dev'
    API_BASE_URL = 'https://chakenai-dev.vvtech.tech/aiassistant-api/'
    SDK_API_BASE_URL = 'https://chakenai-dev.vvtech.tech/aiassistant-sdk-api/'
    RUNTIME_API_BASE_URL = 'https://chakenai-dev.vvtech.tech/aiassistant-runtime/'
}
foreach ($name in $expected.Keys) {
    if ($config.$name -cne $expected[$name]) {
        throw "开发构建配置中的 $name 与批准环境不一致。"
    }
}
$beforeEnvironment = $env:PHONEAGENT_ANDROID_ENV
Push-Location $repo
try {
    $env:PHONEAGENT_ANDROID_ENV = 'dev'
    $version = (& $flutter --version --machine | ConvertFrom-Json).frameworkVersion
    if ($LASTEXITCODE -ne 0 -or $version -ne '3.32.0') {
        throw '此开发包必须使用 Flutter 3.32.0。'
    }
    & $flutter build apk --debug --no-pub --target-platform android-arm64 `
        --build-name=1.0.53 "--build-number=$BuildNumber" `
        "--dart-define-from-file=$defines" `
        --dart-define=ENABLE_MIGRATION_PREVIEWS=false -t lib/main.dart
    if ($LASTEXITCODE -ne 0) { throw '开发包构建失败。' }
} finally {
    $env:PHONEAGENT_ANDROID_ENV = $beforeEnvironment
    Pop-Location
}
