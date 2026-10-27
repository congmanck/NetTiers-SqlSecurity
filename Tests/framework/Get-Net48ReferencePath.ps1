param([string]$RepositoryRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent))
$ErrorActionPreference = 'Stop'
$installed = Join-Path ${env:ProgramFiles(x86)} 'Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8'
$portable = Join-Path $RepositoryRoot '.framework-reference\net48\build\.NETFramework\v4.8'
foreach ($candidate in @($installed, $portable)) {
    if (Test-Path -LiteralPath (Join-Path $candidate 'mscorlib.dll')) { return $candidate }
}
throw 'Missing .NET Framework 4.8 reference assemblies. Install the Developer Pack or run Restore-Net48ReferenceAssemblies.ps1.'
