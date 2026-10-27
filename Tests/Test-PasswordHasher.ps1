param([string] $CodeSmith = 'C:\Program Files (x86)\CodeSmith\v7.1\cs.exe')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!(Test-Path -LiteralPath $CodeSmith)) { throw 'CodeSmith Generator 7.1 is required for this engine test.' }
$folder = Join-Path $PSScriptRoot ('.work/password-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Force -Path $folder
$escape = [Security.SecurityElement]
$project = Join-Path $folder 'Password.csp'
$xml = '<codeSmith xmlns="http://www.codesmithtools.com/schema/csp.xsd"><propertySets><propertySet name="Password" template="' + $escape::Escape((Join-Path $PSScriptRoot 'PasswordHasherProbe.cst')) + '" output="' + $escape::Escape((Join-Path $folder 'result.txt')) + '"><property name="TrialOutput">' + $escape::Escape($folder) + '</property></propertySet></propertySets></codeSmith>'
[IO.File]::WriteAllText($project, $xml, [Text.UTF8Encoding]::new($true))
& $CodeSmith $project /nologo
if ($LASTEXITCODE -ne 0) { throw 'Password template engine test failed.' }
$result = Get-Content -Raw -LiteralPath (Join-Path $folder 'result.txt')
if (([regex]::Matches($result, 'PASSWORD_ASSET_PASS')).Count -ne 2 -or ([regex]::Matches($result, 'PROJECT_FRAMEWORK_PASS')).Count -ne 24) { throw 'Incomplete generation test matrix.' }
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe'
foreach ($namespace in @('Accounts.Data', 'PortingTrial.Data')) {
    $source = Join-Path $folder "$namespace/Security/PasswordHasher.cs"
    $fixture = Join-Path $folder "$namespace/PasswordHasherTests.cs"
    $test = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'PasswordHasherTests.cs.txt')).Replace('__DAL_NAMESPACE__', $namespace)
    [IO.File]::WriteAllText($fixture, $test, [Text.UTF8Encoding]::new($true))
    foreach ($platform in @('AnyCPU', 'x86')) {
        $exe = Join-Path $folder "$namespace/PasswordHasherTests.$platform.exe"
        & $compiler /nologo /target:exe "/platform:$platform" "/out:$exe" $source $fixture
        if ($LASTEXITCODE -ne 0) { throw "Generated hasher did not compile: $namespace $platform" }
        & $exe
        if ($LASTEXITCODE -ne 0) { throw "Generated hasher tests failed: $namespace $platform" }
    }
}
Write-Output $result
Write-Output "PASSWORD_TEMPLATE_PASS: real engine compile, asset emission, 24 project renders, 4 generated-source test runs. Output: $folder"
Write-Output 'No database connection, SQL execution, production profile changes or production regeneration.'
