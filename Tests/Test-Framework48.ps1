param([string]$CodeSmith = 'C:\Program Files (x86)\CodeSmith\v7.1\cs.exe')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!(Test-Path -LiteralPath $CodeSmith)) { throw 'CodeSmith Generator 7.1 is required for the engine test.' }
$folder = Join-Path $PSScriptRoot ('.work\framework48-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$project = Join-Path $folder 'Framework48.csp'
$template = Join-Path $PSScriptRoot 'Framework48Probe.cst'
$escape = [System.Security.SecurityElement]
$xml = '<?xml version="1.0" encoding="utf-8"?><codeSmith xmlns="http://www.codesmithtools.com/schema/csp.xsd"><propertySets><propertySet name="Framework48" template="' + $escape::Escape($template) + '" output="' + $escape::Escape((Join-Path $folder 'result.txt')) + '"><property name="TrialOutput">' + $escape::Escape($folder) + '</property></propertySet></propertySets></codeSmith>'
$xml | Set-Content -LiteralPath $project -Encoding UTF8
$hostProfile = Join-Path (Split-Path $root -Parent) 'HocPhiChung2026\NetTiers.csp'
$profileHash = if (Test-Path -LiteralPath $hostProfile) { (Get-FileHash -LiteralPath $hostProfile -Algorithm SHA256).Hash } else { $null }
try {
    & $CodeSmith $project /nologo
    if ($LASTEXITCODE -ne 0) { throw 'CodeSmith framework engine test failed.' }
} finally {
    if ($profileHash -and (!(Test-Path -LiteralPath $hostProfile) -or (Get-FileHash -LiteralPath $hostProfile -Algorithm SHA256).Hash -ne $profileHash)) {
        throw 'The production profile changed during the trial. Inspect and restore from the migration backup before proceeding.'
    }
}
$result = Get-Content -LiteralPath (Join-Path $folder 'result.txt') -Raw
if ($result -notmatch 'MASTER_TEMPLATE_COMPILE_PASS' -or $result -notmatch 'CONFIG_FRAMEWORK_PASS' -or ([regex]::Matches($result, 'PROJECT_FRAMEWORK_PASS')).Count -ne 12) { throw 'Incomplete CodeSmith framework results.' }
Write-Output $result
Write-Output "CODESMITH_NET48_PASS: full master compilation and 12 project render/re-render scenarios. Output: $folder"
Write-Output 'No production profile, schema query, SQL execution or production regeneration was used. Full schema-specific regeneration remains a separate acceptance step.'
