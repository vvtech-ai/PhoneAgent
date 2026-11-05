$ErrorActionPreference = 'Stop'
$originalTarget = Join-Path $PSScriptRoot 'build-task-test-apk.ps1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('phoneagent-test-policy-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($testRoot) | Out-Null
$encoding = [System.Text.UTF8Encoding]::new($false)
[IO.Directory]::CreateDirectory((Join-Path $testRoot 'scripts')) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $testRoot '.local/cloud-test')) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $testRoot '.local/android/signing')) | Out-Null
$target = Join-Path $testRoot 'scripts/build-task-test-apk.ps1'
Copy-Item -LiteralPath $originalTarget -Destination $target
$defines = Join-Path $testRoot '.local/cloud-test/device-defines.json'
$signing = Join-Path $testRoot '.local/android/signing/signing.properties'
$signingText = "signingStoreFile=registered.keystore`nsigningKeyAlias=synthetic`nsigningStorePassword=synthetic`nsigningKeyPassword=synthetic`n"
$beforeEnvironment = $env:PHONEAGENT_ANDROID_ENV
$beforeSigning = $env:PHONEAGENT_TEST_SIGNING_PROPERTIES
$beforeFailure = $env:PHONEAGENT_POLICY_FAIL_BUILD
[IO.File]::WriteAllText((Join-Path $testRoot 'local.properties'), "trustedCaller.android.test.appKey=synthetic`ntrustedCaller.android.test.appSecret=synthetic`n", $encoding)
$config = @{
    APP_ENV = 'test'
    API_BASE_URL = 'https://chakenai-test.vvtech.tech/aiassistant-api/'
    SDK_API_BASE_URL = 'https://chakenai-test.vvtech.tech/aiassistant-sdk-api/'
    RUNTIME_API_BASE_URL = 'https://chakenai-test.vvtech.tech/aiassistant-runtime/'
    SDK_API_KEY = 'synthetic'; SDK_API_SECRET = 'synthetic'
    AGENT_API_KEY = 'synthetic'; AGENT_API_SECRET = 'synthetic'
}
function Save-TestConfig {
    [System.IO.File]::WriteAllText($defines, ($config | ConvertTo-Json), $encoding)
}
function Expect-Rejection([scriptblock]$action, [string]$reason) {
    $rejected = $false
    try { & $action } catch { $rejected = $true }
    if (!$rejected) { throw "Expected rejection: $reason" }
}
try {
    $trustedPath = Join-Path $testRoot 'local.properties'
    $trustedText = [IO.File]::ReadAllText($trustedPath)
    Remove-Item -LiteralPath $trustedPath
    Expect-Rejection { & $target -BuildNumber 1 -PlanOnly } 'missing root trusted properties'
    [IO.File]::WriteAllText($trustedPath, $trustedText, $encoding)
    Save-TestConfig
    [IO.File]::WriteAllText((Join-Path $testRoot '.local/android/signing/registered.keystore'), 'synthetic')
    [System.IO.File]::WriteAllText($signing, $signingText, $encoding)
    Remove-Item -LiteralPath $defines
    Expect-Rejection { & $target -BuildNumber 1 -PlanOnly } 'missing default cloud-test defines'
    Save-TestConfig
    Expect-Rejection { & $target -BuildNumber 1 -DefinesFile $defines -SigningPropertiesFile (Join-Path $testRoot 'missing.properties') -PlanOnly } 'missing signing'
    foreach ($name in @('APP_ENV', 'API_BASE_URL', 'SDK_API_BASE_URL', 'RUNTIME_API_BASE_URL', 'SDK_API_KEY', 'SDK_API_SECRET', 'AGENT_API_KEY', 'AGENT_API_SECRET')) {
        $before = $config[$name]
        $config[$name] = if ($name -eq 'APP_ENV') { 'dev' } else { '' }
        Save-TestConfig
        Expect-Rejection { & $target -BuildNumber 1 -DefinesFile $defines -SigningPropertiesFile $signing -PlanOnly } $name
        $config[$name] = $before
    }
    Save-TestConfig
    foreach ($name in @('signingStoreFile', 'signingKeyAlias', 'signingStorePassword', 'signingKeyPassword')) {
        [System.IO.File]::WriteAllText($signing, ($signingText -replace "(?m)^$name=.*$", "$name="), $encoding)
        Expect-Rejection { & $target -BuildNumber 1 -DefinesFile $defines -SigningPropertiesFile $signing -PlanOnly } $name
    }
    [System.IO.File]::WriteAllText($signing, $signingText, $encoding)
    Expect-Rejection { & $target -BuildNumber 45 -DefinesFile (Join-Path $testRoot 'outside.json') -PlanOnly } 'outside private root'
    $plan = & $target -BuildNumber 45 -PlanOnly
    if ($plan.TargetPackage -ne 'com.vvtech.aiassistant.test' -or
        $plan.Arguments -notcontains '--release' -or
        $plan.Arguments -notcontains '--pub' -or
        $plan.Arguments -notcontains '--build-name=1.0.53' -or
        $plan.Arguments -notcontains '--build-number=45' -or
        $plan.Arguments -notcontains 'android-arm64' -or
        $plan.Arguments -notcontains 'lib/main.dart') { throw 'Invalid test build plan' }
    $debugPlan = & $target -BuildNumber 1 -DefinesFile $defines -SigningPropertiesFile $signing -BuildMode Debug -PlanOnly
    if ($debugPlan.Arguments -notcontains '--debug') { throw 'Explicit Debug build unavailable' }
    # Execute the orchestration only with a fake Flutter process. Assert the exact
    # fixed executable replacement before invoking, so this test can never build.
    $fakeFlutter = Join-Path $testRoot 'fake-flutter.ps1'
    [System.IO.File]::WriteAllText($fakeFlutter, @'
if ($args -contains '--version') {
    $global:LASTEXITCODE = 0
    Write-Output '{"frameworkVersion":"3.32.0"}'
    return
}
if ($env:PHONEAGENT_ANDROID_ENV -ne 'test' -or !$env:PHONEAGENT_TEST_SIGNING_PROPERTIES) {
    throw 'Missing temporary test environment'
}
$global:LASTEXITCODE = if ($env:PHONEAGENT_POLICY_FAIL_BUILD -eq 'true') { 17 } else { 0 }
'@, $encoding)
    $source = [System.IO.File]::ReadAllText($target)
    $executable = "'D:\tools\flutter-3.32.0\bin\flutter.bat'"
    if (!$source.Contains($executable)) { throw 'Fixed Flutter executable no longer matches; stop before any invocation' }
    $fakeTarget = Join-Path $testRoot 'scripts/fake-test-build.ps1'
    [System.IO.File]::WriteAllText($fakeTarget, $source.Replace($executable, "'$fakeFlutter'"), $encoding)
    foreach ($failure in @('false', 'true')) {
        $env:PHONEAGENT_ANDROID_ENV = 'prior-environment'
        $env:PHONEAGENT_TEST_SIGNING_PROPERTIES = 'prior-signing-path'
        $env:PHONEAGENT_POLICY_FAIL_BUILD = $failure
        if ($failure -eq 'true') {
            Expect-Rejection { & $fakeTarget -BuildNumber 1 -DefinesFile $defines -SigningPropertiesFile $signing } 'fake build failure'
        } else { & $fakeTarget -BuildNumber 1 -DefinesFile $defines -SigningPropertiesFile $signing }
        if ($env:PHONEAGENT_ANDROID_ENV -ne 'prior-environment' -or $env:PHONEAGENT_TEST_SIGNING_PROPERTIES -ne 'prior-signing-path') {
            throw 'Caller environment was not restored'
        }
    }
    Write-Output 'TEST_APK_POLICY: input/plan/environment cases passed; no real Flutter or APK build executed'
} finally {
    $env:PHONEAGENT_ANDROID_ENV = $beforeEnvironment
    $env:PHONEAGENT_TEST_SIGNING_PROPERTIES = $beforeSigning
    $env:PHONEAGENT_POLICY_FAIL_BUILD = $beforeFailure
    # Delete only the exact temp directory created above, never a derived workspace.
    if ((Split-Path -Parent $testRoot) -ne [System.IO.Path]::GetTempPath().TrimEnd([System.IO.Path]::DirectorySeparatorChar)) {
        throw 'Unexpected temporary directory boundary'
    }
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
