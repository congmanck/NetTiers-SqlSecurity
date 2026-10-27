param([string]$RepositoryRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent))
$ErrorActionPreference = 'Stop'
$folder = Join-Path $RepositoryRoot '.framework-reference\net48'
$reference = Join-Path $folder 'build\.NETFramework\v4.8\mscorlib.dll'
if (!(Test-Path -LiteralPath $reference)) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $package = Join-Path $folder 'reference-assemblies.zip'
    Invoke-WebRequest -Uri 'https://api.nuget.org/v3-flatcontainer/microsoft.netframework.referenceassemblies.net48/1.0.3/microsoft.netframework.referenceassemblies.net48.1.0.3.nupkg' -OutFile $package
    Expand-Archive -LiteralPath $package -DestinationPath $folder -Force
    if (!(Test-Path -LiteralPath $reference)) { throw 'The reference assemblies package is incomplete.' }
}
Write-Output "NET48_REFERENCE_ASSEMBLIES=$reference"
