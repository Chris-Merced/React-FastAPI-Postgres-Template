import asyncio
import sys
from contextlib import asynccontextmanager

import jwt
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm

from database import pool
from security import create_access_token, decode_access_token, verify_password

# psycopg3's async mode needs asyncio's SelectorEventLoop; Windows defaults
# to ProactorEventLoop instead, which isn't compatible. Must be set before
# uvicorn creates the event loop, making it the first thing in this module.
#
# Allows Uvicorn to use SelectorEventLoop explicitly via
# Uvicorn's --loop flag (see run --loop none
# in README)
if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

# Tells FastAPI's auto-generated docs (and any client) that tokens are
# obtained by POSTing credentials to /login.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Open the connection pool once when the app starts, close it once when
    # the app shuts down - not per-request.
    await pool.open()
    yield
    await pool.close()


app = FastAPI(lifespan=lifespan)


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/login")
async def login(form: OAuth2PasswordRequestForm = Depends()):
    async with pool.connection() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT id, hashed_password FROM users WHERE email = %s",
                (form.username,),
            )
            row = await cur.fetchone()

    if row is None or not verify_password(form.password, row[1]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    user_id, _ = row
    token = create_access_token(subject=str(user_id))
    return {"access_token": token, "token_type": "bearer"}


async def get_current_user_id(token: str = Depends(oauth2_scheme)) -> int:
    try:
        return int(decode_access_token(token))
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )


@app.get("/me")
async def read_current_user(user_id: int = Depends(get_current_user_id)):
    async with pool.connection() as conn:
        async with conn.cursor() as cur:
            await cur.execute("SELECT id, email FROM users WHERE id = %s", (user_id,))
            row = await cur.fetchone()

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    return {"id": row[0], "email": row[1]}
