$ErrorActionPreference = 'Stop'
$verify = Join-Path $PSScriptRoot 'verify.ps1'
$checks = 0
function Assert-Policy([bool]$condition, [string]$message) {
    if (-not $condition) { throw $message }
    $script:checks++
}
function Assert-Rejected([scriptblock]$action) {
    $rejected = $false
    try { & $action | Out-Null } catch { $rejected = $true }
    Assert-Policy $rejected 'Expected invalid scope to fail before executing tools'
}

Assert-Rejected { & $verify -PlanOnly }
Assert-Rejected { & $verify -FullRegression -PlanOnly }
Assert-Rejected { & $verify -TestPaths 'test' -PlanOnly }
Assert-Rejected { & $verify -TestPaths 'test/../test' -PlanOnly }
Assert-Rejected { & $verify -TestPaths 'lib/main.dart' -PlanOnly }
Assert-Rejected { & $verify -TestPaths 'test/missing_policy_test.dart' -PlanOnly }
Assert-Rejected { & $verify -TestPaths 'test/shell_workbench_test.dart' -FullRegression -Reason 'invalid mixed scope' -PlanOnly }
Assert-Rejected { & $verify -TestPaths 'test/shell_workbench_test.dart' -AndroidBuild -SkipAndroidBuild -PlanOnly }

$plan = (& $verify -TestPaths 'test/shell_workbench_test.dart','test/shell_conversation_ports_test.dart' -PlanOnly) | ConvertFrom-Json
Assert-Policy ($plan.Scope -eq 'targeted') 'Default must be targeted'
$testCommand = @($plan.Commands | Where-Object { $_.Arguments[0] -eq 'test' })
Assert-Policy ($testCommand.Count -eq 1 -and $testCommand[0].Arguments.Count -eq 4) 'Expected exactly two targeted paths'
Assert-Policy (@($plan.Commands | Where-Object { $_.Arguments[0] -in @('build', 'pub') }).Count -eq 0) 'Build and dependency refresh must be opt-in'
$full = (& $verify -FullRegression -Reason 'release checkpoint' -AndroidBuild -RefreshDependencies -PlanOnly) | ConvertFrom-Json
Assert-Policy ($full.Scope -eq 'full' -and $full.Reason -eq 'release checkpoint') 'Full scope must retain the reason'
Assert-Policy (@($full.Commands | Where-Object { $_.Arguments[0] -eq 'test' })[0].Arguments.Count -eq 2) 'Full suite must not have a targeted path'
Assert-Policy (@($full.Commands | Where-Object { $_.Arguments[0] -eq 'build' }).Count -eq 1) 'Explicit Android build must be included'
Assert-Policy (@($full.Commands | Where-Object { $_.Arguments[0] -eq 'pub' }).Count -eq 1) 'Explicit lock refresh must be included'
Write-Host "Verification policy: $checks checks passed; PlanOnly did not execute Flutter, builds, or network tools."
