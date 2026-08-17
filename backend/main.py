from contextlib import asynccontextmanager

import jwt
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm

from config import ALLOWED_ORIGINS
from database import pool
from security import create_access_token, decode_access_token, verify_password

# Tells FastAPI's auto-generated docs (and any client) that tokens are
# obtained by POSTing credentials to /login.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Local (uvicorn) dev only: opens the pool once when the dev server
    # starts, closes it once when it stops. pool.open()/close() are sync
    # calls (ConnectionPool, not AsyncConnectionPool) - fine to call
    # directly from inside this async context manager, they just block
    # briefly. Lambda does NOT use this - see lambda_handler.py for why.
    pool.open()
    yield
    pool.close()


app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/login")
def login(form: OAuth2PasswordRequestForm = Depends()):
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, hashed_password FROM users WHERE email = %s",
                (form.username,),
            )
            row = cur.fetchone()

    if row is None or not verify_password(form.password, row[1]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    user_id, _ = row
    token = create_access_token(subject=str(user_id))
    return {"access_token": token, "token_type": "bearer"}


def get_current_user_id(token: str = Depends(oauth2_scheme)) -> int:
    try:
        return int(decode_access_token(token))
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )


@app.get("/me")
def read_current_user(user_id: int = Depends(get_current_user_id)):
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, email FROM users WHERE id = %s", (user_id,))
            row = cur.fetchone()

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    return {"id": row[0], "email": row[1]}
