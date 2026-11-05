param(
    [Parameter(Mandatory = $true)][string]$SourceRepository,
    [string]$Apk
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$sourceRoot = (Resolve-Path -LiteralPath $SourceRepository).Path
$groups = @(
    @{ Ref = '4c781e3ccfcd148c1f205921534907ee0c5aa864'; Prefix = 'android/app/libs/';
       Target = 'android/app/libs/identity'; Count = 8 },
    @{ Ref = 'ddb996a28f98559ea7d8b76ca9d7712703dedbc1';
       Prefix = 'iOS/PhoneAgent/PhoneAgent/ThirdLib/AliyunIDPro_iOS_2.3.50/';
       Target = 'ios/IdentityCaptureSDK/Vendor'; Count = 328 }
)
foreach ($group in $groups) {
    $entries = @(& git -C $sourceRoot ls-tree -r $group.Ref -- $group.Prefix)
    if ($LASTEXITCODE -ne 0) { throw "Source revision unavailable: $($group.Ref)" }
    $count = 0
    foreach ($entry in $entries) {
        if ($entry -notmatch '^(?:100644|100755) blob ([0-9a-f]{40})\t(.+)$') {
            throw "Unexpected vendor tree entry: $entry"
        }
        $expected = $Matches[1]
        $sourcePath = $Matches[2]
        $relative = $sourcePath.Substring($group.Prefix.Length)
        if ($group.Count -eq 8 -and $relative -notmatch '^(APSecuritySDK-|Android-AliyunFaceGuard-|aliyun-).+\.aar$') {
            continue
        }
        $target = Join-Path (Join-Path $projectRoot $group.Target) $relative
        if (!(Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing vendor file: $relative" }
        # --no-filters verifies bytes, including text headers, without line-ending normalization.
        $actual = & git -C $projectRoot hash-object --no-filters -- $target
        if ($LASTEXITCODE -ne 0 -or $actual -ne $expected) { throw "Vendor bytes changed: $relative" }
        $count++
    }
    $localCount = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot $group.Target) -File -Recurse).Count
    if ($count -ne $group.Count -or $localCount -ne $count) { throw "Unexpected vendor file count: $($group.Target)" }
    Write-Output "$($group.Target): $count source blobs match $($group.Ref)"
}

if (!$Apk) { return }
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Get-EntryHash($Entry) {
    $stream = $Entry.Open()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)) }
    finally { $sha.Dispose(); $stream.Dispose() }
}
$apkPath = (Resolve-Path -LiteralPath $Apk).Path
$package = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
$nativeCount = 0
$assetCount = 0
try {
    foreach ($aarPath in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'android/app/libs/identity') -Filter '*.aar') {
        $aar = [System.IO.Compression.ZipFile]::OpenRead($aarPath.FullName)
        try {
            foreach ($entry in $aar.Entries) {
                $targetName = $null
                if ($entry.FullName -match '^jni/(arm64-v8a|armeabi-v7a)/.+\.so$') {
                    $targetName = 'lib/' + $entry.FullName.Substring(4)
                    $nativeCount++
                } elseif ($entry.FullName.StartsWith('assets/') -and !$entry.FullName.EndsWith('/')) {
                    $targetName = $entry.FullName
                    $assetCount++
                }
                if (!$targetName) { continue }
                $packaged = $package.GetEntry($targetName)
                if (!$packaged) { throw "APK missing vendor entry: $targetName" }
                if ((Get-EntryHash $entry) -ne (Get-EntryHash $packaged)) {
                    throw "APK vendor bytes changed: $targetName"
                }
            }
        } finally { $aar.Dispose() }
    }
    if ($nativeCount -eq 0 -or $assetCount -eq 0) { throw 'No vendor payload verified' }
    Write-Output "APK: $nativeCount native libraries and $assetCount asset entries match AAR bytes"
} finally { $package.Dispose() }
