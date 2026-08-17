"""Lambda entrypoint for the API - what API Gateway actually invokes.

Separate from main.py's `lifespan` handler (which only runs for local
uvicorn dev): Lambda has no equivalent of a one-time "server startup"
moment, so if Mangum drove FastAPI's lifespan events the normal way it
would re-run pool.open() on every single invocation, not once. Instead we
open the pool here, at module-import time - Lambda's "cold start", which
runs once per container and is reused across warm invocations, same
effect as a real server startup hook.
"""

from mangum import Mangum

from database import pool
from main import app

pool.open()

# lifespan="off": pool lifecycle is handled above, not through FastAPI's
# startup/shutdown events - see the module docstring for why.
handler = Mangum(app, lifespan="off")
