param([ValidateRange(1024, 65535)][int]$Port = 8501)

$ErrorActionPreference = 'Stop'
$experimentPython = Join-Path $PSScriptRoot '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $experimentPython)) {
    throw 'Create ai/.venv and install ai/requirements-ui.txt first. See ai/README.md.'
}
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
& $experimentPython -m streamlit run (Join-Path $PSScriptRoot 'playground.py') --server.address 127.0.0.1 --server.port $Port --server.headless true --browser.gatherUsageStats false --client.toolbarMode minimal --theme.base light --theme.primaryColor '#C74700' --theme.backgroundColor '#FFFFFF' --theme.secondaryBackgroundColor '#F7F8FA' --theme.textColor '#111111'
