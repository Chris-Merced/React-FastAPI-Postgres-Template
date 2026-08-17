# Builds the frontend with the real API Gateway URL baked in, syncs it to
# S3, and invalidates CloudFront's cache so the new build is actually
# served (without this, CloudFront may keep serving old cached files).
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

Push-Location "$repoRoot/infra"
try {
    $apiUrl = (terraform output -raw api_url).TrimEnd('/')
    $bucket = terraform output -raw frontend_bucket_name
    $distributionId = terraform output -raw cloudfront_distribution_id
    $frontendUrl = terraform output -raw frontend_url
} finally {
    Pop-Location
}

Push-Location "$repoRoot/frontend"
try {
    # Embed the API URL into the frontend build
    $env:VITE_API_URL = $apiUrl
    Write-Host "Building frontend (VITE_API_URL=$apiUrl)..." -ForegroundColor Cyan
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }

    # Sync and delete any previous files
    Write-Host "Syncing to s3://$bucket/ ..." -ForegroundColor Cyan
    aws s3 sync dist/ "s3://$bucket/" --delete

    # Invalidate CloudFront cache so the new build is actually served
    Write-Host "Invalidating CloudFront cache..." -ForegroundColor Cyan
    aws cloudfront create-invalidation --distribution-id $distributionId --paths "/*" | Out-Null
} finally {
    Pop-Location
}

Write-Host "`nDone: $frontendUrl" -ForegroundColor Green
