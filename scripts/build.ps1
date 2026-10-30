param([string]$compilerPath = 'fpc')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDirectory = Join-Path $projectRoot 'build'
$unitDirectory = Join-Path $buildDirectory 'units'
New-Item -ItemType Directory -Force -Path $unitDirectory | Out-Null
$sourceDirectory = Join-Path $projectRoot 'src'
& $compilerPath '-Mdelphi' '-Sh' '-gl' '-Ci' '-Cr' '-Co' "-Fu$sourceDirectory" "-FU$unitDirectory" "-FE$buildDirectory" '-olabel-demo.exe' (Join-Path $projectRoot 'labelDemo.lpr')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar demonstrador.' }
& $compilerPath '-Mdelphi' '-Sh' '-gl' '-Ci' '-Cr' '-Co' "-Fu$sourceDirectory" "-FU$unitDirectory" "-FE$buildDirectory" '-olabel-tests.exe' (Join-Path $projectRoot 'tests/labelTests.dpr')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar testes.' }
