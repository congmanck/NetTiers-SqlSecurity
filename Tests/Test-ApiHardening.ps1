$ErrorActionPreference = 'Stop'
$base = Split-Path $PSScriptRoot -Parent
$output = Join-Path (Split-Path $base -Parent) ('NetTiers-api-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output | Out-Null
$sdkRoot = Join-Path $env:ProgramFiles 'dotnet\sdk'
$compiler = Get-ChildItem $sdkRoot -Directory | Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'Roslyn\bincore\csc.dll' } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (!$compiler) { throw 'Install .NET SDK for Roslyn.' }
$framework = & (Join-Path $PSScriptRoot 'framework\Get-Net48ReferencePath.ps1')
$references = @('mscorlib','System','System.Core','System.Data','System.Security','System.Configuration','System.Xml') | ForEach-Object { '/reference:' + (Join-Path $framework ($_ + '.dll')) }
$master = [IO.File]::ReadAllText((Join-Path $base 'NetTiers.cst'))
if ($master -notmatch '"ConnectionCipher.cs"') { throw 'Cipher generator registration missing.' }
if ($master -notmatch '"SqlConfiguration.cs"' -or !$master.Contains('AddFileNode(commonNode, "Security\\" + securityFile)')) { throw 'Generator project registration missing.' }
$projectTemplate = [IO.File]::ReadAllText((Join-Path $base 'VisualStudio\vsnet2005.project.cst'))
$securityFilesMatch = [regex]::Match($master, 'string\[\] securityFiles = new string\[\] \{(?<files>[^}]+)\}')
if (!$securityFilesMatch.Success) { throw 'Security generator file list missing.' }
foreach ($fileMatch in [regex]::Matches($securityFilesMatch.Groups['files'].Value, '"(?<name>[^"]+\.cs)"')) {
    $name = $fileMatch.Groups['name'].Value
    $include = '<Compile Include="<%=DALSubFolder%>Security\' + $name + '"'
    if (!$projectTemplate.Contains($include)) { throw "Security Compile Include missing: $name" }
}
foreach ($name in @('ConnectionCipher','LegacyConnectionDecoder','SqlConfiguration','SqlEncryptionUpgrade','DpapiConnectionFile')) {
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
    $sources = foreach ($name in @('ConnectionCipher','SqlSession','SqlConfiguration','SqlEncryptionUpgrade','ConnectionToken','DpapiConnectionFile','LegacyConnectionDecoder')) {
        $asset = [IO.File]::ReadAllText((Join-Path $base ('SecuritySource\' + $name + '.cs.txt')))
        if (!$asset.Contains('__DAL_NAMESPACE__')) { throw "Namespace marker missing: $name" }
        $path = Join-Path $folder ($name + '.cs')
        [IO.File]::WriteAllText($path, $asset.Replace('__DAL_NAMESPACE__', $namespace), [Text.UTF8Encoding]::new($false))
        $path
    }
    $library = Join-Path $folder 'SecurityCore.dll'
    $marker = Join-Path $folder 'Framework48.cs'
    '[assembly: System.Runtime.Versioning.TargetFramework(".NETFramework,Version=v4.8")]' | Set-Content -LiteralPath $marker -Encoding UTF8
    $sources = @($sources) + $marker
    & dotnet $compiler /nologo /nostdlib+ /target:library "/out:$library" @references @sources
    if ($LASTEXITCODE -ne 0) { throw "Template source compilation failed: $namespace" }
    $test = Join-Path $folder 'Tests.cs'
    $code = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ApiSurfaceTests.cs.txt')).Replace('__DAL_NAMESPACE__', $namespace)
    [IO.File]::WriteAllText($test, $code, [Text.UTF8Encoding]::new($false))
    $exe = Join-Path $folder 'Tests.exe'
    & dotnet $compiler /nologo /nostdlib+ /target:exe "/out:$exe" @references "/reference:$library" $test $marker
    if ($LASTEXITCODE -ne 0) { throw "Template probe compilation failed: $namespace" }
    '<configuration><startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8" /></startup></configuration>' | Set-Content -LiteralPath ($exe + '.config') -Encoding UTF8
    & $exe
    if ($LASTEXITCODE -ne 0) { throw "Template tests failed: $namespace" }
    Write-Output "TEMPLATE_API_PASS: $namespace"
}
Write-Output 'CodeSmith engine schema generation not run; source materialization and compilation tested.'
