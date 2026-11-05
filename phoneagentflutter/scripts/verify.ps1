param(
    [string[]]$TestPaths = @(),
    [switch]$FullRegression,
    [string]$Reason = '',
    [switch]$AndroidBuild,
    [switch]$SkipAndroidBuild,
    [switch]$RefreshDependencies,
    [switch]$PlanOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if ($AndroidBuild -and $SkipAndroidBuild) { throw 'AndroidBuild and SkipAndroidBuild are mutually exclusive.' }
if ($FullRegression -and $TestPaths.Count -gt 0) { throw 'Choose TestPaths or FullRegression, not both.' }
if ($FullRegression -and [string]::IsNullOrWhiteSpace($Reason)) { throw 'FullRegression requires a Reason (milestone, release, or unbounded shared impact).' }
if (-not $FullRegression -and $TestPaths.Count -eq 0) { throw 'Specify -TestPaths test/<affected paths>, or -FullRegression -Reason <reason>. No tests or builds were started.' }

Push-Location $projectRoot
try {
    $testRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'test'))
    $selected = @()
    foreach ($path in $TestPaths) {
        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) {
            throw "Test path does not exist: $path"
        }
        $item = Get-Item -LiteralPath $path
        if (-not $item.FullName.StartsWith($testRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Targeted paths must be inside test/, not the test root. Use FullRegression for the whole suite.'
        }
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked test paths are not supported.' }
        if (-not $item.PSIsContainer -and $item.Name -notlike '*_test.dart') { throw "Not a test file: $path" }
        if ($item.PSIsContainer -and -not (Get-ChildItem -LiteralPath $item.FullName -Filter '*_test.dart' -Recurse -File | Select-Object -First 1)) {
            throw "No test files in: $path"
        }
        $selected += $item.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
    }
    $selected = @($selected | Select-Object -Unique)
    $checks = @([pscustomobject]@{ Tool = 'openspec'; Arguments = @('validate', '--all') })
    if ($RefreshDependencies) {
        $checks += [pscustomobject]@{ Tool = 'flutter'; Arguments = @('pub', 'get', '--enforce-lockfile') }
    }
    $checks += [pscustomobject]@{ Tool = 'dart'; Arguments = @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test', 'tool') }
    $checks += [pscustomobject]@{ Tool = 'flutter'; Arguments = @('analyze', '--no-pub') }
    $checks += [pscustomobject]@{ Tool = 'flutter'; Arguments = @('test', '--no-pub') + $selected }
    if ($AndroidBuild) {
        $checks += [pscustomobject]@{ Tool = 'flutter'; Arguments = @('build', 'apk', '--debug', '--no-pub') }
    }
    if ($PlanOnly) {
        [pscustomobject]@{
            Scope = $(if ($FullRegression) { 'full' } else { 'targeted' })
            Reason = $Reason
            Commands = $checks
        } | ConvertTo-Json -Depth 5
        return
    }
    $version = (& flutter --version --machine | ConvertFrom-Json).frameworkVersion
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read Flutter version' }
    if ($version -ne '3.32.0') { throw "Expected Flutter 3.32.0, found $version" }
    if ($FullRegression) { Write-Host "Full regression reason: $Reason" }
    foreach ($check in $checks) {
        $arguments = $check.Arguments
        Write-Host ("Running: " + $check.Tool + ' ' + ($arguments -join ' '))
        & $check.Tool @arguments
        if ($LASTEXITCODE -ne 0) { throw "Verification failed: $($check.Tool) $($arguments -join ' ')" }
    }
} finally {
    Pop-Location
}
