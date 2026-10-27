param(
    [string] $CodeSmith = 'C:\Program Files (x86)\CodeSmith\v7.1\cs.exe',
    [string] $MSBuild = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe'
)
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
if ($result -notmatch 'HOCPHI_INTEGRATION_PASS') { throw 'Missing HocPhi integration generation checks.' }
if ($result -notmatch 'HOCPHI_TLS_UPGRADE_PASS') { throw 'Missing previous-provider upgrade checks.' }
if (!(Test-Path -LiteralPath $MSBuild)) { throw 'MSBuild is required to verify generated integration project items.' }
foreach ($scenario in @(
    @('Data', 'Accounts.Data', 'Security\PasswordStoragePolicy.user.cs'),
    @('SqlClient', 'Accounts.Data.SqlClient', 'SqlTaiKhoanProvider.PasswordSecurity.user.cs')
)) {
    $projectDirectory = Join-Path $folder ('HocPhiIntegration\' + $scenario[1])
    $generatedProject = Join-Path $projectDirectory ($scenario[1] + '.csproj')
    $document = [Xml.XmlDocument]::new()
    $document.Load((Join-Path $folder ($scenario[0] + '-v4_8-True.csproj')))
    $namespace = $document.DocumentElement.NamespaceURI
    $target = $document.CreateElement('Target', $namespace)
    $target.SetAttribute('Name', 'VerifyPasswordIntegration')
    $items = $document.CreateElement('ItemGroup', $namespace)
    $item = $document.CreateElement('PasswordIntegrationItem', $namespace)
    $item.SetAttribute('Include', '@(Compile)')
    $item.SetAttribute('Condition', "'%(Compile.Identity)' == '$($scenario[2])'")
    $null = $items.AppendChild($item)
    $null = $target.AppendChild($items)
    $errorTask = $document.CreateElement('Error', $namespace)
    $errorTask.SetAttribute('Condition', "'@(PasswordIntegrationItem->Count())' != '1'")
    $errorTask.SetAttribute('Text', 'Expected exactly one compiled password integration file.')
    $null = $target.AppendChild($errorTask)
    $null = $document.DocumentElement.AppendChild($target)
    $document.Save($generatedProject)
    & $MSBuild $generatedProject /t:VerifyPasswordIntegration /nologo /v:minimal
    if ($LASTEXITCODE -ne 0) { throw "Integration file is not included exactly once: $($scenario[1])" }
    Write-Output "HOCPHI_PROJECT_ITEMS_PASS: $($scenario[1])"
}
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
