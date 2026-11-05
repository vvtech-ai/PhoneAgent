param([Parameter(Mandatory=$true)][string]$SkillReferences, [string]$Feature='auth')
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$schema = Get-Content (Join-Path $SkillReferences 'artifacts.schema.json') -Raw | ConvertFrom-Json -AsHashtable
$types = @{
    'SourceSnapshot' = 'SourceSnapshot'; 'DesignTree' = 'DesignTree'
    'AssetManifest' = 'AssetManifest'; 'NormalizedDesignTree' = 'DesignTree'
    'updated-AssetManifest' = 'AssetManifest'; 'component-tree' = 'ComponentTree'
    'PageStateGraph' = 'PageStateGraph'; 'RouteGraph' = 'RouteGraph'
    'ActionableControlInventory' = 'ActionableControlInventory'; 'InteractionMap' = 'InteractionMap'
    'AutoValidationPlan' = 'AutoValidationPlan'; 'AutoValidationResult' = 'AutoValidationResult'
}
foreach ($entry in $types.GetEnumerator()) {
    $selected = @{'$schema'=$schema.'$schema'; '$defs'=$schema.'$defs'; '$ref'="#/`$defs/$($entry.Value)"}
    $json = Get-Content (Join-Path $root "design/$Feature/$($entry.Key).json") -Raw
    if (-not (Test-Json -Json $json -Schema ($selected | ConvertTo-Json -Depth 100))) {
        throw "Invalid artifact: $($entry.Key)"
    }
    Write-Output "$($entry.Key): schema valid"
}
$config = Get-Content (Join-Path $root "design/$Feature/TargetAppConfig.json") -Raw
if (-not (Test-Json -Json $config -SchemaFile (Join-Path $SkillReferences 'target-app-config.schema.json'))) {
    throw 'Invalid TargetAppConfig'
}
Write-Output 'TargetAppConfig: schema valid'
