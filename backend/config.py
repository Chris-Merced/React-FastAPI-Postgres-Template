import os

from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.environ["DATABASE_URL"]
JWT_SECRET = os.environ["JWT_SECRET"]
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = 60

# Frontend and backend are different origins in prod (CloudFront vs. API
# Gateway) - unlike local dev, where Vite's proxy keeps everything
# same-origin and no CORS config is needed at all. Comma-separated list;
# defaults to the local Vite dev server so nothing breaks if this var is
# unset locally.
ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "http://localhost:5173").split(",")
