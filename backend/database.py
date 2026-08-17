from psycopg_pool import ConnectionPool

from config import DATABASE_URL

# Sync pool, not async: Lambda gives each warm container one request at a
# time anyway (no in-process concurrency to multiplex), and a sync pool
# never binds itself to an event loop the way AsyncConnectionPool does -
# which matters because Mangum creates a fresh event loop on every single
# Lambda invocation, and a pool bound to invocation #1's loop breaks on
# invocation #2 when the (still-warm) container reuses this same object.
# min_size/max_size kept small: every concurrent Lambda container gets its
# own pool, and RDS has a limited max_connections ceiling to share across
# all of them.
#
# open=False: opened explicitly - via FastAPI's lifespan for local uvicorn
# runs (see main.py), or once at cold start for Lambda (see
# lambda_handler.py). Never opened per-request either way.
pool = ConnectionPool(DATABASE_URL, min_size=1, max_size=2, open=False)
