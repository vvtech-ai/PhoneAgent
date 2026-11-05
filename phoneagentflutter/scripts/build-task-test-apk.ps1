param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$BuildNumber,
    [string]$DefinesFile,
    [string]$SigningPropertiesFile,
    [ValidateSet('Debug', 'Release')]
    [string]$BuildMode = 'Release',
    [switch]$PlanOnly
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$flutter = 'D:\tools\flutter-3.32.0\bin\flutter.bat'
$trustedProperties = Join-Path $repo 'local.properties'
if (!(Test-Path -LiteralPath $trustedProperties -PathType Leaf) -or
    ((Get-Item -LiteralPath $trustedProperties -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw '缺少根目录 local.properties 或路径为符号链接；可信字段由 Gradle 完整校验。'
}
$privateRoot = [IO.Path]::GetFullPath((Join-Path $repo '.local/android/signing')) + [IO.Path]::DirectorySeparatorChar
$expectedDefines = [IO.Path]::GetFullPath((Join-Path $repo '.local/cloud-test/device-defines.json'))
if (!$DefinesFile) { $DefinesFile = $expectedDefines }
if (!$SigningPropertiesFile) { $SigningPropertiesFile = Join-Path $privateRoot 'signing.properties' }
if ([IO.Path]::GetFullPath($DefinesFile) -ine $expectedDefines) {
    throw 'test 配置固定使用工程 .local/cloud-test/device-defines.json。'
}
if (![IO.Path]::GetFullPath($SigningPropertiesFile).StartsWith($privateRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Android 签名属性必须位于工程 .local/android/signing 内。'
}
foreach ($path in @($DefinesFile, $SigningPropertiesFile)) {
    $fullPath = [IO.Path]::GetFullPath($path)
    # Refuse junction/symlink components before reading private contents.
    $component = $fullPath
    while ($component -and $component -ne $repo) {
        if ((Test-Path -LiteralPath $component) -and
            ((Get-Item -LiteralPath $component -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Android 私有输入路径不允许符号链接或目录联接。'
        }
        $component = Split-Path -Parent $component
    }
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
        throw '缺少工程内 test 构建私有参数或签名属性文件。'
    }
}
$defines = (Resolve-Path -LiteralPath $DefinesFile).Path
$signing = (Resolve-Path -LiteralPath $SigningPropertiesFile).Path
try {
    $config = Get-Content -LiteralPath $defines -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
} catch { throw 'test 环境配置无法解析，不输出私有内容。' }
if ($config -isnot [pscustomobject]) { throw 'test 环境配置必须为 JSON 对象。' }
$expected = @{
    APP_ENV = 'test'
    API_BASE_URL = 'https://chakenai-test.vvtech.tech/aiassistant-api/'
    SDK_API_BASE_URL = 'https://chakenai-test.vvtech.tech/aiassistant-sdk-api/'
    RUNTIME_API_BASE_URL = 'https://chakenai-test.vvtech.tech/aiassistant-runtime/'
}
foreach ($name in $expected.Keys) {
    if ($config.$name -cne $expected[$name]) { throw "test 构建 $name 与批准目标不一致。" }
}
foreach ($name in @('SDK_API_KEY', 'SDK_API_SECRET', 'AGENT_API_KEY', 'AGENT_API_SECRET')) {
    if ($config.$name -isnot [string] -or [string]::IsNullOrWhiteSpace($config.$name) -or $config.$name -match '[\r\n\x00]') {
        throw "test 私有参数缺少 $name。"
    }
}
$signingLines = Get-Content -LiteralPath $signing -Encoding UTF8
foreach ($name in @('signingStoreFile', 'signingKeyAlias', 'signingStorePassword', 'signingKeyPassword')) {
    if (!($signingLines | Where-Object { $_.StartsWith("$name=") -and $_.Substring($name.Length + 1).Trim().Length -gt 0 })) {
        throw "工程内签名属性缺少 $name。"
    }
}
$storeLine = $signingLines | Where-Object { $_.StartsWith('signingStoreFile=') }
if ($storeLine.Count -ne 1 -or $storeLine -cne 'signingStoreFile=registered.keystore') {
    throw 'signingStoreFile 必须为相对路径 registered.keystore。'
}
$store = Join-Path (Split-Path -Parent $signing) 'registered.keystore'
if (!(Test-Path -LiteralPath $store -PathType Leaf) -or
    ((Get-Item -LiteralPath $store -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw '缺少工程内 keystore 或路径为符号链接。'
}
$arguments = @('build', 'apk', "--$($BuildMode.ToLowerInvariant())", '--pub', '--target-platform', 'android-arm64',
    '--build-name=1.0.53', "--build-number=$BuildNumber", "--dart-define-from-file=$defines",
    '--dart-define=ENABLE_MIGRATION_PREVIEWS=false', '-t', 'lib/main.dart')
if ($PlanOnly) {
    [pscustomobject]@{ TargetPackage = 'com.vvtech.aiassistant.test'; Flutter = $flutter; Arguments = $arguments }
    return
}
$beforeEnvironment = $env:PHONEAGENT_ANDROID_ENV
$beforeSigning = $env:PHONEAGENT_TEST_SIGNING_PROPERTIES
Push-Location $repo
try {
    $env:PHONEAGENT_ANDROID_ENV = 'test'
    $env:PHONEAGENT_TEST_SIGNING_PROPERTIES = $signing
    $version = (& $flutter --version --machine | ConvertFrom-Json).frameworkVersion
    if ($LASTEXITCODE -ne 0 -or $version -ne '3.32.0') { throw 'test 构建必须使用 Flutter 3.32.0。' }
    & $flutter @arguments
    if ($LASTEXITCODE -ne 0) { throw 'test APK 构建失败。' }
} finally {
    $env:PHONEAGENT_ANDROID_ENV = $beforeEnvironment
    $env:PHONEAGENT_TEST_SIGNING_PROPERTIES = $beforeSigning
    Pop-Location
}
