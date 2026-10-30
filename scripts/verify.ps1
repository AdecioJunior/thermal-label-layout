param([string]$compilerPath = 'fpc')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'build.ps1') -compilerPath $compilerPath
Push-Location $projectRoot
try {
    & './build/label-tests.exe'
    if ($LASTEXITCODE -ne 0) { throw 'Testes falharam.' }
    foreach ($columns in @(3, 5, 6)) {
        & './build/label-demo.exe' "examples/labels-$columns.lay" 'examples/sample-data.ini' "output/columns-$columns" '203' '2'
        if ($LASTEXITCODE -ne 0) { throw "Falha no exemplo de $columns colunas." }
    }
} finally { Pop-Location }
