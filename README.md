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
