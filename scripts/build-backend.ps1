# Packages the backend into backend/lambda.zip: app code + dependencies
# installed for Lambda's actual runtime (Linux/x86_64, Python 3.13,
# Amazon Linux 2023 glibc baseline) rather than whatever OS this script
# happens to run on. Multiple --platform tags are given because different
# packages publish wheels under different (but compatible) manylinux
# tags - pip's cross-platform install mode needs an exact tag match, so
# one tag alone isn't enough to cover every dependency.
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$backendDir = "$repoRoot/backend"
$buildDir = "$backendDir/build"
$zipPath = "$backendDir/lambda.zip"

if (Test-Path $buildDir) { Remove-Item -Recurse -Force $buildDir }
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
New-Item -ItemType Directory -Path $buildDir | Out-Null

pip install `
    --platform manylinux2014_x86_64 `
    --platform manylinux_2_17_x86_64 `
    --platform manylinux_2_28_x86_64 `
    --only-binary=:all: `
    --python-version 3.13 `
    --target $buildDir `
    -r "$backendDir/requirements.txt"
if ($LASTEXITCODE -ne 0) { throw "pip install failed" }

Copy-Item `
    "$backendDir/main.py", "$backendDir/config.py", "$backendDir/database.py", `
    "$backendDir/security.py", "$backendDir/lambda_handler.py", "$backendDir/lambda_migrate.py", `
    "$backendDir/seed.py", "$backendDir/alembic.ini" `
    -Destination $buildDir
# Merge our migrations into build/alembic/, not copy-as-new: pip already
# created that exact directory name (the alembic *library* on PyPI is
# also named "alembic", colliding with our migrations folder, which
# follows Alembic's own naming convention). File-by-file merge is safe
# today since none of our filenames (env.py, versions/, script.py.mako)
# match the library's own top-level files - worth re-checking if a
# future alembic upgrade ever adds one that does.
Copy-Item "$backendDir/alembic/*" -Destination "$buildDir/alembic" -Recurse -Exclude "__pycache__"

Compress-Archive -Path "$buildDir/*" -DestinationPath $zipPath -Force
Remove-Item -Recurse -Force $buildDir

$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host "Built $zipPath ($sizeMB MB)"
