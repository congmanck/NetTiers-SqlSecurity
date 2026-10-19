$ErrorActionPreference = 'Stop'
$base = Split-Path $PSScriptRoot -Parent
$output = Join-Path (Split-Path $base -Parent) ('NetTiers-api-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output | Out-Null
$sdkRoot = Join-Path $env:ProgramFiles 'dotnet\sdk'
$compiler = Get-ChildItem $sdkRoot -Directory | Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'Roslyn\bincore\csc.dll' } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (!$compiler) { throw 'Install .NET SDK for Roslyn.' }
$framework = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319'
$references = @('mscorlib','System','System.Core','System.Data','System.Security','System.Configuration','System.Xml') | ForEach-Object { '/reference:' + (Join-Path $framework ($_ + '.dll')) }
$master = [IO.File]::ReadAllText((Join-Path $base 'NetTiers.cst'))
if ($master -notmatch '"ConnectionCipher.cs"') { throw 'Cipher generator registration missing.' }
if ($master -notmatch '"SqlConfiguration.cs"' -or !$master.Contains('AddFileNode(commonNode, "Security\\" + securityFile)')) { throw 'Generator project registration missing.' }
$projectTemplate = [IO.File]::ReadAllText((Join-Path $base 'VisualStudio\vsnet2005.project.cst'))
if (!$projectTemplate.Contains('Security\ConnectionCipher.cs')) { throw 'Cipher Compile Include missing.' }
foreach ($name in @('ConnectionCipher','LegacyConnectionDecoder','SqlConfiguration','DpapiConnectionFile')) {
    $canonical = [IO.File]::ReadAllText((Join-Path $base ('..\HocPhiChung2026\Accounts.Data\Security\' + $name + '.cs'))).Replace('Accounts.Data','__DAL_NAMESPACE__').Replace("`r`n","`n")
    $asset = [IO.File]::ReadAllText((Join-Path $base ('SecuritySource\' + $name + '.cs.txt'))).Replace("`r`n","`n")
    if ($canonical -cne $asset) { throw "Security source drift: $name" }
}
foreach ($template in Get-ChildItem $base -Recurse -Filter '*.cst') {
    $text = [IO.File]::ReadAllText($template.FullName)
    if ($text.Contains('SqlSessions.ExportLegacy(')) { throw "Legacy getter remains: $($template.FullName)" }
}
foreach ($namespace in @('Accounts.Data','PortingTrial.Data')) {
    $folder = Join-Path $output $namespace
    New-Item -ItemType Directory -Path $folder | Out-Null
    $sources = foreach ($name in @('ConnectionCipher','SqlSession','SqlConfiguration','ConnectionToken','DpapiConnectionFile','LegacyConnectionDecoder')) {
        $asset = [IO.File]::ReadAllText((Join-Path $base ('SecuritySource\' + $name + '.cs.txt')))
        if (!$asset.Contains('__DAL_NAMESPACE__')) { throw "Namespace marker missing: $name" }
        $path = Join-Path $folder ($name + '.cs')
        [IO.File]::WriteAllText($path, $asset.Replace('__DAL_NAMESPACE__', $namespace), [Text.UTF8Encoding]::new($false))
        $path
    }
    $library = Join-Path $folder 'SecurityCore.dll'
    & dotnet $compiler /nologo /nostdlib+ /target:library "/out:$library" @references @sources
    if ($LASTEXITCODE -ne 0) { throw "Template source compilation failed: $namespace" }
    $test = Join-Path $folder 'Tests.cs'
    $code = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ApiSurfaceTests.cs.txt')).Replace('__DAL_NAMESPACE__', $namespace)
    [IO.File]::WriteAllText($test, $code, [Text.UTF8Encoding]::new($false))
    $exe = Join-Path $folder 'Tests.exe'
    & dotnet $compiler /nologo /nostdlib+ /target:exe "/out:$exe" @references "/reference:$library" $test
    if ($LASTEXITCODE -ne 0) { throw "Template probe compilation failed: $namespace" }
    & $exe
    if ($LASTEXITCODE -ne 0) { throw "Template tests failed: $namespace" }
    Write-Output "TEMPLATE_API_PASS: $namespace"
}
Write-Output 'CodeSmith engine schema generation not run; source materialization and compilation tested.'
