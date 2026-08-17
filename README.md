# React-FastAPI-Postgres-Template

Barebones JWT-authenticated login: FastAPI + psycopg3 + Postgres backend, React frontend.

## Backend setup

```powershell
cd backend
python -m venv venv
.\venv\Scripts\pip.exe install -r requirements.txt
```

Copy `.env.example` to `.env` and fill in real values (a fresh `JWT_SECRET` at minimum -
generate one with `python -c "import secrets; print(secrets.token_hex(32))"`).

Start Postgres (from the repo root):

```powershell
docker compose up -d
```

Run migrations to create the schema:

```powershell
cd backend
.\venv\Scripts\python.exe -m alembic upgrade head
```

Then seed a test login (`test@example.com` / `password123`):

```powershell
.\venv\Scripts\python.exe seed.py
```

Run the API:

```powershell
.\venv\Scripts\python.exe -m uvicorn main:app --reload --loop none
```

**Windows note:** `--loop none` is required. Uvicorn defaults to Windows'
`ProactorEventLoop`, which psycopg3's async mode can't run on (it needs
`SelectorEventLoop`). `--loop none` lets `main.py`'s own event-loop-policy
override take effect instead. Without it, every DB-touching endpoint times
out after 30s with `psycopg_pool.PoolTimeout`. This is Windows-dev-only —
Linux (including wherever this deploys) doesn't have the issue.

## Database migrations (Alembic)

Schema changes are versioned migrations under `backend/alembic/versions/`,
applied with `alembic upgrade head`. No ORM/autogenerate here - this project
uses psycopg3 directly (see `backend/database.py`), so migrations are
written by hand with raw SQL via `op.execute()`.

Create a new migration:

```powershell
cd backend
.\venv\Scripts\python.exe -m alembic revision -m "describe the change"
```

Fill in `upgrade()` (and `downgrade()`, its exact reverse) in the generated
file under `alembic/versions/`, then apply it:

```powershell
.\venv\Scripts\python.exe -m alembic upgrade head
```

Other useful commands: `alembic current` (what revision is the DB on),
`alembic history` (full migration chain), `alembic downgrade -1` (undo the
most recent migration).

The connection string comes from `DATABASE_URL` in `.env` (via
`backend/config.py`) - same single source of truth used everywhere else in
this project, so there's nothing migration-specific to reconfigure when
this eventually points at RDS instead of local Docker Postgres.

## Postgres port

`docker-compose.yml` maps Postgres to host port **5433**, not the default
5432 — this avoids clashing with any native/other local Postgres install.
Connect at `localhost:5433`.

## Frontend setup

```powershell
cd frontend
npm install
npm run dev
```

Opens on `http://localhost:5173`. The dev server proxies any `/api/*`
request to the FastAPI backend on port 8000 (see `vite.config.ts`) — the
frontend never hardcodes the backend's URL, and there's no CORS config
needed since requests stay same-origin from the browser's point of view.

Log in with the seeded test user: `test@example.com` / `password123`.

Run both backend and frontend dev servers (plus `docker compose up -d`)
simultaneously to use the app locally.

## Deploying to AWS

Infrastructure (VPC, RDS, Lambda, API Gateway, S3/CloudFront) is defined
in `infra/` with Terraform. Applying infra changes is the normal Terraform
flow:

```powershell
cd infra
terraform plan -out=tfplan
terraform apply tfplan
```

Two scripts under `scripts/` handle the recurring deploy tasks - each is
one command, run from the repo root. (`scripts/build-backend.ps1` is a
third, lower-level script that `deploy-backend.ps1` calls internally -
see the note below.)

### Deploying new backend code

```powershell
./scripts/deploy-backend.ps1
```

The backend deploys as a plain Lambda **zip** package, not a container
image - our dependencies are ~60MB unzipped, well under Lambda's 250MB
zip limit, so a container image (and everything it drags in: ECR, Docker,
image digests) was unnecessary complexity for an app this size. This
script (`scripts/build-backend.ps1` under the hood) installs dependencies
built for Lambda's actual runtime (Linux/x86_64 - cross-compiled from
Windows via `pip install --platform ... --only-binary=:all:`, no Docker
needed) into `backend/lambda.zip`, then runs `terraform apply`.
Terraform's built-in `source_code_hash` (see `infra/lambda.tf`) hashes
that zip and redeploys both Lambda functions whenever it changes - no
custom change-detection needed, unlike the image-digest workaround a
container image would have required.

### Running migrations (and seeding) against RDS

RDS lives in a private subnet with no path in from outside the VPC - not
from your machine, not from anywhere but inside the VPC itself (see
`infra/rds.tf`). Local `alembic upgrade head` / `seed.py` only ever reach
the local Docker Postgres, never RDS. Reaching RDS at all means invoking
`rfp-template-migrate` instead - a second Lambda function sharing the
same zip as the API, just a different handler (see
`backend/lambda_migrate.py` and `infra/lambda.tf`), running *inside* the
VPC. It's never wired to API Gateway, so it's unreachable from the public
internet - this invoke is the only way in:

```powershell
# Migrate only:
aws lambda invoke --function-name rfp-template-migrate --cli-binary-format raw-in-base64-out --payload '{}' out.json; Get-Content out.json

# Migrate + seed the test login (test@example.com / password123) - the
# insert is idempotent, safe to re-run. Note the backslash-escaped
# quotes - PowerShell's argument handling for native executables (aws.exe
# isn't a PowerShell cmdlet) silently corrupts unescaped embedded double
# quotes in a --payload string.
aws lambda invoke --function-name rfp-template-migrate --cli-binary-format raw-in-base64-out --payload '{\"seed\": true}' out.json; Get-Content out.json
```

Run this after every deploy that changes `alembic/versions/` or
`seed.py` - it's a manual, deliberate step on purpose, not automatic on
every deploy (an unattended schema migration running against a real
database is a real footgun to avoid, not just a shortcut skipped for
time).

### Deploying frontend changes

```powershell
./scripts/deploy-frontend.ps1
```

Builds the frontend with the real API Gateway URL baked in
(`VITE_API_URL`, read at build time - see `frontend/src/App.tsx`; there's
no dev-server proxy in prod), syncs it to S3, and invalidates CloudFront's
cache so the new build is actually served.
