# Packages the backend and applies the Terraform change that deploys it.
# Both Lambda functions' source_code_hash is computed from
# backend/lambda.zip (see infra/lambda.tf) - built fresh here, before
# `terraform apply` runs, so Terraform sees a real diff whenever the code
# actually changed and redeploys automatically.
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

& "$PSScriptRoot/build-backend.ps1"
if ($LASTEXITCODE -ne 0) { throw "build-backend.ps1 failed" }

Push-Location "$repoRoot/infra"
try {
    Write-Host "Applying Terraform (redeploys both Lambda functions if the code changed)..." -ForegroundColor Cyan
    terraform apply
} finally {
    Pop-Location
}

Write-Host "`nDone. If this deploy changed alembic/versions/ or seed.py, also run the" -ForegroundColor Yellow
Write-Host "migration command documented in README.md under 'Deploying to AWS'." -ForegroundColor Yellow
