from psycopg_pool import AsyncConnectionPool

from config import DATABASE_URL

# open=False: we open/close this explicitly in main.py's lifespan handler,
# tied to the app actually starting up and shutting down.
pool = AsyncConnectionPool(DATABASE_URL, open=False)
